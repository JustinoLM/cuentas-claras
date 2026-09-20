//
//  MerchantCategorizationTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

struct MerchantCategorizationTests {
    @Test func categoryForRUCExpenseComesFromMerchant() throws {
        let context = try makeInMemoryContext()
        context.insert(Merchant(ruc: "123-1-1", name: "Test S.A.", category: "Comida"))

        let expense = Expense(
            documentType: "INVOICE",
            issuerRuc: "123-1-1",
            issuerName: "Test S.A.",
            totalAmount: 10,
            totalItbms: 0,
            source: .dgi
        )

        #expect(try MerchantCategorization.category(for: expense, in: context) == "Comida")
    }

    @Test func categoryForManualExpenseComesFromTheExpenseItself() throws {
        let context = try makeInMemoryContext()
        let expense = Expense(
            documentType: "MANUAL",
            issuerName: "Efectivo suelto",
            totalAmount: 10,
            totalItbms: 0,
            category: "Varios",
            source: .manual
        )

        #expect(try MerchantCategorization.category(for: expense, in: context) == "Varios")
    }

    @Test func displayNameFallsBackToIssuerNameWithoutAMerchantRecord() throws {
        let context = try makeInMemoryContext()
        let expense = Expense(
            documentType: "INVOICE",
            issuerRuc: "999-9-9",
            issuerName: "Sin Merchant Todavía",
            totalAmount: 10,
            totalItbms: 0,
            source: .dgi
        )

        #expect(MerchantCategorization.displayName(for: expense, in: context) == "Sin Merchant Todavía")
    }

    // El caso que motivó esto: el alias vive en Merchant, no en cada Expense — cambiarlo en un
    // gasto debe reflejarse en TODOS los que comparten el mismo RUC.
    @Test func settingAliasAppliesToEveryExpenseSharingTheRUC() throws {
        let context = try makeInMemoryContext()
        context.insert(Merchant(ruc: "555-5-5", name: "Inmobiliaria Don Antonio, S.A."))

        let firstVisit = Expense(documentType: "INVOICE", issuerRuc: "555-5-5", issuerName: "Inmobiliaria Don Antonio, S.A.", totalAmount: 10, totalItbms: 0, source: .dgi)
        let secondVisit = Expense(documentType: "INVOICE", issuerRuc: "555-5-5", issuerName: "Inmobiliaria Don Antonio, S.A.", totalAmount: 20, totalItbms: 0, source: .dgi)
        context.insert(firstVisit)
        context.insert(secondVisit)

        let success = MerchantCategorization.setAlias("El Rey", for: firstVisit, in: context)

        #expect(success)
        #expect(MerchantCategorization.displayName(for: firstVisit, in: context) == "El Rey")
        #expect(MerchantCategorization.displayName(for: secondVisit, in: context) == "El Rey")
    }

    // Misma idea que el alias, pero para categoría — ya la cubre 9.3, pero vale la pena
    // confirmarla directamente dado que también pasó por un bug real (ExpenseDetailView leía
    // Expense.category en vez de la categoría resuelta).
    @Test func settingCategoryOnARUCExpenseAppliesToEveryExpenseSharingTheRUC() throws {
        let context = try makeInMemoryContext()
        context.insert(Merchant(ruc: "555-5-5", name: "El Rey"))

        let firstVisit = Expense(documentType: "INVOICE", issuerRuc: "555-5-5", issuerName: "El Rey", totalAmount: 10, totalItbms: 0, source: .dgi)
        let secondVisit = Expense(documentType: "INVOICE", issuerRuc: "555-5-5", issuerName: "El Rey", totalAmount: 20, totalItbms: 0, source: .dgi)
        context.insert(firstVisit)
        context.insert(secondVisit)

        let success = MerchantCategorization.setCategory("Supermercado", for: firstVisit, in: context)

        #expect(success)
        #expect(try MerchantCategorization.category(for: secondVisit, in: context) == "Supermercado")
    }

    @Test func setAliasFailsWithoutAnExistingMerchantRecord() throws {
        let context = try makeInMemoryContext()
        // Sin insertar un Merchant — registerMerchantIfNeeded nunca corrió para este RUC.
        let expense = Expense(documentType: "INVOICE", issuerRuc: "000-0-0", issuerName: "Fantasma", totalAmount: 10, totalItbms: 0, source: .dgi)

        #expect(MerchantCategorization.setAlias("Alias", for: expense, in: context) == false)
    }

    @Test func setAliasIsANoOpForManualExpenses() throws {
        let context = try makeInMemoryContext()
        let expense = Expense(documentType: "MANUAL", issuerName: "Efectivo", totalAmount: 10, totalItbms: 0, source: .manual)

        #expect(MerchantCategorization.setAlias("Alias", for: expense, in: context) == false)
    }
}
