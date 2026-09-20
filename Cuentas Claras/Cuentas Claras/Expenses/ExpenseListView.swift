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
    @State private var isShowingPending = false
    @State private var isShowingAnalytics = false
    @State private var collapsedMonths: Set<Date> = []

    private var filteredExpenses: [Expense] {
        let base = expenses.sorted { $0.paymentDate > $1.paymentDate }
        guard !searchText.isEmpty else { return base }
        return base.filter {
            MerchantCategorization.displayName(for: $0, in: modelContext).localizedCaseInsensitiveContains(searchText)
        }
    }

    // Agrupado por mes (usando paymentDate, no scanDate) — con años de datos, una lista plana se
    // vuelve inmanejable.
    private var groupedExpenses: [(month: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredExpenses) { expense -> Date in
            let components = calendar.dateComponents([.year, .month], from: expense.paymentDate)
            return calendar.date(from: components) ?? expense.paymentDate
        }
        return groups.keys.sorted(by: >).map { month in
            (month, groups[month] ?? [])
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "Sin facturas todavía",
                        systemImage: "tray",
                        description: Text("Toca + para capturar tu primera factura.")
                    )
                } else {
                    List {
                        ForEach(groupedExpenses, id: \.month) { group in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { !collapsedMonths.contains(group.month) },
                                    set: { isExpanded in
                                        if isExpanded {
                                            collapsedMonths.remove(group.month)
                                        } else {
                                            collapsedMonths.insert(group.month)
                                        }
                                    }
                                )
                            ) {
                                ForEach(group.expenses) { expense in
                                    NavigationLink {
                                        ExpenseDetailView(expense: expense)
                                    } label: {
                                        ExpenseRow(expense: expense)
                                    }
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        modelContext.delete(group.expenses[index])
                                    }
                                }
                            } label: {
                                Text(group.month.formatted(.dateTime.month(.wide).year()))
                                    .font(.headline)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Buscar por negocio")
                }
            }
            .navigationTitle("Mis Facturas")
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isShowingUncategorized = true
                    } label: {
                        Label("Sin categorizar", systemImage: "tag")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isShowingPending = true
                    } label: {
                        Label("Pendientes", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isShowingAnalytics = true
                    } label: {
                        Label("Gráficas", systemImage: "chart.bar")
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
            .sheet(isPresented: $isShowingPending) {
                PendingLookupsView()
            }
            .sheet(isPresented: $isShowingAnalytics) {
                AnalyticsView()
            }
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
                Text(expense.paymentDate, format: .dateTime.day().month().year())
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
