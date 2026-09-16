import AVFoundation
import Foundation

enum TTSLanguageMode: String, CaseIterable, Identifiable, Codable {
    case auto
    case forcedJapanese
    case forcedEnglish

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: "自動判定(CJK比率)"
        case .forcedJapanese: "常に日本語"
        case .forcedEnglish: "常に英語"
        }
    }
}

struct TTSPreferenceStore {
    private static let characterKey = "ttsCharacter"
    private static let rateKey = "ttsRate"
    private static let volumeKey = "ttsVolume"
    private static let pitchKey = "ttsPitch"
    private static let cjkThresholdKey = "ttsCJKThreshold"
    private static let languageModeKey = "ttsLanguageMode"
    private static let speakRepoPrefixKey = "ttsSpeakRepoPrefix"
    private static let mutedKey = "ttsMuted"
    private static let maxCharactersKey = "ttsMaxCharacters"
    private static let serverEnabledKey = "ttsServerEnabled"
    private static let popupOriginXKey = "ttsPopupOriginX"
    private static let popupOriginYKey = "ttsPopupOriginY"

    static let defaultRate = AVSpeechUtteranceDefaultSpeechRate
    static let defaultVolume: Float = 1.0
    static let defaultPitch: Float = 1.0
    static let defaultCJKThreshold = 0.1
    static let defaultMaxCharacters = 2000

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var character: TTSCharacter {
        get { defaults.string(forKey: Self.characterKey).flatMap(TTSCharacter.init(rawValue:)) ?? .auto }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.characterKey) }
    }

    var rate: Float {
        get {
            let stored = defaults.float(forKey: Self.rateKey)
            return stored == 0 ? Self.defaultRate : stored
        }
        nonmutating set { defaults.set(newValue, forKey: Self.rateKey) }
    }

    var volume: Float {
        get {
            guard defaults.object(forKey: Self.volumeKey) != nil else { return Self.defaultVolume }
            return defaults.float(forKey: Self.volumeKey)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.volumeKey) }
    }

    var pitch: Float {
        get {
            guard defaults.object(forKey: Self.pitchKey) != nil else { return Self.defaultPitch }
            return defaults.float(forKey: Self.pitchKey)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.pitchKey) }
    }

    var cjkThreshold: Double {
        get {
            guard defaults.object(forKey: Self.cjkThresholdKey) != nil else { return Self.defaultCJKThreshold }
            return defaults.double(forKey: Self.cjkThresholdKey)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.cjkThresholdKey) }
    }

    var languageMode: TTSLanguageMode {
        get { defaults.string(forKey: Self.languageModeKey).flatMap(TTSLanguageMode.init(rawValue:)) ?? .auto }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.languageModeKey) }
    }

    var speakRepoPrefix: Bool {
        get {
            guard defaults.object(forKey: Self.speakRepoPrefixKey) != nil else { return true }
            return defaults.bool(forKey: Self.speakRepoPrefixKey)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.speakRepoPrefixKey) }
    }

    var isMuted: Bool {
        get { defaults.bool(forKey: Self.mutedKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.mutedKey) }
    }

    /// Bottom-left origin of the "now speaking" popup, remembered after the
    /// user drags it. `nil` until the user moves it once (default position applies).
    var popupOrigin: CGPoint? {
        get {
            guard defaults.object(forKey: Self.popupOriginXKey) != nil,
                  defaults.object(forKey: Self.popupOriginYKey) != nil
            else { return nil }
            return CGPoint(
                x: defaults.double(forKey: Self.popupOriginXKey),
                y: defaults.double(forKey: Self.popupOriginYKey)
            )
        }
        nonmutating set {
            guard let newValue else {
                defaults.removeObject(forKey: Self.popupOriginXKey)
                defaults.removeObject(forKey: Self.popupOriginYKey)
                return
            }
            defaults.set(newValue.x, forKey: Self.popupOriginXKey)
            defaults.set(newValue.y, forKey: Self.popupOriginYKey)
        }
    }

    var isServerEnabled: Bool {
        get {
            guard defaults.object(forKey: Self.serverEnabledKey) != nil else { return true }
            return defaults.bool(forKey: Self.serverEnabledKey)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.serverEnabledKey) }
    }

    /// Utterances longer than this are truncated before speaking (0 = unlimited).
    var maxCharacters: Int {
        get {
            guard defaults.object(forKey: Self.maxCharactersKey) != nil else { return Self.defaultMaxCharacters }
            return defaults.integer(forKey: Self.maxCharactersKey)
        }
        nonmutating set { defaults.set(newValue, forKey: Self.maxCharactersKey) }
    }
}
