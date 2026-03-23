import Foundation
import os

private let logger = Logger(subsystem: "com.itsowaisiqbal.recoverybar", category: "API")

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
        case .decodingError:
            return "Failed to parse WHOOP data."
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

    func fetchBodyMeasurement() async throws -> BodyMeasurement {
        // Body measurement only available via v1 — v2 profile doesn't include it
        let url = URL(string: "https://api.prod.whoop.com/developer/v1/user/measurement/body")!
        return try await getURL(url)
    }

    // MARK: - Date-Range Fetches

    func fetchRecovery(start: Date, end: Date) async throws -> RecoveryRecord? {
        let collection: RecoveryCollection = try await get(
            endpoint: .recovery(start: start, end: end, limit: 1)
        )
        return collection.records.first
    }

    func fetchCycle(start: Date, end: Date) async throws -> CycleRecord? {
        let collection: CycleCollection = try await get(
            endpoint: .cycles(start: start, end: end, limit: 1)
        )
        return collection.records.first
    }

    func fetchSleeps(start: Date, end: Date) async throws -> [SleepRecord] {
        let collection: SleepCollection = try await get(
            endpoint: .sleep(start: start, end: end, limit: 25)
        )
        return collection.records
    }

    func fetchWorkouts(start: Date, end: Date) async throws -> [WorkoutRecord] {
        let collection: WorkoutCollection = try await get(
            endpoint: .workout(start: start, end: end, limit: 25)
        )
        return collection.records
    }

    // MARK: - Private

    private var oneDayAgo: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    }

    private var twoDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -2, to: Date())!
    }

    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date())!
    }

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func getURL<T: Decodable>(_ url: URL) async throws -> T {
        let token = try await authManager.validAccessToken()
        var request = URLRequest(url: url)
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

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw WhoopAPIError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: "Request failed")
        }

        do {
            return try JSONDecoder.whoopDecoder.decode(T.self, from: data)
        } catch {
            throw WhoopAPIError.decodingError(error)
        }
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
            logger.error("Decode error on \(endpoint.path): \(error.localizedDescription)")
            throw WhoopAPIError.decodingError(error)
        }
    }
}
