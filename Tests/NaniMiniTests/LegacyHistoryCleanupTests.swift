import Testing
@testable import NaniMini

struct LegacyHistoryCleanupTests {
    @Test func pendingQueuePathTargetsOnlyTheRetiredFile() {
        #expect(LegacyHistoryCleanup.pendingQueuePath.lastPathComponent == "pending.json")
        #expect(LegacyHistoryCleanup.pendingQueuePath.deletingLastPathComponent().lastPathComponent == "NaniMini")
    }
}
