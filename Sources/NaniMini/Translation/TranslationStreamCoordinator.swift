import Foundation

@MainActor
struct TranslationStreamCoordinator {
    typealias Stream = (
        _ prompt: String,
        _ model: String,
        _ onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> Void

    private let stream: Stream

    init(stream: @escaping Stream) {
        self.stream = stream
    }

    func run(
        text: String,
        direction: TranslationDirection,
        mode: TranslationMode,
        model: String,
        preferences: TranslationPreferences,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        guard mode == .translate, preferences.isFastLiteralDisplayEnabled else {
            return try await streamComplete(
                prompt: Prompts.build(text: text, direction: direction, mode: mode),
                model: model,
                onDelta: onDelta
            )
        }

        var full = "【直訳】\n"
        onDelta(full)

        try await stream(Prompts.buildLiteral(text: text, direction: direction), model) { delta in
            full += delta
            onDelta(delta)
        }

        full += "\n\n"
        onDelta("\n\n")

        try await stream(Prompts.buildDetails(text: text, direction: direction), model) { delta in
            full += delta
            onDelta(delta)
        }

        return full
    }

    private func streamComplete(
        prompt: String,
        model: String,
        onDelta: @escaping @MainActor (String) -> Void
    ) async throws -> String {
        var full = ""
        try await stream(prompt, model) { delta in
            full += delta
            onDelta(delta)
        }
        return full
    }
}
