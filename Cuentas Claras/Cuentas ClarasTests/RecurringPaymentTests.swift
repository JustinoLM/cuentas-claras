//
//  RecurringPaymentTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 10/07/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

// Siempre a las 12:00 en Panamá, igual que los vencimientos guardados (spec 19).
private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
    RecurrenceSchedule.date(year, month, day)
}

private func pending(
    _ frequency: RecurrenceFrequency,
    anchor: Date,
    from nextDue: Date? = nil,
    today: Date
) -> [Date] {
    RecurrenceSchedule.pendingDueDates(from: nextDue ?? anchor, frequency: frequency, anchor: anchor, today: today)
}

struct RecurringPaymentTests {
    @Test func monthlyAnchoredOnThe31stFallsOnLastDayOfShortMonthsButReturnsToThe31st() {
        let anchor = day(2026, 12, 31)

        // Cruza el año, y marzo vuelve al 31 porque se calcula desde el ancla, no desde el 28 de febrero.
        #expect(pending(.monthly, anchor: anchor, today: day(2027, 3, 31)) == [
            day(2026, 12, 31), day(2027, 1, 31), day(2027, 2, 28), day(2027, 3, 31),
        ])

        let leapAnchor = day(2028, 1, 31)
        let february = RecurrenceSchedule.nextDueDate(after: leapAnchor, frequency: .monthly, anchor: leapAnchor)
        #expect(february == day(2028, 2, 29))
        #expect(RecurrenceSchedule.nextDueDate(after: february, frequency: .monthly, anchor: leapAnchor) == day(2028, 3, 31))
    }

    @Test func biweeklyUsesThe15thAndLastDayAndAnchorOnADueDateCountsAsFirst() {
        // Ancla exactamente en un 15: es el primer vencimiento. Cruza el año y pasa por febrero.
        let on15 = day(2026, 12, 15)
        #expect(RecurrenceSchedule.firstDueDate(frequency: .biweekly, anchor: on15, onOrAfter: on15) == on15)
        #expect(pending(.biweekly, anchor: on15, today: day(2027, 3, 15)) == [
            day(2026, 12, 15), day(2026, 12, 31), day(2027, 1, 15), day(2027, 1, 31),
            day(2027, 2, 15), day(2027, 2, 28), day(2027, 3, 15),
        ])

        // Ancla exactamente en el último día del mes.
        let onLastDay = day(2026, 12, 31)
        #expect(RecurrenceSchedule.firstDueDate(frequency: .biweekly, anchor: onLastDay, onOrAfter: onLastDay) == onLastDay)
        #expect(RecurrenceSchedule.nextDueDate(after: onLastDay, frequency: .biweekly, anchor: onLastDay) == day(2027, 1, 15))

        // Ancla en medio de la quincena: el primero es el próximo 15, sin importar su día.
        let mid = day(2026, 12, 9)
        #expect(RecurrenceSchedule.firstDueDate(frequency: .biweekly, anchor: mid, onOrAfter: mid) == day(2026, 12, 15))

        // Febrero bisiesto termina el 29.
        #expect(RecurrenceSchedule.nextDueDate(after: day(2028, 2, 15), frequency: .biweekly, anchor: day(2028, 1, 1)) == day(2028, 2, 29))
    }

    @Test func yearlyAnchoredOnFeb29FallsOnThe28thInNonLeapYears() {
        let anchor = day(2024, 2, 29)
        #expect(pending(.yearly, anchor: anchor, today: day(2028, 3, 1)) == [
            day(2024, 2, 29), day(2025, 2, 28), day(2026, 2, 28), day(2027, 2, 28), day(2028, 2, 29),
        ])
    }

    @Test func dueTodayIsIncludedAndDueTomorrowIsNotComparingByDay() {
        let due = day(2026, 10, 7)
        #expect(pending(.monthly, anchor: due, today: day(2026, 10, 7)) == [due])
        #expect(pending(.monthly, anchor: due, today: day(2026, 10, 6)).isEmpty)

        // Un "hoy" a las 23:59 sigue siendo el mismo día.
        let lateToday = RecurrenceSchedule.calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 23, minute: 59))!
        #expect(pending(.monthly, anchor: due, today: lateToday) == [due])
    }

    @Test func confirmingCreatesExactlyOneExpenseAndAdvancesOnlyOnePeriod() throws {
        let context = try makeInMemoryContext()
        let payment = RecurringPayment(
            name: "Alquiler", amount: 500, category: "Vivienda", paymentMethod: "Transferencia",
            frequency: .monthly, anchorDate: day(2026, 7, 15), nextDueDate: day(2026, 7, 15)
        )
        context.insert(payment)

        // Julio, agosto, septiembre y octubre vencidos: solo el más antiguo se puede resolver.
        let dues = RecurringPaymentActions.pendingDues(for: [payment], today: day(2026, 10, 20))
        #expect(dues.count == 4)
        #expect(dues.filter(\.isOldest).count == 1)

        RecurringPaymentActions.confirm(payment, amount: 520, issueDate: day(2026, 7, 16), in: context)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let expense = try #require(expenses.first)
        #expect(expenses.count == 1)
        #expect(expense.issuerName == "Alquiler")
        #expect(expense.totalAmount == 520)
        #expect(expense.issueDate == day(2026, 7, 16))
        #expect(expense.category == "Vivienda")
        #expect(expense.paymentMethod == "Transferencia")
        #expect(expense.source == .manual)
        #expect(expense.recurringId == payment.id)
        #expect(expense.layer3SyncState == .pending)
        #expect(payment.nextDueDate == day(2026, 8, 15))
    }

    @Test func resumingJumpsToFirstDueDateFromTodayInclusiveWithoutAccumulatingPausedOnes() {
        let payment = RecurringPayment(
            name: "Internet", amount: 40, frequency: .monthly,
            anchorDate: day(2026, 1, 10), nextDueDate: day(2026, 1, 10)
        )

        RecurringPaymentActions.pause(payment)
        #expect(!payment.isActive)
        #expect(RecurringPaymentActions.pendingDues(for: [payment], today: day(2026, 4, 10)).isEmpty)

        RecurringPaymentActions.resume(payment, today: day(2026, 4, 10))
        #expect(payment.isActive)
        #expect(payment.nextDueDate == day(2026, 4, 10))
        #expect(RecurringPaymentActions.pendingDues(for: [payment], today: day(2026, 4, 10)).count == 1)

        RecurringPaymentActions.resume(payment, today: day(2026, 4, 11))
        #expect(payment.nextDueDate == day(2026, 5, 10))
    }

    @Test func pickerDateIsConvertedFromDeviceCalendarToNoonInPanama() {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = TimeZone(identifier: "Pacific/Auckland")!

        // El picker devuelve medianoche del 5 de octubre en Auckland, que en Panamá todavía es el 4.
        let picked = auckland.date(from: DateComponents(year: 2026, month: 10, day: 5))!
        #expect(RecurrenceSchedule.normalized(fromPicker: picked, deviceCalendar: auckland) == day(2026, 10, 5))

        // Ida y vuelta: el picker muestra el mismo día que se guardó.
        let shown = RecurrenceSchedule.pickerDate(from: day(2026, 10, 5), deviceCalendar: auckland)
        #expect(RecurrenceSchedule.normalized(fromPicker: shown, deviceCalendar: auckland) == day(2026, 10, 5))
    }
}
