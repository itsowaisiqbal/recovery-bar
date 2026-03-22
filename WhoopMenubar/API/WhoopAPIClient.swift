import Foundation

enum WhoopAPIError: LocalizedError {
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case httpError(statusCode: Int, message: String)
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Session expired. Please sign in again."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Retry after \(seconds) seconds."
            }
            return "Rate limited. Please wait before retrying."
        case .httpError(let code, let message):
            return "API error (\(code)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse WHOOP data: \(error.localizedDescription)"
        }
    }
}

actor WhoopAPIClient {
    private let session: URLSession
    private let authManager: AuthManager

    init(authManager: AuthManager, session: URLSession = .shared) {
        self.authManager = authManager
        self.session = session
    }

    // MARK: - Public API

    func fetchProfile() async throws -> UserProfile {
        return try await get(endpoint: .profile)
    }

    func fetchLatestRecovery() async throws -> RecoveryRecord? {
        let collection: RecoveryCollection = try await get(
            endpoint: .recovery(start: oneDayAgo, end: nil, limit: 1)
        )
        return collection.records.first
    }

    func fetchLatestCycle() async throws -> CycleRecord? {
        let collection: CycleCollection = try await get(
            endpoint: .cycles(start: oneDayAgo, end: nil, limit: 1)
        )
        return collection.records.first
    }

    func fetchLatestSleep() async throws -> SleepRecord? {
        let collection: SleepCollection = try await get(
            endpoint: .sleep(start: twoDaysAgo, end: nil, limit: 1)
        )
        // Filter out naps, return the most recent actual sleep
        return collection.records.first { !$0.nap }
    }

    // MARK: - Private

    private var oneDayAgo: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    private var twoDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -2, to: Date())!
    }

    private func get<T: Decodable>(endpoint: WhoopEndpoint) async throws -> T {
        let token = try await authManager.validAccessToken()

        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WhoopAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopAPIError.httpError(statusCode: 0, message: "Invalid response")
        }

        switch httpResponse.statusCode {
        case 200...299:
            break
        case 401:
            throw WhoopAPIError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Reset")
                .flatMap(Int.init)
            throw WhoopAPIError.rateLimited(retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhoopAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder.whoopDecoder.decode(T.self, from: data)
        } catch {
            throw WhoopAPIError.decodingError(error)
        }
    }
}
