import Foundation

/// Static configuration. The active model is chosen at runtime via ModelStore.
enum Config {
    /// Defaults until the user picks in Settings. Translation favors speed,
    /// proofreading favors quality.
    static let defaultModel = "gemini-2.5-flash-lite"
    static let defaultProofreadModel = "gemini-2.5-flash"

    /// Curated, translation-suitable models offered in the Settings picker.
    /// `*-latest` aliases auto-track Google's current stable release.
    static let availableModels = [
        "gemini-flash-latest",
        "gemini-flash-lite-latest",
        "gemini-2.5-flash",
        "gemini-2.5-flash-lite",
        "gemini-3.5-flash",
        "gemini-2.5-pro",
        "gemini-2.0-flash",
        "gemini-pro-latest",
    ]

    static let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
    static let keychainService = "com.ryo.nanimini"
}
