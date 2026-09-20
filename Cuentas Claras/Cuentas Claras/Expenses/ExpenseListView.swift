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
    @State private var banner: ConfirmationBanner?
    @State private var filters = ListFilters()
    @State private var isShowingFilters = false

    private var availableCategories: [String] {
        MerchantCategorization.existingCategories(in: modelContext)
    }

    private var availablePaymentMethods: [String] {
        Array(Set(expenses.compactMap(\.paymentMethod))).sorted()
    }

    private var filteredExpenses: [Expense] {
        var result = expenses.sorted { $0.paymentDate > $1.paymentDate }

        if !searchText.isEmpty {
            result = result.filter {
                MerchantCategorization.displayName(for: $0, in: modelContext).localizedCaseInsensitiveContains(searchText)
            }
        }

        switch filters.ruc {
        case .all:
            break
        case .withRUC:
            result = result.filter { $0.issuerRuc != nil }
        case .withoutRUC:
            result = result.filter { $0.issuerRuc == nil }
        }

        if !filters.categories.isEmpty {
            result = result.filter { expense in
                let category = (try? MerchantCategorization.category(for: expense, in: modelContext)) ?? nil
                return filters.categories.contains(category ?? "Sin categorizar")
            }
        }

        if !filters.paymentMethods.isEmpty {
            result = result.filter { filters.paymentMethods.contains($0.paymentMethod ?? "") }
        }

        return result
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
                    .safeAreaInset(edge: .top) {
                        if filters.isActive {
                            ActiveFiltersRow(filters: $filters)
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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingFilters = true
                    } label: {
                        Label("Filtros", systemImage: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
                CaptureSelectionView(onFinished: { message in
                    isShowingCapture = false
                    banner = ConfirmationBanner(kind: .success, message: message)
                })
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
            .sheet(isPresented: $isShowingFilters) {
                ListFiltersSheet(
                    filters: $filters,
                    availableCategories: availableCategories,
                    availablePaymentMethods: availablePaymentMethods
                )
            }
            .confirmationBanner($banner)
        }
    }
}

private struct ExpenseRow: View {
    @Environment(\.modelContext) private var modelContext
    let expense: Expense

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(MerchantCategorization.displayName(for: expense, in: modelContext))
                        .font(.headline)
                    RUCBadge(hasRUC: expense.issuerRuc != nil)
                }
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

// Chips removibles con los filtros activos — sin esto, no había forma de saber qué se estaba
// filtrando sin volver a abrir la hoja de filtros.
private struct ActiveFiltersRow: View {
    @Binding var filters: ListFilters

    private var chips: [FilterChip] {
        var result: [FilterChip] = []
        if filters.ruc != .all {
            result.append(FilterChip(label: filters.ruc.rawValue) { filters.ruc = .all })
        }
        for category in filters.categories.sorted() {
            result.append(FilterChip(label: category) { filters.categories.remove(category) })
        }
        for method in filters.paymentMethods.sorted() {
            result.append(FilterChip(label: method) { filters.paymentMethods.remove(method) })
        }
        return result
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(chips) { chip in
                    Button(action: chip.remove) {
                        HStack(spacing: 4) {
                            Text(chip.label)
                            Image(systemName: "xmark.circle.fill")
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundStyle(Color("PanamaBlue"))
                    .background(Color("PanamaBlue").opacity(0.15), in: Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(.thinMaterial)
    }
}

private struct FilterChip: Identifiable {
    let id = UUID()
    let label: String
    let remove: () -> Void
}

#Preview {
    ExpenseListView()
        .modelContainer(for: Expense.self, inMemory: true)
}
