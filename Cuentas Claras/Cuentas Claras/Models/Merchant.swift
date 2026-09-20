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
    var name: String  // razón social tal cual la reporta la DGI — no siempre es el nombre comercial (spec 9.1)
    var alias: String?  // nombre visible que el usuario le pone; la UI siempre muestra alias ?? name
    var category: String?  // nil = uncategorized, shows up in the pending screen

    init(ruc: String, name: String, alias: String? = nil, category: String? = nil) {
        self.ruc = ruc
        self.name = name
        self.alias = alias
        self.category = category
    }
}
