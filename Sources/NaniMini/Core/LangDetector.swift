import Foundation

/// Decides translation direction locally (no API call needed for EN<->JA).
enum LangDetector {
    static func direction(for text: String) -> TranslationDirection {
        for scalar in text.unicodeScalars {
            let v = scalar.value
            let isJapanese =
                (0x3040...0x309F).contains(v) ||   // Hiragana
                (0x30A0...0x30FF).contains(v) ||   // Katakana
                (0x4E00...0x9FFF).contains(v)      // CJK Unified Ideographs
            if isJapanese { return .jaToEn }
        }
        return .enToJa
    }
}
