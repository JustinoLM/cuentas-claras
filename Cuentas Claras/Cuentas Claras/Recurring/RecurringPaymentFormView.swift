//
//  RecurringPaymentFormView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/07/26.
//

import SwiftUI
import SwiftData

// Crear o editar una plantilla (spec 3.6 y 19). `payment == nil` crea.
struct RecurringPaymentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let payment: RecurringPayment?
    var onSaved: (String) -> Void = { _ in }

    @State private var name: String
    @State private var amountText: String
    @State private var category: String
    @State private var paymentMethod: ManualPaymentMethod?
    @State private var frequency: RecurrenceFrequency
    @State private var anchor: Date

    init(payment: RecurringPayment?, onSaved: @escaping (String) -> Void = { _ in }) {
        self.payment = payment
        self.onSaved = onSaved
        _name = State(initialValue: payment?.name ?? "")
        _amountText = State(initialValue: payment.map { $0.amount.formatted(.number.precision(.fractionLength(2)).grouping(.never)) } ?? "")
        _category = State(initialValue: payment?.category ?? "")
        _paymentMethod = State(initialValue: payment?.paymentMethod.flatMap(ManualPaymentMethod.init(rawValue:)))
        _frequency = State(initialValue: payment?.frequency ?? .monthly)
        _anchor = State(initialValue: RecurrenceSchedule.pickerDate(from: payment?.anchorDate ?? RecurrenceSchedule.today()))
    }

    private var parsedAmount: Decimal? {
        guard let amount = Decimal(string: amountText, locale: .current), amount > 0 else { return nil }
        return amount
    }

    private var anchorFooter: String {
        switch frequency {
        case .biweekly:
            "Se paga el 15 y el último día de cada mes. El primer vencimiento es el próximo 15 o fin de mes desde esta fecha."
        case .monthly, .yearly:
            "Se repite el mismo día; si el mes no lo tiene, cae en el último día del mes."
        }
    }

    var body: some View {
        Form {
            Section("Pago") {
                TextField("Nombre", text: $name)
                TextField("Monto", text: $amountText)
                    .keyboardType(.decimalPad)
                TextField("Categoría", text: $category)
                Picker("Método de pago", selection: $paymentMethod) {
                    Text("Sin definir").tag(ManualPaymentMethod?.none)
                    ForEach(ManualPaymentMethod.allCases) { method in
                        Text(method.rawValue).tag(ManualPaymentMethod?.some(method))
                    }
                }
            }

            Section {
                Picker("Frecuencia", selection: $frequency) {
                    ForEach(RecurrenceFrequency.allCases) { frequency in
                        Text(frequency.label).tag(frequency)
                    }
                }
                DatePicker("Primer vencimiento", selection: $anchor, displayedComponents: .date)
            } footer: {
                Text(anchorFooter)
            }
        }
        .navigationTitle(payment == nil ? "Nuevo pago recurrente" : "Editar pago recurrente")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if payment == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Guardar") { save() }
                    .disabled(name.isEmpty || parsedAmount == nil)
            }
        }
    }

    private func save() {
        guard let amount = parsedAmount else { return }
        let anchorDate = RecurrenceSchedule.normalized(fromPicker: anchor)

        if let payment {
            let scheduleChanged = frequency != payment.frequency || anchorDate != payment.anchorDate
            payment.name = name
            payment.amount = amount
            payment.category = category.isEmpty ? nil : category
            payment.paymentMethod = paymentMethod?.rawValue
            payment.frequency = frequency
            payment.anchorDate = anchorDate
            if scheduleChanged {
                RecurringPaymentActions.reschedule(payment)
            }
        } else {
            modelContext.insert(RecurringPayment(
                name: name,
                amount: amount,
                category: category.isEmpty ? nil : category,
                paymentMethod: paymentMethod?.rawValue,
                frequency: frequency,
                anchorDate: anchorDate,
                nextDueDate: RecurrenceSchedule.firstDueDate(frequency: frequency, anchor: anchorDate, onOrAfter: anchorDate)
            ))
        }

        onSaved("Pago recurrente guardado")
        dismiss()
    }
}
