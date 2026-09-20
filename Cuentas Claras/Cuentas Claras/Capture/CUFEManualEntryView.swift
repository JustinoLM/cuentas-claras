//
//  CUFEManualEntryView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Vía 2 (spec 4.2): "corre la misma validación y el mismo pipeline de parseo que la Vía 1,
// saltándose solo el paso de lectura del QR" — por eso solo teclea el CUFE y llama al mismo
// DGIInvoiceLookupService. Cubre los estados de la tabla 5.7.
struct CUFEManualEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var cufe = ""
    @State private var isLookingUp = false
    @State private var statusMessage: String?

    var body: some View {
        Form {
            Section {
                TextField("CUFE", text: $cufe)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .onChange(of: cufe) { _, newValue in
                        cufe = String(newValue.uppercased().prefix(66))
                    }
            } footer: {
                if let statusMessage {
                    Text(statusMessage)
                }
            }

            Button {
                Task { await consultar() }
            } label: {
                if isLookingUp {
                    ProgressView()
                } else {
                    Text("Consultar")
                }
            }
            .disabled(cufe.isEmpty || isLookingUp)
        }
        .navigationTitle("CUFE manual")
    }

    private func consultar() async {
        isLookingUp = true
        statusMessage = nil
        defer { isLookingUp = false }

        switch await DGIInvoiceLookupService.lookup(cufe: cufe) {
        case .invalidFormat:
            statusMessage = "El CUFE no tiene un formato válido."

        case .networkError:
            try? PendingLookupQueue.enqueue(cufe: cufe, in: modelContext)
            statusMessage = "No hay conexión. Se guardó para reintentar cuando vuelva la señal."

        case .parsingFailed:
            statusMessage = "No se pudo leer la respuesta de la DGI."

        case .parsed(.notFound):
            statusMessage = "No se encontró ninguna factura con ese CUFE."

        case .parsed(.unsupported):
            statusMessage = "Ese documento no es una factura soportada (por ejemplo, una nota de crédito)."

        case .parsed(.success(let expense)):
            if let existing = try? ExpenseDeduplicator.existingExpense(withCufe: cufe, in: modelContext) {
                statusMessage = "Ya tenías esta factura guardada: \(existing.issuerName)."
                return
            }

            if let issuerRuc = expense.issuerRuc {
                try? MerchantCategorization.registerMerchantIfNeeded(issuerRuc: issuerRuc, issuerName: expense.issuerName, in: modelContext)
            }
            modelContext.insert(expense)
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        CUFEManualEntryView()
    }
    .modelContainer(for: Expense.self, inMemory: true)
}
