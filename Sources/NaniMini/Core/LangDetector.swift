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

    /// Ratio of CJK scalars among all non-whitespace scalars, used to pick a
    /// TTS voice for mixed-language text (e.g. code snippets, repo names).
    static func cjkRatio(for text: String) -> Double {
        var cjkCount = 0
        var totalCount = 0
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) { continue }
            totalCount += 1
            let v = scalar.value
            let isCJK =
                (0x3040...0x309F).contains(v) ||   // Hiragana
                (0x30A0...0x30FF).contains(v) ||   // Katakana
                (0x4E00...0x9FFF).contains(v)      // CJK Unified Ideographs
            if isCJK { cjkCount += 1 }
        }
        guard totalCount > 0 else { return 0 }
        return Double(cjkCount) / Double(totalCount)
    }

    /// TTS voice language for text, using a 10% CJK-ratio threshold.
    static func speechLanguage(for text: String, threshold: Double = 0.1) -> String {
        cjkRatio(for: text) >= threshold ? "ja-JP" : "en-US"
    }
}
