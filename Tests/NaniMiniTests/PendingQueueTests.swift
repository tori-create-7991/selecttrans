import Foundation
import Testing
@testable import NaniMini

@Suite("PendingQueue")
struct PendingQueueTests {
    @Test("Concurrent enqueues preserve every record")
    func concurrentEnqueuesPreserveRecords() async throws {
        let fixture = try QueueFixture()
        defer { fixture.remove() }

        async let first: Void = fixture.queue.enqueue(Self.record(source: "first"))
        async let second: Void = fixture.queue.enqueue(Self.record(source: "second"))
        _ = try await (first, second)

        let records = try await fixture.queue.pendingRecords()
        #expect(Set(records.map(\.source)) == ["first", "second"])
    }

    @Test("Concurrent read and enqueue keep acknowledgement ordered")
    func concurrentReadAndEnqueueKeepAcknowledgementOrdered() async throws {
        let fixture = try QueueFixture()
        defer { fixture.remove() }
        try await fixture.queue.enqueue(Self.record(source: "existing"))

        async let pending = fixture.queue.pendingRecords()
        async let enqueued: Void = fixture.queue.enqueue(Self.record(source: "new"))
        _ = try await (pending, enqueued)
        try await fixture.queue.acknowledgeFirst(1)
        let remaining = try await fixture.queue.pendingRecords()

        #expect(remaining.map(\.source) == ["new"])
    }

    @Test("Batch acknowledgement removes the requested prefix")
    func batchAcknowledgementRemovesRequestedPrefix() async throws {
        let fixture = try QueueFixture()
        defer { fixture.remove() }
        try await fixture.queue.enqueue(Self.record(source: "first"))
        try await fixture.queue.enqueue(Self.record(source: "second"))
        try await fixture.queue.enqueue(Self.record(source: "third"))

        try await fixture.queue.acknowledgeFirst(2)

        let remaining = try await fixture.queue.pendingRecords()
        #expect(remaining.map(\.source) == ["third"])
    }

    @Test("Queue directory and file are owner-only")
    func queueUsesOwnerOnlyPermissions() async throws {
        let fixture = try QueueFixture()
        defer { fixture.remove() }
        try await fixture.queue.enqueue(Self.record(source: "private"))

        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.directory.path
        )
        let fileAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.fileURL.path
        )

        #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect((fileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test("An unavailable queue reports the write failure")
    func unavailableQueueThrows() async throws {
        let fixture = try QueueFixture()
        defer { fixture.remove() }
        let fileAsParent = fixture.directory.appendingPathComponent("not-a-directory")
        try Data().write(to: fileAsParent)
        let queue = PendingQueue(fileURL: fileAsParent.appendingPathComponent("pending.json"))

        await #expect(throws: (any Error).self) {
            try await queue.enqueue(Self.record(source: "cannot-write"))
        }
    }

    @Test("Existing queue permissions are migrated")
    func existingQueuePermissionsAreMigrated() async throws {
        let fixture = try QueueFixture()
        defer { fixture.remove() }
        try FileManager.default.createDirectory(
            at: fixture.directory,
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode([Self.record(source: "legacy")]).write(to: fixture.fileURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fixture.directory.path
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o644],
            ofItemAtPath: fixture.fileURL.path
        )

        _ = PendingQueue(fileURL: fixture.fileURL)

        let directoryAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.directory.path
        )
        let fileAttributes = try FileManager.default.attributesOfItem(
            atPath: fixture.fileURL.path
        )
        #expect((directoryAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700)
        #expect((fileAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    }

    @Test("A failed update preserves the last valid queue")
    func failedUpdatePreservesExistingRecords() async throws {
        let fixture = try QueueFixture()
        defer { fixture.remove() }
        try await fixture.queue.enqueue(Self.record(source: "existing"))
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o500],
            ofItemAtPath: fixture.directory.path
        )

        await #expect(throws: (any Error).self) {
            try await fixture.queue.enqueue(Self.record(source: "new"))
        }

        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: fixture.directory.path
        )
        let remaining = try await fixture.queue.pendingRecords()
        #expect(remaining.map(\.source) == ["existing"])
    }

    private static func record(source: String) -> TranslationRecord {
        TranslationRecord(
            source: source,
            result: "result",
            direction: "ja-en",
            mode: "translate",
            app: "Tests",
            date: "2026-07-18T00:00:00Z"
        )
    }
}

private struct QueueFixture {
    let directory: URL
    let fileURL: URL
    let queue: PendingQueue

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SelectTransTests-\(UUID().uuidString)", isDirectory: true)
        fileURL = directory.appendingPathComponent("pending.json")
        queue = PendingQueue(fileURL: fileURL)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
