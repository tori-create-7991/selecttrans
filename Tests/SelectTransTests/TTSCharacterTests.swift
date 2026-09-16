import Testing
@testable import SelectTrans

struct TTSCharacterTests {
    @Test func autoFallsBackToSystemVoiceForLanguage() {
        let voice = TTSCharacter.auto.voice(language: "en-US")
        #expect(voice?.language == "en-US")
    }

    @Test func bilingualCharacterResolvesToMatchingLanguage() {
        let ja = TTSCharacter.eddy.voice(language: "ja-JP")
        let en = TTSCharacter.eddy.voice(language: "en-US")

        #expect(ja?.language == "ja-JP")
        #expect(en?.language == "en-US")
        #expect(ja?.name == "Eddy")
        #expect(en?.name == "Eddy")
    }
}
