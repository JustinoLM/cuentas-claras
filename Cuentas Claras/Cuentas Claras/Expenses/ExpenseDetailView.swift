//
//  ExpenseDetailView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec section 15, pantalla 2. Solo lectura salvo por borrar y por edición campo por campo — para
// gastos con RUC solo se puede editar alias y categoría (9.1, 9.3); para manuales (cufe == nil,
// spec 4.3) también nombre, fecha de pago, monto y método de pago, porque esos los tecleó el
// usuario y pueden tener errores, a diferencia de los datos oficiales de la DGI.
struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let expense: Expense

    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingCategoryEditor = false
    @State private var isShowingAliasEditor = false
    @State private var isShowingNameEditor = false
    @State private var isShowingDateEditor = false
    @State private var isShowingAmountEditor = false
    @State private var isShowingPaymentMethodEditor = false
    @State private var banner: ConfirmationBanner?

    private var displayName: String {
        MerchantCategorization.displayName(for: expense, in: modelContext)
    }

    private var resolvedCategory: String? {
        try? MerchantCategorization.category(for: expense, in: modelContext)
    }

    var body: some View {
        Form {
            Section {
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
                    Button {
                        isShowingNameEditor = true
                    } label: {
                        LabeledContent("Nombre") {
                            EditableValueLabel(displayName)
                        }
                    }
                    .foregroundStyle(.primary)
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
            } header: {
                HStack {
                    Text("Negocio")
                    Spacer()
                    RUCBadge(hasRUC: expense.issuerRuc != nil)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
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
                if expense.cufe != nil {
                    LabeledContent("Fecha de pago", value: expense.paymentDate.formatted(date: .abbreviated, time: .omitted))
                } else {
                    Button {
                        isShowingDateEditor = true
                    } label: {
                        LabeledContent("Fecha de pago") {
                            EditableValueLabel(expense.paymentDate.formatted(date: .abbreviated, time: .omitted))
                        }
                    }
                    .foregroundStyle(.primary)
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
                if expense.cufe != nil {
                    LabeledContent("Total", value: expense.totalAmount, format: .currency(code: "USD"))
                    LabeledContent("ITBMS", value: expense.totalItbms, format: .currency(code: "USD"))
                    if let paymentMethod = expense.paymentMethod {
                        LabeledContent("Método de pago", value: paymentMethod)
                    }
                } else {
                    Button {
                        isShowingAmountEditor = true
                    } label: {
                        LabeledContent("Total") {
                            EditableValueLabel(expense.totalAmount.formatted(.currency(code: "USD")))
                        }
                    }
                    .foregroundStyle(.primary)
                    Button {
                        isShowingPaymentMethodEditor = true
                    } label: {
                        LabeledContent("Método de pago") {
                            EditableValueLabel(expense.paymentMethod ?? "Sin definir")
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            Section {
                Button(expense.cufe != nil ? "Eliminar factura" : "Eliminar gasto", role: .destructive) {
                    isShowingDeleteConfirmation = true
                }
            }
        }
        .textSelection(.enabled)
        .navigationTitle(displayName)
        .confirmationDialog(
            expense.cufe != nil ? "¿Eliminar esta factura?" : "¿Eliminar este gasto?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                ExpenseDeletion.delete(expense, in: modelContext)
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
                let success = MerchantCategorization.setCategory(newCategory, for: expense, in: modelContext)
                banner = success
                    ? ConfirmationBanner(kind: .success, message: "Categoría actualizada")
                    : ConfirmationBanner(kind: .failure, message: "No se pudo guardar la categoría. Inténtalo de nuevo.")
            }
        }
        .sheet(isPresented: $isShowingAliasEditor) {
            ValueEditorSheet(
                title: "Editar alias",
                fieldLabel: "Alias",
                initialValue: displayName == expense.issuerName ? nil : displayName,
                footer: "Se usa en vez de la razón social de la DGI (\(expense.issuerName)) en toda la app."
            ) { newAlias in
                let success = MerchantCategorization.setAlias(newAlias, for: expense, in: modelContext)
                banner = success
                    ? ConfirmationBanner(kind: .success, message: "Alias actualizado")
                    : ConfirmationBanner(kind: .failure, message: "No se pudo guardar el alias. Inténtalo de nuevo.")
            }
        }
        .sheet(isPresented: $isShowingNameEditor) {
            ValueEditorSheet(
                title: "Editar nombre",
                fieldLabel: "Nombre del negocio",
                initialValue: expense.issuerName
            ) { newName in
                expense.issuerName = newName ?? expense.issuerName
                expense.markModifiedForSync()
                banner = ConfirmationBanner(kind: .success, message: "Nombre actualizado")
            }
        }
        .sheet(isPresented: $isShowingDateEditor) {
            DateEditorSheet(initialValue: expense.paymentDate) { newDate in
                expense.issueDate = newDate
                expense.markModifiedForSync()
                banner = ConfirmationBanner(kind: .success, message: "Fecha actualizada")
            }
        }
        .sheet(isPresented: $isShowingAmountEditor) {
            AmountEditorSheet(initialValue: expense.totalAmount) { newAmount in
                expense.totalAmount = newAmount
                expense.markModifiedForSync()
                banner = ConfirmationBanner(kind: .success, message: "Monto actualizado")
            }
        }
        .sheet(isPresented: $isShowingPaymentMethodEditor) {
            PaymentMethodEditorSheet(initialValue: expense.paymentMethod) { newMethod in
                expense.paymentMethod = newMethod
                expense.markModifiedForSync()
                banner = ConfirmationBanner(kind: .success, message: "Método de pago actualizado")
            }
        }
        .confirmationBanner($banner)
    }
}

// Marca visualmente una fila como tocable — sin esto no hay ninguna señal de que un campo se
// pueda editar, se ve igual que cualquier otra fila de solo lectura.
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

// Compartido por el editor de categoría, alias y nombre — mismo patrón de campo de texto +
// sugerencias opcionales + Cancelar/Guardar.
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

private struct DateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Date) -> Void

    @State private var date: Date

    init(initialValue: Date, onSave: @escaping (Date) -> Void) {
        self.onSave = onSave
        _date = State(initialValue: initialValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Fecha de pago", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
            }
            .navigationTitle("Editar fecha")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(date)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AmountEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (Decimal) -> Void

    @State private var text: String

    init(initialValue: Decimal, onSave: @escaping (Decimal) -> Void) {
        self.onSave = onSave
        _text = State(initialValue: initialValue.formatted(.number.grouping(.never)))
    }

    private var parsedAmount: Decimal? {
        guard let amount = Decimal(string: text, locale: .current), amount > 0 else { return nil }
        return amount
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Monto total", text: $text)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Editar monto")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guard let amount = parsedAmount else { return }
                        onSave(amount)
                        dismiss()
                    }
                    .disabled(parsedAmount == nil)
                }
            }
        }
    }
}

private struct PaymentMethodEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let onSave: (String?) -> Void

    @State private var selection: ManualPaymentMethod?

    init(initialValue: String?, onSave: @escaping (String?) -> Void) {
        self.onSave = onSave
        _selection = State(initialValue: initialValue.flatMap(ManualPaymentMethod.init(rawValue:)))
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Método de pago", selection: $selection) {
                    Text("Sin definir").tag(ManualPaymentMethod?.none)
                    ForEach(ManualPaymentMethod.allCases) { method in
                        Text(method.rawValue).tag(ManualPaymentMethod?.some(method))
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            .navigationTitle("Método de pago")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(selection?.rawValue)
                        dismiss()
                    }
                }
            }
        }
    }
}
