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

/// Token storage that uses file-based storage in DEBUG (avoids Keychain prompts on rebuild)
/// and real Keychain in RELEASE builds.
struct KeychainStore: Sendable {
    private let service: String

    init(service: String = Constants.Keychain.service) {
        self.service = service
    }

    // MARK: - Storage Backend

    #if DEBUG
    // File-based storage for development — no Keychain prompts on rebuild
    private var storageDir: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".whoop-menubar-dev", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(forKey key: String) -> URL {
        storageDir.appendingPathComponent(key)
    }

    func save(_ value: String, forKey key: String) throws {
        let url = fileURL(forKey: key)
        try Data(value.utf8).write(to: url, options: .atomicWrite)
        // Restrict file permissions to owner-only (0600)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    func read(forKey key: String) -> String? {
        let url = fileURL(forKey: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(forKey key: String) throws {
        let url = fileURL(forKey: key)
        try? FileManager.default.removeItem(at: url)
    }

    func deleteAll() throws {
        try? FileManager.default.removeItem(at: storageDir)
    }

    #else
    // Real Keychain for RELEASE builds
    func save(_ value: String, forKey key: String) throws {
        let data = Data(value.utf8)
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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
    #endif

    // MARK: - Token Helpers

    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws {
        try save(accessToken, forKey: Constants.Keychain.accessTokenKey)
        try save(refreshToken, forKey: Constants.Keychain.refreshTokenKey)

        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        let expiryString = ISO8601DateFormatter().string(from: expiryDate)
        try save(expiryString, forKey: Constants.Keychain.tokenExpiryKey)
    }

    var accessToken: String? { read(forKey: Constants.Keychain.accessTokenKey) }
    var refreshToken: String? { read(forKey: Constants.Keychain.refreshTokenKey) }

    var isTokenExpired: Bool {
        guard let expiryString = read(forKey: Constants.Keychain.tokenExpiryKey),
              let expiry = ISO8601DateFormatter().date(from: expiryString) else {
            return true
        }
        return Date() >= expiry.addingTimeInterval(-300)
    }

    var hasTokens: Bool { accessToken != nil && refreshToken != nil }
}
