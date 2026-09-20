//
//  CUFEResolution.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

// Compartido por Vía 1 (QR) y Vía 2 (CUFE manual) — mismo pipeline de resultados (spec 4.2), solo
// cambia cómo se obtuvo el CUFE. Devuelve nil cuando el Expense se insertó y la pantalla debe
// cerrarse; cualquier otro caso devuelve un mensaje para mostrar sin cerrar.
enum CUFEResolution {
    static func handle(_ outcome: CUFELookupOutcome, cufe: String, in context: ModelContext) -> String? {
        switch outcome {
        case .invalidFormat:
            return "El CUFE no tiene un formato válido."

        case .networkError:
            try? PendingLookupQueue.enqueue(cufe: cufe, in: context)
            return "No hay conexión. Se guardó para reintentar cuando vuelva la señal."

        case .parsingFailed:
            return "No se pudo leer la respuesta de la DGI."

        case .parsed(.notFound):
            return "No se encontró ninguna factura con ese CUFE."

        case .parsed(.unsupported):
            return "Ese documento no es una factura soportada (por ejemplo, una nota de crédito)."

        case .parsed(.success(let expense)):
            if let existing = try? ExpenseDeduplicator.existingExpense(withCufe: cufe, in: context) {
                return "Ya tenías esta factura guardada: \(existing.issuerName)."
            }

            if let issuerRuc = expense.issuerRuc {
                try? MerchantCategorization.registerMerchantIfNeeded(issuerRuc: issuerRuc, issuerName: expense.issuerName, in: context)
            }
            context.insert(expense)
            return nil
        }
    }
}
