import SwiftUI

struct RecoveryCard: View {
    let recovery: RecoveryRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recovery")
                    .font(.headline)
                Spacer()

                if let score = scoredRecovery {
                    Text(score.recoveryPercent.percentFormatted)
                        .font(.title2.bold())
                        .foregroundStyle(Constants.Recovery.color(for: score.recoveryPercent))
                } else {
                    statusBadge
                }
            }

            if let score = scoredRecovery {
                DetailRow(label: "HRV", value: score.hrvMilliseconds.hrvFormatted)
                DetailRow(label: "Resting HR", value: score.restingHR.bpmFormatted)

                if let spo2 = score.spo2Percent {
                    DetailRow(label: "SpO2", value: spo2.percentFormatted)
                }

                if let temp = score.skinTempCelsius {
                    DetailRow(label: "Skin Temp", value: temp.temperatureFormatted)
                }
            }
        }
    }

    private var scoredRecovery: RecoveryScore? {
        guard let recovery = recovery,
              recovery.scoreState == .scored else {
            return nil
        }
        return recovery.score
    }

    private var statusBadge: some View {
        Group {
            if recovery == nil {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if recovery?.scoreState == .pendingScore {
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }
}
