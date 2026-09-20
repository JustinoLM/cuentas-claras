//
//  ExpenseDetailView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec section 15, pantalla 2. Solo lectura salvo por borrar, categoría (cambiarla aquí en un
// gasto con RUC cambia la de TODO el Merchant, 9.3) y edición completa para gastos manuales
// (cufe == nil) — esos los tecleó el usuario y pueden tener errores, a diferencia de los de DGI.
struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let expense: Expense

    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingCategoryEditor = false
    @State private var isShowingAliasEditor = false

    private var displayName: String {
        MerchantCategorization.displayName(for: expense, in: modelContext)
    }

    private var resolvedCategory: String? {
        try? MerchantCategorization.category(for: expense, in: modelContext)
    }

    var body: some View {
        Form {
            Section("Negocio") {
                if expense.issuerRuc != nil {
                    Button {
                        isShowingAliasEditor = true
                    } label: {
                        LabeledContent("Nombre") {
                            EditableValueLabel(displayName)
                        }
                    }
                    .foregroundStyle(.primary)
                } else {
                    NavigationLink {
                        ManualExpenseFormView(existingExpense: expense)
                    } label: {
                        LabeledContent("Nombre") {
                            EditableValueLabel(displayName)
                        }
                    }
                }
                if let issuerRuc = expense.issuerRuc {
                    LabeledContent("RUC", value: issuerRuc)
                }
                if displayName != expense.issuerName {
                    LabeledContent("Razón social (DGI)", value: expense.issuerName)
                }
                Button {
                    isShowingCategoryEditor = true
                } label: {
                    LabeledContent("Categoría") {
                        EditableValueLabel(resolvedCategory ?? "Sin categorizar")
                    }
                }
                .foregroundStyle(.primary)
            }

            Section("Documento") {
                LabeledContent("Tipo", value: expense.documentType)
                if let invoiceNumber = expense.invoiceNumber {
                    LabeledContent("No. factura", value: invoiceNumber)
                }
                if let cufe = expense.cufe {
                    LabeledContent("CUFE") {
                        Text(cufe)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                    }
                }
                if let authorizationDate = expense.authorizationDate {
                    LabeledContent("Autorización", value: authorizationDate.formatted(date: .abbreviated, time: .shortened))
                } else if let issueDate = expense.issueDate {
                    LabeledContent("Fecha", value: issueDate.formatted(date: .abbreviated, time: .omitted))
                }
            }

            if !expense.items.isEmpty {
                Section("Ítems") {
                    ForEach(expense.items.sorted(by: { $0.lineNumber < $1.lineNumber })) { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.itemDescription)
                            Text("\(item.quantity.formatted()) x \(item.unitPrice, format: .currency(code: "USD"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Totales") {
                LabeledContent("Total", value: expense.totalAmount, format: .currency(code: "USD"))
                if expense.cufe != nil {
                    LabeledContent("ITBMS", value: expense.totalItbms, format: .currency(code: "USD"))
                }
                if let paymentMethod = expense.paymentMethod {
                    LabeledContent("Método de pago", value: paymentMethod)
                }
            }
            if expense.cufe == nil {
                Section {
                    NavigationLink("Editar gasto") {
                        ManualExpenseFormView(existingExpense: expense)
                    }
                }
            }

            Section {
                Button("Eliminar gasto", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .textSelection(.enabled)
        .navigationTitle(displayName)
        .confirmationDialog(
            "¿Eliminar este gasto?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                modelContext.delete(expense)
                dismiss()
            }
        } message: {
            Text("No se puede deshacer.")
        }
        .sheet(isPresented: $isShowingCategoryEditor) {
            ValueEditorSheet(
                title: "Editar categoría",
                fieldLabel: "Categoría",
                initialValue: resolvedCategory,
                footer: expense.issuerRuc != nil ? "Este cambio aplica a todas las facturas de este negocio (mismo RUC), no solo a esta." : nil,
                suggestions: MerchantCategorization.existingCategories(in: modelContext)
            ) { newCategory in
                MerchantCategorization.setCategory(newCategory, for: expense, in: modelContext)
            }
        }
        .sheet(isPresented: $isShowingAliasEditor) {
            ValueEditorSheet(
                title: "Editar alias",
                fieldLabel: "Alias",
                initialValue: displayName == expense.issuerName ? nil : displayName,
                footer: "Se usa en vez de la razón social de la DGI (\(expense.issuerName)) en toda la app, para este negocio."
            ) { newAlias in
                MerchantCategorization.setAlias(newAlias, for: expense, in: modelContext)
            }
        }
    }
}

// Compartido por el editor de categoría y de alias — mismo patrón de campo de texto + sugerencias
// opcionales + Cancelar/Guardar.
// Marca visualmente una fila como tocable — sin esto no hay ninguna señal de que "Nombre" y
// "Categoría" se puedan editar, se ven igual que cualquier otra fila de solo lectura.
private struct EditableValueLabel: View {
    let value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(value)
            Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ValueEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let fieldLabel: String
    let initialValue: String?
    var footer: String?
    var suggestions: [String] = []
    let onSave: (String?) -> Void

    @State private var value: String

    init(title: String, fieldLabel: String, initialValue: String?, footer: String? = nil, suggestions: [String] = [], onSave: @escaping (String?) -> Void) {
        self.title = title
        self.fieldLabel = fieldLabel
        self.initialValue = initialValue
        self.footer = footer
        self.suggestions = suggestions
        self.onSave = onSave
        _value = State(initialValue: initialValue ?? "")
    }

    private var filteredSuggestions: [String] {
        guard !value.isEmpty else { return suggestions }
        return suggestions.filter { $0.localizedCaseInsensitiveContains(value) && $0 != value }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(fieldLabel, text: $value)
                } footer: {
                    if let footer {
                        Text(footer)
                    }
                }

                if !filteredSuggestions.isEmpty {
                    Section("Ya usadas") {
                        ForEach(filteredSuggestions, id: \.self) { suggestion in
                            Button(suggestion) { value = suggestion }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(value.isEmpty ? nil : value)
                        dismiss()
                    }
                }
            }
        }
    }
}
