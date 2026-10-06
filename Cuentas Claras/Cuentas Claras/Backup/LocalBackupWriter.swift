//
//  LocalBackupWriter.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

// Capa 0 (spec section 10): a full CSV backup in the app's own Documents folder, regenerated after
// every save. Exists to survive a phone change where the user sets up "as new" instead of restoring
// a backup — something iCloud/iTunes backup doesn't guarantee to cover. There's no single save
// choke point in the app (three places insert an Expense, several more edit fields in place, all
// through SwiftData's autosave), so this observes `ModelContext.didSave` instead of hooking every
// call site.
enum LocalBackupWriter {
    static let fileName = "cuentas_claras_backup.csv"

    private static var observer: NSObjectProtocol?

    static func startObserving(context: ModelContext) {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave,
            object: context,
            queue: .main
        ) { _ in
            regenerate(from: context)
        }
    }

    static func regenerate(from context: ModelContext) {
        guard let expenses = try? context.fetch(FetchDescriptor<Expense>(sortBy: [SortDescriptor(\.scanDate)])) else {
            return
        }
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let csv = ExpenseCSVSerializer.fullCSV(for: expenses, in: context)
        let fileURL = documentsURL.appendingPathComponent(fileName)
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}
