//
//  ExpenseAnalyticsTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

struct ExpenseAnalyticsTests {
    private func expense(amount: String, date: Date) -> Expense {
        Expense(
            documentType: "MANUAL",
            issueDate: date,
            issuerName: "Test",
            totalAmount: Decimal(string: amount)!,
            totalItbms: 0,
            source: .manual
        )
    }

    @Test func fortnightSplitsOnDay15Boundary() {
        let expenses = [
            expense(amount: "10", date: testDate(2026, 9, 15)),
            expense(amount: "20", date: testDate(2026, 9, 16)),
        ]

        let totals = ExpenseAnalytics.totalsByFortnight(for: expenses, year: 2026, month: 9)

        #expect(totals.first(where: { $0.label == "1 – 15" })?.total == 10)
        #expect(totals.first(where: { $0.label == "16 – fin" })?.total == 20)
    }

    @Test func fortnightIgnoresOtherMonthsAndYears() {
        let expenses = [
            expense(amount: "10", date: testDate(2026, 8, 20)),
            expense(amount: "10", date: testDate(2025, 9, 20)),
        ]

        let totals = ExpenseAnalytics.totalsByFortnight(for: expenses, year: 2026, month: 9)

        #expect(totals.allSatisfy { $0.total == 0 })
    }

    @Test func monthlyTotalsGroupByCalendarMonth() {
        let expenses = [
            expense(amount: "10", date: testDate(2026, 9, 1)),
            expense(amount: "5", date: testDate(2026, 9, 30)),
            expense(amount: "7", date: testDate(2026, 10, 1)),
        ]

        let totals = ExpenseAnalytics.totalsByMonth(for: expenses)

        #expect(totals.count == 2)
        #expect(totals.first?.total == 15)
    }

    @Test func yearlyTotalsGroupAcrossTheDecemberBoundary() {
        let expenses = [
            expense(amount: "10", date: testDate(2025, 12, 31)),
            expense(amount: "5", date: testDate(2026, 1, 1)),
        ]

        let totals = ExpenseAnalytics.totalsByYear(for: expenses)

        #expect(totals.first(where: { $0.year == 2025 })?.total == 10)
        #expect(totals.first(where: { $0.year == 2026 })?.total == 5)
    }

    @Test func monthlyTotalsUseAuthorizationDateOverIssueDateAndScanDate() {
        let expense = Expense(
            documentType: "FACTURA",
            issueDate: testDate(2026, 8, 31),
            authorizationDate: testDate(2026, 9, 1),
            issuerName: "Test",
            totalAmount: 10,
            totalItbms: 0,
            source: .dgi,
            scanDate: testDate(2026, 10, 15)
        )

        let totals = ExpenseAnalytics.totalsByMonth(for: [expense])

        #expect(totals.count == 1)
        #expect(totals.first?.month == testDate(2026, 9, 1, hour: 0))
        #expect(totals.first?.total == 10)
    }

    @Test func categoryAndMerchantTotalsSumByRucWithAliasAndBucketUncategorized() throws {
        let context = try makeInMemoryContext()
        context.insert(Merchant(ruc: "111-1-111", name: "EL REY S.A.", alias: "Rey", category: "Comida"))

        let first = Expense(
            documentType: "FACTURA",
            issueDate: testDate(2026, 9, 1),
            issuerRuc: "111-1-111",
            issuerName: "EL REY S.A.",
            totalAmount: 10,
            totalItbms: 0,
            source: .dgi
        )
        let second = Expense(
            documentType: "FACTURA",
            issueDate: testDate(2026, 9, 2),
            issuerRuc: "111-1-111",
            issuerName: "SUPER EL REY, S.A.",
            totalAmount: 5,
            totalItbms: 0,
            source: .dgi
        )
        let manualWithoutCategory = Expense(
            documentType: "MANUAL",
            issueDate: testDate(2026, 9, 3),
            issuerName: "Fonda",
            totalAmount: 7,
            totalItbms: 0,
            source: .manual
        )
        let expenses = [first, second, manualWithoutCategory]
        for expense in expenses {
            context.insert(expense)
        }

        let categories = ExpenseAnalytics.totalsByCategory(for: expenses, in: context)
        let merchants = ExpenseAnalytics.totalsByMerchant(for: expenses, in: context)

        #expect(categories.first(where: { $0.category == "Comida" })?.total == 15)
        #expect(categories.first(where: { $0.category == "Sin categorizar" })?.total == 7)
        #expect(merchants.filter { $0.name == "Rey" }.count == 1)
        #expect(merchants.first(where: { $0.name == "Rey" })?.total == 15)
    }
}
