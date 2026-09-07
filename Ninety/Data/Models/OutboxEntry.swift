import Foundation
import SwiftData

/// A write that has not reached the server yet. Mirrors `public.sync_outbox`.
///
/// The heart of ADR 0005. Gyms have no signal, restaurant basements have no
/// signal, aeroplanes have no signal — and those are precisely where and when
/// people log food. So a write lands in SwiftData and returns immediately, an
/// entry goes in here, and a sync service drains the queue when connectivity
/// comes back. The UI never waits on the network.
///
/// This is the model's real home. The Postgres table of the same name is inert
/// by construction: a row only stops existing here once it has arrived there.
@Model
final class OutboxEntry {
    @Attribute(.unique)
    var id: UUID
    var userID: UUID
    var createdAt: Date

    /// The table this belongs to, by its Postgres name.
    var entity: String
    var entityID: UUID
    var operationRaw: String
    var payload: Data

    /// Incremented by the sync service. Kept so a row that fails forever can be
    /// found rather than retried silently until the end of time.
    var attempts: Int

    init(
        id: UUID = UUID(),
        userID: UUID,
        createdAt: Date,
        entity: String,
        entityID: UUID,
        operation: OutboxOperation,
        payload: Data,
        attempts: Int = 0
    ) {
        self.id = id
        self.userID = userID
        self.createdAt = createdAt
        self.entity = entity
        self.entityID = entityID
        self.operationRaw = operation.rawValue
        self.payload = payload
        self.attempts = attempts
    }
}

extension OutboxEntry {
    var operation: OutboxOperation {
        get { OutboxOperation(rawValue: operationRaw) ?? .insert }
        set { operationRaw = newValue.rawValue }
    }
}
