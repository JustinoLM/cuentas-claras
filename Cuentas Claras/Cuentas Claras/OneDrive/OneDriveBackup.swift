//
//  OneDriveBackup.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import SwiftData

// Spec 13.4: "Respaldar ahora". Solo lo dispara el usuario; sube el CSV completo (misma función que la
// Capa 0) y sobrescribe cada vez. Comparte las reglas de errores de 13.3 vía OneDriveSync.execute.
enum OneDriveBackup {
    enum Outcome: Equatable {
        case succeeded(count: Int)
        case failed(OneDriveSync.StopReason)
        case localError
    }

    private static let backupURL = URL(string: "https://graph.microsoft.com/v1.0/me/drive/special/approot:/Backups/respaldo.csv:/content")!

    static func run(in context: ModelContext, environment: OneDriveSyncEnvironment = .live) async -> Outcome {
        guard let expenses = try? ManualExporter.allExpenses(in: context) else { return .localError }
        let csv = ExpenseCSVSerializer.fullCSV(for: expenses, in: context)

        do {
            let status = try await OneDriveSync.execute("PUT", url: backupURL, body: Data(csv.utf8), environment: environment)
            guard (200..<300).contains(status) else { return .failed(.httpError(status)) }
            return .succeeded(count: expenses.count)
        } catch let stop as OneDriveSync.Stop {
            return .failed(stop.reason)
        } catch {
            return .failed(.networkError)
        }
    }
}
