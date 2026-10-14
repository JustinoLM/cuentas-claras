//
//  RecurringDueConfirmView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/07/26.
//

import SwiftUI
import SwiftData

// Spec section 19: confirmar un vencimiento crea un gasto manual normal; monto y fecha son editables.
struct RecurringDueConfirmView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let due: PendingRecurringDue
    var onConfirmed: () -> Void

    @State private var amountText: String
    @State private var date: Date

    init(due: PendingRecurringDue, onConfirmed: @escaping () -> Void) {
        self.due = due
        self.onConfirmed = onConfirmed
        _amountText = State(initialValue: due.payment.amount.formatted(.number.precision(.fractionLength(2)).grouping(.never)))
        _date = State(initialValue: RecurrenceSchedule.pickerDate(from: due.dueDate))
    }

    private var parsedAmount: Decimal? {
        guard let amount = Decimal(string: amountText, locale: .current), amount > 0 else { return nil }
        return amount
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Pago", value: due.payment.name)
                TextField("Monto", text: $amountText)
                    .keyboardType(.decimalPad)
                DatePicker("Fecha", selection: $date, displayedComponents: .date)
            }
        }
        .navigationTitle("Confirmar pago")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Confirmar") { confirm() }
                    .disabled(parsedAmount == nil)
            }
        }
    }

    private func confirm() {
        guard let amount = parsedAmount else { return }
        RecurringPaymentActions.confirm(
            due.payment,
            amount: amount,
            issueDate: RecurrenceSchedule.normalized(fromPicker: date),
            in: modelContext
        )
        onConfirmed()
        dismiss()
    }
}
