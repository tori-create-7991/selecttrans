import Testing
@testable import NaniMini

private actor NotionHistoryRecorder {
    private(set) var postCount = 0
    private(set) var enqueueCount = 0
    private(set) var acknowledgedRecordCount = 0
    private(set) var acknowledgeCallCount = 0
    private(set) var acknowledgedCounts: [Int] = []

    func recordPost() {
        postCount += 1
    }

    func recordEnqueue() {
        enqueueCount += 1
    }

    func recordAcknowledge(_ count: Int) {
        acknowledgeCallCount += 1
        acknowledgedRecordCount += count
        acknowledgedCounts.append(count)
    }
}

@Suite("NotionHistoryPolicy")
struct NotionHistoryPolicyTests {
    @Test("History is disabled when the token is missing")
    func historyIsDisabledWhenTokenIsMissing() {
        #expect(NotionHistoryPolicy.credentials(token: nil, databaseID: "database") == nil)
        #expect(NotionHistoryPolicy.credentials(token: "", databaseID: "database") == nil)
        #expect(NotionHistoryPolicy.credentials(token: " \n", databaseID: "database") == nil)
    }

    @Test("History is disabled when the database ID is missing")
    func historyIsDisabledWhenDatabaseIDIsMissing() {
        #expect(NotionHistoryPolicy.credentials(token: "token", databaseID: nil) == nil)
        #expect(NotionHistoryPolicy.credentials(token: "token", databaseID: "") == nil)
        #expect(NotionHistoryPolicy.credentials(token: "token", databaseID: "\t ") == nil)
    }

    @Test("History is disabled when both credentials are missing")
    func historyIsDisabledWhenBothCredentialsAreMissing() {
        #expect(NotionHistoryPolicy.credentials(token: nil, databaseID: nil) == nil)
    }

    @Test("History is enabled when both credentials are present")
    func historyIsEnabledWhenBothCredentialsArePresent() {
        #expect(NotionHistoryPolicy.credentials(token: "token", databaseID: "database") != nil)
    }

    @Test("Missing credentials cause no network or queue writes")
    func missingCredentialsHaveNoSideEffects() async {
        let recorder = NotionHistoryRecorder()
        let client = NotionHistoryClient(
            credentialReader: { key in
                key == .notionDatabaseID ? "database" : nil
            },
            postRecord: { _, _ in
                await recorder.recordPost()
            },
            enqueueRecord: { _ in
                await recorder.recordEnqueue()
            }
        )

        await client.save(Self.record)

        #expect(await recorder.postCount == 0)
        #expect(await recorder.enqueueCount == 0)
    }

    @Test("Configured request failure queues the record once")
    func requestFailureQueuesRecord() async {
        let recorder = NotionHistoryRecorder()
        let client = NotionHistoryClient(
            credentialReader: { key in
                key == .notionToken ? "token" : "database"
            },
            postRecord: { _, _ in
                await recorder.recordPost()
                throw TestError.requestFailed
            },
            enqueueRecord: { _ in
                await recorder.recordEnqueue()
            }
        )

        await client.save(Self.record)

        #expect(await recorder.postCount == 1)
        #expect(await recorder.enqueueCount == 1)
    }

    @Test("Failed retry remains pending")
    func failedRetryIsNotAcknowledged() async {
        let recorder = NotionHistoryRecorder()
        let client = NotionHistoryClient(
            credentialReader: { key in
                key == .notionToken ? "token" : "database"
            },
            postRecord: { _, _ in
                await recorder.recordPost()
                throw TestError.requestFailed
            },
            enqueueRecord: { _ in },
            pendingRecords: { [Self.record] },
            acknowledgeRecords: { count in
                await recorder.recordAcknowledge(count)
            }
        )

        await client.flushPending()

        #expect(await recorder.postCount == 1)
        #expect(await recorder.acknowledgedRecordCount == 0)
    }

    @Test("Successful retry is acknowledged")
    func successfulRetryIsAcknowledged() async {
        let recorder = NotionHistoryRecorder()
        let client = NotionHistoryClient(
            credentialReader: { key in
                key == .notionToken ? "token" : "database"
            },
            postRecord: { _, _ in
                await recorder.recordPost()
            },
            enqueueRecord: { _ in },
            pendingRecords: { [Self.record] },
            acknowledgeRecords: { count in
                await recorder.recordAcknowledge(count)
            }
        )

        await client.flushPending()

        #expect(await recorder.postCount == 1)
        #expect(await recorder.acknowledgedRecordCount == 1)
    }

    @Test("Successful retries are acknowledged in one batch")
    func successfulRetriesAreAcknowledgedInOneBatch() async {
        let recorder = NotionHistoryRecorder()
        let client = NotionHistoryClient(
            credentialReader: { key in
                key == .notionToken ? "token" : "database"
            },
            postRecord: { _, _ in
                await recorder.recordPost()
            },
            enqueueRecord: { _ in },
            pendingRecords: { [Self.record, Self.record] },
            acknowledgeRecords: { count in
                await recorder.recordAcknowledge(count)
            }
        )

        await client.flushPending()

        #expect(await recorder.postCount == 2)
        #expect(await recorder.acknowledgeCallCount == 1)
        #expect(await recorder.acknowledgedCounts == [2])
        #expect(await recorder.acknowledgedRecordCount == 2)
    }

    private static let record = TranslationRecord(
        source: "source",
        result: "result",
        direction: "ja-en",
        mode: "translate",
        app: "Tests",
        date: "2026-07-18T00:00:00Z"
    )

    private enum TestError: Error {
        case requestFailed
    }
}
