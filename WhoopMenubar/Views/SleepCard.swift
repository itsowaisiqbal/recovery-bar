import SwiftUI

struct SleepCard: View {
    let sleep: SleepRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Sleep")
                    .font(.headline)
                Spacer()

                if let score = scoredSleep {
                    Text(score.totalSleepMillis.sleepDurationFormatted)
                        .font(.title2.bold())
                        .foregroundStyle(.purple)
                } else {
                    statusBadge
                }
            }

            if let score = scoredSleep {
                if let performance = score.performancePercent {
                    DetailRow(label: "Performance", value: performance.percentFormatted)
                }
                if let efficiency = score.efficiencyPercent {
                    DetailRow(label: "Efficiency", value: efficiency.percentFormatted)
                }
                if let consistency = score.consistencyPercent {
                    DetailRow(label: "Consistency", value: consistency.percentFormatted)
                }
                if let respRate = score.respiratoryRate {
                    DetailRow(label: "Resp. Rate", value: String(format: "%.1f rpm", respRate))
                }
            }
        }
    }

    private var scoredSleep: SleepScore? {
        guard let sleep = sleep,
              sleep.scoreState == .scored else {
            return nil
        }
        return sleep.score
    }

    private var statusBadge: some View {
        Group {
            if sleep == nil {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
