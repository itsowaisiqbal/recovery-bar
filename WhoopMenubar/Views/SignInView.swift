import SwiftUI

struct SignInView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("WHOOP Menubar")
                .font(.headline)

            Text("View your recovery, strain, and sleep data right from the menu bar.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if case .error(let message) = appState.authManager.state {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: {
                Task {
                    await appState.authManager.signIn()
                }
            }) {
                HStack {
                    if appState.authManager.state == .signingIn {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(appState.authManager.state == .signingIn ? "Signing in..." : "Sign in with WHOOP")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(appState.authManager.state == .signingIn)
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 280)
    }
}
