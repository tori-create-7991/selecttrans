import Foundation
import Testing
@testable import NaniMini

struct TranslationPreferenceStoreTests {
    @Test func fastLiteralDisplayDefaultsToDisabled() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        let store = TranslationPreferenceStore(defaults: defaults)

        #expect(store.isFastLiteralDisplayEnabled == false)
    }

    @Test func persistsFastLiteralDisplayPreference() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = TranslationPreferenceStore(defaults: defaults)

        store.isFastLiteralDisplayEnabled = true

        #expect(TranslationPreferenceStore(defaults: defaults).isFastLiteralDisplayEnabled)
    }

    @Test func snapshotRemainsStableWhenStoredPreferenceChanges() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = TranslationPreferenceStore(defaults: defaults)
        let snapshot = store.current

        store.isFastLiteralDisplayEnabled = true

        #expect(snapshot.isFastLiteralDisplayEnabled == false)
        #expect(store.current.isFastLiteralDisplayEnabled)
    }
}
