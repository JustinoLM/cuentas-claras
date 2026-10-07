//
//  PendingRemoteDeletion.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import SwiftData

// Spec section 3.5: gasto ya borrado localmente cuyo archivo en OneDrive falta por eliminar.
@Model
final class PendingRemoteDeletion {
    var expenseId: UUID

    init(expenseId: UUID) {
        self.expenseId = expenseId
    }
}
