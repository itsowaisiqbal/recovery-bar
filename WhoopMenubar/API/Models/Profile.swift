import Foundation

struct UserProfile: Codable, Sendable, Equatable {
    let userId: Int
    let email: String
    let firstName: String
    let lastName: String

    var displayName: String {
        "\(firstName) \(lastName)"
    }
}
