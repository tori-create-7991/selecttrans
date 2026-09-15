import Foundation

/// One-time moves from pre-rename `NaniMini/...` storage locations to their
/// `SelectTrans/...` equivalents, so upgrading users don't lose data (or,
/// for the Qwen model, need to re-download ~869MB).
enum LegacyStorageMigration {
    static func moveDirectoryIfNeeded(legacy: URL, to destination: URL) {
        guard FileManager.default.fileExists(atPath: legacy.path),
              !FileManager.default.fileExists(atPath: destination.path)
        else { return }
        try? FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.moveItem(at: legacy, to: destination)
    }
}
