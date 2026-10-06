//
//  ManualExporterTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

private func makeEmptyFile() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString).csv")
    try Data().write(to: url)
    return url
}

private func makeExpense(_ name: String, in context: ModelContext) -> Expense {
    let expense = Expense(
        documentType: "MANUAL",
        issuerName: name,
        totalAmount: 10,
        totalItbms: 0,
        source: .manual
    )
    context.insert(expense)
    return expense
}

struct ManualExporterTests {
    @Test func appendsOnlyNewExpensesAndWritesHeaderOnce() throws {
        let context = try makeInMemoryContext()
        let url = try makeEmptyFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let version = ExpenseCSVSerializer.schemaVersion

        let first = makeExpense("El Rey", in: context)
        #expect(try ManualExporter.export(to: url, fileSchemaVersion: version, in: context) == .exported(count: 1))
        #expect(first.layer2ExportedAt != nil)

        let second = makeExpense("Super 99", in: context)
        #expect(try ManualExporter.export(to: url, fileSchemaVersion: version, in: context) == .exported(count: 1))
        #expect(second.layer2ExportedAt != nil)

        let lines = try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines.filter { $0 == ExpenseCSVSerializer.headerLine }.count == 1)
        #expect(lines.filter { $0.contains("El Rey") }.count == 1)
        #expect(lines.filter { $0.contains("Super 99") }.count == 1)
    }

    @Test func nothingToExportLeavesTheFileUntouched() throws {
        let context = try makeInMemoryContext()
        let url = try makeEmptyFile()
        defer { try? FileManager.default.removeItem(at: url) }

        let expense = makeExpense("El Rey", in: context)
        expense.layer2ExportedAt = Date()

        let outcome = try ManualExporter.export(to: url, fileSchemaVersion: ExpenseCSVSerializer.schemaVersion, in: context)

        #expect(outcome == .nothingToExport)
        #expect(try Data(contentsOf: url).isEmpty)
    }

    @Test func schemaVersionMismatchRegeneratesWholeFileWithoutResettingExportState() throws {
        let context = try makeInMemoryContext()
        let url = try makeEmptyFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("old,schema\r\n".utf8).write(to: url)

        let alreadyExportedAt = testDate(2026, 9, 1)
        let old = makeExpense("El Rey", in: context)
        old.layer2ExportedAt = alreadyExportedAt
        let new = makeExpense("Super 99", in: context)

        let outcome = try ManualExporter.export(to: url, fileSchemaVersion: ExpenseCSVSerializer.schemaVersion - 1, in: context)

        #expect(outcome == .exported(count: 1))
        #expect(old.layer2ExportedAt == alreadyExportedAt)
        #expect(new.layer2ExportedAt != nil)

        let content = try String(contentsOf: url, encoding: .utf8)
        #expect(!content.contains("old,schema"))
        #expect(content.contains("El Rey"))
        #expect(content.contains("Super 99"))
    }
}
