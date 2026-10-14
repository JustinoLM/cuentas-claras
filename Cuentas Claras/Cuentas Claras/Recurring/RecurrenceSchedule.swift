//
//  RecurrenceSchedule.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/07/26.
//

import Foundation

// Spec section 19: cálculo puro de vencimientos. Todo se hace con un calendario gregoriano fijo en
// America/Panama (igual que el CSV, sección 11) y los vencimientos se guardan a las 12:00, para que
// ningún borde de medianoche cambie el día.
enum RecurrenceSchedule {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Panama")!
        return calendar
    }()

    static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    // Fecha elegida en un DatePicker (calendario del dispositivo) -> mismo año/mes/día a las 12:00 en Panamá.
    static func normalized(fromPicker pickerDate: Date, deviceCalendar: Calendar = .current) -> Date {
        let parts = deviceCalendar.dateComponents([.year, .month, .day], from: pickerDate)
        return date(parts.year!, parts.month!, parts.day!)
    }

    // Inverso de `normalized`: para que el DatePicker muestre el mismo día aunque el dispositivo no esté en Panamá.
    static func pickerDate(from stored: Date, deviceCalendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: stored)
        return deviceCalendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12))!
    }

    // El día se muestra en Panamá, no en la zona del dispositivo, para que coincida con el que se guarda.
    static func displayString(_ stored: Date) -> String {
        stored.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: calendar.timeZone))
    }

    static func today(now: Date = Date()) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return date(parts.year!, parts.month!, parts.day!)
    }

    // Primer vencimiento cuyo día es igual o posterior al de `reference`. Mensual y anual solo existen
    // desde `anchor` en adelante, así que una referencia anterior al ancla devuelve el ancla.
    static func firstDueDate(
        frequency: RecurrenceFrequency,
        anchor: Date,
        onOrAfter reference: Date
    ) -> Date {
        let referenceDay = calendar.startOfDay(for: reference)

        switch frequency {
        case .biweekly:
            let start = max(referenceDay, calendar.startOfDay(for: anchor))
            let parts = calendar.dateComponents([.year, .month, .day], from: start)
            let day = parts.day! <= 15 ? 15 : lastDay(year: parts.year!, month: parts.month!)
            return date(parts.year!, parts.month!, day)
        case .monthly, .yearly:
            var index = 0
            while true {
                let candidate = occurrence(index, frequency: frequency, anchor: anchor)
                if candidate >= referenceDay { return candidate }
                index += 1
            }
        }
    }

    static func nextDueDate(
        after current: Date,
        frequency: RecurrenceFrequency,
        anchor: Date
    ) -> Date {
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: current))!
        return firstDueDate(frequency: frequency, anchor: anchor, onOrAfter: nextDay)
    }

    // Desde `nextDueDate`, un periodo a la vez, hasta hoy inclusive, comparando por día.
    static func pendingDueDates(
        from nextDueDate: Date,
        frequency: RecurrenceFrequency,
        anchor: Date,
        today: Date
    ) -> [Date] {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
        var result: [Date] = []
        var due = nextDueDate
        while due < tomorrow {
            result.append(due)
            due = Self.nextDueDate(after: due, frequency: frequency, anchor: anchor)
        }
        return result
    }

    // Siempre se calcula desde el ancla, no desde el vencimiento anterior: un ancla en día 31 vuelve
    // al 31 después de febrero.
    private static func occurrence(_ index: Int, frequency: RecurrenceFrequency, anchor: Date) -> Date {
        let parts = calendar.dateComponents([.year, .month, .day], from: anchor)
        let year: Int
        let month: Int
        switch frequency {
        case .monthly:
            let totalMonths = parts.year! * 12 + (parts.month! - 1) + index
            year = totalMonths / 12
            month = totalMonths % 12 + 1
        case .yearly:
            year = parts.year! + index
            month = parts.month!
        case .biweekly:
            preconditionFailure("biweekly no se calcula por índice")
        }
        return date(year, month, min(parts.day!, lastDay(year: year, month: month)))
    }

    private static func lastDay(year: Int, month: Int) -> Int {
        let firstOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return calendar.range(of: .day, in: .month, for: firstOfMonth)!.count
    }
}
