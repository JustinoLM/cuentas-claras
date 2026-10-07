//
//  CUFEResolution.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

// Salida de `handle`: o hay un mensaje de estado/error para mostrar, o el parseo salió bien y hay
// que mostrar la pantalla de revisión (spec 4.4) antes de guardar nada.
enum CUFEResolutionResult {
    case message(String)
    case needsReview(Expense)
}

// Compartido por Vía 1 (QR) y Vía 2 (CUFE manual) — mismo pipeline de resultados (spec 4.2), solo
// cambia cómo se obtuvo el CUFE.
enum CUFEResolution {
    static func handle(_ outcome: CUFELookupOutcome, cufe: String, in context: ModelContext) -> CUFEResolutionResult {
        switch outcome {
        case .invalidFormat:
            return .message("El CUFE no es válido. Revisa que lo copiaste completo.")

        case .networkError:
            try? PendingLookupQueue.enqueue(cufe: cufe, in: context)
            return .message("Sin conexión. Guardamos la consulta y la reintentaremos cuando vuelvas a tener internet.")

        case .parsingFailed:
            return .message("No se pudo leer la respuesta de la DGI. Inténtalo de nuevo más tarde.")

        case .parsed(.notFound):
            return .message("La DGI no tiene ninguna factura con ese CUFE. Revisa que sea correcto.")

        case .parsed(.unsupported):
            return .message("Esta app todavía no admite este tipo de documento (por ejemplo, una nota de crédito).")

        case .parsed(.success(let expense)):
            if let existing = try? ExpenseDeduplicator.existingExpense(withCufe: cufe, in: context) {
                return .message("Ya tenías esta factura guardada: \(existing.issuerName).")
            }
            return .needsReview(expense)
        }
    }

    // Se llama solo cuando el usuario confirma la pantalla de revisión — el único lugar que ya
    // inserta un Expense parseado, ahora que el éxito del parseo ya no lo hace automático.
    static func confirm(_ expense: Expense, alias: String?, in context: ModelContext) {
        if let issuerRuc = expense.issuerRuc {
            try? MerchantCategorization.registerMerchantIfNeeded(issuerRuc: issuerRuc, issuerName: expense.issuerName, in: context)

            if let alias, !alias.isEmpty {
                var descriptor = FetchDescriptor<Merchant>(predicate: #Predicate { $0.ruc == issuerRuc })
                descriptor.fetchLimit = 1
                if let merchant = (try? context.fetch(descriptor))?.first {
                    merchant.alias = alias
                }
            }
        }

        context.insert(expense)
    }
}
