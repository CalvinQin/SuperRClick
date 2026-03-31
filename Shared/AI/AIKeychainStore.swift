import Foundation
import Security

public final class AIKeychainStore {
    private static let service = "com.haoqiqin.superrclick.ai"

    public static func save(apiKey: String, for providerID: String) throws {
        let account = providerID
        guard let data = apiKey.data(using: .utf8) else { return }

        // Try to delete first to overwrite
        try? delete(for: providerID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    public static func load(for providerID: String) throws -> String? {
        let account = providerID
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return apiKey
    }

    public static func delete(for providerID: String) throws {
        let account = providerID
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    public enum KeychainError: Error, LocalizedError {
        case unhandledError(status: OSStatus)
        
        public var errorDescription: String? {
            switch self {
            case .unhandledError(let status):
                return "Keychain error: \(status) (\(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown"))"
            }
        }
    }
}
