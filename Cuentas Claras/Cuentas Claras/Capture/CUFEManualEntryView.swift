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

    var onSaved: () -> Void = {}

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

        let outcome = await DGIInvoiceLookupService.lookup(cufe: cufe)
        if let message = CUFEResolution.handle(outcome, cufe: cufe, in: modelContext) {
            statusMessage = message
        } else {
            onSaved()
        }
    }
}

#Preview {
    NavigationStack {
        CUFEManualEntryView()
    }
    .modelContainer(for: Expense.self, inMemory: true)
}
