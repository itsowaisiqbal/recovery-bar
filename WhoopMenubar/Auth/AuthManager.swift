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

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var state: AuthState = .signedOut

    private let keychain: KeychainStore
    private let proxyClient: AuthProxyClient
    private let clientID: String

    init(
        keychain: KeychainStore = KeychainStore(),
        proxyClient: AuthProxyClient = AuthProxyClient(),
        clientID: String = ""
    ) {
        self.keychain = keychain
        self.proxyClient = proxyClient
        self.clientID = clientID

        if keychain.hasTokens {
            state = .signedIn
        }
    }

    // MARK: - Public API

    func validAccessToken() async throws -> String {
        guard let token = keychain.accessToken else {
            state = .signedOut
            throw AuthProxyError.invalidResponse
        }

        if !keychain.isTokenExpired {
            return token
        }

        return try await refreshTokens()
    }

    func signIn() async {
        state = .signingIn

        do {
            guard !clientID.isEmpty else {
                state = .error("Client ID is not configured.")
                return
            }

            let stateParam = String.randomState()
            var components = URLComponents(string: Constants.API.authorizationURL)!
            components.queryItems = [
                URLQueryItem(name: "client_id", value: clientID),
                URLQueryItem(name: "redirect_uri", value: Constants.OAuth.redirectURI),
                URLQueryItem(name: "scope", value: Constants.API.defaultScopes),
                URLQueryItem(name: "state", value: stateParam),
                URLQueryItem(name: "response_type", value: "code")
            ]

            guard let authURL = components.url else {
                state = .error("Failed to build authorization URL")
                return
            }

            let server = LocalAuthServer(expectedState: stateParam)
            NSWorkspace.shared.open(authURL)

            let code: String
            do {
                code = try await server.waitForCallback()
            } catch {
                await server.stop()
                throw error
            }

            let tokenResponse = try await proxyClient.exchangeCode(
                code,
                redirectURI: Constants.OAuth.redirectURI
            )

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

    func signOut() {
        try? keychain.deleteAll()
        state = .signedOut
    }

    // MARK: - Private

    private func refreshTokens() async throws -> String {
        guard let refreshToken = keychain.refreshToken else {
            state = .signedOut
            throw AuthProxyError.invalidResponse
        }

        let tokenResponse = try await proxyClient.refreshTokens(refreshToken: refreshToken)

        // CRITICAL: Save new tokens immediately (refresh tokens are single-use)
        try keychain.saveTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresIn: tokenResponse.expiresIn
        )

        return tokenResponse.accessToken
    }
}
