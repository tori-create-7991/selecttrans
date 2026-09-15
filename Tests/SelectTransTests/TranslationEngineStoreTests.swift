import Foundation
import Testing
@testable import SelectTrans

struct TranslationEngineStoreTests {
    @Test func defaultsToGemini() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)

        #expect(TranslationEngineStore(defaults: defaults).selected == .gemini)
    }

    @Test func persistsSelectedEngine() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let store = TranslationEngineStore(defaults: defaults)

        store.selected = .qwenMLX

        #expect(TranslationEngineStore(defaults: defaults).selected == .qwenMLX)
    }

    @Test func engineNamesExplainNetworkBoundary() {
        #expect(TranslationEngineID.gemini.usesNetworkForTranslation)
        #expect(!TranslationEngineID.qwenMLX.usesNetworkForTranslation)
        #expect(!TranslationEngineID.foundationModels.usesNetworkForTranslation)
    }
}
