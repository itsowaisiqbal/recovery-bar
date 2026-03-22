import SwiftUI

enum Constants {
    // MARK: - WHOOP API
    enum API {
        static let baseURL = "https://api.prod.whoop.com/developer/v2"
        static let authorizationURL = "https://api.prod.whoop.com/oauth/oauth2/auth"
        static let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"

        static let defaultScopes = "read:recovery read:cycles read:sleep read:profile offline"
    }

    // MARK: - Auth Proxy
    enum Proxy {
        // TODO: Replace with your deployed Cloudflare Worker URL
        static let baseURL = "https://whoop-auth-proxy.YOUR_SUBDOMAIN.workers.dev"
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
        static let accessTokenKey = "whoop_access_token"
        static let refreshTokenKey = "whoop_refresh_token"
        static let clientIDKey = "whoop_client_id"
        static let clientSecretKey = "whoop_client_secret"
        static let tokenExpiryKey = "whoop_token_expiry"
    }

    // MARK: - Polling
    enum Polling {
        static let interval: TimeInterval = 15 * 60 // 15 minutes
        static let retryDelay: TimeInterval = 30
    }

    // MARK: - Recovery Thresholds
    enum Recovery {
        static let greenMin = 67
        static let yellowMin = 34

        static func color(for score: Int) -> Color {
            switch score {
            case greenMin...100:
                return .green
            case yellowMin..<greenMin:
                return .yellow
            default:
                return .red
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
}
