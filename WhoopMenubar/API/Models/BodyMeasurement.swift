import Foundation

struct BodyMeasurement: Codable, Sendable, Equatable {
    let heightMeter: Double?
    let weightKilogram: Double?
    let maxHeartRate: Int?

    var heightCm: Double? {
        guard let h = heightMeter else { return nil }
        return h * 100
    }

    var heightFormatted: String? {
        guard let cm = heightCm else { return nil }
        let feet = Int(cm / 30.48)
        let inches = Int((cm.truncatingRemainder(dividingBy: 30.48)) / 2.54)
        return "\(feet)'\(inches)\" (\(Int(cm))cm)"
    }

    var weightFormatted: String? {
        guard let kg = weightKilogram else { return nil }
        let lbs = kg * 2.20462
        return String(format: "%.0f kg (%.0f lbs)", kg, lbs)
    }
}
