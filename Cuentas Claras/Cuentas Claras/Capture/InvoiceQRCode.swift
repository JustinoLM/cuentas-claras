//
//  InvoiceQRCode.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation

// Shared by both QR paths (live camera and PDF, see spec section 4.1) — the QR/URL content
// only matters for its "chFE" query parameter; "jwt" and "digestValue" are discarded.
enum InvoiceQRCode {
    static func cufe(fromScannedValue value: String) -> String? {
        guard let components = URLComponents(string: value) else { return nil }
        return components.queryItems?.first(where: { $0.name == "chFE" })?.value
    }
}
