import Foundation

enum TranslationEngineID: String, CaseIterable, Codable, Identifiable, Sendable {
    case gemini
    case qwenMLX
    case foundationModels

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini: "Gemini"
        case .qwenMLX: "Qwen 1.5B MLX"
        case .foundationModels: "Apple Foundation Models"
        }
    }

    var usesNetworkForTranslation: Bool {
        self == .gemini
    }
}

struct TranslationEngineAvailability: Equatable, Sendable {
    let isAvailable: Bool
    let reason: String?

    static let available = Self(isAvailable: true, reason: nil)
}

enum TranslationEngineError: LocalizedError {
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable(let reason): reason
        }
    }
}

protocol TranslationEngine: Sendable {
    var id: TranslationEngineID { get }
    func availability() async -> TranslationEngineAvailability
    func translate(prompt: String, mode: TranslationMode, onDelta: @escaping @MainActor (String) -> Void) async throws
    func warmUp() async
}
