//
//  RecurringPayment.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/07/26.
//

import Foundation
import SwiftData

// Spec section 3.6 / 19. Plantilla de un pago periódico; nunca se exporta, solo los gastos que genera.
@Model
final class RecurringPayment {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var category: String?
    var paymentMethod: String?
    var frequency: RecurrenceFrequency
    var anchorDate: Date  // primer vencimiento; fija el día del mes (mensual, anual)
    var nextDueDate: Date  // próximo vencimiento sin resolver
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        category: String? = nil,
        paymentMethod: String? = nil,
        frequency: RecurrenceFrequency,
        anchorDate: Date,
        nextDueDate: Date,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.category = category
        self.paymentMethod = paymentMethod
        self.frequency = frequency
        self.anchorDate = anchorDate
        self.nextDueDate = nextDueDate
        self.isActive = isActive
    }
}

enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case biweekly  // día 15 y último día de cada mes
    case monthly
    case yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .biweekly: "Quincenal"
        case .monthly: "Mensual"
        case .yearly: "Anual"
        }
    }
}
