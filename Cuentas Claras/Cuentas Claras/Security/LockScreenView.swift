//
//  LockScreenView.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 10/06/26.
//

import SwiftUI

// También es la cobertura de privacidad en .inactive (selector de apps): sin botón cuando solo cubre.
struct LockScreenView: View {
    private let lock = AppLock.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color("PanamaBlue"))
            Text("Cuentas Claras")
                .font(.title2.bold())
            if lock.isLocked && !lock.isAuthenticating {
                Button("Desbloquear") {
                    Task { await lock.authenticate() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
    }
}
