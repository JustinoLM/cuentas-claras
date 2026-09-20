//
//  ExpenseAnalyticsTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras

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
}
