//
//  QRCodeScannerView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI
import Vision
import VisionKit

// Vía 1, cámara en vivo (spec 4.1). Entrega el payload crudo del QR — la extracción del CUFE
// (InvoiceQRCode) es la misma que usa la vía PDF.
struct QRCodeScannerView: UIViewControllerRepresentable {
    var onScannedValue: (String) -> Void

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScannedValue: onScannedValue)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScannedValue: (String) -> Void

        init(onScannedValue: @escaping (String) -> Void) {
            self.onScannedValue = onScannedValue
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                guard case .barcode(let barcode) = item, let payload = barcode.payloadStringValue else { continue }
                onScannedValue(payload)
            }
        }
    }
}
