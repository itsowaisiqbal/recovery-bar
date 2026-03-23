import Foundation
import os

private let logger = Logger(subsystem: "com.itsowaisiqbal.recoverybar", category: "Auth")

enum AuthProxyError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from auth proxy"
        case .httpError(let code, let message):
            return "Auth proxy error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        }
    }
}

struct TokenResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let tokenType: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

struct AuthProxyErrorResponse: Codable {
    let error: String
}

actor AuthProxyClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Proxy Flow

    /// Exchange authorization code for tokens via the auth proxy
    func exchangeCode(_ code: String, redirectURI: String) async throws -> TokenResponse {
        let url = URL(string: Constants.Proxy.baseURL + Constants.Proxy.tokenPath)!

        let body: [String: String] = [
            "code": code,
            "redirect_uri": redirectURI
        ]

        return try await postJSON(url: url, body: body)
    }

    /// Refresh tokens via the auth proxy
    func refreshTokens(refreshToken: String) async throws -> TokenResponse {
        let url = URL(string: Constants.Proxy.baseURL + Constants.Proxy.refreshPath)!

        let body: [String: String] = [
            "refresh_token": refreshToken
        ]

        return try await postJSON(url: url, body: body)
    }

    // MARK: - Direct Flow (User-Provided Credentials)

    /// Exchange authorization code using user's own client credentials
    func exchangeCodeDirect(
        code: String,
        redirectURI: String,
        clientID: String,
        clientSecret: String
    ) async throws -> TokenResponse {
        let url = URL(string: Constants.API.tokenURL)!

        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        let body: [String: String] = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "client_id": trimmedClientID,
            "client_secret": trimmedSecret
        ]

        return try await postFormEncoded(url: url, body: body)
    }

    /// Refresh tokens using user's own client credentials
    func refreshTokensDirect(
        refreshToken: String,
        clientID: String,
        clientSecret: String
    ) async throws -> TokenResponse {
        let url = URL(string: Constants.API.tokenURL)!

        let trimmedClientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)

        let body: [String: String] = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": trimmedClientID,
            "client_secret": trimmedSecret,
            "scope": "offline"
        ]

        return try await postFormEncoded(url: url, body: body)
    }

    // MARK: - HTTP Helpers

    private func postJSON(url: URL, body: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await execute(request)
    }

    private func postFormEncoded(url: URL, body: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let formString = body
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
        request.httpBody = Data(formString.utf8)

        return try await execute(request)
    }

    private func execute(_ request: URLRequest) async throws -> TokenResponse {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthProxyError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthProxyError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message: String
            if let errorResponse = try? JSONDecoder().decode(AuthProxyErrorResponse.self, from: data) {
                message = errorResponse.error
            } else {
                message = "HTTP \(httpResponse.statusCode)"
            }
            logger.error("Token request failed: HTTP \(httpResponse.statusCode)")
            throw AuthProxyError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(TokenResponse.self, from: data)
        } catch {
            throw AuthProxyError.decodingError(error)
        }
    }
}
