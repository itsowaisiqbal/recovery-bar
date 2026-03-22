import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView()
                    .environmentObject(appState)
            } else {
                mainContent
            }
        }
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Greeting
            if let profile = appState.profile {
                Text("Hi, \(profile.firstName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Error banner
            if let error = appState.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.yellow.opacity(0.1))
                .cornerRadius(6)
            }

            // Data cards
            RecoveryCard(recovery: appState.recovery)
            Divider()
            StrainCard(cycle: appState.cycle)
            Divider()
            SleepCard(sleep: appState.sleep)

            // Footer
            Divider()
            HStack {
                if let lastUpdated = appState.lastUpdated {
                    Text("Updated \(lastUpdated.relativeString)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: {
                    showSettings.toggle()
                }) {
                    Image(systemName: "gear")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button(action: {
                    Task { await appState.refresh() }
                }) {
                    if appState.isLoading {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .disabled(appState.isLoading)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
