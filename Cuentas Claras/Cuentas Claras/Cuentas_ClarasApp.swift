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
            PendingRemoteDeletion.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        LocalBackupWriter.startObserving(context: sharedModelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase, initial: true) { _, phase in
                    AppLock.shared.scenePhaseChanged(phase)
                }
                .onOpenURL { url in
                    // Respuesta del broker de Microsoft (app Authenticator), si el login pasa por ahí.
                    MSALPublicClientApplication.handleMSALResponse(url, sourceApplication: nil)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
