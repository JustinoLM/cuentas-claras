//
//  ManualExporter.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import SwiftData

enum ManualExportError: Error {
    case noDestination
    case accessDenied
}

// Capa 2 (spec section 12): CSV en una ubicación que elige el usuario. La primera vez se escribe el
// archivo completo vía el selector de documentos; después solo se agregan al final los Expense con
// `layer2ExportedAt == nil`, reusando un security-scoped bookmark para no pedir permiso otra vez.
enum ManualExporter {
    nonisolated enum Outcome: Equatable {
        case exported(count: Int)
        case nothingToExport
    }

    private static let bookmarkKey = "layer2ExportBookmark"
    private static let schemaVersionKey = "layer2ExportSchemaVersion"

    static func allExpenses(in context: ModelContext) throws -> [Expense] {
        try context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.scanDate)]))
    }

    // Núcleo sin bookmarks ni UserDefaults, para poder probarlo contra un archivo temporal.
    // `fileSchemaVersion` es la versión con la que se creó el archivo en `url` (11.1).
    static func export(to url: URL, fileSchemaVersion: Int, in context: ModelContext) throws -> Outcome {
        let all = try allExpenses(in: context)
        let pending = all.filter { $0.layer2ExportedAt == nil }

        if fileSchemaVersion != ExpenseCSVSerializer.schemaVersion {
            // 11.1: regenerar completo no reinicia `layer2ExportedAt` de nada — solo se marcan los
            // que todavía no tenían fecha, porque el archivo nuevo ya los incluye.
            let csv = ExpenseCSVSerializer.fullCSV(for: all, in: context)
            try Data(csv.utf8).write(to: url)
            markExported(pending)
            return pending.isEmpty ? .nothingToExport : .exported(count: pending.count)
        }

        guard !pending.isEmpty else { return .nothingToExport }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }

        var text = try handle.seekToEnd() == 0 ? ExpenseCSVSerializer.headerLine + "\r\n" : ""
        text += ExpenseCSVSerializer.rows(for: pending, in: context).map { $0 + "\r\n" }.joined()
        try handle.write(contentsOf: Data(text.utf8))

        markExported(pending)
        return .exported(count: pending.count)
    }

    static func exportToSavedDestination(in context: ModelContext) throws -> Outcome {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw ManualExportError.noDestination
        }

        var isStale = false
        let url = try URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale)
        guard url.startAccessingSecurityScopedResource() else { throw ManualExportError.accessDenied }
        defer { url.stopAccessingSecurityScopedResource() }

        let storedVersion = UserDefaults.standard.integer(forKey: schemaVersionKey)
        let outcome = try export(to: url, fileSchemaVersion: storedVersion, in: context)

        UserDefaults.standard.set(ExpenseCSVSerializer.schemaVersion, forKey: schemaVersionKey)
        if isStale {
            UserDefaults.standard.set(try url.bookmarkData(), forKey: bookmarkKey)
        }
        return outcome
    }

    // El selector ya escribió el CSV completo en `url`; aquí solo se recuerda dónde quedó y se marca
    // como exportado todo lo que ese archivo ya contiene.
    @discardableResult
    static func completeInitialExport(to url: URL, in context: ModelContext) throws -> Int {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        let bookmark = try url.bookmarkData()
        let pending = try allExpenses(in: context).filter { $0.layer2ExportedAt == nil }
        markExported(pending)

        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        UserDefaults.standard.set(ExpenseCSVSerializer.schemaVersion, forKey: schemaVersionKey)
        return pending.count
    }

    private static func markExported(_ expenses: [Expense]) {
        let now = Date()
        for expense in expenses {
            expense.layer2ExportedAt = now
        }
    }
}
