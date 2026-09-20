//
//  PendingLookupsView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData

// Spec section 15 (pantalla 6) y sección 8: respaldo manual de la cola offline — el reintento
// automático al volver a primer plano vive en ContentView (scenePhase), no aquí.
struct PendingLookupsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PendingLookup.firstAttemptDate) private var pendingLookups: [PendingLookup]
    @State private var isRetrying = false

    var body: some View {
        NavigationStack {
            Group {
                if pendingLookups.isEmpty {
                    ContentUnavailableView(
                        "Sin pendientes",
                        systemImage: "checkmark.circle",
                        description: Text("No hay consultas esperando por conexión.")
                    )
                } else {
                    List(pendingLookups) { lookup in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lookup.cufe)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Text("\(attemptCountLabel(lookup.attemptCount)) desde \(lookup.firstAttemptDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Pendientes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await retryNow() }
                    } label: {
                        if isRetrying {
                            ProgressView()
                        } else {
                            Label("Reintentar ahora", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isRetrying || pendingLookups.isEmpty)
                }
            }
        }
    }

    private func retryNow() async {
        isRetrying = true
        defer { isRetrying = false }
        try? await PendingLookupQueue.retryAll(in: modelContext)
    }

    private func attemptCountLabel(_ count: Int) -> String {
        count == 1 ? "1 intento" : "\(count) intentos"
    }
}
