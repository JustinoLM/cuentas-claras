//
//  DGIInvoiceParser.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation
import SwiftSoup

enum DGIInvoiceParser {
    static func parse(html: String) throws -> DGIParseResult {
        let document = try SwiftSoup.parse(html)

        // #detalle only renders when the DGI actually found a document for the CUFE (5.7).
        guard try document.select("#detalle").first() != nil else {
            return .notFound
        }

        guard try documentTypeText(in: document) == "FACTURA" else {
            return .unsupported(referencedCufe: nil)
        }

        let cufe = try requiredLabel("CÓDIGO ÚNICO DE FACTURA ELECTRÓNICA [CUFE]", in: document)
        let invoiceNumber = try requiredInvoiceNumber(in: document)
        let authorizationDate = try requiredDate(forLabel: "FECHA AUTORIZACIÓN", in: document)

        guard let emisor = try emisorPanelBody(in: document) else {
            throw DGIParsingError.missingField("panel EMISOR")
        }
        let issuerRuc = try requiredLabel("RUC", in: emisor)
        let issuerName = try requiredLabel("NOMBRE", in: emisor)

        let items = try invoiceItems(in: document)
        let totals = try footerTotals(in: document)

        let expense = Expense(
            cufe: cufe,
            documentType: "INVOICE",
            authorizationDate: authorizationDate,
            issuerRuc: issuerRuc,
            issuerName: issuerName,
            invoiceNumber: invoiceNumber,
            items: items,
            totalAmount: totals.totalAmount,
            totalItbms: totals.totalItbms,
            paymentMethod: totals.paymentMethod,
            totalPaid: totals.totalPaid,
            source: .dgi
        )
        return .success(expense)
    }

    // MARK: - Patrón A: pares dt/dd (5.4)

    private static func documentTypeText(in document: Element) throws -> String? {
        guard let text = try document.select("h4 strong").first()?.text() else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func requiredInvoiceNumber(in document: Element) throws -> String {
        for h5 in try document.select("h5").array() {
            let text = try h5.text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.hasPrefix("No.") else { continue }
            let number = text.dropFirst("No.".count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !number.isEmpty {
                return number
            }
        }
        throw DGIParsingError.missingField("No. de factura")
    }

    private static func emisorPanelBody(in document: Element) throws -> Element? {
        for heading in try document.select("div.panel-heading").array() {
            let text = try heading.text().trimmingCharacters(in: .whitespacesAndNewlines)
            guard text == "EMISOR" else { continue }
            return try heading.parent()?.select("div.panel-body").first()
        }
        return nil
    }

    private static func label(_ text: String, in scope: Element) throws -> String? {
        for dt in try scope.select("dl.dl-vertical dt.small").array() {
            guard try dt.text().trimmingCharacters(in: .whitespacesAndNewlines) == text else { continue }
            guard let dd = try dt.nextElementSibling() else { return nil }
            let value = try dd.text().trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func requiredLabel(_ text: String, in scope: Element) throws -> String {
        guard let value = try label(text, in: scope) else {
            throw DGIParsingError.missingField(text)
        }
        return value
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/Panama")
        formatter.dateFormat = "dd/MM/yyyy HH:mm:ss"
        return formatter
    }()

    private static func requiredDate(forLabel text: String, in document: Element) throws -> Date {
        guard let raw = try label(text, in: document), let date = dateFormatter.date(from: raw) else {
            throw DGIParsingError.missingField(text)
        }
        return date
    }

    // MARK: - Patrón B: tabla de ítems, por data-title (5.5)

    private static func cellText(_ row: Element, dataTitle: String) throws -> String? {
        guard let cell = try row.select("td[data-title=\"\(dataTitle)\"]").first() else {
            throw DGIParsingError.missingField(dataTitle)
        }
        let text = try cell.text().trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private static func requiredCellText(_ row: Element, dataTitle: String) throws -> String {
        guard let text = try cellText(row, dataTitle: dataTitle) else {
            throw DGIParsingError.missingField(dataTitle)
        }
        return text
    }

    private static func requiredCellInt(_ row: Element, dataTitle: String) throws -> Int {
        guard let value = Int(try requiredCellText(row, dataTitle: dataTitle)) else {
            throw DGIParsingError.missingField(dataTitle)
        }
        return value
    }

    private static func optionalCellDecimal(_ row: Element, dataTitle: String) throws -> Decimal? {
        guard let text = try cellText(row, dataTitle: dataTitle) else { return nil }
        guard let value = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) else {
            throw DGIParsingError.missingField(dataTitle)
        }
        return value
    }

    private static func requiredCellDecimal(_ row: Element, dataTitle: String) throws -> Decimal {
        guard let value = try optionalCellDecimal(row, dataTitle: dataTitle) else {
            throw DGIParsingError.missingField(dataTitle)
        }
        return value
    }

    private static func invoiceItems(in document: Element) throws -> [InvoiceItem] {
        let rows = try document.select("#detalle table tbody tr").array()
        return try rows.map { row in
            InvoiceItem(
                lineNumber: try requiredCellInt(row, dataTitle: "Linea"),
                code: try cellText(row, dataTitle: "Código"),
                itemDescription: try requiredCellText(row, dataTitle: "Descripción"),
                quantity: try requiredCellDecimal(row, dataTitle: "Cantidad"),
                unitPrice: try requiredCellDecimal(row, dataTitle: "Precio"),
                unitDiscount: try requiredCellDecimal(row, dataTitle: "Descuento"),
                amount: try requiredCellDecimal(row, dataTitle: "Monto"),
                itbms: try requiredCellDecimal(row, dataTitle: "Impuesto"),
                isc: try optionalCellDecimal(row, dataTitle: "ISC"),
                freight: try optionalCellDecimal(row, dataTitle: "Acarreo"),
                insurance: try optionalCellDecimal(row, dataTitle: "Seguro"),
                total: try requiredCellDecimal(row, dataTitle: "Total")
            )
        }
    }

    // MARK: - Patrón C: totales del footer (5.6)

    private struct FooterTotals {
        let totalAmount: Decimal
        let totalItbms: Decimal
        let totalPaid: Decimal
        let paymentMethod: String?
    }

    private static func footerTotals(in document: Element) throws -> FooterTotals {
        let fixedLabels: Set<String> = ["Descuentos:", "Valor Total:", "ITBMS Total:", "TOTAL PAGADO:", "Vuelto:"]

        var totalAmount: Decimal?
        var totalItbms: Decimal?
        var totalPaid: Decimal?
        var paymentMethod: String?

        for cell in try document.select("#detalle table tfoot tr td").array() {
            let label = cell.ownText().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }  // e.g. the "Forma de Pago" <kbd> row

            let amountText = try cell.select("div").first()?.text().trimmingCharacters(in: .whitespacesAndNewlines)
            let amount = amountText.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }

            switch label {
            case "Valor Total:":
                totalAmount = amount
            case "ITBMS Total:":
                totalItbms = amount
            case "TOTAL PAGADO:":
                totalPaid = amount
            case "Descuentos:", "Vuelto:":
                continue
            default:
                // Whichever payment-method row has an amount is the one that applies (only
                // "Efectivo" is confirmed so far — see spec section 5.6).
                if !fixedLabels.contains(label), let amount, amount > 0 {
                    paymentMethod = String(label.dropLast())
                }
            }
        }

        guard let totalAmount, let totalItbms, let totalPaid else {
            throw DGIParsingError.missingField("totales del footer")
        }

        return FooterTotals(totalAmount: totalAmount, totalItbms: totalItbms, totalPaid: totalPaid, paymentMethod: paymentMethod)
    }
}
