//
//  InvoiceItem.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation
import SwiftData

@Model
final class InvoiceItem {
    var lineNumber: Int
    var code: String?
    var itemDescription: String
    var quantity: Decimal
    var unitPrice: Decimal
    var unitDiscount: Decimal
    var amount: Decimal
    var itbms: Decimal
    var isc: Decimal?
    var freight: Decimal?
    var insurance: Decimal?
    var total: Decimal

    init(
        lineNumber: Int,
        code: String? = nil,
        itemDescription: String,
        quantity: Decimal,
        unitPrice: Decimal,
        unitDiscount: Decimal,
        amount: Decimal,
        itbms: Decimal,
        isc: Decimal? = nil,
        freight: Decimal? = nil,
        insurance: Decimal? = nil,
        total: Decimal
    ) {
        self.lineNumber = lineNumber
        self.code = code
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.unitDiscount = unitDiscount
        self.amount = amount
        self.itbms = itbms
        self.isc = isc
        self.freight = freight
        self.insurance = insurance
        self.total = total
    }
}
