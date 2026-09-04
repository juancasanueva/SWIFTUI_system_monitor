import SwiftUI

/// One key/value line of the CPU card.
nonisolated struct CPUCardRow: Sendable, Equatable, Identifiable {
    let key: String
    let value: String
    let valueColor: Color

    var id: String { key }
}

/// One titled group of per-core bars.
nonisolated struct CPUCardGroup: Sendable, Equatable, Identifiable {
    let title: String
    let cores: [CoreUsage]
    let color: Color

    var id: String { title }
}

/// Pure derivation of everything the CPU card renders.
///
/// Keeping the mapping out of `body` makes each cpu-card scenario testable
/// without rendering, and keeps the view itself a thin layout.
nonisolated enum CPUCardModel {

    /// Number of history samples the card graph spans.
    static let graphCapacity = 120

    private static let performanceTitle = "P-Cores"
    private static let efficiencyTitle = "E-Cores"
    private static let degradedTitle = "Cores"

    /// Rows in display order. The level rows appear only when the snapshot
    /// carries the matching average (cpu-card "Two rows when levels unknown").
    static func rows(for snapshot: CPUSnapshot?, locale: Locale = .current) -> [CPUCardRow] {
        var rows: [CPUCardRow] = [
            CPUCardRow(
                key: "User",
                value: PercentFormatter.oneDecimal(snapshot?.user ?? 0, locale: locale),
                valueColor: Palette.textPrimary
            ),
            CPUCardRow(
                key: "System",
                value: PercentFormatter.oneDecimal(snapshot?.system ?? 0, locale: locale),
                valueColor: Palette.textPrimary
            )
        ]

        if let performance = snapshot?.performanceAverage {
            rows.append(
                CPUCardRow(
                    key: performanceTitle,
                    value: PercentFormatter.oneDecimal(performance, locale: locale),
                    valueColor: Palette.cpuAccent
                )
            )
        }
        if let efficiency = snapshot?.efficiencyAverage {
            rows.append(
                CPUCardRow(
                    key: efficiencyTitle,
                    value: PercentFormatter.oneDecimal(efficiency, locale: locale),
                    valueColor: Palette.cpuEfficiency
                )
            )
        }

        return rows
    }

    /// Gauge value text, `"0.0%"` before the first snapshot.
    static func gaugeText(for snapshot: CPUSnapshot?, locale: Locale = .current) -> String {
        PercentFormatter.oneDecimal(gaugeFraction(for: snapshot), locale: locale)
    }

    /// Gauge fill fraction, zero before the first snapshot.
    static func gaugeFraction(for snapshot: CPUSnapshot?) -> Double {
        snapshot?.total ?? 0
    }

    /// Bar groups: P then E when the levels are trusted, otherwise a single
    /// `Cores` group (cpu-card "Degraded 'Cores' layout").
    static func groups(for snapshot: CPUSnapshot?) -> [CPUCardGroup] {
        guard let snapshot, !snapshot.cores.isEmpty else { return [] }

        guard snapshot.hasPerformanceLevels else {
            return [
                CPUCardGroup(title: degradedTitle, cores: snapshot.cores, color: Palette.cpuAccent)
            ]
        }

        let candidates = [
            (performanceTitle, PerformanceLevel.performance, Palette.cpuAccent),
            (efficiencyTitle, PerformanceLevel.efficiency, Palette.cpuEfficiency)
        ]

        return candidates.compactMap { title, level, color in
            let cores = snapshot.cores.filter { $0.level == level }
            guard !cores.isEmpty else { return nil }
            return CPUCardGroup(title: title, cores: cores, color: color)
        }
    }

    /// Label under one core bar.
    static func barLabel(for usage: Double) -> String {
        PercentFormatter.integer(usage)
    }

    /// History values for the card graph, oldest first.
    static func graphSamples(for history: MetricHistory) -> [Double] {
        history.suffix(graphCapacity)
    }
}

/// The CPU detail card inside the popover (PRD 7.3).
///
/// Presentational: it reads nothing from the environment beyond the reduce
/// motion preference, so a preview or a test can render it from fixed inputs.
struct CPUCard: View {

    /// Latest reading, `nil` before the first snapshot is published.
    let snapshot: CPUSnapshot?

    /// Recent totals driving the history graph.
    let history: MetricHistory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cardPadding: CGFloat = 16
    private static let sectionSpacing: CGFloat = 14
    private static let rowSpacing: CGFloat = 6
    private static let headerSpacing: CGFloat = 6
    private static let graphHeight: CGFloat = 48
    private static let headerFontSize: CGFloat = 13
    private static let gaugeAnimation = Animation.easeOut(duration: 0.25)

    private var rows: [CPUCardRow] { CPUCardModel.rows(for: snapshot) }
    private var groups: [CPUCardGroup] { CPUCardModel.groups(for: snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            header

            HStack(alignment: .top, spacing: Self.sectionSpacing) {
                RingGauge(
                    fraction: CPUCardModel.gaugeFraction(for: snapshot),
                    color: Palette.cpuAccent,
                    valueText: CPUCardModel.gaugeText(for: snapshot),
                    subtitle: "CPU"
                )
                .equatable()
                .animation(reduceMotion ? nil : Self.gaugeAnimation, value: snapshot?.total)

                VStack(spacing: Self.rowSpacing) {
                    ForEach(rows) { row in
                        KeyValueRow(key: row.key, value: row.value, valueColor: row.valueColor)
                    }
                    Spacer(minLength: 0)
                }
            }

            HistoryGraph(
                samples: CPUCardModel.graphSamples(for: history),
                capacity: CPUCardModel.graphCapacity,
                color: Palette.cpuAccent
            )
            .equatable()
            .frame(height: Self.graphHeight)

            ForEach(groups) { group in
                CoreBarGrid(title: group.title, cores: group.cores, color: group.color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.cardPadding)
        .background(
            Palette.cardBackground,
            in: RoundedRectangle(cornerRadius: Palette.cardCornerRadius)
        )
    }

    private var header: some View {
        HStack(spacing: Self.headerSpacing) {
            Image(systemName: "cpu")
                .foregroundStyle(Palette.cpuAccent)
            Text("CPU")
                .font(.system(size: Self.headerFontSize, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

#Preview("CPU card — Apple Silicon") {
    var history = MetricHistory(capacity: CPUCardModel.graphCapacity)
    for step in 0..<CPUCardModel.graphCapacity {
        history.append(0.45 + 0.35 * sin(Double(step) / 9))
    }

    let cores = (0..<8).map { CoreUsage(index: $0, usage: 0.7, level: .performance) }
        + (8..<12).map { CoreUsage(index: $0, usage: 0.1, level: .efficiency) }

    return CPUCard(
        snapshot: CPUSnapshot(
            total: 0.402,
            user: 0.306,
            system: 0.096,
            performanceAverage: 0.706,
            efficiencyAverage: 0.098,
            cores: cores
        ),
        history: history
    )
    .padding(12)
    .frame(width: 320)
    .background(Palette.panelBackground)
}

#Preview("CPU card — unknown levels") {
    CPUCard(
        snapshot: CPUSnapshot(
            total: 0.21,
            user: 0.15,
            system: 0.06,
            performanceAverage: nil,
            efficiencyAverage: nil,
            cores: (0..<8).map { CoreUsage(index: $0, usage: 0.21, level: .unknown) }
        ),
        history: MetricHistory(capacity: CPUCardModel.graphCapacity)
    )
    .padding(12)
    .frame(width: 320)
    .background(Palette.panelBackground)
}

#Preview("CPU card — no snapshot") {
    CPUCard(snapshot: nil, history: MetricHistory(capacity: CPUCardModel.graphCapacity))
        .padding(12)
        .frame(width: 320)
        .background(Palette.panelBackground)
}
