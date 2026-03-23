import SwiftUI

enum Constants {
    // MARK: - WHOOP API
    enum API {
        static let baseURL = "https://api.prod.whoop.com/developer/v2"
        static let authorizationURL = "https://api.prod.whoop.com/oauth/oauth2/auth"
        static let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"

        static let defaultScopes = "read:recovery read:cycles read:sleep read:workout read:profile read:body_measurement offline"
    }

    // MARK: - Auth Proxy
    enum Proxy {
        static let baseURL = "https://whoop-auth-proxy.itsowaisiqbal.workers.dev"
        static let tokenPath = "/token"
        static let refreshPath = "/refresh"
    }

    // MARK: - OAuth
    enum OAuth {
        static let callbackPort: UInt16 = 8_919
        static let redirectURI = "http://localhost:\(callbackPort)/callback"
        static let stateLength = 32
    }

    // MARK: - Keychain
    enum Keychain {
        static let service = "com.itsowaisiqbal.whoop-menubar"
    }

    // MARK: - Polling
    enum Polling {
        static let interval: TimeInterval = 15 * 60 // 15 minutes
        static let retryDelay: TimeInterval = 30
    }

    // MARK: - WHOOP Brand Colors (Official)
    enum Brand {
        // Recovery zone colors
        static let recoveryGreen = Color(hex: 0x16EC06)
        static let recoveryYellow = Color(hex: 0xFFDE00)
        static let recoveryRed = Color(hex: 0xFF0026)

        // Data category colors
        static let strain = Color(hex: 0x0093E7)
        static let sleep = Color(hex: 0x7BA1BB)
        static let teal = Color(hex: 0x00F19F)

        // Background
        static let backgroundTop = Color(hex: 0x283339)
        static let backgroundBottom = Color(hex: 0x101518)
        static let cardBackground = Color(hex: 0x1A2329)
        static let surfaceBackground = Color(hex: 0x0B0B0B)

        // Text
        static let primaryText = Color.white
        static let secondaryText = Color.white.opacity(0.6)
        static let tertiaryText = Color.white.opacity(0.4)
    }

    // MARK: - Recovery Thresholds
    enum Recovery {
        static let greenMin = 67
        static let yellowMin = 34

        static func color(for score: Int) -> Color {
            switch score {
            case greenMin...100:
                return Brand.recoveryGreen
            case yellowMin..<greenMin:
                return Brand.recoveryYellow
            default:
                return Brand.recoveryRed
            }
        }

        static func label(for score: Int) -> String {
            switch score {
            case greenMin...100:
                return "Green"
            case yellowMin..<greenMin:
                return "Yellow"
            default:
                return "Red"
            }
        }
    }

    // MARK: - Strain
    enum Strain {
        static let maxStrain: Double = 21.0
    }

}

// MARK: - Color Extension

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
