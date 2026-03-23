import Foundation
import Security

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case readFailed(OSStatus)
    case deleteFailed(OSStatus)
    case unexpectedData
    case encodingFailed

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
        case .encodingFailed:
            return "Failed to encode token data"
        }
    }
}

/// All tokens stored as a single Keychain entry to avoid multiple password prompts.
private struct TokenBundle: Codable {
    let accessToken: String
    let refreshToken: String
    let expiryDate: String
}

/// Token storage using a single Keychain item (one prompt max).
/// DEBUG builds use file-based storage to avoid Keychain prompts on rebuild.
struct KeychainStore: Sendable {
    private let service: String
    private let tokenKey = "auth_tokens"

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

    private var tokenFileURL: URL {
        storageDir.appendingPathComponent(tokenKey)
    }

    private func saveRaw(_ data: Data) throws {
        try data.write(to: tokenFileURL, options: .atomicWrite)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: tokenFileURL.path
        )
    }

    private func readRaw() -> Data? {
        try? Data(contentsOf: tokenFileURL)
    }

    func deleteAll() throws {
        try? FileManager.default.removeItem(at: storageDir)
    }

    #else
    // Real Keychain for RELEASE builds — single item, single prompt
    private func saveRaw(_ data: Data) throws {
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func readRaw() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
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

    private func readBundle() -> TokenBundle? {
        guard let data = readRaw() else { return nil }
        return try? JSONDecoder().decode(TokenBundle.self, from: data)
    }

    func saveTokens(accessToken: String, refreshToken: String, expiresIn: Int) throws {
        let expiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
        let expiryString = ISO8601DateFormatter().string(from: expiryDate)

        let bundle = TokenBundle(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryDate: expiryString
        )

        guard let data = try? JSONEncoder().encode(bundle) else {
            throw KeychainError.encodingFailed
        }

        try saveRaw(data)
    }

    var accessToken: String? { readBundle()?.accessToken }
    var refreshToken: String? { readBundle()?.refreshToken }

    var isTokenExpired: Bool {
        guard let bundle = readBundle(),
              let expiry = ISO8601DateFormatter().date(from: bundle.expiryDate) else {
            return true
        }
        return Date() >= expiry.addingTimeInterval(-300)
    }

    var hasTokens: Bool { readBundle() != nil }
}
