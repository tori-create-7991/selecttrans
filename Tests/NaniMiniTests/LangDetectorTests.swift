import Testing
@testable import NaniMini

struct LangDetectorTests {
    @Test func cjkRatioIsOneForPureJapanese() {
        #expect(LangDetector.cjkRatio(for: "こんにちは世界") == 1.0)
    }

    @Test func cjkRatioIsZeroForPureEnglish() {
        #expect(LangDetector.cjkRatio(for: "hello world") == 0.0)
    }

    @Test func cjkRatioIgnoresWhitespace() {
        #expect(LangDetector.cjkRatio(for: "  こんにちは  ") == 1.0)
    }

    @Test func cjkRatioIsZeroForEmptyText() {
        #expect(LangDetector.cjkRatio(for: "") == 0.0)
    }

    @Test func speechLanguageIsJapaneseAtOrAboveThreshold() {
        // "selecttrans" (11 ascii) + "です" (2 CJK) = 2/13 ≈ 0.154 >= 0.1
        #expect(LangDetector.speechLanguage(for: "selecttransです") == "ja-JP")
    }

    @Test func speechLanguageIsEnglishBelowThreshold() {
        // 1 CJK char in a long English sentence stays below the 10% threshold.
        let text = "this is a long english sentence with only one kanji 字 in it"
        #expect(LangDetector.speechLanguage(for: text) == "en-US")
    }

    @Test func speechLanguageIsEnglishForEmptyText() {
        #expect(LangDetector.speechLanguage(for: "") == "en-US")
    }
}
