//
//  ExpenseDeduplicator.swift
//  Cuentas Claras
//
//  Created by Justin Williams on 09/20/26.
//

import Foundation
import SwiftData

enum ExpenseDeduplicator {
    // 6.1: cufe already has a unique constraint in the model — this is the check-before-create so a
    // repeat scan shows the existing Expense instead of hitting that constraint on insert.
    static func existingExpense(withCufe cufe: String, in context: ModelContext) throws -> Expense? {
        var descriptor = FetchDescriptor<Expense>(predicate: #Predicate { $0.cufe == cufe })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // 6.2: manual expenses have no reliable unique id, so this is a soft check meant to prompt the
    // user ("¿lo agregas igual?"), never to block silently — same issuer (RUC when both have one,
    // otherwise name), same calendar day, same total.
    static func possibleDuplicate(
        issuerRuc: String?,
        issuerName: String,
        date: Date,
        totalAmount: Decimal,
        in context: ModelContext
    ) throws -> Expense? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }

        let sameAmount = try context.fetch(FetchDescriptor<Expense>(predicate: #Predicate { $0.totalAmount == totalAmount }))

        return sameAmount.first { expense in
            let sameIssuer: Bool
            if let issuerRuc, let expenseRuc = expense.issuerRuc {
                sameIssuer = issuerRuc == expenseRuc
            } else {
                sameIssuer = expense.issuerName.caseInsensitiveCompare(issuerName) == .orderedSame
            }

            let expenseDate = expense.issueDate ?? expense.authorizationDate
            let sameDay = expenseDate.map { $0 >= dayStart && $0 < dayEnd } ?? false

            return sameIssuer && sameDay
        }
    }
}
