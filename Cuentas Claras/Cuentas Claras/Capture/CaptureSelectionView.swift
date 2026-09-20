//
//  CaptureSelectionView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// Spec section 15, pantalla 3: selector entre las tres vías de captura (sección 4). QR llega en un
// PR separado (necesita dispositivo real para probarse) — CUFE manual y gasto manual ya están conectados.
struct CaptureSelectionView: View {
    var body: some View {
        NavigationStack {
            List {
                Label("Escanear QR", systemImage: "qrcode.viewfinder")
                    .foregroundStyle(.secondary)

                NavigationLink {
                    CUFEManualEntryView()
                } label: {
                    Label("CUFE manual", systemImage: "number")
                }

                NavigationLink {
                    ManualExpenseFormView()
                } label: {
                    Label("Gasto manual completo", systemImage: "square.and.pencil")
                }
            }
            .navigationTitle("Capturar factura")
        }
    }
}

#Preview {
    CaptureSelectionView()
}
