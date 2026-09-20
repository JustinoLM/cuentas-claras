//
//  Expense.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation
import SwiftData

@Model
final class Expense {
    @Attribute(.unique) var id: UUID
    var cufe: String?  // nil for manual expenses; unique when present (see spec section 6, deduplication)
    var documentType: String  // "INVOICE" | "UNSUPPORTED" (mapped from DGI's literal "FACTURA" text during parsing; see spec section 7)
    var referencedCufe: String?  // credit notes: CUFE of the invoice being voided/reduced (partial support, see spec section 7)

    var issueDate: Date?
    var authorizationDate: Date?

    var issuerRuc: String?
    var issuerName: String  // written directly by the user for manual expenses
    var invoiceNumber: String?

    var items: [InvoiceItem]  // empty for simple manual expenses

    var totalAmount: Decimal
    var totalItbms: Decimal
    var paymentMethod: String?
    var totalPaid: Decimal?

    var category: String?  // inherited from Merchant by RUC, or set directly for manual expenses

    var source: ExpenseSource
    var scanDate: Date  // local timestamp of when this was saved in the app

    // Layer 2 state (manual export)
    var layer2ExportedAt: Date?

    // Layer 3 state (OneDrive sync)
    var layer3SyncState: SyncState

    init(
        id: UUID = UUID(),
        cufe: String? = nil,
        documentType: String,
        referencedCufe: String? = nil,
        issueDate: Date? = nil,
        authorizationDate: Date? = nil,
        issuerRuc: String? = nil,
        issuerName: String,
        invoiceNumber: String? = nil,
        items: [InvoiceItem] = [],
        totalAmount: Decimal,
        totalItbms: Decimal,
        paymentMethod: String? = nil,
        totalPaid: Decimal? = nil,
        category: String? = nil,
        source: ExpenseSource,
        scanDate: Date = Date(),
        layer2ExportedAt: Date? = nil,
        layer3SyncState: SyncState = .pending
    ) {
        self.id = id
        self.cufe = cufe
        self.documentType = documentType
        self.referencedCufe = referencedCufe
        self.issueDate = issueDate
        self.authorizationDate = authorizationDate
        self.issuerRuc = issuerRuc
        self.issuerName = issuerName
        self.invoiceNumber = invoiceNumber
        self.items = items
        self.totalAmount = totalAmount
        self.totalItbms = totalItbms
        self.paymentMethod = paymentMethod
        self.totalPaid = totalPaid
        self.category = category
        self.source = source
        self.scanDate = scanDate
        self.layer2ExportedAt = layer2ExportedAt
        self.layer3SyncState = layer3SyncState
    }
}
