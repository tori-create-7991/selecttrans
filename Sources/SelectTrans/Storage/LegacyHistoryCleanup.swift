import Foundation

enum LegacyHistoryCleanup {
    /// Points at the on-disk path this file actually had under the app's old
    /// name — NOT renamed alongside `SelectTrans`, since the goal is deleting
    /// whatever the old app left behind, not creating a new file to delete.
    static let pendingQueuePath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("NaniMini/pending.json")

    static func removePendingQueue() {
        guard FileManager.default.fileExists(atPath: pendingQueuePath.path) else { return }
        do {
            try FileManager.default.removeItem(at: pendingQueuePath)
        } catch {
            NSLog("[SelectTrans] Could not remove retired pending history: \(error.localizedDescription)")
        }
    }
}
