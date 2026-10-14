//
//  TestSupport.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData
@testable import Cuentas_Claras

func makeInMemoryContext() throws -> ModelContext {
    let schema = Schema([Expense.self, InvoiceItem.self, Merchant.self, PendingLookup.self, PendingRemoteDeletion.self, RecurringPayment.self])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    return ModelContext(container)
}

// Siempre a mediodía para no depender de en qué zona horaria corre el test — construir y leer
// componentes de fecha con el mismo Calendar es internamente consistente sin importar la zona.
func testDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return Calendar.current.date(from: components)!
}
