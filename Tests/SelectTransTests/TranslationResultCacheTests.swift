import Testing
@testable import SelectTrans

struct TranslationResultCacheTests {
    @Test func separatesResultsByFastDisplaySetting() {
        var cache = TranslationResultCache()
        cache.set("standard", for: .translate, fastLiteralDisplay: false, engine: .gemini)

        #expect(cache.value(for: .translate, fastLiteralDisplay: false, engine: .gemini) == "standard")
        #expect(cache.value(for: .translate, fastLiteralDisplay: true, engine: .gemini) == nil)
        #expect(cache.value(for: .translate, fastLiteralDisplay: false, engine: .qwenMLX) == nil)
    }
}
