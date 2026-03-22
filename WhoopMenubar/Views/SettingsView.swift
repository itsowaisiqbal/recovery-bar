import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isShowing: Bool
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Button(action: { isShowing = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Constants.Brand.teal)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("SETTINGS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.5)

                Spacer()
                Text("Back").font(.system(size: 11)).hidden()
            }

            // Account
            if let profile = appState.profile {
                GlassCard {
                    SectionHeader(title: "ACCOUNT")
                    Text(profile.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(profile.email)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }

            // Preferences
            GlassCard {
                SectionHeader(title: "PREFERENCES")

                Toggle(isOn: $launchAtLogin) {
                    Text("Start at Login")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Constants.Brand.teal)
                .onChange(of: launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = !newValue
                    }
                }
            }

            // Actions
            HStack {
                Button("Sign Out") {
                    appState.signOut()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Constants.Brand.recoveryRed)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.secondary)
            }
        }
        .padding(WhoopSpacing.outerPadding)
        .frame(width: WhoopSpacing.popoverWidth)
    }
}
