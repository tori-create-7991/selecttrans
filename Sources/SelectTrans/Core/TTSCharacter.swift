import AVFoundation

/// Eloquence voices that ship both an en-US and a ja-JP variant under the same
/// character name, so switching TTS language mid-conversation keeps the same "voice".
enum TTSCharacter: String, CaseIterable, Identifiable, Codable {
    case auto
    case eddy = "Eddy"
    case flo = "Flo"
    case grandma = "Grandma"
    case grandpa = "Grandpa"
    case reed = "Reed"
    case rocko = "Rocko"
    case sandy = "Sandy"
    case shelley = "Shelley"

    var id: String { rawValue }

    var displayName: String {
        self == .auto ? "自動(システム標準)" : rawValue
    }

    /// Resolves to the installed voice for this character/language, falling back
    /// to the system default for `language` if the Eloquence voice isn't installed.
    func voice(language: String) -> AVSpeechSynthesisVoice? {
        guard self != .auto else { return AVSpeechSynthesisVoice(language: language) }
        let identifier = "com.apple.eloquence.\(language).\(rawValue)"
        return AVSpeechSynthesisVoice(identifier: identifier) ?? AVSpeechSynthesisVoice(language: language)
    }
}
