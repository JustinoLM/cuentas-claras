//
//  RecurringPaymentActions.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/07/26.
//

import Foundation
import SwiftData

// Un vencimiento pendiente de resolver. Solo el más antiguo de cada plantilla (`isOldest`) se puede
// confirmar u omitir: confirmar avanza `nextDueDate` un periodo, que solo tiene sentido en orden.
struct PendingRecurringDue: Identifiable {
    let payment: RecurringPayment
    let dueDate: Date
    let isOldest: Bool

    var id: String { "\(payment.id.uuidString)-\(dueDate.timeIntervalSince1970)" }
}

// Spec section 19. Confirmar crea un gasto manual normal, sin pasar por el aviso de duplicado de 6.2.
// Capa 0 y Capa 3 se activan solas: la primera observa `ModelContext.didSave` y el Expense nace en
// `.pending`.
enum RecurringPaymentActions {
    static func pendingDues(for payments: [RecurringPayment], today: Date = RecurrenceSchedule.today()) -> [PendingRecurringDue] {
        payments
            .filter(\.isActive)
            .flatMap { payment in
                RecurrenceSchedule.pendingDueDates(
                    from: payment.nextDueDate,
                    frequency: payment.frequency,
                    anchor: payment.anchorDate,
                    today: today
                )
                .enumerated()
                .map { PendingRecurringDue(payment: payment, dueDate: $1, isOldest: $0 == 0) }
            }
            .sorted { $0.dueDate < $1.dueDate }
    }

    // `amount` y `issueDate` son editables al confirmar; `nextDueDate` avanza desde el vencimiento
    // de la plantilla, no desde la fecha editada.
    @discardableResult
    static func confirm(
        _ payment: RecurringPayment,
        amount: Decimal,
        issueDate: Date,
        in context: ModelContext
    ) -> Expense {
        let expense = Expense(
            documentType: "MANUAL",
            issueDate: issueDate,
            issuerName: payment.name,
            totalAmount: amount,
            totalItbms: 0,
            paymentMethod: payment.paymentMethod,
            category: payment.category,
            source: .manual,
            recurringId: payment.id
        )
        context.insert(expense)
        advance(payment)
        return expense
    }

    static func skip(_ payment: RecurringPayment) {
        advance(payment)
    }

    static func pause(_ payment: RecurringPayment) {
        payment.isActive = false
    }

    // Sin acumular los vencimientos del periodo pausado.
    static func resume(_ payment: RecurringPayment, today: Date = RecurrenceSchedule.today()) {
        payment.isActive = true
        reschedule(payment, today: today)
    }

    // Al editar `frequency` o `anchorDate`.
    static func reschedule(_ payment: RecurringPayment, today: Date = RecurrenceSchedule.today()) {
        payment.nextDueDate = RecurrenceSchedule.firstDueDate(
            frequency: payment.frequency,
            anchor: payment.anchorDate,
            onOrAfter: today
        )
    }

    private static func advance(_ payment: RecurringPayment) {
        payment.nextDueDate = RecurrenceSchedule.nextDueDate(
            after: payment.nextDueDate,
            frequency: payment.frequency,
            anchor: payment.anchorDate
        )
    }
}
