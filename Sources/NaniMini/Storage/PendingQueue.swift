import Foundation

/// On-disk fallback buffer used only when a configured Notion request fails.
/// Actor isolation keeps each read-modify-write operation serialized.
actor PendingQueue {
    static let shared = PendingQueue(fileURL: defaultFileURL)

    private static let defaultFileURL: URL = {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NaniMini", isDirectory: true)
            .appendingPathComponent("pending.json")
    }()

    private let fileURL: URL?

    init(fileURL: URL) {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: fileURL.path
                )
            }
            self.fileURL = fileURL
        } catch {
            self.fileURL = nil
        }
    }

    func enqueue(_ record: TranslationRecord) async throws {
        var all = try load()
        all.append(record)
        try store(all)
    }

    func pendingRecords() async throws -> [TranslationRecord] {
        try load()
    }

    func acknowledgeFirst(_ count: Int) async throws {
        var all = try load()
        guard count > 0, count <= all.count else {
            throw QueueError.invalidAcknowledgement
        }
        all.removeFirst(count)
        try store(all)
    }

    private func load() throws -> [TranslationRecord] {
        guard let fileURL else {
            throw QueueError.storageUnavailable
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([TranslationRecord].self, from: data)
    }

    private func store(_ records: [TranslationRecord]) throws {
        guard let fileURL else {
            throw QueueError.storageUnavailable
        }
        let data = try JSONEncoder().encode(records)
        try data.write(to: fileURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private enum QueueError: Error {
        case storageUnavailable
        case invalidAcknowledgement
    }
}
