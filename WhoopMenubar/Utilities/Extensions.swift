import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    /// Format as relative time string (e.g., "2 min ago", "1 hr ago")
    var relativeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Format as short time (e.g., "3:45 PM")
    var shortTimeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: self)
    }

    /// Format as medium date (e.g., "Mar 22, 2026")
    var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
}

// MARK: - ISO 8601 Parsing

extension DateFormatter {
    static let whoopISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension JSONDecoder {
    static let whoopDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            if let date = DateFormatter.whoopISO8601.date(from: dateString) {
                return date
            }

            // Fallback without fractional seconds
            let fallback = ISO8601DateFormatter()
            fallback.formatOptions = [.withInternetDateTime]
            if let date = fallback.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }
        return decoder
    }()
}

// MARK: - Double Formatting

extension Double {
    /// Format as strain value (e.g., "12.5")
    var strainFormatted: String {
        String(format: "%.1f", self)
    }

    /// Format as calories (e.g., "2,030")
    var caloriesFormatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
    }

    /// Format as temperature (e.g., "33.2°C")
    var temperatureFormatted: String {
        String(format: "%.1f°C", self)
    }
}

// MARK: - Int Formatting

extension Int {
    /// Format as percentage (e.g., "72%")
    var percentFormatted: String {
        "\(self)%"
    }

    /// Format as heart rate (e.g., "52 bpm")
    var bpmFormatted: String {
        "\(self) bpm"
    }

    /// Format as HRV (e.g., "65 ms")
    var hrvFormatted: String {
        "\(self) ms"
    }
}

// MARK: - TimeInterval Formatting

extension TimeInterval {
    /// Format milliseconds as duration (e.g., "7:30") matching WHOOP app style
    var sleepDurationFormatted: String {
        let totalMinutes = Int(self / 1_000 / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }
}

// MARK: - String Extensions

extension String {
    /// Generate a cryptographically random string using SecRandomCopyBytes
    static func randomState(length: Int = Constants.OAuth.stateLength) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { characters[Int($0) % characters.count] })
    }
}
