struct TranslationResultCache {
    private struct Key: Hashable {
        let mode: TranslationMode
        let fastLiteralDisplay: Bool
        let engine: TranslationEngineID
    }

    private var values: [Key: String] = [:]

    func value(for mode: TranslationMode, fastLiteralDisplay: Bool, engine: TranslationEngineID) -> String? {
        values[Key(mode: mode, fastLiteralDisplay: fastLiteralDisplay, engine: engine)]
    }

    mutating func set(_ value: String, for mode: TranslationMode, fastLiteralDisplay: Bool, engine: TranslationEngineID) {
        values[Key(mode: mode, fastLiteralDisplay: fastLiteralDisplay, engine: engine)] = value
    }

    mutating func removeAll() {
        values.removeAll()
    }
}
