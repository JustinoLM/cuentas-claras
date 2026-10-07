//
//  ListFiltersTests.swift
//  Cuentas ClarasTests
//

import Foundation
import Testing
@testable import Cuentas_Claras

struct ListFiltersTests {

    // Zona fija: los tests no pueden depender de la zona de la máquina ni de CI.
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Panama")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    @Test func includesLastMomentOfUpperBoundDay() {
        var filters = ListFilters()
        filters.dateTo = date(2026, 9, 20, 10, 30)

        #expect(filters.includes(date: date(2026, 9, 20, 23, 59), calendar: calendar))
        #expect(!filters.includes(date: date(2026, 9, 21, 0, 0), calendar: calendar))
    }

    @Test func includesFirstMomentOfLowerBoundDay() {
        var filters = ListFilters()
        filters.dateFrom = date(2026, 9, 5, 15, 0)

        #expect(filters.includes(date: date(2026, 9, 5, 0, 0), calendar: calendar))
        #expect(!filters.includes(date: date(2026, 9, 4, 23, 59), calendar: calendar))
    }

    @Test func openEndedRangeHasNoOppositeLimit() {
        var fromOnly = ListFilters()
        fromOnly.dateFrom = date(2026, 9, 5)
        #expect(fromOnly.includes(date: date(2099, 1, 1), calendar: calendar))

        var toOnly = ListFilters()
        toOnly.dateTo = date(2026, 9, 20)
        #expect(toOnly.includes(date: date(2000, 1, 1), calendar: calendar))
    }
}
