//
//  CaptureSelectionView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// Spec section 15, pantalla 3: selector entre las tres vías de captura (sección 4).
struct CaptureSelectionView: View {
    // Se llama cuando cualquiera de las tres vías guarda un Expense, con un mensaje ya redactado
    // según el tipo ("Factura guardada" / "Gasto guardado") — quien presenta esta vista
    // (ExpenseListView, como sheet) decide qué hacer, normalmente cerrar el sheet y mostrarlo.
    var onFinished: (String) -> Void = { _ in }

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
