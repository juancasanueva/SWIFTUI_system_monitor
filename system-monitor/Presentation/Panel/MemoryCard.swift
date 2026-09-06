import SwiftUI

/// One key/value line of the memory card.
nonisolated struct MemoryCardRow: Sendable, Equatable, Identifiable {
    let key: String
    let value: String

    var id: String { key }
}

/// One slice of the memory stacked bar, in drawing order.
///
/// `unattributed` is the part of Used that App, Wired and Compressed do not
/// name (kernel allocations Activity Monitor also folds into Used). It is drawn
/// in the App colour and carries no legend entry, so every labelled segment
/// stays proportional to the value it names.
nonisolated enum MemorySegmentKind: Sendable, Hashable, CaseIterable {
    case app
    case unattributed
    case wired
    case compressed
    case cached
    case free
}

/// One measured slice of the memory stacked bar.
nonisolated struct MemorySegment: Sendable, Equatable, Identifiable {
    let kind: MemorySegmentKind
    let bytes: UInt64
    let fraction: Double
    let color: Color

    var id: MemorySegmentKind { kind }
}

/// Vertical order of the memory card.
///
/// The view derives its `VStack` from `MemoryCardModel.sections`, so "the graph
/// sits at the bottom" is an assertion on a pure array rather than a rendering
/// inspection, and the layout cannot drift from the model.
nonisolated enum MemoryCardSection: Sendable, Equatable, CaseIterable, Identifiable {
    case header
    case gaugeAndRows
    case stackedBar
    case legend
    case graph

    var id: Self { self }
}

/// Pure derivation of everything the memory card renders.
///
/// Mirrors `CPUCardModel`: the mapping lives outside `body`, so every
/// memory-card scenario is testable without rendering and the view stays a thin
/// layout. The locale is injected rather than read from the environment.
nonisolated enum MemoryCardModel {

    /// Number of history samples the card graph spans.
    static let graphCapacity = 120

    /// Card sections top to bottom; the history graph is last (PRD 4.3).
    static let sections: [MemoryCardSection] = [
        .header,
        .gaugeAndRows,
        .stackedBar,
        .legend,
        .graph
    ]

    /// Colour key under the bar. `unattributed` is deliberately absent: it
    /// shares the App colour and naming it would invent a component the
    /// product palette does not define.
    static let legend: [LegendEntry] = [
        LegendEntry(label: "App", color: color(for: .app)),
        LegendEntry(label: "Wired", color: color(for: .wired)),
        LegendEntry(label: "Compressed", color: color(for: .compressed)),
        LegendEntry(label: "Cached", color: color(for: .cached)),
        LegendEntry(label: "Free", color: color(for: .free))
    ]

    /// Rows in display order, reading zero bytes before the first snapshot.
    static func rows(for snapshot: MemorySnapshot?, locale: Locale = .current) -> [MemoryCardRow] {
        [
            MemoryCardRow(key: "Used", value: ByteFormatter.memory(snapshot?.used ?? 0, locale: locale)),
            MemoryCardRow(key: "Total", value: ByteFormatter.memory(snapshot?.total ?? 0, locale: locale)),
            MemoryCardRow(key: "Wired", value: ByteFormatter.memory(snapshot?.wired ?? 0, locale: locale)),
            MemoryCardRow(
                key: "Compressed",
                value: ByteFormatter.memory(snapshot?.compressed ?? 0, locale: locale)
            )
        ]
    }

    /// Gauge value text, `"0.0%"` before the first snapshot.
    static func gaugeText(for snapshot: MemorySnapshot?, locale: Locale = .current) -> String {
        PercentFormatter.oneDecimal(gaugeFraction(for: snapshot), locale: locale)
    }

    /// Gauge fill fraction, zero before the first snapshot.
    static func gaugeFraction(for snapshot: MemorySnapshot?) -> Double {
        snapshot?.fraction ?? 0
    }

    /// Bar segments left to right, or an empty bar when there is nothing to
    /// split. The byte values sum to Total whenever `used` did not saturate.
    static func segments(for snapshot: MemorySnapshot?) -> [MemorySegment] {
        guard let snapshot, snapshot.total > 0 else { return [] }

        let byteValues: [(MemorySegmentKind, UInt64)] = [
            (.app, snapshot.app),
            (.unattributed, snapshot.unattributedUsed),
            (.wired, snapshot.wired),
            (.compressed, snapshot.compressed),
            (.cached, snapshot.cached),
            (.free, snapshot.free)
        ]

        let total = Double(snapshot.total)
        return byteValues.map { kind, bytes in
            MemorySegment(
                kind: kind,
                bytes: bytes,
                fraction: Double(bytes) / total,
                color: color(for: kind)
            )
        }
    }

    /// Palette token for one segment kind.
    static func color(for kind: MemorySegmentKind) -> Color {
        switch kind {
        case .app, .unattributed: Palette.memAccent
        case .wired: Palette.memWired
        case .compressed: Palette.memCompressed
        case .cached: Palette.memCached
        case .free: Palette.memFree
        }
    }

    /// History values for the card graph, oldest first.
    static func graphSamples(for history: MetricHistory) -> [Double] {
        history.suffix(graphCapacity)
    }

    /// The ring gauge animation, or `nil` under reduced motion (MC-10).
    ///
    /// MC-10 requires the same mechanism and the same animation as the CPU
    /// card, so this delegates rather than repeating the constant: the two can
    /// never drift apart.
    static func gaugeAnimation(reduceMotion: Bool) -> Animation? {
        CPUCardModel.gaugeAnimation(reduceMotion: reduceMotion)
    }
}

/// The Memory detail card inside the popover (PRD 4.3, 7.3).
///
/// Presentational: it reads nothing from the environment beyond the reduce
/// motion preference, so a preview or a test can render it from fixed inputs.
/// The vertical order comes from `MemoryCardModel.sections`, with the history
/// graph last.
struct MemoryCard: View {

    /// Latest reading, `nil` before the first snapshot is published.
    let snapshot: MemorySnapshot?

    /// Recent used fractions driving the history graph.
    let history: MetricHistory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let cardPadding: CGFloat = 16
    private static let sectionSpacing: CGFloat = 14
    private static let rowSpacing: CGFloat = 6
    private static let headerSpacing: CGFloat = 6
    private static let barHeight: CGFloat = 8
    private static let graphHeight: CGFloat = 48
    private static let headerFontSize: CGFloat = 13

    private var rows: [MemoryCardRow] { MemoryCardModel.rows(for: snapshot) }

    private var barSegments: [StackedBar.Segment] {
        MemoryCardModel.segments(for: snapshot).map {
            StackedBar.Segment(fraction: $0.fraction, color: $0.color)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            ForEach(MemoryCardModel.sections) { section in
                self.section(section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Self.cardPadding)
        .background(
            Palette.cardBackground,
            in: RoundedRectangle(cornerRadius: Palette.cardCornerRadius)
        )
    }

    @ViewBuilder
    private func section(_ section: MemoryCardSection) -> some View {
        switch section {
        case .header: header
        case .gaugeAndRows: gaugeAndRows
        case .stackedBar: StackedBar(segments: barSegments).equatable().frame(height: Self.barHeight)
        case .legend: SegmentLegend(entries: MemoryCardModel.legend)
        case .graph:
            HistoryGraph(
                samples: MemoryCardModel.graphSamples(for: history),
                capacity: MemoryCardModel.graphCapacity,
                color: Palette.memAccent
            )
            .equatable()
            .frame(height: Self.graphHeight)
        }
    }

    private var header: some View {
        HStack(spacing: Self.headerSpacing) {
            Image(systemName: "memorychip")
                .foregroundStyle(Palette.memAccent)
            Text("Memory")
                .font(.system(size: Self.headerFontSize, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var gaugeAndRows: some View {
        HStack(alignment: .top, spacing: Self.sectionSpacing) {
            RingGauge(
                fraction: MemoryCardModel.gaugeFraction(for: snapshot),
                color: Palette.memAccent,
                valueText: MemoryCardModel.gaugeText(for: snapshot),
                subtitle: "RAM"
            )
            .equatable()
            .animation(
                MemoryCardModel.gaugeAnimation(reduceMotion: reduceMotion),
                value: snapshot?.fraction
            )

            VStack(spacing: Self.rowSpacing) {
                ForEach(rows) { row in
                    KeyValueRow(key: row.key, value: row.value)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

#Preview("Memory card — 8 GiB machine") {
    var history = MetricHistory(capacity: MemoryCardModel.graphCapacity)
    for step in 0..<MemoryCardModel.graphCapacity {
        history.append(0.62 + 0.08 * sin(Double(step) / 9))
    }

    return MemoryCard(
        snapshot: MemorySnapshot(
            total: 8_589_934_592,
            app: 1_460_961_280,
            wired: 1_986_560_000,
            compressed: 1_954_283_520,
            cached: 901_120_000,
            free: 1_762_721_792,
            used: 5_926_092_800
        ),
        history: history
    )
    .padding(12)
    .frame(width: 320)
    .background(Palette.panelBackground)
}

#Preview("Memory card — no snapshot") {
    MemoryCard(snapshot: nil, history: MetricHistory(capacity: MemoryCardModel.graphCapacity))
        .padding(12)
        .frame(width: 320)
        .background(Palette.panelBackground)
}
