//
//  Cuentas_ClarasApp.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import MSAL
import SwiftUI
import SwiftData

@main
struct Cuentas_ClarasApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Expense.self,
            InvoiceItem.self,
            Merchant.self,
            PendingLookup.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        LocalBackupWriter.startObserving(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Respuesta del broker de Microsoft (app Authenticator), si el login pasa por ahí.
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
