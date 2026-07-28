import Foundation

/// Persists the chosen Gemini model per mode (translate / proofread). Read fresh
/// on every request, so a change in Settings takes effect on the next call.
enum ModelStore {
    private static func key(for mode: TranslationMode) -> String {
        switch mode {
        case .translate: return "geminiModel_translate"
        case .proofread: return "geminiModel_proofread"
        }
    }

    static func model(for mode: TranslationMode) -> String {
        if let stored = UserDefaults.standard.string(forKey: key(for: mode)), !stored.isEmpty {
            return stored
        }
        // Migrate from the old single-model setting if present.
        if let legacy = UserDefaults.standard.string(forKey: "selectedGeminiModel"), !legacy.isEmpty {
            return legacy
        }
        return mode == .proofread ? Config.defaultProofreadModel : Config.defaultModel
    }

    static func set(_ model: String, for mode: TranslationMode) {
        UserDefaults.standard.set(model, forKey: key(for: mode))
    }
}
