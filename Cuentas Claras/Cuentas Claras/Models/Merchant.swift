//
//  Merchant.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation
import SwiftData

@Model
final class Merchant {
    @Attribute(.unique) var ruc: String
    var name: String
    var category: String?  // nil = uncategorized, shows up in the pending screen

    init(ruc: String, name: String, category: String? = nil) {
        self.ruc = ruc
        self.name = name
        self.category = category
    }
}
