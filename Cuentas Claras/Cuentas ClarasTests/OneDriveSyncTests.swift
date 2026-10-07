//
//  OneDriveSyncTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

private final class RequestRecorder {
    var requests: [URLRequest] = []
}

private func makeStore(connected: Bool, in context: ModelContext) throws -> OneDriveAccountStore {
    let store = OneDriveAccountStore(defaults: UserDefaults(suiteName: "onedrive-sync-tests-\(UUID().uuidString)")!)
    if connected {
        try store.registerLogin(homeAccountId: "account-a", in: context)
    }
    return store
}

private func makeEnvironment(
    recorder: RequestRecorder,
    status: @escaping (URLRequest) -> Int
) -> OneDriveSyncEnvironment {
    OneDriveSyncEnvironment(
        accessToken: { _ in "token" },
        send: { request in
            recorder.requests.append(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status(request), httpVersion: nil, headerFields: nil)!
            return (Data(), response)
        },
        markSessionExpired: {},
        gate: OneDriveSyncGate()
    )
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

@MainActor
struct OneDriveSyncTests {
    @Test func uploadsPendingAndModifiedAndMarksThemSynced() async throws {
        let context = try makeInMemoryContext()
        let store = try makeStore(connected: true, in: context)
        let pending = makeExpense(.pending, in: context)
        let modified = makeExpense(.modifiedLocally, in: context)
        let synced = makeExpense(.synced, in: context)
        let recorder = RequestRecorder()

        let outcome = await OneDriveSync.run(in: context, store: store, environment: makeEnvironment(recorder: recorder) { _ in 200 })

        #expect(outcome == .finished(uploaded: 2, deleted: 0))
        #expect(pending.layer3SyncState == .synced)
        #expect(modified.layer3SyncState == .synced)
        #expect(synced.layer3SyncState == .synced)
        #expect(recorder.requests.count == 2)
        #expect(recorder.requests.allSatisfy { $0.httpMethod == "PUT" })
        #expect(recorder.requests.contains { $0.url!.absoluteString.contains(pending.id.uuidString) })
    }

    @Test func deleteReturningNotFoundCountsAsSuccess() async throws {
        let context = try makeInMemoryContext()
        let store = try makeStore(connected: true, in: context)
        context.insert(PendingRemoteDeletion(expenseId: UUID()))
        let recorder = RequestRecorder()

        let outcome = await OneDriveSync.run(in: context, store: store, environment: makeEnvironment(recorder: recorder) { _ in 404 })

        #expect(outcome == .finished(uploaded: 0, deleted: 1))
        #expect(recorder.requests.first?.httpMethod == "DELETE")
        #expect(try context.fetch(FetchDescriptor<PendingRemoteDeletion>()).isEmpty)
    }

    @Test func throttlingStopsTheCycleAndLeavesTheRestPending() async throws {
        let context = try makeInMemoryContext()
        let store = try makeStore(connected: true, in: context)
        let first = makeExpense(.pending, in: context)
        let second = makeExpense(.pending, in: context)
        context.insert(PendingRemoteDeletion(expenseId: UUID()))
        let recorder = RequestRecorder()

        let outcome = await OneDriveSync.run(in: context, store: store, environment: makeEnvironment(recorder: recorder) { _ in 429 })

        #expect(outcome == .stopped(.throttled, uploaded: 0, deleted: 0))
        #expect(recorder.requests.count == 1)
        #expect(first.layer3SyncState == .pending)
        #expect(second.layer3SyncState == .pending)
        #expect(try context.fetch(FetchDescriptor<PendingRemoteDeletion>()).count == 1)
    }

    @Test func skipsWithoutAccountOrWhileReconnectionIsNeeded() async throws {
        let context = try makeInMemoryContext()
        _ = makeExpense(.pending, in: context)
        let recorder = RequestRecorder()
        let environment = makeEnvironment(recorder: recorder) { _ in 200 }

        let disconnected = try makeStore(connected: false, in: context)
        #expect(await OneDriveSync.run(in: context, store: disconnected, environment: environment) == .skipped)

        let expired = try makeStore(connected: true, in: context)
        expired.needsReconnection = true
        #expect(await OneDriveSync.run(in: context, store: expired, environment: environment) == .skipped)

        #expect(recorder.requests.isEmpty)
    }

    @Test func tombstoneIsCreatedOnlyOnceTheUserHasEverConnected() throws {
        let context = try makeInMemoryContext()
        let store = try makeStore(connected: false, in: context)

        let neverConnected = makeExpense(.pending, in: context)
        ExpenseDeletion.delete(neverConnected, in: context, store: store)
        #expect(try context.fetch(FetchDescriptor<PendingRemoteDeletion>()).isEmpty)

        try store.registerLogin(homeAccountId: "account-a", in: context)
        store.clearOnDisconnect()
        let afterDisconnect = makeExpense(.synced, in: context)
        let id = afterDisconnect.id
        ExpenseDeletion.delete(afterDisconnect, in: context, store: store)
        #expect(try context.fetch(FetchDescriptor<PendingRemoteDeletion>()).map(\.expenseId) == [id])
    }
}
