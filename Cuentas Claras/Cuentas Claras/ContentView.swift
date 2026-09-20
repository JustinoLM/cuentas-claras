//
//  ContentView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        ExpenseListView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Expense.self, inMemory: true)
}
