import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published private(set) var recovery: RecoveryRecord?
    @Published private(set) var cycle: CycleRecord?
    @Published private(set) var sleep: SleepRecord?
    @Published private(set) var profile: UserProfile?
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    let authManager: AuthManager
    private var apiClient: WhoopAPIClient?
    private var syncService: DataSyncService?

    // MARK: - Init

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: - Computed Properties

    var recoveryScore: Int? {
        guard let recovery = recovery,
              recovery.scoreState == .scored,
              let score = recovery.score else {
            return nil
        }
        return score.recoveryPercent
    }

    var recoveryColor: Color {
        guard let score = recoveryScore else { return .gray }
        return Constants.Recovery.color(for: score)
    }

    var menuBarTitle: String {
        guard authManager.state == .signedIn else { return "W" }
        guard let score = recoveryScore else { return "..." }
        return "\(score)%"
    }

    // MARK: - Actions

    func startSync() {
        guard apiClient == nil else { return }

        let client = WhoopAPIClient(authManager: authManager)
        self.apiClient = client

        let service = DataSyncService(appState: self, apiClient: client)
        self.syncService = service
        service.startPolling()
    }

    func stopSync() {
        syncService?.stopPolling()
        syncService = nil
        apiClient = nil
    }

    func refresh() async {
        guard let apiClient = apiClient else { return }

        isLoading = true
        error = nil

        do {
            async let fetchedRecovery = apiClient.fetchLatestRecovery()
            async let fetchedCycle = apiClient.fetchLatestCycle()
            async let fetchedSleep = apiClient.fetchLatestSleep()

            let (newRecovery, newCycle, newSleep) = try await (
                fetchedRecovery,
                fetchedCycle,
                fetchedSleep
            )

            self.recovery = newRecovery
            self.cycle = newCycle
            self.sleep = newSleep
            self.lastUpdated = Date()
            self.error = nil
        } catch let apiError as WhoopAPIError {
            handleAPIError(apiError)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func fetchProfile() async {
        guard let apiClient = apiClient else { return }

        do {
            self.profile = try await apiClient.fetchProfile()
        } catch {
            // Profile fetch failure is non-critical
            print("Failed to fetch profile: \(error)")
        }
    }

    func signOut() {
        stopSync()
        recovery = nil
        cycle = nil
        sleep = nil
        profile = nil
        lastUpdated = nil
        error = nil
        authManager.signOut()
    }

    // MARK: - Private

    private func handleAPIError(_ error: WhoopAPIError) {
        switch error {
        case .unauthorized:
            self.error = error.localizedDescription
            signOut()
        case .rateLimited:
            self.error = error.localizedDescription
        default:
            self.error = error.localizedDescription
        }
    }
}
