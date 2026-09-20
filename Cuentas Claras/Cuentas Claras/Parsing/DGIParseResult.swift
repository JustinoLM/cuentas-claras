//
//  DGIParseResult.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation

// invalidFormat is decided by DGICUFEValidator before any request; networkError belongs to the
// networking layer (section 8). This only covers what an actual DGI response can resolve to (5.7).
enum DGIParseResult {
    case success(Expense)
    case notFound
    case unsupported(referencedCufe: String?)
}
