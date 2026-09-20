//
//  InvoicePDFBarcodeScanner.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import PDFKit
import Vision

// Vía 1, PDF path (spec 4.1): facturas compartidas como PDF en vez de escaneadas en vivo.
// PDFKit rasteriza la primera página, Vision lee el QR de esa imagen — mismo extractor de CUFE
// que la vía de cámara (InvoiceQRCode).
enum InvoicePDFBarcodeScanner {
    enum ScanError: Error {
        case noPages
        case renderingFailed
        case noBarcodeFound
    }

    static func cufe(from document: PDFDocument) throws -> String? {
        let payload = try scanFirstPage(of: document)
        return InvoiceQRCode.cufe(fromScannedValue: payload)
    }

    static func scanFirstPage(of document: PDFDocument, scale: CGFloat = 2) throws -> String {
        guard let page = document.page(at: 0) else {
            throw ScanError.noPages
        }

        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        guard let cgImage = page.thumbnail(of: size, for: .mediaBox).cgImage else {
            throw ScanError.renderingFailed
        }

        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

        guard let payload = request.results?.first?.payloadStringValue else {
            throw ScanError.noBarcodeFound
        }
        return payload
    }
}
