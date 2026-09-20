//
//  PendingLookup.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation
import SwiftData

@Model
final class PendingLookup {
    var cufe: String
    var firstAttemptDate: Date
    var attemptCount: Int

    init(cufe: String, firstAttemptDate: Date, attemptCount: Int) {
        self.cufe = cufe
        self.firstAttemptDate = firstAttemptDate
        self.attemptCount = attemptCount
    }
}
