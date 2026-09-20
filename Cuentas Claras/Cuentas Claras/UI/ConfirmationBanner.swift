//
//  ConfirmationBanner.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// iOS no tiene un "toast" nativo — esto es lo más cercano dentro de HIG: un banner chico que
// aparece con feedback háptico y se desvanece solo, para confirmar (o avisar del error de) una
// acción que de otra forma no deja ningún rastro visible inmediato (ej. cerrar un sheet).
struct ConfirmationBanner: Identifiable {
    enum Kind {
        case success
        case failure
    }

    let id = UUID()
    let kind: Kind
    let message: String
}

private struct ConfirmationBannerModifier: ViewModifier {
    @Binding var banner: ConfirmationBanner?

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let banner {
                HStack(spacing: 8) {
                    Image(systemName: banner.kind == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    Text(banner.message)
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(banner.kind == .success ? Color("PanamaBlue") : Color("PanamaRed"))
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task(id: banner.id) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(banner.kind == .success ? .success : .error)
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation {
                        self.banner = nil
                    }
                }
            }
        }
        .animation(.spring(duration: 0.3), value: banner?.id)
    }
}

extension View {
    func confirmationBanner(_ banner: Binding<ConfirmationBanner?>) -> some View {
        modifier(ConfirmationBannerModifier(banner: banner))
    }
}
