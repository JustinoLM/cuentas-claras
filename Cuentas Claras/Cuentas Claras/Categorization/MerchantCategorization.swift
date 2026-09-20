//
//  MerchantCategorization.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

enum MerchantCategorization {
    // 9.1: every Expense with a RUC needs a Merchant row to hang a category off of, even before the
    // user categorizes anything — that's what makes it show up in "Negocios sin categorizar".
    static func registerMerchantIfNeeded(issuerRuc: String, issuerName: String, in context: ModelContext) throws {
        var descriptor = FetchDescriptor<Merchant>(predicate: #Predicate { $0.ruc == issuerRuc })
        descriptor.fetchLimit = 1

        guard try context.fetch(descriptor).first == nil else { return }
        context.insert(Merchant(ruc: issuerRuc, name: issuerName))
    }

    // 9.3: category is never duplicated onto Expense for RUC-based expenses — it's resolved by
    // joining Merchant on issuerRuc. Expense.category is only ever the source of truth for manual
    // expenses (no RUC to join on).
    static func category(for expense: Expense, in context: ModelContext) throws -> String? {
        guard let issuerRuc = expense.issuerRuc else {
            return expense.category
        }

        var descriptor = FetchDescriptor<Merchant>(predicate: #Predicate { $0.ruc == issuerRuc })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.category
    }

    // 9.1: el nombre de la DGI es la razón social, no siempre el nombre comercial — la UI siempre
    // muestra el alias del Merchant cuando existe uno.
    static func displayName(for expense: Expense, in context: ModelContext) -> String {
        guard let issuerRuc = expense.issuerRuc else { return expense.issuerName }

        var descriptor = FetchDescriptor<Merchant>(predicate: #Predicate { $0.ruc == issuerRuc })
        descriptor.fetchLimit = 1
        guard let merchant = try? context.fetch(descriptor).first else { return expense.issuerName }
        return merchant.alias ?? merchant.name
    }

    // Cambiar la categoría de un Expense con RUC cambia la de TODO su Merchant (9.3) — nunca se
    // toca Expense.category para esos casos. Para manuales (sin RUC) sí es directo en el Expense.
    static func setCategory(_ category: String?, for expense: Expense, in context: ModelContext) {
        guard let issuerRuc = expense.issuerRuc else {
            expense.category = category
            return
        }

        var descriptor = FetchDescriptor<Merchant>(predicate: #Predicate { $0.ruc == issuerRuc })
        descriptor.fetchLimit = 1
        if let merchant = try? context.fetch(descriptor).first {
            merchant.category = category
        }
    }

    // 9.2: "lista corta que el usuario mismo mantiene" — categorías ya usadas, para sugerir en vez
    // de escribir todo de nuevo cada vez.
    static func existingCategories(in context: ModelContext) -> [String] {
        let merchantCategories = ((try? context.fetch(FetchDescriptor<Merchant>())) ?? []).compactMap(\.category)
        let expenseCategories = ((try? context.fetch(FetchDescriptor<Expense>())) ?? []).compactMap(\.category)
        return Array(Set(merchantCategories).union(expenseCategories)).sorted()
    }

    // 9.1: el alias vive en Merchant, así que solo aplica a gastos con RUC — un gasto manual no
    // tiene Merchant al que amarrarlo (ya tiene su propio nombre editable vía "Editar gasto").
    static func setAlias(_ alias: String?, for expense: Expense, in context: ModelContext) {
        guard let issuerRuc = expense.issuerRuc else { return }

        var descriptor = FetchDescriptor<Merchant>(predicate: #Predicate { $0.ruc == issuerRuc })
        descriptor.fetchLimit = 1
        if let merchant = try? context.fetch(descriptor).first {
            merchant.alias = alias
        }
    }
}
