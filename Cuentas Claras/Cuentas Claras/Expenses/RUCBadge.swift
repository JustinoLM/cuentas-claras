//
//  RUCBadge.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import SwiftUI

// Identificador visual de si un gasto tiene RUC (factura DGI) o no (gasto manual) — paleta
// inspirada en la bandera de Panamá (PanamaBlue/PanamaRed en Assets.xcassets, con variante para
// modo oscuro). Fondo tenue + texto de color, no relleno sólido, para no sobrecargar la fila.
struct RUCBadge: View {
    let hasRUC: Bool

    private var tint: Color {
        hasRUC ? Color("PanamaBlue") : Color("PanamaRed")
    }

    var body: some View {
        Text(hasRUC ? "RUC" : "SIN RUC")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
    }
}
