import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 2) {
            if let score = appState.recoveryScore {
                Text("\(score)")
                    .font(.system(.body, design: .rounded).monospacedDigit().bold())
                    .foregroundStyle(appState.recoveryColor)
            } else if appState.authManager.state == .signedIn {
                Image(systemName: "heart.fill")
                    .font(.caption)
            } else {
                Text("W")
                    .font(.system(.body, design: .rounded).bold())
            }
        }
    }
}
