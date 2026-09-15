import Testing
@testable import SelectTrans

struct TranslationOutputParserTests {
    @Test func extractsNaturalTranslationForSentenceOutput() {
        let output = """
        【直訳】
        私は駅に行きました。

        【つまり】
        The speaker went to the station.

        【自然な訳】
        I went to the station.
        """

        #expect(TranslationOutputParser.backTranslationInput(from: output) == "I went to the station.")
    }

    @Test func extractsBasicMeaningForSingleWordOutput() {
        let output = """
        【直訳】
        走る

        【よく使われる意味】
        move quickly on foot

        【例文】
        - I run every morning. = 毎朝走ります。
        """

        #expect(TranslationOutputParser.backTranslationInput(from: output) == "走る")
    }
}
