struct TranslationResultCache {
    private struct Key: Hashable {
        let mode: TranslationMode
        let fastLiteralDisplay: Bool
    }

    private var values: [Key: String] = [:]

    func value(for mode: TranslationMode, fastLiteralDisplay: Bool) -> String? {
        values[Key(mode: mode, fastLiteralDisplay: fastLiteralDisplay)]
    }

    mutating func set(_ value: String, for mode: TranslationMode, fastLiteralDisplay: Bool) {
        values[Key(mode: mode, fastLiteralDisplay: fastLiteralDisplay)] = value
    }

    mutating func removeAll() {
        values.removeAll()
    }
}
