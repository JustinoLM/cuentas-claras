//
//  QRCaptureView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

// Vía 1 (spec 4.1), sus dos caminos: cámara en vivo (QRCodeScannerView) y facturas compartidas
// como PDF (InvoicePDFBarcodeScanner) — ambos terminan en el mismo extractor de CUFE
// (InvoiceQRCode) y el mismo pipeline de resolución (CUFEResolution) que la Vía 2.
// DataScannerViewController.isSupported siempre es false en el Simulator — la cámara solo se
// puede probar en un iPhone físico, pero el camino de PDF no depende de eso.
struct QRCaptureView: View {
    @Environment(\.modelContext) private var modelContext

    var onSaved: (String) -> Void = { _ in }

    @State private var statusMessage: String?
    @State private var isProcessing = false
    @State private var isShowingFileImporter = false
    @State private var pendingExpense: Expense?

    var body: some View {
        ZStack(alignment: .bottom) {
            if QRCodeScannerView.isSupported {
                QRCodeScannerView { scannedValue in
                    handle(scannedValue: scannedValue)
                }
                .ignoresSafeArea()
            } else {
                ContentUnavailableView(
                    "Escaneo no disponible",
                    systemImage: "camera.fill",
                    description: Text("Este dispositivo no tiene cámara disponible para escanear códigos QR. Puedes importar un PDF con el código.")
                )
            }

            if let statusMessage {
                Text(statusMessage)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
        .navigationTitle("Escanear QR")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Importar PDF", systemImage: "doc.badge.plus")
                }
            }
        }
        .fileImporter(isPresented: $isShowingFileImporter, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                handle(pdfAt: url)
            case .failure:
                statusMessage = "No se pudo abrir el PDF."
            }
        }
        .navigationDestination(item: $pendingExpense) { expense in
            PendingExpenseReviewView(expense: expense, onSaved: onSaved, onDiscarded: { pendingExpense = nil })
        }
    }

    private func handle(scannedValue: String) {
        guard !isProcessing else { return }

        guard let cufe = InvoiceQRCode.cufe(fromScannedValue: scannedValue) else {
            statusMessage = "Este código QR no corresponde a una factura de la DGI."
            return
        }

        lookupAndResolve(cufe: cufe)
    }

    private func handle(pdfAt url: URL) {
        guard !isProcessing else { return }

        guard url.startAccessingSecurityScopedResource() else {
            statusMessage = "No se pudo abrir el PDF."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let document = PDFDocument(url: url) else {
            statusMessage = "No se pudo abrir el PDF."
            return
        }

        let cufe: String?
        do {
            cufe = try InvoicePDFBarcodeScanner.cufe(from: document)
        } catch {
            statusMessage = "No encontramos un código QR en el PDF."
            return
        }

        guard let cufe else {
            statusMessage = "El código QR del PDF no corresponde a una factura de la DGI."
            return
        }

        lookupAndResolve(cufe: cufe)
    }

    private func lookupAndResolve(cufe: String) {
        isProcessing = true
        Task {
            let outcome = await DGIInvoiceLookupService.lookup(cufe: cufe)
            isProcessing = false
            switch CUFEResolution.handle(outcome, cufe: cufe, in: modelContext) {
            case .message(let message):
                statusMessage = message
            case .needsReview(let expense):
                pendingExpense = expense
            }
        }
    }
}
