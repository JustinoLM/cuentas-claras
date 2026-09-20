//
//  ExpenseAnalytics.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

// Spec section 15: gasto por categoría, por mes y por comercio. Agrupa en memoria — a esta escala
// (gastos personales) no vale la pena resolverlo con predicados/agregados de SwiftData.
enum ExpenseAnalytics {
    struct CategoryTotal: Identifiable {
        let category: String
        let total: Decimal
        var id: String { category }
    }

    struct MonthlyTotal: Identifiable {
        let month: Date  // primer día del mes
        let total: Decimal
        var id: Date { month }
    }

    struct MerchantTotal: Identifiable {
        let name: String
        let total: Decimal
        var id: String { name }
    }

    struct YearlyTotal: Identifiable {
        let year: Int
        let total: Decimal
        var id: Int { year }
    }

    struct MerchantFrequency: Identifiable {
        let name: String
        let visits: Int
        var id: String { name }
    }

    struct FortnightTotal: Identifiable {
        let label: String  // "1 – 15" o "16 – fin"
        let total: Decimal
        var id: String { label }
    }

    // 9.4: lo no categorizado cae en un bucket "Sin categorizar".
    static func totalsByCategory(for expenses: [Expense], in context: ModelContext) -> [CategoryTotal] {
        var totals: [String: Decimal] = [:]
        for expense in expenses {
            let category = (try? MerchantCategorization.category(for: expense, in: context)) ?? nil
            let key = category ?? "Sin categorizar"
            totals[key, default: 0] += expense.totalAmount
        }
        return totals.map { CategoryTotal(category: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }

    // Usa authorizationDate (fecha real de la DGI) cuando existe, si no issueDate (manual), si no
    // scanDate como último recurso — nunca debería faltar todo a la vez.
    static func totalsByMonth(for expenses: [Expense]) -> [MonthlyTotal] {
        let calendar = Calendar.current
        var totals: [Date: Decimal] = [:]
        for expense in expenses {
            let date = expense.authorizationDate ?? expense.issueDate ?? expense.scanDate
            let components = calendar.dateComponents([.year, .month], from: date)
            let monthStart = calendar.date(from: components) ?? date
            totals[monthStart, default: 0] += expense.totalAmount
        }
        return totals.map { MonthlyTotal(month: $0.key, total: $0.value) }.sorted { $0.month < $1.month }
    }

    static func totalsByMerchant(for expenses: [Expense], in context: ModelContext) -> [MerchantTotal] {
        var totals: [String: Decimal] = [:]
        for expense in expenses {
            let name = MerchantCategorization.displayName(for: expense, in: context)
            totals[name, default: 0] += expense.totalAmount
        }
        return totals.map { MerchantTotal(name: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }

    static func totalsByYear(for expenses: [Expense]) -> [YearlyTotal] {
        let calendar = Calendar.current
        var totals: [Int: Decimal] = [:]
        for expense in expenses {
            let date = expense.authorizationDate ?? expense.issueDate ?? expense.scanDate
            let year = calendar.component(.year, from: date)
            totals[year, default: 0] += expense.totalAmount
        }
        return totals.map { YearlyTotal(year: $0.key, total: $0.value) }.sorted { $0.year < $1.year }
    }

    // Cuántas veces compraste en cada negocio, no cuánto — complementa totalsByMerchant.
    static func visitFrequencyByMerchant(for expenses: [Expense], in context: ModelContext) -> [MerchantFrequency] {
        var counts: [String: Int] = [:]
        for expense in expenses {
            let name = MerchantCategorization.displayName(for: expense, in: context)
            counts[name, default: 0] += 1
        }
        return counts.map { MerchantFrequency(name: $0.key, visits: $0.value) }.sorted { $0.visits > $1.visits }
    }

    static func availableYears(for expenses: [Expense]) -> [Int] {
        let calendar = Calendar.current
        let years = expenses.map { calendar.component(.year, from: $0.authorizationDate ?? $0.issueDate ?? $0.scanDate) }
        return Array(Set(years)).sorted(by: >)
    }

    // División de un mes en dos quincenas (1–15, 16–fin) — no es un concepto que exista en el
    // modelo, se calcula al vuelo a partir del día del mes de cada Expense.
    static func totalsByFortnight(for expenses: [Expense], year: Int, month: Int) -> [FortnightTotal] {
        let calendar = Calendar.current
        var firstHalf: Decimal = 0
        var secondHalf: Decimal = 0

        for expense in expenses {
            let date = expense.authorizationDate ?? expense.issueDate ?? expense.scanDate
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            guard components.year == year, components.month == month, let day = components.day else { continue }

            if day <= 15 {
                firstHalf += expense.totalAmount
            } else {
                secondHalf += expense.totalAmount
            }
        }

        return [
            FortnightTotal(label: "1 – 15", total: firstHalf),
            FortnightTotal(label: "16 – fin", total: secondHalf),
        ]
    }
}

extension Decimal {
    // Swift Charts no sabe graficar Decimal directamente — solo se usa para dibujar, nunca para
    // los cálculos en sí (esos ya están hechos en Decimal arriba).
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
