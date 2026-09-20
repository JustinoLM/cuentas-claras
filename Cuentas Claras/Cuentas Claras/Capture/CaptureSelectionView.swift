//
//  CaptureSelectionView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// Spec section 15, pantalla 3: selector entre las tres vías de captura (sección 4).
struct CaptureSelectionView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    QRCaptureView()
                } label: {
                    Label("Escanear QR", systemImage: "qrcode.viewfinder")
                }

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
