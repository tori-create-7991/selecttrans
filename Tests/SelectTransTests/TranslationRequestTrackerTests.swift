import Testing
@testable import SelectTrans

struct TranslationRequestTrackerTests {
    @Test func startingNewRequestSupersedesPreviousRequest() {
        var tracker = TranslationRequestTracker()
        let first = tracker.begin()
        let second = tracker.begin()

        #expect(!tracker.isCurrent(first))
        #expect(tracker.isCurrent(second))
    }
}
