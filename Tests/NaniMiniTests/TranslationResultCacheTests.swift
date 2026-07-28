import Testing
@testable import NaniMini

struct TranslationResultCacheTests {
    @Test func separatesResultsByFastDisplaySetting() {
        var cache = TranslationResultCache()
        cache.set("standard", for: .translate, fastLiteralDisplay: false)

        #expect(cache.value(for: .translate, fastLiteralDisplay: false) == "standard")
        #expect(cache.value(for: .translate, fastLiteralDisplay: true) == nil)
    }
}
