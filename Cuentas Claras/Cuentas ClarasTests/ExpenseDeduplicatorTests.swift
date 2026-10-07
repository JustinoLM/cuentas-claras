//
//  ExpenseDeduplicatorTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

struct ExpenseDeduplicatorTests {
    @Test func possibleDuplicateMatchesSameDayAndAmount() throws {
        let context = try makeInMemoryContext()
        let existing = Expense(
            documentType: "MANUAL",
            issueDate: testDate(2026, 9, 20),
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            source: .manual
        )
        context.insert(existing)

        let duplicate = try ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: nil,
            issuerName: "El Rey",
            date: testDate(2026, 9, 20),
            totalAmount: 25,
            in: context
        )

        #expect(duplicate === existing)
    }

    @Test func possibleDuplicateDoesNotMatchTheNextDay() throws {
        let context = try makeInMemoryContext()
        let existing = Expense(
            documentType: "MANUAL",
            issueDate: testDate(2026, 9, 20),
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            source: .manual
        )
        context.insert(existing)

        let duplicate = try ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: nil,
            issuerName: "El Rey",
            date: testDate(2026, 9, 21),
            totalAmount: 25,
            in: context
        )

        #expect(duplicate == nil)
    }

    @Test func possibleDuplicateMatchesAcrossTheSameDayAtDifferentHours() throws {
        let context = try makeInMemoryContext()
        let existing = Expense(
            documentType: "MANUAL",
            issueDate: testDate(2026, 9, 20, hour: 23),
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            source: .manual
        )
        context.insert(existing)

        let duplicate = try ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: nil,
            issuerName: "El Rey",
            date: testDate(2026, 9, 20, hour: 1),
            totalAmount: 25,
            in: context
        )

        #expect(duplicate === existing)
    }

    @Test func possibleDuplicateIgnoresADifferentAmount() throws {
        let context = try makeInMemoryContext()
        let existing = Expense(
            documentType: "MANUAL",
            issueDate: testDate(2026, 9, 20),
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            source: .manual
        )
        context.insert(existing)

        let duplicate = try ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: nil,
            issuerName: "El Rey",
            date: testDate(2026, 9, 20),
            totalAmount: 30,
            in: context
        )

        #expect(duplicate == nil)
    }

    @Test func possibleDuplicateIgnoresSameNameWhenBothHaveDifferentRucs() throws {
        let context = try makeInMemoryContext()
        context.insert(Expense(
            documentType: "FACTURA",
            issueDate: testDate(2026, 9, 20),
            issuerRuc: "111-1-111",
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            source: .dgi
        ))

        let duplicate = try ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: "222-2-222",
            issuerName: "El Rey",
            date: testDate(2026, 9, 20),
            totalAmount: 25,
            in: context
        )

        #expect(duplicate == nil)
    }

    @Test func possibleDuplicateComparesNamesIgnoringCaseWhenOneSideHasNoRuc() throws {
        let context = try makeInMemoryContext()
        let existing = Expense(
            documentType: "MANUAL",
            issueDate: testDate(2026, 9, 20),
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            source: .manual
        )
        context.insert(existing)

        let sameNameDifferentCase = try ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: "111-1-111",
            issuerName: "el rey",
            date: testDate(2026, 9, 20),
            totalAmount: 25,
            in: context
        )
        let differentName = try ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: "111-1-111",
            issuerName: "Rey Express",
            date: testDate(2026, 9, 20),
            totalAmount: 25,
            in: context
        )

        #expect(sameNameDifferentCase === existing)
        #expect(differentName == nil)
    }

    @Test func existingExpenseWithCufeFindsOnlyAnExactMatch() throws {
        let context = try makeInMemoryContext()
        let existing = Expense(
            cufe: "FE0120000000000-1-1-2026",
            documentType: "FACTURA",
            issueDate: testDate(2026, 9, 20),
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            source: .dgi
        )
        context.insert(existing)

        let found = try ExpenseDeduplicator.existingExpense(withCufe: "FE0120000000000-1-1-2026", in: context)
        let notFound = try ExpenseDeduplicator.existingExpense(withCufe: "FE0120000000000-1-1-2027", in: context)

        #expect(found === existing)
        #expect(notFound == nil)
    }
}
