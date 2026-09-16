import Foundation
import Testing
@testable import SelectTrans

struct TTSPreferenceStoreTests {
    private func freshStore(_ name: String) -> TTSPreferenceStore {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return TTSPreferenceStore(defaults: defaults)
    }

    @Test func defaultsAreSensible() {
        let store = freshStore(#function)

        #expect(store.character == .auto)
        #expect(store.rate == TTSPreferenceStore.defaultRate)
        #expect(store.volume == TTSPreferenceStore.defaultVolume)
        #expect(store.pitch == TTSPreferenceStore.defaultPitch)
        #expect(store.cjkThreshold == TTSPreferenceStore.defaultCJKThreshold)
        #expect(store.languageMode == .auto)
        #expect(store.speakRepoPrefix == true)
        #expect(store.isMuted == false)
        #expect(store.maxCharacters == TTSPreferenceStore.defaultMaxCharacters)
        #expect(store.isServerEnabled == true)
        #expect(store.popupOrigin == nil)
    }

    @Test func persistsServerEnabledToggle() {
        let store = freshStore(#function)

        store.isServerEnabled = false

        #expect(store.isServerEnabled == false)
    }

    @Test func persistsAndClearsPopupOrigin() {
        let store = freshStore(#function)

        store.popupOrigin = CGPoint(x: 12, y: 34)
        #expect(store.popupOrigin == CGPoint(x: 12, y: 34))

        store.popupOrigin = nil
        #expect(store.popupOrigin == nil)
    }

    @Test func persistsCharacterSelection() {
        let store = freshStore(#function)

        store.character = .eddy

        #expect(store.character == .eddy)
    }

    @Test func persistsNumericPreferences() {
        let store = freshStore(#function)

        store.rate = 0.42
        store.volume = 0.5
        store.pitch = 1.5
        store.cjkThreshold = 0.25
        store.maxCharacters = 100

        #expect(store.rate == 0.42)
        #expect(store.volume == 0.5)
        #expect(store.pitch == 1.5)
        #expect(store.cjkThreshold == 0.25)
        #expect(store.maxCharacters == 100)
    }

    @Test func persistsLanguageModeAndToggles() {
        let store = freshStore(#function)

        store.languageMode = .forcedJapanese
        store.speakRepoPrefix = false
        store.isMuted = true

        #expect(store.languageMode == .forcedJapanese)
        #expect(store.speakRepoPrefix == false)
        #expect(store.isMuted == true)
    }
}
