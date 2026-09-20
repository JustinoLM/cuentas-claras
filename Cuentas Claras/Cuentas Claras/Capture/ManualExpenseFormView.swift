//
//  ManualExpenseFormView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Vía 3 (spec 4.3): sin CUFE, sin RUC. "Seleccionar uno existente de Merchant si coincide" se
// resuelve como autocompletado del nombre — no hay RUC que enlazar, así que la categoría de este
// gasto siempre sale directo de Expense.category (ver MerchantCategorization).
struct ManualExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Merchant.name) private var merchants: [Merchant]

    // nil = capturando uno nuevo (Vía 3). No nil = editando un gasto manual existente — no pasa
    // por la verificación de duplicados (6.2), no tendría sentido comparar el gasto contra sí mismo.
    var existingExpense: Expense?
    var onSaved: () -> Void = {}

    @State private var issuerName: String
    @State private var totalAmountText: String
    @State private var date: Date
    @State private var category: String
    @State private var duplicateCandidate: Expense?
    @State private var showingDuplicateAlert = false

    init(existingExpense: Expense? = nil, onSaved: @escaping () -> Void = {}) {
        self.existingExpense = existingExpense
        self.onSaved = onSaved
        _issuerName = State(initialValue: existingExpense?.issuerName ?? "")
        _totalAmountText = State(initialValue: existingExpense?.totalAmount.formatted(.number.grouping(.never)) ?? "")
        _date = State(initialValue: existingExpense?.issueDate ?? Date())
        _category = State(initialValue: existingExpense?.category ?? "")
    }

    private var matchingMerchants: [Merchant] {
        guard !issuerName.isEmpty else { return [] }
        return merchants.filter { $0.name.localizedCaseInsensitiveContains(issuerName) && $0.name != issuerName }
    }

    private var parsedAmount: Decimal? {
        guard let amount = Decimal(string: totalAmountText, locale: .current), amount > 0 else { return nil }
        return amount
    }

    var body: some View {
        Form {
            Section("Negocio") {
                TextField("Nombre del negocio", text: $issuerName)
                ForEach(matchingMerchants, id: \.ruc) { merchant in
                    Button(merchant.name) {
                        issuerName = merchant.name
                    }
                }
            }

            Section("Detalle") {
                TextField("Monto total", text: $totalAmountText)
                    .keyboardType(.decimalPad)
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
                TextField("Categoría", text: $category)
            }
        }
        .navigationTitle(existingExpense == nil ? "Gasto manual" : "Editar gasto")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { save() }
                    .disabled(issuerName.isEmpty || parsedAmount == nil)
            }
        }
        .alert("Gasto similar encontrado", isPresented: $showingDuplicateAlert, presenting: duplicateCandidate) { existing in
            Button("Agregar igual", role: .destructive) {
                if let amount = parsedAmount {
                    commit(totalAmount: amount)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: { existing in
            Text("Ya tienes un gasto de \(existing.issuerName) por el mismo monto y fecha. ¿Lo agregas igual?")
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }

        guard existingExpense == nil else {
            commit(totalAmount: amount)
            return
        }

        if let existing = try? ExpenseDeduplicator.possibleDuplicate(
            issuerRuc: nil,
            issuerName: issuerName,
            date: date,
            totalAmount: amount,
            in: modelContext
        ) {
            duplicateCandidate = existing
            showingDuplicateAlert = true
            return
        }

        commit(totalAmount: amount)
    }

    private func commit(totalAmount: Decimal) {
        if let existingExpense {
            existingExpense.issuerName = issuerName
            existingExpense.totalAmount = totalAmount
            existingExpense.issueDate = date
            existingExpense.category = category.isEmpty ? nil : category
        } else {
            let expense = Expense(
                documentType: "MANUAL",
                issueDate: date,
                issuerName: issuerName,
                totalAmount: totalAmount,
                totalItbms: 0,
                category: category.isEmpty ? nil : category,
                source: .manual
            )
            modelContext.insert(expense)
        }
        onSaved()
    }
}

#Preview {
    NavigationStack {
        ManualExpenseFormView()
    }
    .modelContainer(for: Expense.self, inMemory: true)
}
