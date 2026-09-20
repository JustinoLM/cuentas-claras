//
//  DGIInvoiceLookupService.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation

// Adds the two states DGIParseResult deliberately leaves out (see its own comment): .invalidFormat
// is decided before any request, and .networkError is the only one that feeds the offline queue
// (section 8) — a markup change (.parsingFailed) is a different problem and must not be retried.
enum CUFELookupOutcome {
    case invalidFormat
    case networkError(Error)
    case parsingFailed(DGIParsingError)
    case parsed(DGIParseResult)
}

// Shared by Vía 1 (QR) and Vía 2 (CUFE manual) — same validation, same request, same parser (spec 4.2).
enum DGIInvoiceLookupService {
    private static let baseURL = URL(string: "https://dgi-fep.mef.gob.pa/Consultas/FacturasPorCUFE/")!

    static func lookup(cufe: String, urlSession: URLSession = .shared) async -> CUFELookupOutcome {
        guard DGICUFEValidator.isValidFormat(cufe) else {
            return .invalidFormat
        }

        let url = baseURL.appendingPathComponent(cufe)
        let html: String
        do {
            let (data, _) = try await urlSession.data(from: url)
            guard let decoded = String(data: data, encoding: .utf8) else {
                return .networkError(URLError(.cannotDecodeContentData))
            }
            html = decoded
        } catch {
            return .networkError(error)
        }

        do {
            return .parsed(try DGIInvoiceParser.parse(html: html))
        } catch let error as DGIParsingError {
            return .parsingFailed(error)
        } catch {
            return .networkError(error)
        }
    }
}
