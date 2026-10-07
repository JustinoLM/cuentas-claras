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
    var dateFrom: Date?
    var dateTo: Date?

    var isActive: Bool {
        ruc != .all || !categories.isEmpty || !paymentMethods.isEmpty || dateFrom != nil || dateTo != nil
    }

    // Rango inclusivo comparado por día calendario, no por instante: una factura de las 23:59 del día
    // "Hasta" tiene que entrar, y el DatePicker devuelve una hora arbitraria del día elegido.
    func includes(date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        if let dateFrom, day < calendar.startOfDay(for: dateFrom) { return false }
        if let dateTo, day > calendar.startOfDay(for: dateTo) { return false }
        return true
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

                Section("Fecha") {
                    Toggle("Desde", isOn: dateToggle(\.dateFrom, limit: filters.dateTo, isUpperBound: false))
                    if filters.dateFrom != nil {
                        DatePicker(
                            "Fecha de inicio",
                            selection: dateBinding(\.dateFrom),
                            in: Date.distantPast...(filters.dateTo ?? .distantFuture),
                            displayedComponents: .date
                        )
                    }

                    Toggle("Hasta", isOn: dateToggle(\.dateTo, limit: filters.dateFrom, isUpperBound: true))
                    if filters.dateTo != nil {
                        DatePicker(
                            "Fecha de fin",
                            selection: dateBinding(\.dateTo),
                            in: (filters.dateFrom ?? .distantPast)...Date.distantFuture,
                            displayedComponents: .date
                        )
                    }
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

    // Al encender un extremo arranca en hoy, ajustado al otro extremo si ya existe para que el rango
    // nunca quede invertido.
    private func dateToggle(_ keyPath: WritableKeyPath<ListFilters, Date?>, limit: Date?, isUpperBound: Bool) -> Binding<Bool> {
        Binding(
            get: { filters[keyPath: keyPath] != nil },
            set: { isOn in
                guard isOn else {
                    filters[keyPath: keyPath] = nil
                    return
                }
                let today = Calendar.current.startOfDay(for: Date())
                if let limit {
                    filters[keyPath: keyPath] = isUpperBound ? max(today, limit) : min(today, limit)
                } else {
                    filters[keyPath: keyPath] = today
                }
            }
        )
    }

    private func dateBinding(_ keyPath: WritableKeyPath<ListFilters, Date?>) -> Binding<Date> {
        Binding(
            get: { filters[keyPath: keyPath] ?? Calendar.current.startOfDay(for: Date()) },
            set: { filters[keyPath: keyPath] = Calendar.current.startOfDay(for: $0) }
        )
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
