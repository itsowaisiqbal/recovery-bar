import SwiftUI

@main
struct WhoopMenubarApp: App {
    @StateObject private var appState: AppState

    init() {
        let authManager = AuthManager()
        _appState = StateObject(wrappedValue: AppState(authManager: authManager))
    }

    var body: some Scene {
        MenuBarExtra {
            popoverContent
                .environmentObject(appState)
        } label: {
            MenuBarView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)
        .onChange(of: appState.authManager.state) { oldValue, newValue in
            handleAuthStateChange(from: oldValue, to: newValue)
        }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if appState.authManager.state == .signedIn {
            PopoverView()
        } else {
            SignInView()
        }
    }

    private func handleAuthStateChange(from oldValue: AuthState, to newValue: AuthState) {
        switch newValue {
        case .signedIn:
            appState.startSync()
        case .signedOut:
            appState.stopSync()
        default:
            break
        }
    }
}
