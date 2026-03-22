import SwiftUI

struct StrainCard: View {
    let cycle: CycleRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Strain")
                    .font(.headline)
                Spacer()

                if let score = scoredCycle {
                    Text(score.strain.strainFormatted)
                        .font(.title2.bold())
                        .foregroundStyle(.blue)
                } else {
                    statusBadge
                }
            }

            if let score = scoredCycle {
                DetailRow(label: "Calories", value: score.caloriesKcal.caloriesFormatted)
                DetailRow(label: "Max HR", value: score.maxHeartRate.bpmFormatted)
                DetailRow(label: "Avg HR", value: score.averageHeartRate.bpmFormatted)
            }
        }
    }

    private var scoredCycle: CycleScore? {
        guard let cycle = cycle,
              cycle.scoreState == .scored else {
            return nil
        }
        return cycle.score
    }

    private var statusBadge: some View {
        Group {
            if cycle == nil {
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
