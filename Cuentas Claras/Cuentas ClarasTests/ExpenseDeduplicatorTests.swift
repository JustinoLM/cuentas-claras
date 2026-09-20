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
}
