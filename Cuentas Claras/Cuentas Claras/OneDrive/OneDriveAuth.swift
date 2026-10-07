//
//  OneDriveAuth.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import MSAL
import Observation
import SwiftData
import UIKit

enum OneDriveAuthError: Error {
    case cancelled
    case notConnected
    case reconnectionRequired
    case noPresenter
    case noResult
}

// Envoltorio de MSAL (spec 13.2). Los tokens viven solo en la caché de MSAL; aquí no se guarda nada.
@Observable
final class OneDriveAuth {
    static let shared = OneDriveAuth()

    // El client ID no es secreto.
    private static let clientId = "945ada28-46a3-4feb-9361-adf052be6dd1"
    private static let redirectUri = "msauth.com.118warehouse.Cuentas-Claras://auth"
    private static let authorityURL = "https://login.microsoftonline.com/consumers"
    private static let scopes = ["Files.ReadWrite.AppFolder"]

    private(set) var isConnected: Bool
    private(set) var needsReconnection: Bool

    private let store = OneDriveAccountStore.shared
    @ObservationIgnored private var application: MSALPublicClientApplication?

    private init() {
        isConnected = store.homeAccountId != nil
        needsReconnection = store.needsReconnection
    }

    func signIn(in context: ModelContext) async throws {
        let application = try makeApplication()
        guard let presenter = Self.topViewController() else { throw OneDriveAuthError.noPresenter }

        let webviewParameters = MSALWebviewParameters(authPresentationViewController: presenter)
        let parameters = MSALInteractiveTokenParameters(scopes: Self.scopes, webviewParameters: webviewParameters)

        let result: MSALResult
        do {
            result = try await withCheckedThrowingContinuation { continuation in
                application.acquireToken(with: parameters) { result, error in
                    if let result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: error ?? OneDriveAuthError.noResult)
                    }
                }
            }
        } catch let error as NSError where error.domain == MSALErrorDomain && error.code == MSALError.userCanceled.rawValue {
            throw OneDriveAuthError.cancelled
        }

        guard let homeAccountId = result.account.homeAccountId?.identifier else { throw OneDriveAuthError.noResult }
        try store.registerLogin(homeAccountId: homeAccountId, in: context)
        refreshState()
    }

    // Marca el flag de reconexión cuando la renovación silenciosa pide interacción; cualquier otro
    // error (red, etc.) se propaga sin tocar el flag. `forceRefresh` es para el reintento tras un 401.
    func accessToken(forceRefresh: Bool = false) async throws -> String {
        guard let homeAccountId = store.homeAccountId else { throw OneDriveAuthError.notConnected }
        guard !store.needsReconnection else { throw OneDriveAuthError.reconnectionRequired }

        let application = try makeApplication()
        // Una cuenta ausente de la caché (ej. Keychain borrado) tampoco se resuelve sin login.
        guard let account = try? application.account(forIdentifier: homeAccountId) else {
            markReconnectionRequired()
            throw OneDriveAuthError.reconnectionRequired
        }

        let parameters = MSALSilentTokenParameters(scopes: Self.scopes, account: account)
        parameters.forceRefresh = forceRefresh
        do {
            let result: MSALResult = try await withCheckedThrowingContinuation { continuation in
                application.acquireTokenSilent(with: parameters) { result, error in
                    if let result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: error ?? OneDriveAuthError.noResult)
                    }
                }
            }
            return result.accessToken
        } catch let error as NSError where error.domain == MSALErrorDomain && error.code == MSALError.interactionRequired.rawValue {
            markReconnectionRequired()
            throw OneDriveAuthError.reconnectionRequired
        }
    }

    func disconnect() {
        if let homeAccountId = store.homeAccountId,
           let application = try? makeApplication(),
           let account = try? application.account(forIdentifier: homeAccountId) {
            try? application.remove(account)
        }
        store.clearOnDisconnect()
        refreshState()
    }

    func markReconnectionRequired() {
        store.needsReconnection = true
        refreshState()
    }

    private func refreshState() {
        isConnected = store.homeAccountId != nil
        needsReconnection = store.needsReconnection
    }

    private func makeApplication() throws -> MSALPublicClientApplication {
        if let application { return application }
        let authority = try MSALAADAuthority(url: URL(string: Self.authorityURL)!)
        let configuration = MSALPublicClientApplicationConfig(
            clientId: Self.clientId,
            redirectUri: Self.redirectUri,
            authority: authority
        )
        // Sin capability de Keychain Sharing: el grupo es el propio bundle ID (spec 13.2).
        configuration.cacheConfig.keychainSharingGroup = Bundle.main.bundleIdentifier ?? ""
        let application = try MSALPublicClientApplication(configuration: configuration)
        self.application = application
        return application
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
