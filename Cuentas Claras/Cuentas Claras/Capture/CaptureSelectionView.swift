//
//  CaptureSelectionView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// Spec section 15, pantalla 3: selector entre las tres vías de captura (sección 4). QR y CUFE
// manual llegan en PRs separados — por ahora solo Vía 3 (gasto manual) está conectada.
struct CaptureSelectionView: View {
    var body: some View {
        NavigationStack {
            List {
                Label("Escanear QR", systemImage: "qrcode.viewfinder")
                    .foregroundStyle(.secondary)
                Label("CUFE manual", systemImage: "number")
                    .foregroundStyle(.secondary)

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
