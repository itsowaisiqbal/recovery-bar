import Foundation

@MainActor
final class DataSyncService {
    private let appState: AppState
    private let apiClient: WhoopAPIClient
    private var pollingTask: Task<Void, Never>?

    init(appState: AppState, apiClient: WhoopAPIClient) {
        self.appState = appState
        self.apiClient = apiClient
    }

    func startPolling() {
        stopPolling()

        pollingTask = Task {
            // Full refresh on first launch
            await appState.refresh(fullRefresh: true)
            await appState.fetchProfile()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Constants.Polling.interval * 1_000_000_000))

                guard !Task.isCancelled else { break }

                // Smart poll: skip if cycle hasn't changed
                await appState.refresh(fullRefresh: false)
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
