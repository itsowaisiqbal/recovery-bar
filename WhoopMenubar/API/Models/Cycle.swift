import Foundation

struct CycleCollection: Codable, Sendable {
    let records: [CycleRecord]
    let nextToken: String?
}

struct CycleRecord: Codable, Sendable, Identifiable, Equatable {
    let id: Int
    let userId: Int
    let createdAt: Date
    let updatedAt: Date
    let start: Date
    let end: Date?
    let timezoneOffset: String?
    let scoreState: ScoreState
    let score: CycleScore?
}

struct CycleScore: Codable, Sendable, Equatable {
    let strain: Double
    let kilojoule: Double
    let averageHeartRate: Int
    let maxHeartRate: Int

    var caloriesKcal: Double {
        kilojoule / 4.184
    }
}
