import Foundation
import Testing
@testable import SelectTrans

struct MarkdownHistoryStoreTests {
    @Test func appendsEngineLabelledRecordToMonthlyMarkdown() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("MarkdownHistoryStoreTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MarkdownHistoryStore(directory: directory)
        let record = TranslationRecord(
            source: "hello", result: "こんにちは", direction: "EN → JA",
            mode: "翻訳", app: "Test", date: "2026-09-06T10:00:00Z", engine: "Qwen 1.5B MLX"
        )

        try await store.save(record)

        let file = directory.appendingPathComponent("2026-09.md")
        let contents = try String(contentsOf: file, encoding: .utf8)
        #expect(contents.contains("Engine: Qwen 1.5B MLX"))
        #expect(contents.contains("hello"))
        #expect(contents.contains("こんにちは"))
    }
}
