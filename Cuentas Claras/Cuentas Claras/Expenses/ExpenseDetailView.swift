//
//  ExpenseDetailView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec section 15, pantalla 2. Solo lectura salvo por borrar — no hay edición descrita en el spec
// para este gasto; la categoría de gastos con RUC se ajusta desde "Negocios sin categorizar"
// (sección 9), no aquí.
struct ExpenseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let expense: Expense

    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Negocio") {
                LabeledContent("Nombre", value: expense.issuerName)
                if let issuerRuc = expense.issuerRuc {
                    LabeledContent("RUC", value: issuerRuc)
                }
                LabeledContent("Categoría", value: expense.category ?? "Sin categorizar")
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
        .navigationTitle(expense.issuerName)
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
    }
}
