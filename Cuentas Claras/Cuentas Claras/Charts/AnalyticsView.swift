//
//  AnalyticsView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import Charts
import SwiftData

// Spec section 15, pantalla 5.
struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var expenses: [Expense]

    @State private var selectedYear: Int?
    @State private var selectedMonth = Calendar.current.component(.month, from: Date())

    private var availableYears: [Int] {
        ExpenseAnalytics.availableYears(for: expenses)
    }

    private var fortnightTotals: [ExpenseAnalytics.FortnightTotal] {
        guard let selectedYear else { return [] }
        return ExpenseAnalytics.totalsByFortnight(for: expenses, year: selectedYear, month: selectedMonth)
    }

    private var byCategory: [ExpenseAnalytics.CategoryTotal] {
        ExpenseAnalytics.totalsByCategory(for: expenses, in: modelContext)
    }

    private var byMonth: [ExpenseAnalytics.MonthlyTotal] {
        ExpenseAnalytics.totalsByMonth(for: expenses)
    }

    private var merchantTotals: [ExpenseAnalytics.MerchantTotal] {
        ExpenseAnalytics.totalsByMerchant(for: expenses, in: modelContext)
    }

    private var topMerchants: [ExpenseAnalytics.MerchantTotal] {
        Array(merchantTotals.prefix(10))
    }

    private var bottomMerchants: [ExpenseAnalytics.MerchantTotal] {
        Array(merchantTotals.suffix(10))
    }

    private var byYear: [ExpenseAnalytics.YearlyTotal] {
        ExpenseAnalytics.totalsByYear(for: expenses)
    }

    private var byVisitFrequency: [ExpenseAnalytics.MerchantFrequency] {
        Array(ExpenseAnalytics.visitFrequencyByMerchant(for: expenses, in: modelContext).prefix(10))
    }

    var body: some View {
        NavigationStack {
            Group {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "Sin datos todavía",
                        systemImage: "chart.bar",
                        description: Text("Captura alguna factura para ver las gráficas.")
                    )
                } else {
                    List {
                        Section("Quincenas") {
                            Picker("Año", selection: $selectedYear) {
                                ForEach(availableYears, id: \.self) { year in
                                    Text(String(year)).tag(Int?.some(year))
                                }
                            }
                            Picker("Mes", selection: $selectedMonth) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(Calendar.current.monthSymbols[month - 1].capitalized).tag(month)
                                }
                            }
                            Chart(fortnightTotals) { item in
                                BarMark(
                                    x: .value("Quincena", item.label),
                                    y: .value("Total", item.total.doubleValue)
                                )
                            }
                            .frame(height: 180)
                        }

                        Section("Por comercio — donde más gastas (top 10)") {
                            Chart(topMerchants) { item in
                                BarMark(
                                    x: .value("Total", item.total.doubleValue),
                                    y: .value("Comercio", item.name)
                                )
                            }
                            .frame(height: CGFloat(topMerchants.count) * 36 + 20)
                        }

                        Section("Por comercio — donde menos gastas (top 10)") {
                            Chart(bottomMerchants) { item in
                                BarMark(
                                    x: .value("Total", item.total.doubleValue),
                                    y: .value("Comercio", item.name)
                                )
                                .foregroundStyle(.red)
                            }
                            .frame(height: CGFloat(bottomMerchants.count) * 36 + 20)
                        }

                        Section("Por comercio — frecuencia de visitas (top 10)") {
                            Chart(byVisitFrequency) { item in
                                BarMark(
                                    x: .value("Visitas", item.visits),
                                    y: .value("Comercio", item.name)
                                )
                            }
                            .frame(height: CGFloat(byVisitFrequency.count) * 36 + 20)
                        }

                        Section("Por mes") {
                            Chart(byMonth) { item in
                                BarMark(
                                    x: .value("Mes", item.month, unit: .month),
                                    y: .value("Total", item.total.doubleValue)
                                )
                            }
                            .frame(height: 220)
                        }

                        Section("Por categoría") {
                            Chart(byCategory) { item in
                                BarMark(
                                    x: .value("Total", item.total.doubleValue),
                                    y: .value("Categoría", item.category)
                                )
                            }
                            .frame(height: CGFloat(byCategory.count) * 36 + 20)
                        }

                        Section("Por año") {
                            Chart(byYear) { item in
                                BarMark(
                                    x: .value("Año", String(item.year)),
                                    y: .value("Total", item.total.doubleValue)
                                )
                            }
                            .frame(height: 180)
                        }
                    }
                }
            }
            .navigationTitle("Gráficas")
            .onAppear {
                if selectedYear == nil {
                    selectedYear = availableYears.first
                }
            }
        }
    }
}
