//
//  OneDriveSync.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import SwiftData

// Guard de un solo ciclo a la vez. Es inyectable (en vez de un estático) para que los tests no
// compartan estado con el sync real de la app anfitriona, que también corre al abrirse.
final class OneDriveSyncGate {
    static let shared = OneDriveSyncGate()
    fileprivate var isRunning = false
}

// Dependencias externas del ciclo, inyectables para probar sin red ni MSAL.
struct OneDriveSyncEnvironment {
    var accessToken: (_ forceRefresh: Bool) async throws -> String
    var send: (URLRequest) async throws -> (Data, URLResponse)
    var markSessionExpired: () -> Void
    var gate: OneDriveSyncGate

    static let live = OneDriveSyncEnvironment(
        accessToken: { try await OneDriveAuth.shared.accessToken(forceRefresh: $0) },
        send: { try await URLSession.shared.data(for: $0) },
        markSessionExpired: { OneDriveAuth.shared.markReconnectionRequired() },
        gate: .shared
    )
}

// Spec 13.3. Un ciclo secuencial: primero los PUT de los Expense pendientes o modificados, luego los
// DELETE de los PendingRemoteDeletion. Cualquier corte deja lo no procesado exactamente como estaba.
enum OneDriveSync {
    enum StopReason: Equatable {
        case networkError
        case throttled
        case sessionExpired
        case httpError(Int)
    }

    enum Outcome: Equatable {
        case skipped
        case finished(uploaded: Int, deleted: Int)
        case stopped(StopReason, uploaded: Int, deleted: Int)
    }

    private struct Stop: Error {
        let reason: StopReason
    }

    private static let folderURL = "https://graph.microsoft.com/v1.0/me/drive/special/approot:/Facturas/"

    static func run(
        in context: ModelContext,
        store: OneDriveAccountStore = .shared,
        environment: OneDriveSyncEnvironment = .live
    ) async -> Outcome {
        let gate = environment.gate
        guard !gate.isRunning, store.homeAccountId != nil, !store.needsReconnection else { return .skipped }
        guard let allExpenses = try? context.fetch(FetchDescriptor<Expense>()),
              let tombstones = try? context.fetch(FetchDescriptor<PendingRemoteDeletion>()) else { return .skipped }

        gate.isRunning = true
        defer { gate.isRunning = false }

        var uploaded = 0
        var deleted = 0
        var stopReason: StopReason?

        do {
            for expense in allExpenses where expense.layer3SyncState != .synced {
                let csv = ExpenseCSVSerializer.fullCSV(for: [expense], in: context)
                let url = fileURL(for: expense.id, suffix: ":/content")
                let status = try await execute("PUT", url: url, body: Data(csv.utf8), environment: environment)
                guard (200..<300).contains(status) else { throw Stop(reason: .httpError(status)) }
                expense.layer3SyncState = .synced
                uploaded += 1
            }

            for tombstone in tombstones {
                let url = fileURL(for: tombstone.expenseId, suffix: "")
                let status = try await execute("DELETE", url: url, body: nil, environment: environment)
                // 404: el archivo ya no existe, que es justo lo que se buscaba.
                guard (200..<300).contains(status) || status == 404 else { throw Stop(reason: .httpError(status)) }
                context.delete(tombstone)
                deleted += 1
            }
        } catch let stop as Stop {
            stopReason = stop.reason
        } catch {
            stopReason = .networkError
        }

        // Una sola escritura al final: si la app muere antes, el próximo ciclo repite PUT/DELETE, que
        // son idempotentes.
        try? context.save()

        if let stopReason {
            return .stopped(stopReason, uploaded: uploaded, deleted: deleted)
        }
        return .finished(uploaded: uploaded, deleted: deleted)
    }

    private static func fileURL(for id: UUID, suffix: String) -> URL {
        URL(string: "\(folderURL)\(id.uuidString).csv\(suffix)")!
    }

    // Un 401 se reintenta una vez con un token renovado a la fuerza; el segundo cuenta como sesión
    // expirada (13.3).
    private static func execute(
        _ method: String,
        url: URL,
        body: Data?,
        environment: OneDriveSyncEnvironment
    ) async throws -> Int {
        var forceRefresh = false

        while true {
            let token: String
            do {
                token = try await environment.accessToken(forceRefresh)
            } catch OneDriveAuthError.reconnectionRequired, OneDriveAuthError.notConnected {
                throw Stop(reason: .sessionExpired)
            } catch {
                throw Stop(reason: .networkError)
            }

            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let body {
                request.setValue("text/csv", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
            }

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await environment.send(request)
            } catch {
                throw Stop(reason: .networkError)
            }
            guard let status = (response as? HTTPURLResponse)?.statusCode else {
                throw Stop(reason: .networkError)
            }

            switch status {
            case 401:
                if forceRefresh {
                    environment.markSessionExpired()
                    throw Stop(reason: .sessionExpired)
                }
                forceRefresh = true
            case 429:
                throw Stop(reason: .throttled)
            default:
                if !(200..<300).contains(status) && status != 404 {
                    print("OneDrive \(method) failed: HTTP \(status) \(String(decoding: data, as: UTF8.self))")
                }
                return status
            }
        }
    }
}
