import Foundation
import Security

enum KeychainKey: String {
    case geminiAPIKey
}

/// Stores secrets (API keys, tokens) in the macOS Keychain, never on disk in plaintext.
enum KeychainStore {
    static func set(_ value: String, for key: KeychainKey) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Config.keychainService,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(base as CFDictionary)

        guard !value.isEmpty else { return }
        var attributes = base
        attributes[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: KeychainKey) -> String? {
        if let value = value(for: key, service: Config.keychainService) {
            return value
        }
        // Migrate items saved under the pre-rename service id, so upgrading
        // from NaniMini doesn't silently drop the user's Gemini API key.
        guard let legacyValue = value(for: key, service: Config.legacyKeychainService) else {
            return nil
        }
        set(legacyValue, for: key)
        return legacyValue
    }

    private static func value(for key: KeychainKey, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)
        else { return nil }
        return value
    }
}
