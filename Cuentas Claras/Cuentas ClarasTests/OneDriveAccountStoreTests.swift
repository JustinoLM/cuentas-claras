//
//  OneDriveAccountStoreTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

private func makeStore() -> OneDriveAccountStore {
    OneDriveAccountStore(defaults: UserDefaults(suiteName: "onedrive-tests-\(UUID().uuidString)")!)
}

private func makeExpense(_ state: SyncState, in context: ModelContext) -> Expense {
    let expense = Expense(
        documentType: "MANUAL",
        issuerName: "Test",
        totalAmount: 10,
        totalItbms: 0,
        source: .manual,
        layer3SyncState: state
    )
    context.insert(expense)
    return expense
}

struct OneDriveAccountStoreTests {
    @Test func firstLoginSavesIdAndResetsSyncedAndModifiedToPendingButKeepsTombstones() throws {
        let context = try makeInMemoryContext()
        let store = makeStore()
        let synced = makeExpense(.synced, in: context)
        let modified = makeExpense(.modifiedLocally, in: context)
        let tombstone = PendingRemoteDeletion(expenseId: UUID())
        context.insert(tombstone)

        try store.registerLogin(homeAccountId: "account-a", in: context)

        #expect(store.homeAccountId == "account-a")
        #expect(synced.layer3SyncState == .pending)
        #expect(modified.layer3SyncState == .pending)
        #expect(try context.fetch(FetchDescriptor<PendingRemoteDeletion>()).count == 1)
        #expect(store.everConnected)
    }

    @Test func differentAccountResetsStates() throws {
        let context = try makeInMemoryContext()
        let store = makeStore()
        try store.registerLogin(homeAccountId: "account-a", in: context)
        let synced = makeExpense(.synced, in: context)

        try store.registerLogin(homeAccountId: "account-b", in: context)

        #expect(store.homeAccountId == "account-b")
        #expect(synced.layer3SyncState == .pending)
    }

    @Test func sameAccountTouchesNothing() throws {
        let context = try makeInMemoryContext()
        let store = makeStore()
        try store.registerLogin(homeAccountId: "account-a", in: context)
        let synced = makeExpense(.synced, in: context)
        let modified = makeExpense(.modifiedLocally, in: context)

        try store.registerLogin(homeAccountId: "account-a", in: context)

        #expect(synced.layer3SyncState == .synced)
        #expect(modified.layer3SyncState == .modifiedLocally)
    }

    @Test func disconnectClearsIdSoNextLoginResets() throws {
        let context = try makeInMemoryContext()
        let store = makeStore()
        try store.registerLogin(homeAccountId: "account-a", in: context)
        let synced = makeExpense(.synced, in: context)

        store.clearOnDisconnect()
        #expect(store.homeAccountId == nil)

        try store.registerLogin(homeAccountId: "account-a", in: context)
        #expect(synced.layer3SyncState == .pending)
    }

    @Test func loginClearsReconnectionFlagButExpiredSessionKeepsId() throws {
        let context = try makeInMemoryContext()
        let store = makeStore()
        try store.registerLogin(homeAccountId: "account-a", in: context)

        store.needsReconnection = true
        #expect(store.homeAccountId == "account-a")

        try store.registerLogin(homeAccountId: "account-a", in: context)
        #expect(store.needsReconnection == false)
    }
}
