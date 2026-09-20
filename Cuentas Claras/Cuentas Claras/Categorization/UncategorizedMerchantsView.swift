//
//  UncategorizedMerchantsView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec section 15 (pantalla 4) y sección 9: Merchant con category == nil. También deja editar el
// alias (9.1) — la mayoría de negocios recién capturados llegan aquí sin categorizar todavía, así
// que es el lugar más natural para ajustarlo, aunque el spec no lo pida explícito para esta pantalla.
//
// Un gasto manual nunca crea un Merchant (no tiene RUC, spec 4.3), así que uno sin categoría no
// aparecería en ningún lado sin esta segunda lista — se identifican por cufe == nil, igual que en
// el resto del código (MerchantCategorization.setCategory usa el mismo criterio para saber dónde
// guardar la categoría).
struct UncategorizedMerchantsView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Merchant> { $0.category == nil }, sort: \Merchant.name)
    private var merchants: [Merchant]

    @Query(filter: #Predicate<Expense> { $0.cufe == nil && $0.category == nil }, sort: \Expense.issuerName)
    private var uncategorizedManualExpenses: [Expense]

    var body: some View {
        NavigationStack {
            Group {
                if merchants.isEmpty && uncategorizedManualExpenses.isEmpty {
                    ContentUnavailableView(
                        "Todo categorizado",
                        systemImage: "checkmark.circle",
                        description: Text("No hay negocios ni gastos pendientes de categorizar.")
                    )
                } else {
                    List {
                        if !merchants.isEmpty {
                            Section("Negocios") {
                                ForEach(merchants) { merchant in
                                    MerchantCategorizationRow(
                                        merchant: merchant,
                                        existingCategories: MerchantCategorization.existingCategories(in: modelContext)
                                    )
                                }
                            }
                        }

                        if !uncategorizedManualExpenses.isEmpty {
                            Section("Gastos manuales") {
                                ForEach(uncategorizedManualExpenses) { expense in
                                    ManualExpenseCategorizationRow(
                                        expense: expense,
                                        existingCategories: MerchantCategorization.existingCategories(in: modelContext)
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sin categorizar")
        }
    }
}

private struct MerchantCategorizationRow: View {
    let merchant: Merchant
    let existingCategories: [String]

    @State private var alias: String
    @State private var category = ""

    init(merchant: Merchant, existingCategories: [String]) {
        self.merchant = merchant
        self.existingCategories = existingCategories
        _alias = State(initialValue: merchant.alias ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(merchant.alias ?? merchant.name)
                .font(.headline)
            Text(merchant.ruc)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Alias (opcional)", text: $alias)
                .textFieldStyle(.roundedBorder)

            CategoryField(category: $category, existingCategories: existingCategories)

            Button("Guardar") {
                merchant.alias = alias.isEmpty ? nil : alias
                merchant.category = category
            }
            .disabled(category.isEmpty)
        }
        .padding(.vertical, 4)
    }
}

private struct ManualExpenseCategorizationRow: View {
    let expense: Expense
    let existingCategories: [String]

    @State private var category = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(expense.issuerName)
                .font(.headline)
            Text(expense.totalAmount, format: .currency(code: "USD"))
                .font(.caption)
                .foregroundStyle(.secondary)

            CategoryField(category: $category, existingCategories: existingCategories)

            Button("Guardar") {
                expense.category = category
            }
            .disabled(category.isEmpty)
        }
        .padding(.vertical, 4)
    }
}

private struct CategoryField: View {
    @Binding var category: String
    let existingCategories: [String]

    private var suggestions: [String] {
        guard !category.isEmpty else { return existingCategories }
        return existingCategories.filter { $0.localizedCaseInsensitiveContains(category) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Categoría", text: $category)
                .textFieldStyle(.roundedBorder)

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) { category = suggestion }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
}
