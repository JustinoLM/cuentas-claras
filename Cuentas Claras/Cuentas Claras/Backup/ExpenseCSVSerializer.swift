//
//  ExpenseCSVSerializer.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

// Frozen CSV schema (spec section 11), shared by the Capa 0 backup and the Capa 2 manual export so
// both write byte-for-byte the same format. One row per item, header fields repeated on every row
// so opening the file in Excel/Power Query never needs a join. Column order and names are
// load-bearing — any change here needs schema versioning (section 11.1), not just an edit.
enum ExpenseCSVSerializer {
    // 2: BOM UTF-8 and ISO 8601 dates (section 11). 3: recurringId column (section 19).
    static let schemaVersion = 3

    // Excel only detects UTF-8 (accents) when the file starts with a BOM. Prepended once per file by
    // `fullCSV` and by the Capa 2 append path when it writes into an empty file.
    static let bom = "\u{FEFF}"

    static let header = [
        "id", "cufe", "documentType", "issueDate", "authorizationDate", "issuerRuc", "issuerName",
        "category", "invoiceNumber", "lineNumber", "itemCode", "itemDescription", "quantity",
        "unitPrice", "unitDiscount", "itemAmount", "itemItbms", "itemTotal", "totalAmount",
        "totalItbms", "paymentMethod", "totalPaid", "source", "scanDate", "referencedCufe",
        "recurringId",
    ]

    static let headerLine = csvLine(header)

    // Full file: header + every row. Used by the Capa 0 backup (regenerated whole each time) and by
    // the Capa 2 first export / schema-version-mismatch regeneration (section 11.1).
    static func fullCSV(for expenses: [Expense], in context: ModelContext) -> String {
        bom + ([headerLine] + rows(for: expenses, in: context)).map { $0 + "\r\n" }.joined()
    }

    // Rows only, no header — used by the Capa 2 append path, which only writes expenses where
    // `layer2ExportedAt == nil` onto an existing file.
    static func rows(for expenses: [Expense], in context: ModelContext) -> [String] {
        expenses.flatMap { rows(for: $0, in: context) }
    }

    private static func rows(for expense: Expense, in context: ModelContext) -> [String] {
        let category = (try? MerchantCategorization.category(for: expense, in: context)) ?? nil

        guard !expense.items.isEmpty else {
            return [csvLine(fields(for: expense, category: category, item: nil))]
        }
        return expense.items
            .sorted { $0.lineNumber < $1.lineNumber }
            .map { csvLine(fields(for: expense, category: category, item: $0)) }
    }

    private static func fields(for expense: Expense, category: String?, item: InvoiceItem?) -> [String] {
        [
            expense.id.uuidString,
            expense.cufe ?? "",
            expense.documentType,
            expense.issueDate.map { dateString($0) } ?? "",
            expense.authorizationDate.map { dateTimeString($0) } ?? "",
            expense.issuerRuc ?? "",
            expense.issuerName,
            category ?? "",
            expense.invoiceNumber ?? "",
            item.map { String($0.lineNumber) } ?? "1",
            item?.code ?? "",
            item?.itemDescription ?? "",
            item.map { decimalString($0.quantity) } ?? "",
            item.map { decimalString($0.unitPrice) } ?? "",
            item.map { decimalString($0.unitDiscount) } ?? "",
            item.map { decimalString($0.amount) } ?? "",
            item.map { decimalString($0.itbms) } ?? "",
            item.map { decimalString($0.total) } ?? "",
            decimalString(expense.totalAmount),
            decimalString(expense.totalItbms),
            expense.paymentMethod ?? "",
            expense.totalPaid.map { decimalString($0) } ?? "",
            expense.source.rawValue,
            dateTimeString(expense.scanDate),
            expense.referencedCufe ?? "",
            expense.recurringId?.uuidString ?? "",
        ]
    }

    // MARK: - Formatting

    // Fixed locale/timezone so the file is byte-identical regardless of the phone's region — unlike
    // the UI, which intentionally follows device locale for display (ExpenseDetailView etc).
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Panama")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Panama")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static func dateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static func dateTimeString(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static func decimalString(_ value: Decimal) -> String {
        decimalFormatter.string(from: value as NSDecimalNumber) ?? value.description
    }

    // MARK: - CSV escaping (RFC 4180)

    private static func csvLine(_ fields: [String]) -> String {
        fields.map { csvField($0) }.joined(separator: ",")
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
