//
//  ExpenseDetailView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec section 15, pantalla 2. Solo lectura salvo por borrar y por categoría — cambiarla aquí en
// un gasto con RUC cambia la de TODO el Merchant (9.3), igual que desde "Negocios sin categorizar".
struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let expense: Expense

    @State private var isShowingDeleteConfirmation = false
    @State private var isShowingCategoryEditor = false

    private var displayName: String {
        MerchantCategorization.displayName(for: expense, in: modelContext)
    }

    private var resolvedCategory: String? {
        try? MerchantCategorization.category(for: expense, in: modelContext)
    }

    var body: some View {
        Form {
            Section("Negocio") {
                LabeledContent("Nombre", value: displayName)
                if let issuerRuc = expense.issuerRuc {
                    LabeledContent("RUC", value: issuerRuc)
                }
                if displayName != expense.issuerName {
                    LabeledContent("Razón social (DGI)", value: expense.issuerName)
                }
                Button {
                    isShowingCategoryEditor = true
                } label: {
                    LabeledContent("Categoría", value: resolvedCategory ?? "Sin categorizar")
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
                LabeledContent("ITBMS", value: expense.totalItbms, format: .currency(code: "USD"))
                if let paymentMethod = expense.paymentMethod {
                    LabeledContent("Método de pago", value: paymentMethod)
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
            CategoryEditorSheet(
                currentCategory: resolvedCategory,
                appliesToWholeBusiness: expense.issuerRuc != nil,
                existingCategories: MerchantCategorization.existingCategories(in: modelContext)
            ) { newCategory in
                MerchantCategorization.setCategory(newCategory, for: expense, in: modelContext)
            }
        }
    }
}

private struct CategoryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentCategory: String?
    let appliesToWholeBusiness: Bool
    let existingCategories: [String]
    let onSave: (String?) -> Void

    @State private var category: String

    init(currentCategory: String?, appliesToWholeBusiness: Bool, existingCategories: [String], onSave: @escaping (String?) -> Void) {
        self.currentCategory = currentCategory
        self.appliesToWholeBusiness = appliesToWholeBusiness
        self.existingCategories = existingCategories
        self.onSave = onSave
        _category = State(initialValue: currentCategory ?? "")
    }

    private var suggestions: [String] {
        guard !category.isEmpty else { return existingCategories }
        return existingCategories.filter { $0.localizedCaseInsensitiveContains(category) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Categoría", text: $category)
                } footer: {
                    if appliesToWholeBusiness {
                        Text("Este cambio aplica a todas las facturas de este negocio (mismo RUC), no solo a esta.")
                    }
                }

                if !suggestions.isEmpty {
                    Section("Ya usadas") {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) { category = suggestion }
                        }
                    }
                }
            }
            .navigationTitle("Editar categoría")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(category.isEmpty ? nil : category)
                        dismiss()
                    }
                }
            }
        }
    }
}
