//
//  OneDriveAccountStore.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import SwiftData

// Estado local de la conexión con OneDrive (spec 13.3). Sin MSAL a propósito, para poder probar la
// regla de cambio de cuenta. homeAccountId es un identificador, no un secreto: va en UserDefaults.
struct OneDriveAccountStore {
    static let shared = OneDriveAccountStore(defaults: .standard)

    private static let homeAccountIdKey = "oneDriveHomeAccountId"
    private static let needsReconnectionKey = "oneDriveNeedsReconnection"
    private static let everConnectedKey = "layer3EverConnected"
    private static let lastSyncedSchemaVersionKey = "oneDriveLastSyncedSchemaVersion"

    let defaults: UserDefaults

    // Spec 11.1: nil (nunca guardada) cuenta como distinta de la versión actual.
    var lastSyncedSchemaVersion: Int? {
        get { defaults.object(forKey: Self.lastSyncedSchemaVersionKey) as? Int }
        nonmutating set { defaults.set(newValue, forKey: Self.lastSyncedSchemaVersionKey) }
    }

    var homeAccountId: String? {
        defaults.string(forKey: Self.homeAccountIdKey)
    }

    // Spec 3.5: pasa a true en el primer login exitoso y nunca se borra.
    var everConnected: Bool {
        defaults.bool(forKey: Self.everConnectedKey)
    }

    var needsReconnection: Bool {
        get { defaults.bool(forKey: Self.needsReconnectionKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.needsReconnectionKey) }
    }

    // Se guarda el id solo después de que el reset de estados quedó persistido: si el save falla,
    // el id viejo se mantiene y el reset se reintenta en el próximo login.
    func registerLogin(homeAccountId newId: String, in context: ModelContext) throws {
        if homeAccountId != newId {
            for expense in try context.fetch(FetchDescriptor<Expense>()) {
                switch expense.layer3SyncState {
                case .synced, .modifiedLocally:
                    expense.layer3SyncState = .pending
                case .pending:
                    break
                }
            }
            try context.save()
            defaults.set(newId, forKey: Self.homeAccountIdKey)
            // Todo quedó en .pending y se subirá con el formato actual: no hay nada que retransmitir
            // por cambio de schemaVersion.
            lastSyncedSchemaVersion = ExpenseCSVSerializer.schemaVersion
        }
        defaults.set(true, forKey: Self.everConnectedKey)
        needsReconnection = false
    }

    // Solo la desconexión manual borra el id; la reconexión por sesión expirada lo conserva.
    func clearOnDisconnect() {
        defaults.removeObject(forKey: Self.homeAccountIdKey)
        needsReconnection = false
    }
}
