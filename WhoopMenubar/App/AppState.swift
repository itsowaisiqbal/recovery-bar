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
    @Published private(set) var lastRefreshed: Date?

    let authManager: AuthManager
    private var apiClient: WhoopAPIClient?
    private var syncService: DataSyncService?
    private var lastCycleId: Int?

    private static let refreshCooldown: TimeInterval = 30

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

    var canRefresh: Bool {
        guard let lastRefreshed else { return true }
        return Date().timeIntervalSince(lastRefreshed) >= Self.refreshCooldown
    }

    var refreshCooldownRemaining: Int {
        guard let lastRefreshed else { return 0 }
        let elapsed = Date().timeIntervalSince(lastRefreshed)
        return max(0, Int(ceil(Self.refreshCooldown - elapsed)))
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

    /// - Parameter fullRefresh: `true` for manual refresh (always fetches all data),
    ///   `false` for timer polls (skips if cycle unchanged).
    func refresh(fullRefresh: Bool = true) async {
        guard let apiClient = apiClient else { return }

        // Cooldown: skip if refreshed recently (only for manual refreshes)
        if fullRefresh && !canRefresh { return }

        isLoading = true
        error = nil

        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let now = Date()

        do {
            // Always fetch cycle first (1 API call)
            let newCycle = try await apiClient.fetchCycle(start: twoDaysAgo, end: now)

            // Smart polling: skip remaining calls if cycle hasn't changed
            if !fullRefresh, let newId = newCycle?.id, newId == lastCycleId {
                isLoading = false
                return
            }

            // Cycle changed or manual refresh — fetch everything
            self.lastCycleId = newCycle?.id
            self.cycle = newCycle

            let newRecovery = try await apiClient.fetchRecovery(start: twoDaysAgo, end: now)
            self.recovery = newRecovery

            let cycleStart = newCycle?.start ?? twoDaysAgo
            let cycleEnd = newCycle?.end ?? Date()

            async let fetchedSleeps = apiClient.fetchSleeps(start: cycleStart, end: cycleEnd)
            async let fetchedWorkouts = apiClient.fetchWorkouts(start: cycleStart, end: cycleEnd)

            let (newSleeps, newWorkouts) = try await (fetchedSleeps, fetchedWorkouts)

            let sortedSleeps = newSleeps.sorted { $0.start < $1.start }
            let sortedWorkouts = newWorkouts.sorted { $0.start < $1.start }

            self.sleep = sortedSleeps.first { !$0.nap }
            self.naps = sortedSleeps.filter { $0.nap }

            self.dayWorkouts = sortedWorkouts
            self.workout = sortedWorkouts.first

            self.lastUpdated = Date()
            self.lastRefreshed = Date()
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
