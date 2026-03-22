import Foundation
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published State

    @Published private(set) var recovery: RecoveryRecord?
    @Published private(set) var cycle: CycleRecord?
    @Published private(set) var sleep: SleepRecord?
    @Published private(set) var naps: [SleepRecord] = []
    @Published private(set) var workout: WorkoutRecord?
    @Published private(set) var dayWorkouts: [WorkoutRecord] = []
    @Published private(set) var bodyMeasurement: BodyMeasurement?
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

        // Fetch the latest/current cycle (last 2 days to catch ongoing cycles)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!

        do {
            // Fetch latest cycle and recovery
            let now = Date()
            async let fetchedCycle = apiClient.fetchCycle(start: twoDaysAgo, end: now)
            async let fetchedRecovery = apiClient.fetchRecovery(start: twoDaysAgo, end: now)

            let (newCycle, newRecovery) = try await (fetchedCycle, fetchedRecovery)
            self.cycle = newCycle
            self.recovery = newRecovery

            // Use the cycle's boundaries to fetch activities for the current cycle
            let cycleStart = newCycle?.start ?? twoDaysAgo
            let cycleEnd = newCycle?.end ?? Date()

            async let fetchedSleeps = apiClient.fetchSleeps(start: cycleStart, end: cycleEnd)
            async let fetchedWorkouts = apiClient.fetchWorkouts(start: cycleStart, end: cycleEnd)

            let (newSleeps, newWorkouts) = try await (fetchedSleeps, fetchedWorkouts)

            // Sort chronologically (earliest first)
            let sortedSleeps = newSleeps.sorted { $0.start < $1.start }
            let sortedWorkouts = newWorkouts.sorted { $0.start < $1.start }

            // Separate main sleep from naps
            self.sleep = sortedSleeps.first { !$0.nap }
            self.naps = sortedSleeps.filter { $0.nap }

            // Store all workouts
            self.dayWorkouts = sortedWorkouts
            self.workout = sortedWorkouts.first

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
            async let profileResult = apiClient.fetchProfile()
            async let bodyResult = try? apiClient.fetchBodyMeasurement()

            self.profile = try await profileResult
            self.bodyMeasurement = await bodyResult
        } catch {
            // Profile fetch failure is non-critical
        }
    }

    func signOut() {
        stopSync()
        recovery = nil
        cycle = nil
        sleep = nil
        naps = []
        workout = nil
        dayWorkouts = []
        bodyMeasurement = nil
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
