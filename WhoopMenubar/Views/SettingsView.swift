import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var saveError: String?
    @State private var localClientID: String = ""
    @State private var localClientSecret: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Auth Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Authentication")
                    .font(.subheadline.bold())

                HStack {
                    ForEach(AuthMode.allCases, id: \.self) { mode in
                        Button(action: {
                            appState.authManager.authMode = mode
                        }) {
                            Text(mode.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    appState.authManager.authMode == mode
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.clear
                                )
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if appState.authManager.authMode == .userCredentials {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Client ID", text: $localClientID)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        SecureField("Client Secret", text: $localClientSecret)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)

                        if let error = saveError {
                            Text(error)
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }

                        Button("Save Credentials") {
                            appState.authManager.userClientID = localClientID
                            appState.authManager.userClientSecret = localClientSecret
                            do {
                                try appState.authManager.saveUserCredentials()
                                saveError = nil
                            } catch {
                                saveError = error.localizedDescription
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Divider()

            // Account
            if let profile = appState.profile {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Account")
                        .font(.subheadline.bold())
                    Text(profile.displayName)
                        .font(.caption)
                    Text(profile.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            // Actions
            HStack {
                Button("Sign Out") {
                    appState.signOut()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            localClientID = appState.authManager.userClientID
            localClientSecret = appState.authManager.userClientSecret
        }
    }
}
