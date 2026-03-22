import Foundation

struct RecoveryCollection: Codable, Sendable {
    let records: [RecoveryRecord]
    let nextToken: String?
}

struct RecoveryRecord: Codable, Sendable, Identifiable, Equatable {
    let cycleId: Int
    let sleepId: Int
    let userId: Int
    let createdAt: Date
    let updatedAt: Date
    let scoreState: ScoreState
    let score: RecoveryScore?

    var id: Int { cycleId }
}

struct RecoveryScore: Codable, Sendable, Equatable {
    let userCalibrating: Bool
    let recoveryScore: Double
    let restingHeartRate: Double
    let hrvRmssdMilli: Double
    let spo2Percentage: Double?
    let skinTempCelsius: Double?

    var recoveryPercent: Int {
        Int(recoveryScore.rounded())
    }

    var hrvMilliseconds: Int {
        Int(hrvRmssdMilli.rounded())
    }

    var restingHR: Int {
        Int(restingHeartRate.rounded())
    }

    var spo2Percent: Int? {
        guard let spo2 = spo2Percentage else { return nil }
        return Int(spo2.rounded())
    }
}

enum ScoreState: String, Codable, Sendable {
    case scored = "SCORED"
    case pendingScore = "PENDING_SCORE"
    case unscorable = "UNSCORABLE"
}
