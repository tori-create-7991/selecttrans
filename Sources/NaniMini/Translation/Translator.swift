import AppKit

struct TranslationResult {
    let source: String
    let output: String
    let direction: TranslationDirection
    let mode: TranslationMode
}

/// Orchestrates direction detection, the selected engine, and local history.
@MainActor
final class Translator {
    private let engines = TranslationEngineStore()
    private let history = MarkdownHistoryStore.shared

    /// Streams the translation; `onDelta` receives chunks as they arrive.
    /// Returns the full result once the stream completes.
    @discardableResult
    func runStream(
        text: String,
        mode: TranslationMode,
        sourceApp: String,
        preferences: TranslationPreferences,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> TranslationResult {
        let direction = LangDetector.direction(for: text)
        let engine = makeEngine()
        let availability = await engine.availability()
        guard availability.isAvailable else {
            throw TranslationEngineError.unavailable(availability.reason ?? "選択した翻訳エンジンを利用できません。")
        }
        let coordinator = TranslationStreamCoordinator { prompt, _, onDelta in
            try await engine.translate(prompt: prompt, mode: mode, onDelta: onDelta)
        }
        let full = try await coordinator.run(
            text: text,
            direction: direction,
            mode: mode,
            model: "",
            preferences: preferences,
            onDelta: onDelta
        )

        let result = TranslationResult(source: text, output: full, direction: direction, mode: mode)

        let record = TranslationRecord(
            source: text,
            result: full,
            direction: direction.label,
            mode: mode.rawValue,
            app: sourceApp,
            date: ISO8601DateFormatter().string(from: Date()),
            engine: engine.id.displayName
        )
        Task { try? await history.save(record) }

        return result
    }

    /// Translates the given (already translated) text back to the other language
    /// so the user can sanity-check meaning.
    func backTranslate(_ text: String) async throws -> String {
        let input = TranslationOutputParser.backTranslationInput(from: text)
        let direction = LangDetector.direction(for: input)
        let engine = makeEngine()
        let availability = await engine.availability()
        guard availability.isAvailable else {
            throw TranslationEngineError.unavailable(availability.reason ?? "選択した翻訳エンジンを利用できません。")
        }
        var output = ""
        try await engine.translate(
            prompt: Prompts.build(text: input, direction: direction, mode: .translate),
            mode: .translate
        ) { output += $0 }
        return output
    }

    func warmUp() async {
        await makeEngine().warmUp()
    }

    private func makeEngine() -> any TranslationEngine {
        switch engines.selected {
        case .gemini:
            GeminiTranslationEngine()
        case .qwenMLX:
            QwenMLXTranslationEngine()
        case .foundationModels:
            FoundationModelsTranslationEngine()
        }
    }
}
