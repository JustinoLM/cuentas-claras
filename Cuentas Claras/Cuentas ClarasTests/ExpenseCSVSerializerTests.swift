//
//  ExpenseCSVSerializerTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

// Anchored to America/Panama regardless of the machine running the tests — the serializer formats
// dates in that fixed timezone (spec section 11), so the input needs to be pinned the same way for
// the expected output string to be deterministic.
private func panamaDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Panama")!
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    components.second = second
    return calendar.date(from: components)!
}

struct ExpenseCSVSerializerTests {
    @Test func headerMatchesFrozenSchema() {
        #expect(ExpenseCSVSerializer.headerLine == [
            "id", "cufe", "documentType", "issueDate", "authorizationDate", "issuerRuc", "issuerName",
            "category", "invoiceNumber", "lineNumber", "itemCode", "itemDescription", "quantity",
            "unitPrice", "unitDiscount", "itemAmount", "itemItbms", "itemTotal", "totalAmount",
            "totalItbms", "paymentMethod", "totalPaid", "source", "scanDate", "referencedCufe",
        ].joined(separator: ","))
    }

    @Test func fullCSVStartsWithUTF8BOMAndHeaderLineDoesNot() throws {
        let context = try makeInMemoryContext()
        let csv = ExpenseCSVSerializer.fullCSV(for: [], in: context)

        #expect(Array(Data(csv.utf8).prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(!ExpenseCSVSerializer.headerLine.hasPrefix(ExpenseCSVSerializer.bom))
    }

    // Un día de 12 o menos es el caso que dd/MM vs MM/dd invertía en silencio; el 19 no puede ser mes.
    @Test func datesAreISO8601RegardlessOfDayValue() throws {
        let context = try makeInMemoryContext()
        let expense = Expense(
            documentType: "MANUAL",
            issueDate: panamaDate(2026, 8, 4),
            authorizationDate: panamaDate(2026, 9, 19, hour: 14, minute: 52, second: 59),
            issuerName: "El Rey",
            totalAmount: 1,
            totalItbms: 0,
            source: .manual,
            scanDate: panamaDate(2026, 8, 4, hour: 9, minute: 5, second: 3)
        )
        context.insert(expense)

        let fields = try #require(ExpenseCSVSerializer.rows(for: [expense], in: context).first).components(separatedBy: ",")
        #expect(fields[3] == "2026-08-04")
        #expect(fields[4] == "2026-09-19 14:52:59")
        #expect(fields[23] == "2026-08-04 09:05:03")
    }

    @Test func dgiExpenseProducesOneRowPerItemWithCategoryFromMerchant() throws {
        let context = try makeInMemoryContext()
        context.insert(Merchant(ruc: "2029164-1-744562", name: "JV PANAMA S.A.", category: "Comida"))

        let expense = Expense(
            cufe: "FE0120...746379",
            documentType: "INVOICE",
            issueDate: panamaDate(2026, 9, 19),
            authorizationDate: panamaDate(2026, 9, 19, hour: 14, minute: 52, second: 59),
            issuerRuc: "2029164-1-744562",
            issuerName: "JV PANAMA S.A.",
            invoiceNumber: "0000074637",
            items: [
                InvoiceItem(
                    lineNumber: 1, code: "248", itemDescription: "Cafe Americano 12 Oz",
                    quantity: 2, unitPrice: Decimal(string: "3.35")!, unitDiscount: 0,
                    amount: Decimal(string: "6.70")!, itbms: 0, total: Decimal(string: "6.70")!
                ),
                InvoiceItem(
                    lineNumber: 2, code: "999", itemDescription: "Croissant",
                    quantity: 1, unitPrice: Decimal(string: "5.40")!, unitDiscount: 0,
                    amount: Decimal(string: "5.40")!, itbms: 0, total: Decimal(string: "5.40")!
                ),
            ],
            totalAmount: Decimal(string: "12.10")!,
            totalItbms: 0,
            paymentMethod: "Efectivo",
            totalPaid: Decimal(string: "20.10")!,
            source: .dgi,
            scanDate: panamaDate(2026, 9, 19, hour: 14, minute: 52, second: 59)
        )
        context.insert(expense)

        let rows = ExpenseCSVSerializer.rows(for: [expense], in: context)
        #expect(rows.count == 2)

        let firstFields = rows[0].components(separatedBy: ",")
        #expect(firstFields[3] == "2026-09-19")
        #expect(firstFields[4] == "2026-09-19 14:52:59")
        #expect(firstFields[7] == "Comida")
        #expect(firstFields[9] == "1")
        #expect(firstFields[11] == "Cafe Americano 12 Oz")
        #expect(firstFields[12] == "2.00")
        #expect(firstFields[18] == "12.10")
        #expect(firstFields[23] == "2026-09-19 14:52:59")

        let secondFields = rows[1].components(separatedBy: ",")
        #expect(secondFields[9] == "2")
        #expect(secondFields[11] == "Croissant")
        #expect(secondFields[18] == "12.10") // shared expense-level fields repeat on every row
    }

    @Test func manualExpenseWithoutItemsProducesOneFixedRow() throws {
        let context = try makeInMemoryContext()
        let expense = Expense(
            documentType: "MANUAL",
            issueDate: panamaDate(2026, 9, 20),
            issuerName: "El Rey",
            totalAmount: 25,
            totalItbms: 0,
            category: "Comida",
            source: .manual,
            scanDate: panamaDate(2026, 9, 20, hour: 9)
        )
        context.insert(expense)

        let rows = ExpenseCSVSerializer.rows(for: [expense], in: context)
        #expect(rows.count == 1)

        let fields = rows[0].components(separatedBy: ",")
        #expect(fields[7] == "Comida") // no RUC: category is direct on Expense, not via Merchant
        #expect(fields[9] == "1") // fixed lineNumber for a manual expense with no items (section 11)
        #expect(fields[10] == "")
        #expect(fields[11] == "")
        #expect(fields[12] == "")
    }

    @Test func escapesCommasAndQuotesInItemDescription() throws {
        let context = try makeInMemoryContext()
        let expense = Expense(
            documentType: "INVOICE",
            issuerName: "Tienda",
            items: [
                InvoiceItem(
                    lineNumber: 1, itemDescription: "Café, 12\" oz",
                    quantity: 1, unitPrice: 1, unitDiscount: 0, amount: 1, itbms: 0, total: 1
                ),
            ],
            totalAmount: 1,
            totalItbms: 0,
            source: .dgi
        )
        context.insert(expense)

        let row = try #require(ExpenseCSVSerializer.rows(for: [expense], in: context).first)
        #expect(row.contains("\"Café, 12\"\" oz\""))
    }
}
