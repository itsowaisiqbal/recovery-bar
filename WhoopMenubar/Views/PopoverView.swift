import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            if showSettings {
                SettingsView(isShowing: $showSettings)
                    .environmentObject(appState)
            } else {
                mainContent
            }
        }
        .onAppear {
            if appState.authManager.state == .signedIn {
                appState.startSync()
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 20) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 20)

            // Three score sections — info left, ring right
            VStack(spacing: 18) {
                recoverySection
                strainSection
                sleepSection
            }
            .padding(.horizontal, 20)

            // Activities
            if hasActivities {
                activitiesSection
                    .padding(.horizontal, 20)
            }

            // Body measurements (v1 endpoint — not available in v2)
            if let body = appState.bodyMeasurement {
                bodySection(body)
                    .padding(.horizontal, 20)
            }

            footer
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
        .frame(width: WhoopSpacing.popoverWidth)
    }

    // MARK: - Recovery

    private var recoverySection: some View {
        HStack(alignment: .center, spacing: 14) {
            // Left: label + sub-metrics
            VStack(alignment: .leading, spacing: 6) {
                Text("RECOVERY")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                if let recovery = appState.recovery, recovery.scoreState == .scored, let score = recovery.score {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ], spacing: 8) {
                        subMetric("HRV", score.hrvMilliseconds.hrvFormatted)
                        subMetric("RHR", score.restingHR.bpmFormatted)
                        if let spo2 = score.spo2Percent {
                            subMetric("SpO2", spo2.percentFormatted)
                        }
                        if let temp = score.skinTempCelsius {
                            subMetric("Temp", temp.temperatureFormatted)
                        }
                    }
                }
            }

            Spacer()

            // Right: radial ring with score inside
            if let score = appState.recoveryScore {
                ScoreRing(
                    value: "\(score)%",
                    progress: Double(score) / 100.0,
                    color: Constants.Recovery.color(for: score),
                    size: 64
                )
            } else {
                ScoreRing(value: "--", progress: 0, color: .gray, size: 64)
            }
        }
    }

    // MARK: - Strain

    private var strainSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("STRAIN")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                if let cycle = appState.cycle, cycle.scoreState == .scored, let score = cycle.score {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ], spacing: 8) {
                        subMetric("Calories", score.caloriesKcal.caloriesFormatted)
                        subMetric("Max HR", score.maxHeartRate.bpmFormatted)
                        subMetric("Avg HR", score.averageHeartRate.bpmFormatted)
                    }
                }
            }

            Spacer()

            if let cycle = appState.cycle, cycle.scoreState == .scored, let score = cycle.score {
                ScoreRing(
                    value: score.strain.strainFormatted,
                    progress: score.strain / Constants.Strain.maxStrain,
                    color: Constants.Brand.strain,
                    size: 64
                )
            } else {
                ScoreRing(value: "--", progress: 0, color: .gray, size: 64)
            }
        }
    }

    // MARK: - Sleep

    private var sleepSection: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("SLEEP")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)

                if let sleep = appState.sleep, sleep.scoreState == .scored, let score = sleep.score {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ], spacing: 8) {
                        if let eff = score.efficiencyPercent {
                            subMetric("Efficiency", eff.percentFormatted)
                        }
                        if let cons = score.consistencyPercent {
                            subMetric("Consistency", cons.percentFormatted)
                        }
                        if let rr = score.respiratoryRate {
                            subMetric("Resp Rate", String(format: "%.1f", rr))
                        }
                    }
                }
            }

            Spacer()

            if let sleep = appState.sleep, sleep.scoreState == .scored, let score = sleep.score {
                ScoreRing(
                    value: score.performancePercent.map { "\($0)%" } ?? "--",
                    progress: Double(score.performancePercent ?? 0) / 100.0,
                    color: Constants.Brand.sleep,
                    size: 64
                )
            } else {
                ScoreRing(value: "--", progress: 0, color: .gray, size: 64)
            }
        }
    }

    // MARK: - Sub-Metric Cell

    private func subMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased())
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Activities

    // MARK: - Activities

    private var hasActivities: Bool {
        let hasSleep = appState.sleep?.scoreState == .scored
        let hasNaps = !appState.naps.isEmpty
        let hasWorkouts = !appState.dayWorkouts.isEmpty
        return hasSleep || hasNaps || hasWorkouts
    }

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACTIVITY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(spacing: 6) {
                // Main sleep
                if let sleep = appState.sleep, sleep.scoreState == .scored, let score = sleep.score {
                    activityRow(
                        name: "Sleep",
                        value: score.totalSleepMillis.sleepDurationFormatted,
                        time: "\(sleep.start.shortTimeString) – \(sleep.end.shortTimeString)",
                        color: Constants.Brand.sleep
                    )
                }

                // Naps
                ForEach(appState.naps) { nap in
                    if nap.scoreState == .scored, let score = nap.score {
                        activityRow(
                            name: "Nap",
                            value: score.totalSleepMillis.sleepDurationFormatted,
                            time: "\(nap.start.shortTimeString) – \(nap.end.shortTimeString)",
                            color: Constants.Brand.sleep.opacity(0.7)
                        )
                    }
                }

                // Workouts
                ForEach(appState.dayWorkouts) { workout in
                    if workout.scoreState == .scored, let score = workout.score {
                        activityRow(
                            name: workout.sportName?.capitalized ?? "Activity",
                            value: score.strain.strainFormatted,
                            time: "\(workout.start.shortTimeString) – \(workout.end.shortTimeString)",
                            color: Constants.Brand.strain
                        )
                    }
                }
            }
        }
    }

    private func activityRow(name: String, value: String, time: String, color: Color) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 60, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(color)

            Spacer()

            Text(time)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .modifier(GlassBackground(cornerRadius: 10))
    }

    // MARK: - Body Measurements

    private func bodySection(_ body: BodyMeasurement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BODY")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)

            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 8) {
                if let height = body.heightFormatted {
                    subMetric("Height", height)
                }
                if let weight = body.weightFormatted {
                    subMetric("Weight", weight)
                }
                if let maxHR = body.maxHeartRate {
                    subMetric("Max HR", "\(maxHR) bpm")
                }
            }
        }
    }

    // MARK: - Header & Footer

    private var header: some View {
        HStack {
            if let profile = appState.profile {
                Text("Hi, \(profile.firstName)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            Spacer()
            HStack(spacing: 4) {
                HeaderButton(icon: "gear", action: { showSettings.toggle() })
                HeaderButton(
                    icon: appState.isLoading ? nil : "arrow.clockwise",
                    isLoading: appState.isLoading,
                    action: { Task { await appState.refresh() } }
                )
                .disabled(appState.isLoading)
            }
        }
    }

    private var footer: some View {
        HStack {
            if let lastUpdated = appState.lastUpdated {
                Text("Updated \(lastUpdated.relativeString)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            HStack(spacing: 5) {
                Text("DATA BY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(1)
                Image("WhoopWordmark")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 12)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Score Ring

/// Radial progress ring with score value centered inside
struct ScoreRing: View {
    let value: String
    let progress: Double
    let color: Color
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let lineWidth: CGFloat = 5

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Fill
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: progress)

            // Score text
            Text(value)
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Header Button

struct HeaderButton: View {
    let icon: String?
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Constants.Brand.teal)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(isHovered ? .primary : .secondary)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
