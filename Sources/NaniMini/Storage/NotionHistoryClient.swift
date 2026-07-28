import Foundation

struct TranslationRecord: Codable, Sendable {
    let source: String
    let result: String
    let direction: String
    let mode: String
    let app: String
    let date: String   // ISO8601
}

enum NotionHistoryPolicy {
    struct Credentials: Sendable {
        let token: String
        let databaseID: String
    }

    static func credentials(token: String?, databaseID: String?) -> Credentials? {
        let token = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        let databaseID = databaseID?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let token, !token.isEmpty, let databaseID, !databaseID.isEmpty else {
            return nil
        }
        return Credentials(token: token, databaseID: databaseID)
    }
}

/// Pushes each translation to a Notion database as one page. Non-blocking and
/// best-effort: failures fall back to PendingQueue and retry later.
struct NotionHistoryClient: Sendable {
    private let credentialReader: @Sendable (KeychainKey) -> String?
    private let postRecord: @Sendable (TranslationRecord, NotionHistoryPolicy.Credentials) async throws -> Void
    private let enqueueRecord: @Sendable (TranslationRecord) async throws -> Void
    private let pendingRecords: @Sendable () async throws -> [TranslationRecord]
    private let acknowledgeRecords: @Sendable (Int) async throws -> Void

    init() {
        let queue = PendingQueue.shared
        credentialReader = { KeychainStore.get($0) }
        postRecord = { record, credentials in
            try await Self.post(record, credentials: credentials)
        }
        enqueueRecord = { try await queue.enqueue($0) }
        pendingRecords = { try await queue.pendingRecords() }
        acknowledgeRecords = { try await queue.acknowledgeFirst($0) }
    }

    init(
        credentialReader: @escaping @Sendable (KeychainKey) -> String?,
        postRecord: @escaping @Sendable (
            TranslationRecord,
            NotionHistoryPolicy.Credentials
        ) async throws -> Void,
        enqueueRecord: @escaping @Sendable (TranslationRecord) async throws -> Void,
        pendingRecords: @escaping @Sendable () async throws -> [TranslationRecord] = { [] },
        acknowledgeRecords: @escaping @Sendable (Int) async throws -> Void = { _ in }
    ) {
        self.credentialReader = credentialReader
        self.postRecord = postRecord
        self.enqueueRecord = enqueueRecord
        self.pendingRecords = pendingRecords
        self.acknowledgeRecords = acknowledgeRecords
    }

    func save(_ record: TranslationRecord) async {
        guard
            let credentials = NotionHistoryPolicy.credentials(
                token: credentialReader(.notionToken),
                databaseID: credentialReader(.notionDatabaseID)
            )
        else {
            return
        }
        do {
            try await postRecord(record, credentials)
        } catch {
            do {
                try await enqueueRecord(record)
            } catch {
                NSLog("SelectTrans: failed to persist pending Notion history")
            }
        }
    }

    func flushPending() async {
        guard
            let credentials = NotionHistoryPolicy.credentials(
                token: credentialReader(.notionToken),
                databaseID: credentialReader(.notionDatabaseID)
            )
        else { return }

        let records: [TranslationRecord]
        do {
            records = try await pendingRecords()
        } catch {
            NSLog("SelectTrans: failed to load pending Notion history")
            return
        }

        var successfulCount = 0
        for record in records {
            do {
                try await postRecord(record, credentials)
                successfulCount += 1
            } catch {
                break
            }
        }

        guard successfulCount > 0 else { return }
        do {
            try await acknowledgeRecords(successfulCount)
        } catch {
            NSLog("SelectTrans: failed to acknowledge pending Notion history")
        }
    }

    private static func post(
        _ record: TranslationRecord,
        credentials: NotionHistoryPolicy.Credentials
    ) async throws {
        var request = URLRequest(url: URL(string: "https://api.notion.com/v1/pages")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.token)", forHTTPHeaderField: "Authorization")
        request.setValue(Config.notionVersion, forHTTPHeaderField: "Notion-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "parent": ["database_id": credentials.databaseID],
            "properties": [
                "原文": ["title": [["text": ["content": String(record.source.prefix(2000))]]]],
                "訳文": ["rich_text": [["text": ["content": String(record.result.prefix(2000))]]]],
                "方向": ["select": ["name": record.direction]],
                "モード": ["select": ["name": record.mode]],
                "取得元アプリ": ["rich_text": [["text": ["content": record.app]]]],
                "日時": ["date": ["start": record.date]]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "Notion", code: code,
                          userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? ""])
        }
    }
}
