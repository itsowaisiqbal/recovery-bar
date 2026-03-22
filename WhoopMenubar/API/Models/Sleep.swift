import Foundation

struct SleepCollection: Codable, Sendable {
    let records: [SleepRecord]
    let nextToken: String?
}

struct SleepRecord: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let userId: Int
    let createdAt: Date
    let updatedAt: Date
    let start: Date
    let end: Date
    let timezoneOffset: String?
    let nap: Bool
    let scoreState: ScoreState
    let score: SleepScore?
}

struct SleepScore: Codable, Sendable, Equatable {
    let stageSummary: SleepStageSummary
    let sleepNeeded: SleepNeeded
    let respiratoryRate: Double?
    let sleepPerformancePercentage: Double?
    let sleepConsistencyPercentage: Double?
    let sleepEfficiencyPercentage: Double?

    var performancePercent: Int? {
        guard let perf = sleepPerformancePercentage else { return nil }
        return Int(perf.rounded())
    }

    var efficiencyPercent: Int? {
        guard let eff = sleepEfficiencyPercentage else { return nil }
        return Int(eff.rounded())
    }

    var consistencyPercent: Int? {
        guard let cons = sleepConsistencyPercentage else { return nil }
        return Int(cons.rounded())
    }

    /// Total sleep duration in milliseconds
    var totalSleepMillis: TimeInterval {
        let summary = stageSummary
        return Double(
            summary.totalLightSleepTimeMilli
            + summary.totalSlowWaveSleepTimeMilli
            + summary.totalRemSleepTimeMilli
        )
    }
}

struct SleepStageSummary: Codable, Sendable, Equatable {
    let totalInBedTimeMilli: Int
    let totalAwakeTimeMilli: Int
    let totalNoDataTimeMilli: Int
    let totalLightSleepTimeMilli: Int
    let totalSlowWaveSleepTimeMilli: Int
    let totalRemSleepTimeMilli: Int
    let sleepCycleCount: Int
    let disturbanceCount: Int
}

struct SleepNeeded: Codable, Sendable, Equatable {
    let baselineMilli: Int
    let needFromSleepDebtMilli: Int
    let needFromRecentStrainMilli: Int
    let needFromRecentNapMilli: Int
}
