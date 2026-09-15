import Foundation

struct TranslationEngineStore {
    private static let selectedEngineKey = "selectedTranslationEngine"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selected: TranslationEngineID {
        get {
            guard let value = defaults.string(forKey: Self.selectedEngineKey),
                  let engine = TranslationEngineID(rawValue: value) else {
                return .gemini
            }
            return engine
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.selectedEngineKey)
        }
    }
}
