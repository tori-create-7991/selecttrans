import Foundation

struct TTSSpeakingItem: Equatable {
    let repo: String
    let text: String
}

/// Publishes what `Speaker` is currently reading aloud, so the UI can show a
/// popup while speech is in progress and hide it automatically when done.
@MainActor
final class TTSSpeakingNowStore: ObservableObject {
    static let shared = TTSSpeakingNowStore()

    @Published private(set) var current: TTSSpeakingItem?

    func set(_ item: TTSSpeakingItem?) {
        current = item
    }
}
