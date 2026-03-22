import Foundation
import AppKit

enum AuthState: Equatable {
    case signedOut
    case signingIn
    case signedIn
    case error(String)

    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.signedOut, .signedOut): return true
        case (.signingIn, .signingIn): return true
        case (.signedIn, .signedIn): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

enum AuthMode: String, CaseIterable {
    case proxy = "Auth Proxy (Default)"
    case userCredentials = "Own Credentials"
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var state: AuthState = .signedOut
    @Published var authMode: AuthMode = .proxy
    @Published var userClientID: String = ""
    @Published var userClientSecret: String = ""

    private let keychain: KeychainStore
    private let proxyClient: AuthProxyClient
    private let localServer: LocalAuthServer
    private let clientID: String

    init(
        keychain: KeychainStore = KeychainStore(),
        proxyClient: AuthProxyClient = AuthProxyClient(),
        clientID: String = ""
    ) {
        self.keychain = keychain
        self.proxyClient = proxyClient
        self.localServer = LocalAuthServer()
        self.clientID = clientID

        // Load saved user credentials if any
        if let savedClientID = keychain.userClientID,
           let savedSecret = keychain.userClientSecret {
            self.userClientID = savedClientID
            self.userClientSecret = savedSecret
            self.authMode = .userCredentials
        }

        // Check if already signed in
        if keychain.hasTokens {
            state = .signedIn
        }
    }

    // MARK: - Public API

    /// Get a valid access token, refreshing if needed
    func validAccessToken() async throws -> String {
        guard let token = keychain.accessToken else {
            state = .signedOut
            throw AuthProxyError.invalidResponse
        }

        if !keychain.isTokenExpired {
            return token
        }

        // Token expired, refresh it
        return try await refreshTokens()
    }

    /// Start the OAuth sign-in flow
    func signIn() async {
        state = .signingIn

        do {
            let effectiveClientID = resolvedClientID
            guard !effectiveClientID.isEmpty else {
                state = .error("Client ID is not configured. Please set it in Settings.")
                return
            }

            // Build authorization URL
            let stateParam = String.randomState()
            var components = URLComponents(string: Constants.API.authorizationURL)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: effectiveClientID),
                URLQueryItem(name: "redirect_uri", value: Constants.OAuth.redirectURI),
                URLQueryItem(name: "scope", value: Constants.API.defaultScopes),
                URLQueryItem(name: "state", value: stateParam),
                URLQueryItem(name: "response_type", value: "code")
            ]

            guard let authURL = components.url else {
                state = .error("Failed to build authorization URL")
                return
            }

            // Open browser
            NSWorkspace.shared.open(authURL)

            // Wait for callback
            let code = try await localServer.waitForCallback()

            // Exchange code for tokens
            let tokenResponse: TokenResponse
            if authMode == .userCredentials {
                tokenResponse = try await proxyClient.exchangeCodeDirect(
                    code: code,
                    redirectURI: Constants.OAuth.redirectURI,
                    clientID: userClientID,
                    clientSecret: userClientSecret
                )
            } else {
                tokenResponse = try await proxyClient.exchangeCode(
                    code,
                    redirectURI: Constants.OAuth.redirectURI
                )
            }

            // Save tokens
            try keychain.saveTokens(
                accessToken: tokenResponse.accessToken,
                refreshToken: tokenResponse.refreshToken,
                expiresIn: tokenResponse.expiresIn
            )

            state = .signedIn
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Sign out and clear all tokens
    func signOut() {
        try? keychain.deleteAll()
        state = .signedOut
    }

    /// Save user-provided credentials for direct auth mode
    func saveUserCredentials() throws {
        guard !userClientID.isEmpty, !userClientSecret.isEmpty else { return }
        try keychain.saveUserCredentials(clientID: userClientID, clientSecret: userClientSecret)
        authMode = .userCredentials
    }

    /// Clear user-provided credentials
    func clearUserCredentials() throws {
        try keychain.delete(forKey: Constants.Keychain.clientIDKey)
        try keychain.delete(forKey: Constants.Keychain.clientSecretKey)
        userClientID = ""
        userClientSecret = ""
        authMode = .proxy
    }

    // MARK: - Private

    private var resolvedClientID: String {
        if authMode == .userCredentials, !userClientID.isEmpty {
            return userClientID
        }
        return clientID
    }

    private func refreshTokens() async throws -> String {
        guard let refreshToken = keychain.refreshToken else {
            state = .signedOut
            throw AuthProxyError.invalidResponse
        }

        let tokenResponse: TokenResponse
        if authMode == .userCredentials,
           let savedClientID = keychain.userClientID,
           let savedSecret = keychain.userClientSecret {
            tokenResponse = try await proxyClient.refreshTokensDirect(
                refreshToken: refreshToken,
                clientID: savedClientID,
                clientSecret: savedSecret
            )
        } else {
            tokenResponse = try await proxyClient.refreshTokens(refreshToken: refreshToken)
        }

        // CRITICAL: Save new tokens immediately (refresh tokens are single-use)
        try keychain.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn
        )

        return tokenResponse.accessToken
    }
}
