import Foundation

struct WorkoutCollection: Codable, Sendable {
    let records: [WorkoutRecord]
    let nextToken: String?
}

struct WorkoutRecord: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let userId: Int
    let createdAt: Date
    let updatedAt: Date
    let start: Date
    let end: Date
    let timezoneOffset: String?
    let sportId: Int
    let sportName: String?
    let scoreState: ScoreState
    let score: WorkoutScore?

    var durationMinutes: Int {
        Int(end.timeIntervalSince(start) / 60)
    }
}

struct WorkoutScore: Codable, Sendable, Equatable {
    let strain: Double
    let averageHeartRate: Int
    let maxHeartRate: Int
    let kilojoule: Double
    let percentRecorded: Double?
    let distanceMeter: Double?
    let altitudeGainMeter: Double?
    let altitudeChangeMeter: Double?
    let zoneDurations: ZoneDuration?

    var caloriesKcal: Double {
        kilojoule / 4.184
    }
}

struct ZoneDuration: Codable, Sendable, Equatable {
    let zoneZeroMilli: Int?
    let zoneOneMilli: Int?
    let zoneTwoMilli: Int?
    let zoneThreeMilli: Int?
    let zoneFourMilli: Int?
    let zoneFiveMilli: Int?

    /// Returns zone durations as array of (zone label, millis) for display
    var allZones: [(label: String, millis: Int)] {
        [
            ("Zone 0", zoneZeroMilli ?? 0),
            ("Zone 1", zoneOneMilli ?? 0),
            ("Zone 2", zoneTwoMilli ?? 0),
            ("Zone 3", zoneThreeMilli ?? 0),
            ("Zone 4", zoneFourMilli ?? 0),
            ("Zone 5", zoneFiveMilli ?? 0)
        ]
    }

    var totalMillis: Int {
        let z0 = zoneZeroMilli ?? 0
        let z1 = zoneOneMilli ?? 0
        let z2 = zoneTwoMilli ?? 0
        let z3 = zoneThreeMilli ?? 0
        let z4 = zoneFourMilli ?? 0
        let z5 = zoneFiveMilli ?? 0
        return z0 + z1 + z2 + z3 + z4 + z5
    }
}
