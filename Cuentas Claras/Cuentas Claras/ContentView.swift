//
//  ContentView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ExpenseListView()
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    try? await PendingLookupQueue.retryAll(in: modelContext)
                    _ = await OneDriveSync.run(in: modelContext)
                }
            }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Expense.self, inMemory: true)
}
