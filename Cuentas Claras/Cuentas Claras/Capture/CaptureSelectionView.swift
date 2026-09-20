//
//  CaptureSelectionView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// Spec section 15, pantalla 3: selector entre las tres vías de captura (sección 4).
struct CaptureSelectionView: View {
    // Se llama cuando cualquiera de las tres vías guarda un Expense — quien presenta esta vista
    // (ExpenseListView, como sheet) decide qué hacer, normalmente cerrar el sheet entero.
    var onFinished: () -> Void = {}

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    QRCaptureView(onSaved: onFinished)
                } label: {
                    Label("Escanear QR", systemImage: "qrcode.viewfinder")
                }

                NavigationLink {
                    CUFEManualEntryView(onSaved: onFinished)
                } label: {
                    Label("CUFE manual", systemImage: "number")
                }

                NavigationLink {
                    ManualExpenseFormView(onSaved: onFinished)
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
