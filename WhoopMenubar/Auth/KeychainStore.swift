import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Keychain save failed: \(SecCopyErrorMessageString(status, nil) ?? "Unknown" as CFString)"
        case .readFailed(let status):
            return "Keychain read failed: \(SecCopyErrorMessageString(status, nil) ?? "Unknown" as CFString)"
        case .deleteFailed(let status):
            return "Keychain delete failed: \(SecCopyErrorMessageString(status, nil) ?? "Unknown" as CFString)"
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        }
    }
}

struct KeychainStore: Sendable {
    private let service: String

    init(service: String = Constants.Keychain.service) {
        self.service = service
    }

    // MARK: - Public API

    func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)

        // Delete existing item first
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    func read(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    // MARK: - Token Helpers

    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws {
        try save(accessToken, forKey: Constants.Keychain.accessTokenKey)
        try save(refreshToken, forKey: Constants.Keychain.refreshTokenKey)

        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        let expiryString = ISO8601DateFormatter().string(from: expiryDate)
        try save(expiryString, forKey: Constants.Keychain.tokenExpiryKey)
    }

    var accessToken: String? {
        read(forKey: Constants.Keychain.accessTokenKey)
    }

    var refreshToken: String? {
        read(forKey: Constants.Keychain.refreshTokenKey)
    }

    var isTokenExpired: Bool {
        guard let expiryString = read(forKey: Constants.Keychain.tokenExpiryKey),
              let expiry = ISO8601DateFormatter().date(from: expiryString) else {
            return true
        }
        // Consider expired 60 seconds early to avoid edge cases
        return Date() >= expiry.addingTimeInterval(-60)
    }

    var hasTokens: Bool {
        accessToken != nil && refreshToken != nil
    }

    // MARK: - User Credentials (Fallback Mode)

    func saveUserCredentials(clientID: String, clientSecret: String) throws {
        try save(clientID, forKey: Constants.Keychain.clientIDKey)
        try save(clientSecret, forKey: Constants.Keychain.clientSecretKey)
    }

    var userClientID: String? {
        read(forKey: Constants.Keychain.clientIDKey)
    }

    var userClientSecret: String? {
        read(forKey: Constants.Keychain.clientSecretKey)
    }

    var hasUserCredentials: Bool {
        userClientID != nil && userClientSecret != nil
    }
}
