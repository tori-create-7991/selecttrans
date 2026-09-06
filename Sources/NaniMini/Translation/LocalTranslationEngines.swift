import Foundation
import FoundationModels
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

struct GeminiTranslationEngine: TranslationEngine {
    let id: TranslationEngineID = .gemini
    private let client = GeminiClient()

    func availability() async -> TranslationEngineAvailability {
        guard let key = KeychainStore.get(.geminiAPIKey), !key.isEmpty else {
            return .init(isAvailable: false, reason: "Gemini APIキーを設定してください。")
        }
        return .available
    }

    func translate(prompt: String, mode: TranslationMode, onDelta: @escaping @MainActor (String) -> Void) async throws {
        try await client.translateStream(prompt: prompt, model: ModelStore.model(for: mode), onDelta: onDelta)
    }

    func warmUp() async { await client.warmUp() }
}

@available(macOS 26.0, *)
struct FoundationModelsTranslationEngine: TranslationEngine {
    let id: TranslationEngineID = .foundationModels

    func availability() async -> TranslationEngineAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            .available
        case .unavailable(let reason):
            .init(isAvailable: false, reason: "Apple Intelligenceを利用できません: \(reason)")
        }
    }

    func translate(prompt: String, mode: TranslationMode, onDelta: @escaping @MainActor (String) -> Void) async throws {
        guard (await availability()).isAvailable else {
            throw TranslationEngineError.unavailable((await availability()).reason ?? "Apple Intelligenceを利用できません。")
        }
        let session = LanguageModelSession()
        let response = try await session.respond(to: prompt)
        await onDelta(response.content)
    }

    func warmUp() async {}
}

struct QwenMLXTranslationEngine: TranslationEngine {
    let id: TranslationEngineID = .qwenMLX
    let modelDirectory: URL?

    init(modelDirectory: URL? = LocalModelStore().qwenModelURL) {
        self.modelDirectory = modelDirectory
    }

    func availability() async -> TranslationEngineAvailability {
        guard let modelDirectory else {
            return .init(isAvailable: false, reason: "Qwenモデルをダウンロードまたは選択してください。")
        }
        let accessed = modelDirectory.startAccessingSecurityScopedResource()
        defer { if accessed { modelDirectory.stopAccessingSecurityScopedResource() } }
        let required = ["config.json", "tokenizer.json"]
        if let missing = required.first(where: { !FileManager.default.fileExists(atPath: modelDirectory.appendingPathComponent($0).path) }) {
            return .init(isAvailable: false, reason: "Qwenモデルに\(missing)がありません。")
        }
        let weights = (try? FileManager.default.contentsOfDirectory(at: modelDirectory, includingPropertiesForKeys: nil)) ?? []
        guard weights.contains(where: { $0.pathExtension == "safetensors" }) else {
            return .init(isAvailable: false, reason: "Qwenモデルにsafetensors重みがありません。")
        }
        return .available
    }

    func translate(prompt: String, mode: TranslationMode, onDelta: @escaping @MainActor (String) -> Void) async throws {
        guard let modelDirectory else {
            throw TranslationEngineError.unavailable("Qwenモデルをダウンロードまたは選択してください。")
        }
        guard (await availability()).isAvailable else {
            throw TranslationEngineError.unavailable((await availability()).reason ?? "Qwenモデルを利用できません。")
        }
        let accessed = modelDirectory.startAccessingSecurityScopedResource()
        defer { if accessed { modelDirectory.stopAccessingSecurityScopedResource() } }
        let container = try await LLMModelFactory.shared.loadContainer(
            from: modelDirectory,
            using: #huggingFaceTokenizerLoader()
        )
        let session = ChatSession(container)
        let response = try await session.respond(to: prompt)
        await onDelta(response)
    }

    func warmUp() async {}
}

struct LocalModelStore {
    private static let qwenBookmarkKey = "qwenModelBookmark"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var qwenModelURL: URL? {
        guard let data = defaults.data(forKey: Self.qwenBookmarkKey) else { return nil }
        var stale = false
        return try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale)
    }

    func setQwenModelURL(_ url: URL?) throws {
        guard let url else { defaults.removeObject(forKey: Self.qwenBookmarkKey); return }
        defaults.set(try url.bookmarkData(options: [.withSecurityScope]), forKey: Self.qwenBookmarkKey)
    }
}
