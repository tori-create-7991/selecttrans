import Testing
@testable import SelectTrans

struct LegacyHistoryCleanupTests {
    @Test func pendingQueuePathTargetsOnlyTheRetiredFile() {
        #expect(LegacyHistoryCleanup.pendingQueuePath.lastPathComponent == "pending.json")
        #expect(LegacyHistoryCleanup.pendingQueuePath.deletingLastPathComponent().lastPathComponent == "NaniMini")
    }
}
