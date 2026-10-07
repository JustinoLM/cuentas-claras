//
//  PendingLookupQueueTests.swift
//  Cuentas ClarasTests
//
//  Created by Justin Williams on 10/06/26.
//

import Foundation
import Testing
@testable import Cuentas_Claras
import SwiftData

// Responde a toda request con un error de red y registra cuáles se intentaron.
private final class FailingURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestedURLs: [URL] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requestedURLs.append(request.url!)
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

private func makeFailingSession() -> URLSession {
    FailingURLProtocol.requestedURLs = []
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FailingURLProtocol.self]
    return URLSession(configuration: configuration)
}

// Cumple la regex de DGICUFEValidator; `tag` hace distinto a cada CUFE.
private func makeCufe(_ tag: String) -> String {
    "FE011" + String(repeating: tag, count: 20) + "-ABC123" + "20260101" + "1234567890123" + "01" + "1" + "1234567890"
}

@Suite(.serialized)
struct PendingLookupQueueTests {
    @Test @MainActor func networkErrorEndsCycleLeavingRestUntouched() async throws {
        let context = try makeInMemoryContext()
        let cufes = ["A", "B", "C"].map(makeCufe)
        for (index, cufe) in cufes.enumerated() {
            context.insert(PendingLookup(cufe: cufe, firstAttemptDate: testDate(2026, 1, index + 1), attemptCount: 1))
        }

        try await PendingLookupQueue.retryAll(in: context, urlSession: makeFailingSession(), gate: PendingLookupGate())

        let remaining = try context.fetch(FetchDescriptor<PendingLookup>(sortBy: [SortDescriptor(\.firstAttemptDate)]))
        #expect(remaining.count == 3)
        #expect(remaining.map(\.attemptCount) == [2, 1, 1])
        #expect(FailingURLProtocol.requestedURLs.count == 1)
    }

    @Test @MainActor func runningGateSkipsCycle() async throws {
        let context = try makeInMemoryContext()
        context.insert(PendingLookup(cufe: makeCufe("A"), firstAttemptDate: testDate(2026, 1, 1), attemptCount: 1))
        let gate = PendingLookupGate()
        gate.isRunning = true

        try await PendingLookupQueue.retryAll(in: context, urlSession: makeFailingSession(), gate: gate)

        #expect(FailingURLProtocol.requestedURLs.isEmpty)
        #expect(try context.fetch(FetchDescriptor<PendingLookup>()).first?.attemptCount == 1)
        #expect(gate.isRunning)
    }
}
