//
//  PendingExpenseReviewView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec 4.4: entre el parseo exitoso (vías 1 y 2) y el guardado real — el Expense que llega acá
// todavía no está insertado en el modelContext.
struct PendingExpenseReviewView: View {
    @Query(sort: \Merchant.name) private var merchants: [Merchant]
    @Environment(\.modelContext) private var modelContext

    let expense: Expense
    var onSaved: () -> Void = {}
    var onDiscarded: () -> Void = {}

    @State private var alias = ""

    private var existingMerchant: Merchant? {
        guard let issuerRuc = expense.issuerRuc else { return nil }
        return merchants.first { $0.ruc == issuerRuc }
    }

    private var aliasSuggestions: [Merchant] {
        guard !alias.isEmpty else { return [] }
        let currentDisplayName = existingMerchant?.alias ?? existingMerchant?.name
        return merchants.filter {
            let name = $0.alias ?? $0.name
            return name.localizedCaseInsensitiveContains(alias) && name != currentDisplayName
        }
    }

    var body: some View {
        Form {
            Section("Negocio") {
                LabeledContent("Nombre DGI", value: expense.issuerName)
                if let issuerRuc = expense.issuerRuc {
                    LabeledContent("RUC", value: issuerRuc)
                }
                TextField("Alias (opcional)", text: $alias)
                ForEach(aliasSuggestions, id: \.ruc) { merchant in
                    Button(merchant.alias ?? merchant.name) {
                        alias = merchant.alias ?? merchant.name
                    }
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
        }
        .navigationTitle("Revisar factura")
        .navigationBarBackButtonHidden()
        .onAppear {
            alias = existingMerchant?.alias ?? ""
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Descartar", role: .destructive) {
                    onDiscarded()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") {
                    CUFEResolution.confirm(expense, alias: alias.isEmpty ? nil : alias, in: modelContext)
                    onSaved()
                }
            }
        }
    }
}
