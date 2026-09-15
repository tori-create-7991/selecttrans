import Foundation

enum LegacyHistoryCleanup {
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
