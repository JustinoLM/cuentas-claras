//
//  DGIParsingError.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation

// Thrown instead of defaulting to nil/0 so a DGI markup change fails loudly (see spec section 16)
// instead of silently producing an Expense with wrong or missing values.
enum DGIParsingError: Error, Equatable {
    case missingField(String)
}
