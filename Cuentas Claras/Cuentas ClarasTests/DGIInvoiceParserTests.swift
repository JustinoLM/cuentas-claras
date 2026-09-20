//
//  DGIInvoiceParserTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras

private final class FixtureBundleMarker {}

private func loadFixture(_ name: String) throws -> String {
    let bundle = Bundle(for: FixtureBundleMarker.self)
    let url = try #require(bundle.url(forResource: name, withExtension: "html"))
    return try String(contentsOf: url, encoding: .utf8)
}

struct DGIInvoiceParserTests {

    @Test func parsesValidInvoice() throws {
        let html = try loadFixture("factura_valida")
        let result = try DGIInvoiceParser.parse(html: html)

        guard case .success(let expense) = result else {
            Issue.record("Expected .success, got \(result)")
            return
        }

        #expect(expense.cufe == "FE01200002029164-1-744562-9400072026091900000746370010310000746379")
        #expect(expense.documentType == "INVOICE")
        #expect(expense.invoiceNumber == "0000074637")
        #expect(expense.issuerRuc == "2029164-1-744562")
        #expect(expense.issuerName == "JV PANAMA S.A.")
        #expect(expense.totalAmount == Decimal(string: "12.10"))
        #expect(expense.totalItbms == Decimal(string: "0.00"))
        #expect(expense.totalPaid == Decimal(string: "20.10"))
        #expect(expense.paymentMethod == "Efectivo")
        #expect(expense.source == .dgi)
        #expect(expense.items.count == 2)

        let firstItem = try #require(expense.items.first)
        #expect(firstItem.lineNumber == 1)
        #expect(firstItem.code == "248")
        #expect(firstItem.itemDescription == "Cafe Americano 12 Oz")
        #expect(firstItem.quantity == Decimal(string: "2.00"))
        #expect(firstItem.unitPrice == Decimal(string: "3.35"))
        #expect(firstItem.amount == Decimal(string: "6.70"))
        #expect(firstItem.itbms == Decimal(string: "0.00"))
        #expect(firstItem.isc == nil)
        #expect(firstItem.total == Decimal(string: "6.70"))
    }

    @Test func nonexistentCufeIsNotFound() throws {
        let html = try loadFixture("factura_inexistente")
        let result = try DGIInvoiceParser.parse(html: html)

        guard case .notFound = result else {
            Issue.record("Expected .notFound, got \(result)")
            return
        }
    }

    @Test func malformedCufeIsNotFound() throws {
        let html = try loadFixture("factura_malformada")
        let result = try DGIInvoiceParser.parse(html: html)

        guard case .notFound = result else {
            Issue.record("Expected .notFound, got \(result)")
            return
        }
    }

    // FacturasPorQR response (jwt/digestValue params) — confirms the invoice panel markup is the
    // same as FacturasPorCUFE and those extra params are safe to discard (spec section 4.1).
    @Test func qrEndpointResponseParsesTheSamePanel() throws {
        let html = try loadFixture("factura")
        let result = try DGIInvoiceParser.parse(html: html)

        guard case .success(let expense) = result else {
            Issue.record("Expected .success, got \(result)")
            return
        }

        #expect(expense.cufe == "FE01200002029164-1-744562-9400072026091900000746370010310000746379")
        #expect(expense.issuerRuc == "2029164-1-744562")
        #expect(expense.issuerName == "JV PANAMA S.A.")
        #expect(expense.totalAmount == Decimal(string: "12.10"))
        #expect(expense.items.count == 2)
    }
}
