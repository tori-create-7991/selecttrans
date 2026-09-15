import Foundation

struct TTSHistoryEntry: Identifiable {
    let id = UUID()
    let repo: String
    let session: String
    let text: String
    let timestamp: Date
}

/// In-memory history of TTS requests, shown in the history window.
/// Not persisted across launches — the HTTP server caller (Claude Code hook)
/// already owns the durable record.
@MainActor
final class TTSHistoryStore: ObservableObject {
    static let shared = TTSHistoryStore()

    private let maxEntries = 200
    @Published private(set) var entries: [TTSHistoryEntry] = []

    func record(repo: String, session: String, text: String) {
        entries.insert(
            TTSHistoryEntry(repo: repo, session: session, text: text, timestamp: Date()),
            at: 0
        )
        if entries.count > maxEntries {
            entries.removeLast(entries.count - maxEntries)
        }
    }
}
