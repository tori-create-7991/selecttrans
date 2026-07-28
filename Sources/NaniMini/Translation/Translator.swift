import AppKit

struct TranslationResult {
    let source: String
    let output: String
    let direction: TranslationDirection
    let mode: TranslationMode
}

/// Orchestrates: detect direction -> build prompt -> stream from Gemini ->
/// fire history to Notion. Also offers back-translation and warm-up.
@MainActor
final class Translator {
    private let gemini = GeminiClient()
    private let notion = NotionHistoryClient()

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
        let model = ModelStore.model(for: mode)
        let coordinator = TranslationStreamCoordinator { [gemini] prompt, model, onDelta in
            try await gemini.translateStream(prompt: prompt, model: model, onDelta: onDelta)
        }
        let full = try await coordinator.run(
            text: text,
            direction: direction,
            mode: mode,
            model: model,
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
            date: ISO8601DateFormatter().string(from: Date())
        )
        Task { await notion.save(record) }

        return result
    }

    /// Translates the given (already translated) text back to the other language
    /// so the user can sanity-check meaning.
    func backTranslate(_ text: String) async throws -> String {
        let input = TranslationOutputParser.backTranslationInput(from: text)
        let direction = LangDetector.direction(for: input)
        let prompt = Prompts.build(text: input, direction: direction, mode: .translate)
        return try await gemini.translate(prompt: prompt, model: ModelStore.model(for: .translate))
    }

    func warmUp() async {
        await gemini.warmUp()
    }
}
