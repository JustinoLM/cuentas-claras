//
//  SyncState.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/19/26.
//

import Foundation

enum SyncState: String, Codable {
    case pending
    case synced
    case modifiedLocally
    case deletedLocally
}
