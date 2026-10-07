//
//  SettingsView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Spec section 15, pantalla 7. Exportación de la Capa 2, conexión y respaldo de la Capa 3; el
// bloqueo con Face ID llega con su fase.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var oneDrive = OneDriveAuth.shared
    @State private var isSigningIn = false
    @State private var isBackingUp = false
    @State private var isShowingBackupReconnectPrompt = false
    @Query(filter: #Predicate<Expense> { $0.layer2ExportedAt == nil }) private var pendingExport: [Expense]
    @State private var banner: ConfirmationBanner?
    @State private var isShowingReconnectNotice = false
    @State private var isShowingExporter = false
    @State private var exportDocument: CSVDocument?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Exportar ahora") { export() }
                } header: {
                    Text("Exportar a archivo")
                } footer: {
                    Text("\(pendingLabel). Se guardan en un archivo CSV en la ubicación que elijas.")
                }

                Section {
                    if !oneDrive.isConnected {
                        Button("Conectar con OneDrive") { signIn() }
                            .disabled(isSigningIn)
                    } else {
                        if oneDrive.needsReconnection {
                            Label("Reconexión necesaria", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color("PanamaRed"))
                            Button("Iniciar sesión") { signIn() }
                                .disabled(isSigningIn)
                        } else {
                            Label("Conectado", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(Color("PanamaBlue"))
                        }
                        Button("Respaldar ahora") { backUp() }
                            .disabled(isBackingUp)
                        Button("Desconectar", role: .destructive) { oneDrive.disconnect() }
                    }
                } header: {
                    Text("OneDrive")
                } footer: {
                    Text(oneDrive.isConnected
                        ? "Respaldar ahora sube un archivo CSV con todas tus facturas y reemplaza el respaldo anterior."
                        : "Opcional. Requiere una cuenta personal de Microsoft.")
                }
            }
            .navigationTitle("Ajustes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .alert("Reconexión necesaria", isPresented: $isShowingBackupReconnectPrompt) {
                Button("Iniciar sesión") { signIn() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Tu sesión de OneDrive expiró. Inicia sesión de nuevo para respaldar.")
            }
            .alert("No encontramos tu archivo anterior", isPresented: $isShowingReconnectNotice) {
                Button("Elegir ubicación") { presentExporter() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Elige dónde guardar el archivo.")
            }
            .fileExporter(
                isPresented: $isShowingExporter,
                document: exportDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "cuentas_claras"
            ) { result in
                handleExporterResult(result)
            }
            .confirmationBanner($banner)
        }
    }

    private var pendingLabel: String {
        pendingExport.count == 1 ? "1 factura sin exportar" : "\(pendingExport.count) facturas sin exportar"
    }

    private func backUp() {
        isBackingUp = true
        Task {
            defer { isBackingUp = false }
            switch await OneDriveBackup.run(in: modelContext) {
            case .succeeded:
                banner = ConfirmationBanner(kind: .success, message: "Respaldo subido a OneDrive")
            case .failed(.sessionExpired):
                isShowingBackupReconnectPrompt = true
            case .failed(.throttled):
                banner = ConfirmationBanner(kind: .failure, message: "OneDrive pide esperar. Inténtalo más tarde")
            case .failed(.networkError):
                banner = ConfirmationBanner(kind: .failure, message: "No se pudo conectar con OneDrive")
            case .failed(.httpError), .localError:
                banner = ConfirmationBanner(kind: .failure, message: "No se pudo respaldar")
            }
        }
    }

    private func signIn() {
        isSigningIn = true
        Task {
            defer { isSigningIn = false }
            do {
                try await oneDrive.signIn(in: modelContext)
                banner = ConfirmationBanner(kind: .success, message: "OneDrive conectado")
            } catch OneDriveAuthError.cancelled {
                // El usuario cerró el login; no es un error.
            } catch {
                print("OneDrive sign-in failed: \(error)")
                banner = ConfirmationBanner(kind: .failure, message: "No se pudo conectar con OneDrive")
            }
        }
    }

    private func export() {
        do {
            switch try ManualExporter.exportToSavedDestination(in: modelContext) {
            case .exported(let count):
                banner = ConfirmationBanner(kind: .success, message: exportedLabel(count))
            case .nothingToExport:
                banner = ConfirmationBanner(kind: .success, message: "No hay facturas nuevas para exportar")
            }
        } catch ManualExportError.noDestination {
            presentExporter()
        } catch {
            isShowingReconnectNotice = true
        }
    }

    // El selector siempre recibe el CSV completo: tanto en la primera exportación como al reconectar
    // con un archivo nuevo, el destino empieza vacío.
    private func presentExporter() {
        guard let expenses = try? ManualExporter.allExpenses(in: modelContext) else {
            banner = ConfirmationBanner(kind: .failure, message: "No se pudo preparar la exportación")
            return
        }
        exportDocument = CSVDocument(text: ExpenseCSVSerializer.fullCSV(for: expenses, in: modelContext))
        isShowingExporter = true
    }

    private func handleExporterResult(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let count = try ManualExporter.completeInitialExport(to: url, in: modelContext)
                banner = ConfirmationBanner(kind: .success, message: exportedLabel(count))
            } catch {
                banner = ConfirmationBanner(kind: .failure, message: "No se pudo guardar la ubicación del archivo")
            }
        case .failure(let error):
            guard (error as? CocoaError)?.code != .userCancelled else { return }
            banner = ConfirmationBanner(kind: .failure, message: "No se pudo exportar")
        }
    }

    private func exportedLabel(_ count: Int) -> String {
        count == 1 ? "1 factura exportada" : "\(count) facturas exportadas"
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Expense.self, inMemory: true)
}
