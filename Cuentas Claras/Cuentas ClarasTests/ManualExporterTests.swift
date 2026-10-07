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

        let data = try Data(contentsOf: url)
        #expect(Array(data.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(decoding: data, as: UTF8.self).components(separatedBy: ExpenseCSVSerializer.bom).count == 2)
        let lines = String(decoding: data.dropFirst(3), as: UTF8.self).components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)
        #expect(lines.filter { $0 == ExpenseCSVSerializer.headerLine }.count == 1)
        #expect(lines.filter { $0.contains("El Rey") }.count == 1)
        #expect(lines.filter { $0.contains("Super 99") }.count == 1)
    }

    @Test func appendWritesBOMAndHeaderOnlyIntoAnEmptyFile() throws {
        let context = try makeInMemoryContext()
        let url = try makeEmptyFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let version = ExpenseCSVSerializer.schemaVersion

        _ = makeExpense("El Rey", in: context)
        _ = try ManualExporter.export(to: url, fileSchemaVersion: version, in: context)
        let afterFirst = try Data(contentsOf: url)
        #expect(Array(afterFirst.prefix(3)) == [0xEF, 0xBB, 0xBF])
        #expect(String(decoding: afterFirst.dropFirst(3), as: UTF8.self).hasPrefix(ExpenseCSVSerializer.headerLine))

        _ = makeExpense("Super 99", in: context)
        _ = try ManualExporter.export(to: url, fileSchemaVersion: version, in: context)
        let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        #expect(text.components(separatedBy: ExpenseCSVSerializer.bom).count == 2)
    }

    // 11.1: un archivo con versión anterior se regenera completo antes de cualquier append, así que
    // nunca conviven filas con formato viejo y nuevo.
    @Test func fileFromOlderSchemaIsRegeneratedWholeNeverAppended() throws {
        let context = try makeInMemoryContext()
        let url = try makeEmptyFile()
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("01/09/2026,old row\r\n".utf8).write(to: url)

        _ = makeExpense("El Rey", in: context)
        _ = try ManualExporter.export(to: url, fileSchemaVersion: ExpenseCSVSerializer.schemaVersion - 1, in: context)

        let expected = ExpenseCSVSerializer.fullCSV(for: try ManualExporter.allExpenses(in: context), in: context)
        #expect(try Data(contentsOf: url) == Data(expected.utf8))
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
