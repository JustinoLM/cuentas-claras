//
//  AppLock.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import LocalAuthentication
import Observation
import SwiftUI
import UIKit

// Bloqueo opcional al abrir la app (spec sección 14). `.deviceOwnerAuthentication` cae al código del
// dispositivo si la biometría falla o no está configurada, y falla del todo solo si no hay código.
@Observable
final class AppLock {
    static let shared = AppLock()

    private static let enabledKey = "appLockEnabled"

    private(set) var isEnabled: Bool
    private(set) var isLocked = false
    private(set) var isAuthenticating = false

    private var isCovered = false
    // El prompt de Face ID pone la escena en .inactive y al cerrarse la devuelve a .active: sin esta
    // bandera, cancelar el prompt lo volvería a lanzar en bucle. Solo se lanza solo al bloquear.
    private var promptOnActive = false
    private let window = LockWindow()

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        // Arranque en frío: bloqueado desde el primer frame, sin intervalo de gracia.
        if shouldLock {
            isLocked = true
            promptOnActive = true
        }
    }

    // Si la política dejó de poder evaluarse con el bloqueo activo (por ejemplo se quitó el código
    // del dispositivo), la app abre sin bloquear en vez de dejar al usuario fuera.
    private var shouldLock: Bool { isEnabled && Self.canUseDeviceAuthentication }

    static var canUseDeviceAuthentication: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func setEnabled(_ enabled: Bool) {
        guard !enabled || Self.canUseDeviceAuthentication else { return }
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
        refreshWindow()
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        // El bloqueo ocurre solo en .background. En .inactive (prompt de Face ID, permiso de cámara,
        // picker de archivos, login de MSAL) solo se cubre el contenido, nunca se pide autenticación.
        if phase == .background, shouldLock {
            isLocked = true
            promptOnActive = true
        }
        isCovered = isEnabled && phase != .active
        refreshWindow()

        if phase == .active, isLocked, promptOnActive {
            promptOnActive = false
            Task { await authenticate() }
        }
    }

    func authenticate() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        guard Self.canUseDeviceAuthentication else {
            isLocked = false
            refreshWindow()
            return
        }

        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Desbloquea Cuentas Claras para ver tus gastos."
            )
            if success { isLocked = false }
        } catch {
            // Cancelado o fallido: queda bloqueado y el botón de la pantalla de bloqueo reintenta.
        }
        refreshWindow()
    }

    private func refreshWindow() {
        window.setVisible(isLocked || isCovered)
    }
}

// Ventana propia por encima de todo, y no un overlay de ContentView: un overlay no cubre los sheets
// (Ajustes, Analíticas), así que con uno abierto la app quedaría usable sin autenticarse.
private final class LockWindow {
    private var window: UIWindow?

    func setVisible(_ visible: Bool) {
        if visible, window == nil {
            guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
            let lockWindow = UIWindow(windowScene: scene)
            lockWindow.windowLevel = .alert + 1
            lockWindow.rootViewController = UIHostingController(rootView: LockScreenView())
            window = lockWindow
        }
        window?.isHidden = !visible
    }
}
