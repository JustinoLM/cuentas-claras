//
//  RecurringPaymentsView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/07/26.
//

import SwiftUI
import SwiftData

// Spec section 15 (pantalla 8) y sección 19: plantillas y vencimientos "Por confirmar".
struct RecurringPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecurringPayment.name) private var payments: [RecurringPayment]
    @State private var today = RecurrenceSchedule.today()
    @State private var isShowingNew = false
    @State private var dueToConfirm: PendingRecurringDue?
    @State private var banner: ConfirmationBanner?

    private var dues: [PendingRecurringDue] {
        RecurringPaymentActions.pendingDues(for: payments, today: today)
    }

    var body: some View {
        NavigationStack {
            Group {
                if payments.isEmpty {
                    ContentUnavailableView(
                        "Sin pagos recurrentes",
                        systemImage: "repeat",
                        description: Text("Toca + para crear tu primera plantilla.")
                    )
                } else {
                    List {
                        if !dues.isEmpty {
                            Section {
                                ForEach(dues) { due in
                                    dueRow(due)
                                }
                            } header: {
                                Text("Por confirmar")
                            } footer: {
                                Text("Toca el más antiguo de cada pago para confirmarlo, o desliza para omitirlo.")
                            }
                        }

                        Section("Plantillas") {
                            ForEach(payments) { payment in
                                NavigationLink {
                                    RecurringPaymentFormView(payment: payment, onSaved: showSuccess)
                                } label: {
                                    templateRow(payment)
                                }
                                .swipeActions(edge: .leading) {
                                    if payment.isActive {
                                        Button("Pausar") { RecurringPaymentActions.pause(payment) }
                                            .tint(.orange)
                                    } else {
                                        Button("Reanudar") { RecurringPaymentActions.resume(payment) }
                                            .tint(.green)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    modelContext.delete(payments[index])
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Pagos recurrentes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isShowingNew = true
                    } label: {
                        Label("Nuevo pago recurrente", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingNew) {
                NavigationStack {
                    RecurringPaymentFormView(payment: nil, onSaved: showSuccess)
                }
            }
            .sheet(item: $dueToConfirm) { due in
                NavigationStack {
                    RecurringDueConfirmView(due: due) {
                        showSuccess("Pago confirmado")
                    }
                }
            }
            .confirmationBanner($banner)
        }
    }

    private func showSuccess(_ message: String) {
        banner = ConfirmationBanner(kind: .success, message: message)
    }

    @ViewBuilder
    private func dueRow(_ due: PendingRecurringDue) -> some View {
        let content = HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(due.payment.name)
                Text(RecurrenceSchedule.displayString(due.dueDate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !due.isOldest {
                    Text("Resuelve primero el anterior")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(due.payment.amount, format: .currency(code: "USD"))
        }

        if due.isOldest {
            Button {
                dueToConfirm = due
            } label: {
                content
            }
            .foregroundStyle(.primary)
            .swipeActions {
                Button("Omitir") {
                    RecurringPaymentActions.skip(due.payment)
                    showSuccess("Vencimiento omitido")
                }
                .tint(.gray)
            }
        } else {
            content.foregroundStyle(.secondary)
        }
    }

    private func templateRow(_ payment: RecurringPayment) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(payment.name)
            Group {
                if payment.isActive {
                    Text("\(payment.frequency.label) · \(payment.amount.formatted(.currency(code: "USD"))) · Próximo: \(RecurrenceSchedule.displayString(payment.nextDueDate))")
                } else {
                    Text("\(payment.frequency.label) · \(payment.amount.formatted(.currency(code: "USD"))) · Pausado")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
