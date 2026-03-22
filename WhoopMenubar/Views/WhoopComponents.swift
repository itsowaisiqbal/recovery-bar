import SwiftUI

// MARK: - Design Constants

enum WhoopSpacing {
    static let cardPadding: CGFloat = 16
    static let cardGap: CGFloat = 8
    static let sectionGap: CGFloat = 12
    static let outerPadding: CGFloat = 16
    static let gaugeSize: CGFloat = 64
    static let popoverWidth: CGFloat = 340
}

// MARK: - Glass Card Container

/// Liquid Glass card — uses .glassEffect() on macOS 26+, falls back to .thinMaterial
struct GlassCard<Content: View>: View {
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(GlassBackground(cornerRadius: 14))
    }
}

// MARK: - Glass Background Modifier

/// Applies Liquid Glass on macOS 26+, .regularMaterial on older
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                )
        }
    }
}

/// Interactive glass background (responds to hover/touch on macOS 26+)
struct InteractiveGlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 16
    var isActive: Bool = false

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content
                .glassEffect(
                    .regular.interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
        } else {
            content
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            isActive
                                ? Color.primary.opacity(0.2)
                                : Color.primary.opacity(0.1),
                            lineWidth: 0.5
                        )
                )
        }
    }
}

// MARK: - Legacy Card (alias)

typealias WhoopCard = GlassCard

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .tracking(1.5)
    }
}

// MARK: - Metric Display

struct MetricCell: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }
}

struct MetricsRow: View {
    let metrics: [(label: String, value: String, color: Color)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                MetricCell(label: metric.label, value: metric.value, color: metric.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Pending State

func pendingState(title: String, state: ScoreState?) -> some View {
    HStack {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: title)

            if let state = state {
                switch state {
                case .pendingScore:
                    Text("Processing...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Constants.Brand.teal)
                case .unscorable:
                    Text("Unscorable")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                case .scored:
                    EmptyView()
                }
            } else {
                Text("No data yet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        Spacer()
    }
}
