import Foundation

struct TranslationPreferences {
    let isFastLiteralDisplayEnabled: Bool
}

struct TranslationPreferenceStore {
    private static let fastLiteralDisplayKey = "fastLiteralDisplayEnabled"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isFastLiteralDisplayEnabled: Bool {
        get { defaults.bool(forKey: Self.fastLiteralDisplayKey) }
        nonmutating set { defaults.set(newValue, forKey: Self.fastLiteralDisplayKey) }
    }

    var current: TranslationPreferences {
        TranslationPreferences(isFastLiteralDisplayEnabled: isFastLiteralDisplayEnabled)
    }
}
