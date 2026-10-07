//
//  ExpenseSyncSupport.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import SwiftData

extension Expense {
    // Un gasto en .pending todavía se va a subir completo; solo uno ya subido necesita volver a la cola.
    func markModifiedForSync() {
        if layer3SyncState == .synced {
            layer3SyncState = .modifiedLocally
        }
    }
}

enum ExpenseDeletion {
    // Spec 3.5: el borrado local siempre es en duro. El tombstone solo existe si alguna vez hubo una
    // conexión, para que quien nunca usó OneDrive no acumule registros que nadie va a procesar.
    static func delete(_ expense: Expense, in context: ModelContext, store: OneDriveAccountStore = .shared) {
        if store.everConnected {
            context.insert(PendingRemoteDeletion(expenseId: expense.id))
        }
        context.delete(expense)
    }
}
