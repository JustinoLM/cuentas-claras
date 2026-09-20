//
//  ListFiltersSheet.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// Filtros de Mis Facturas, además del buscador por nombre que ya existe. Solo estado de UI, no se
// persiste — categoría y método de pago se restringen a lo que ya está en uso, no a listas fijas
// arbitrarias (el método de pago manual sí tiene una lista fija propia, ManualPaymentMethod, pero
// la DGI puede traer otros valores en el HTML — filtrar debe cubrir ambos).
struct ListFilters {
    enum RUCFilter: String, CaseIterable, Identifiable {
        case all = "Todos"
        case withRUC = "Con RUC"
        case withoutRUC = "Sin RUC"
        var id: String { rawValue }
    }

    var ruc: RUCFilter = .all
    var categories: Set<String> = []
    var paymentMethods: Set<String> = []

    var isActive: Bool {
        ruc != .all || !categories.isEmpty || !paymentMethods.isEmpty
    }
}

struct ListFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var filters: ListFilters
    let availableCategories: [String]
    let availablePaymentMethods: [String]

    var body: some View {
        NavigationStack {
            Form {
                Section("RUC") {
                    Picker("RUC", selection: $filters.ruc) {
                        ForEach(ListFilters.RUCFilter.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                if !availableCategories.isEmpty {
                    Section("Categoría") {
                        ForEach(availableCategories, id: \.self) { category in
                            toggleRow(category, isOn: filters.categories.contains(category)) {
                                toggle(category, in: &filters.categories)
                            }
                        }
                    }
                }

                if !availablePaymentMethods.isEmpty {
                    Section("Método de pago") {
                        ForEach(availablePaymentMethods, id: \.self) { method in
                            toggleRow(method, isOn: filters.paymentMethods.contains(method)) {
                                toggle(method, in: &filters.paymentMethods)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Limpiar") { filters = ListFilters() }
                        .disabled(!filters.isActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func toggleRow(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                if isOn {
                    Image(systemName: "checkmark")
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) {
            set.remove(value)
        } else {
            set.insert(value)
        }
    }
}
