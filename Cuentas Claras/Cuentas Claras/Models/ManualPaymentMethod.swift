//
//  ManualPaymentMethod.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation

// Vocabulario fijo para el método de pago de un gasto manual (spec 4.3) — Expense.paymentMethod
// sigue siendo un String? porque el parser DGI llena ese mismo campo con texto libre tomado del
// HTML (sección 5.6); este enum solo restringe lo que el usuario puede elegir a mano.
enum ManualPaymentMethod: String, CaseIterable, Identifiable {
    case efectivo = "Efectivo"
    case tarjeta = "Tarjeta"
    case transferencia = "Transferencia"
    case yappy = "Yappy"
    case bancaEnLinea = "Banca en línea"
    case otro = "Otro"

    var id: String { rawValue }
}
