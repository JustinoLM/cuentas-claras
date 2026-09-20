//
//  DGICUFEValidator.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation

enum DGICUFEValidator {
    // Literal regex from the DGI form itself (data-val-regex-pattern on the CUFE input), see spec section 5.2.
    private static let pattern = "^(FE[0-9]{2}[1-2]{1}([0-9A-Z]|[-]){20}-[0-9A-Z]{6}([12]\\d{3}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01]))\\d{13}0[1-4]{1}[1-2]{1}\\d{10})$"
    private static let regex = try! NSRegularExpression(pattern: pattern)

    static func isValidFormat(_ cufe: String) -> Bool {
        let range = NSRange(cufe.startIndex..<cufe.endIndex, in: cufe)
        return regex.firstMatch(in: cufe, range: range) != nil
    }
}
