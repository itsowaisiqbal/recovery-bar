import SwiftUI
import Combine

@main
struct WhoopMenubarApp: App {
    @StateObject private var appState: AppState

    init() {
        guard let clientID = Bundle.main.object(forInfoDictionaryKey: "WhoopClientID") as? String,
              !clientID.isEmpty,
              clientID != "your-client-id-here" else {
            fatalError("WHOOP_CLIENT_ID not set. Copy Secrets.xcconfig.template to Secrets.xcconfig and add your client ID.")
        }
        let authManager = AuthManager(clientID: clientID)
        _appState = StateObject(wrappedValue: AppState(authManager: authManager))
    }

    var body: some Scene {
        MenuBarExtra {
            popoverContent
                .environmentObject(appState)
                .background(PopoverWindowConfigurator())
        } label: {
            MenuBarLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)
    }

    @ViewBuilder
    private var popoverContent: some View {
        if appState.authManager.state == .signedIn {
            PopoverView()
        } else {
            SignInView()
        }
    }
}

/// Separate view to observe auth state and trigger sync
struct MenuBarLabel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        MenuBarView()
            .environmentObject(appState)
            .onReceive(appState.authManager.$state) { newState in
                if newState == .signedIn {
                    appState.startSync()
                } else if newState == .signedOut {
                    appState.stopSync()
                }
            }
    }
}

// MARK: - Window Configurator

/// Makes the popover window transparent so .glassEffect() elements
/// can properly blur the desktop content behind them.
struct PopoverWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.frame = .zero
        DispatchQueue.main.async {
            configureWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWindow(nsView.window)
    }

    private func configureWindow(_ window: NSWindow?) {
        guard let window = window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        // Remove the default panel visual effect background
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = .clear
            // Remove any NSVisualEffectView that the panel adds by default
            for subview in contentView.subviews where subview is NSVisualEffectView {
                subview.isHidden = true
            }
        }
    }
}
