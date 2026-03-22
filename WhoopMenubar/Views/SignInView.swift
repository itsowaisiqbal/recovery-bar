import SwiftUI

struct SignInView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if case .error(let message) = appState.authManager.state {
                Text(message)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Constants.Brand.recoveryRed)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            Button(action: {
                Task { await appState.authManager.signIn() }
            }) {
                HStack(spacing: 6) {
                    if appState.authManager.state == .signingIn {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("SIGN IN WITH")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(1.5)

                        Image("WhoopWordmark")
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 11)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.primary)
                .modifier(InteractiveGlassBackground(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(appState.authManager.state == .signingIn)

            Spacer()
        }
        .padding(.horizontal, 24)
        .frame(width: WhoopSpacing.popoverWidth, height: 120)
    }
}
