//
//  PendingLookupQueue.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

enum PendingLookupQueue {
    // Called when DGIInvoiceLookupService returns .networkError for a CUFE — see its own comment on
    // why only that case (not .parsingFailed) belongs in this queue.
    static func enqueue(cufe: String, in context: ModelContext) throws {
        var descriptor = FetchDescriptor<PendingLookup>(predicate: #Predicate { $0.cufe == cufe })
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.attemptCount += 1
        } else {
            context.insert(PendingLookup(cufe: cufe, firstAttemptDate: Date(), attemptCount: 1))
        }
    }

    // Meant to run on scenePhase becoming .active, and from the manual "Reintentar ahora" button
    // (spec section 8) — not BGTaskScheduler. Only .networkError keeps an entry queued; any other
    // outcome is resolved one way or another and the entry is removed.
    static func retryAll(in context: ModelContext, urlSession: URLSession = .shared) async throws {
        let pending = try context.fetch(FetchDescriptor<PendingLookup>())

        for lookup in pending {
            switch await DGIInvoiceLookupService.lookup(cufe: lookup.cufe, urlSession: urlSession) {
            case .networkError:
                lookup.attemptCount += 1

            case .parsed(.success(let expense)):
                // No pasa por la pantalla de revisión (4.4) — el reintento corre en segundo plano,
                // sin garantía de que el usuario esté mirando. Sí crea el Merchant, igual que las
                // vías interactivas, para que se pueda categorizar y ponerle alias después.
                if try ExpenseDeduplicator.existingExpense(withCufe: lookup.cufe, in: context) == nil {
                    if let issuerRuc = expense.issuerRuc {
                        try? MerchantCategorization.registerMerchantIfNeeded(issuerRuc: issuerRuc, issuerName: expense.issuerName, in: context)
                    }
                    context.insert(expense)
                }
                context.delete(lookup)

            case .parsed(.notFound), .parsed(.unsupported), .parsingFailed, .invalidFormat:
                context.delete(lookup)
            }
        }
    }
}
