//
//  ExpenseListView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec section 15, pantalla 1 — raíz de la app.
struct ExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.scanDate, order: .reverse) private var expenses: [Expense]
    @State private var searchText = ""
    @State private var isShowingCapture = false
    @State private var isShowingUncategorized = false

    private var filteredExpenses: [Expense] {
        guard !searchText.isEmpty else { return expenses }
        return expenses.filter {
            MerchantCategorization.displayName(for: $0, in: modelContext).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "Sin gastos todavía",
                        systemImage: "tray",
                        description: Text("Toca + para capturar tu primera factura.")
                    )
                } else {
                    List {
                        ForEach(filteredExpenses) { expense in
                            NavigationLink {
                                ExpenseDetailView(expense: expense)
                            } label: {
                                ExpenseRow(expense: expense)
                            }
                        }
                        .onDelete(perform: deleteExpenses)
                    }
                    .searchable(text: $searchText, prompt: "Buscar por negocio")
                }
            }
            .navigationTitle("Gastos")
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isShowingUncategorized = true
                    } label: {
                        Label("Sin categorizar", systemImage: "tag")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingCapture = true
                    } label: {
                        Label("Capturar", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingCapture) {
                CaptureSelectionView(onFinished: { isShowingCapture = false })
            }
            .sheet(isPresented: $isShowingUncategorized) {
                UncategorizedMerchantsView()
            }
        }
    }

    private func deleteExpenses(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredExpenses[index])
        }
    }
}

private struct ExpenseRow: View {
    @Environment(\.modelContext) private var modelContext
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(MerchantCategorization.displayName(for: expense, in: modelContext))
                    .font(.headline)
                Text(expense.scanDate, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(expense.totalAmount, format: .currency(code: "USD"))
                .font(.subheadline.monospacedDigit())
        }
    }
}

#Preview {
    ExpenseListView()
        .modelContainer(for: Expense.self, inMemory: true)
}
