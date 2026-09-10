import SwiftUI

/// One key/value line of the network card.
nonisolated struct NetworkCardRow: Sendable, Equatable, Identifiable {
    let key: String
    let value: String

    var id: String { key }
}

/// Vertical order of the network card.
///
/// The view derives its `VStack` from `NetworkCardModel.sections`, so "the
/// graph is last and there is no ring gauge and no stacked bar" (NC-2) is an
/// assertion on a pure array rather than a rendering inspection, and the layout
/// cannot drift.
nonisolated enum NetworkCardSection: Sendable, Equatable, CaseIterable, Identifiable {
    case header
    case ratesAndTotals
    case graph

    var id: Self { self }
}

/// Pure derivation of everything the network card renders.
///
/// Mirrors `DiskCardModel`: the mapping lives outside `body`, so every
/// network-card scenario is testable without rendering and the view stays a
/// thin layout. The locale is injected rather than read from the environment.
///
/// Like the disk model it distinguishes "no reading yet" from "zero": a missing
/// rate renders an em dash, never `0 B/s` (NC-6, NC-7), because a link nobody
/// has measured is not an idle link. The totals are the other way round — they
/// are absolute counters, so a genuine `0` renders as digits.
nonisolated enum NetworkCardModel {

    /// Card sections top to bottom (NC-2). The graph is last.
    static let sections: [NetworkCardSection] = [.header, .ratesAndTotals, .graph]

    /// Visible width of the history graph in samples, shared by both lines.
    static let graphCapacity = 120

    /// Header title. Model-owned rather than typed into the view, per NC-1.
    static let title = "Network"

    /// Header glyph, resolved as an SF Symbol by the NC-3 test.
    static let headerSymbolName = "globe"

    /// Direction glyphs. Filled circles read as badges at 11 pt and differ by
    /// direction, so the reading is legible without its label (decision 6).
    static let downloadSymbolName = "arrow.down.circle.fill"
    static let uploadSymbolName = "arrow.up.circle.fill"

    /// What an unavailable value renders as, and what is spoken in its place.
    static let unavailableText = "\u{2014}"
    static let unavailableAccessibilityValue = "unavailable"

    /// Accent of each reading, in the order `rateReadings` returns them, so the
    /// download badge matches its graph line and the upload badge matches its
    /// own (NC-4).
    ///
    /// It colours the **icon** only. The value text keeps `Palette.textPrimary`,
    /// because the card reuses `ThroughputLabel` exactly as the Disk card's
    /// footer does (DC-7) and reference 4.6 shows the direction on the badge,
    /// not on the digits. Model-owned rather than view-private so the colour
    /// order is assertable without rendering, like every other NC-4 value.
    static let readingColors: [Color] = [
        Palette.networkDownload,
        Palette.networkUpload
    ]

    /// Smallest divisor the shared graph scale may use (decision 6).
    ///
    /// An idle Mac's background chatter sits at hundreds of bytes to a few kB/s.
    /// Without a floor the maximum of an idle window is tiny and that noise
    /// renders as full-scale spikes; 10 kB/s is one order above the chatter and
    /// two below any real transfer, so an idle link draws flat lines while a
    /// 1 MB/s download still reaches the top of the graph.
    static let graphFloorBytesPerSecond: Double = 10_000

    private static let totalInKey = "Total In"
    private static let totalOutKey = "Total Out"
    private static let downloadLabel = "Download"
    private static let uploadLabel = "Upload"

    /// Since-boot totals in display order, em dashes before the first reading
    /// (NC-5, NC-7).
    static func rows(for snapshot: NetworkSnapshot?, locale: Locale = .current) -> [NetworkCardRow] {
        let byteValues: [(String, UInt64?)] = [
            (totalInKey, snapshot?.totalIn),
            (totalOutKey, snapshot?.totalOut)
        ]

        return byteValues.map { key, bytes in
            NetworkCardRow(key: key, value: capacityText(bytes, locale: locale))
        }
    }

    /// Rate readings, download then upload (NC-4, NC-6).
    static func rateReadings(
        for snapshot: NetworkSnapshot?,
        locale: Locale = .current
    ) -> [ThroughputReading] {
        [
            reading(
                symbolName: downloadSymbolName,
                accessibilityLabel: downloadLabel,
                bytesPerSecond: snapshot?.downloadBytesPerSecond,
                locale: locale
            ),
            reading(
                symbolName: uploadSymbolName,
                accessibilityLabel: uploadLabel,
                bytesPerSecond: snapshot?.uploadBytesPerSecond,
                locale: locale
            )
        ]
    }

    /// Divisor both graph lines share, never below the floor (NC-8).
    ///
    /// One scale for both directions is what keeps the two lines comparable: a
    /// 5 kB/s download drawn beside a 78 kB/s upload must read as the smaller
    /// of the two rather than being stretched to the same height.
    static func graphScale(download: [Double], upload: [Double]) -> Double {
        max(download.max() ?? 0, upload.max() ?? 0, graphFloorBytesPerSecond)
    }

    /// Raw bytes per second mapped onto `0...1` by the shared scale (NC-8).
    ///
    /// `scale` is at least the largest sample, so every result already lands in
    /// range; `SparklineGeometry` clamps again downstream.
    static func normalised(_ samples: [Double], scale: Double) -> [Double] {
        guard scale > 0 else { return samples.map { _ in 0 } }
        return samples.map { $0 / scale }
    }

    /// The two graph lines, download first so it is drawn underneath (NC-8).
    ///
    /// Both histories are appended in the same main-actor call, so they hold
    /// the same number of samples and the two series come back equal in length.
    /// Neither line is filled: the mockup shows two bare strokes, and
    /// overlapping areas would muddy the point where they cross.
    static func graphSeries(
        download: MetricHistory,
        upload: MetricHistory
    ) -> [HistoryGraphSeries] {
        let downloadSamples = download.suffix(graphCapacity)
        let uploadSamples = upload.suffix(graphCapacity)
        let scale = graphScale(download: downloadSamples, upload: uploadSamples)

        return [
            HistoryGraphSeries(
                samples: normalised(downloadSamples, scale: scale),
                color: Palette.networkDownload,
                fillOpacity: 0
            ),
            HistoryGraphSeries(
                samples: normalised(uploadSamples, scale: scale),
                color: Palette.networkUpload,
                fillOpacity: 0
            )
        ]
    }

    /// The card's animation, or `nil` under reduced motion (NC-13).
    ///
    /// NC-13 requires the same mechanism and the same animation as the CPU
    /// card, so this delegates rather than repeating the constant, exactly as
    /// `DiskCardModel.gaugeAnimation` does: the four can never drift apart.
    static func animation(reduceMotion: Bool) -> Animation? {
        CPUCardModel.gaugeAnimation(reduceMotion: reduceMotion)
    }

    /// Decimal capacity string, or the em dash when there is no reading.
    private static func capacityText(_ bytes: UInt64?, locale: Locale) -> String {
        guard let bytes else { return unavailableText }
        return ByteFormatter.capacity(bytes, locale: locale)
    }

    /// One rate reading. The unavailable rate is substituted here rather than
    /// passed to the formatter as a sentinel: `throughput(0)` renders
    /// `"0 B/s"`, which NC-6 forbids for a rate nobody measured.
    private static func reading(
        symbolName: String,
        accessibilityLabel: String,
        bytesPerSecond: Double?,
        locale: Locale
    ) -> ThroughputReading {
        guard let bytesPerSecond else {
            return ThroughputReading(
                symbolName: symbolName,
                accessibilityLabel: accessibilityLabel,
                text: unavailableText,
                accessibilityValue: unavailableAccessibilityValue
            )
        }

        let text = ByteFormatter.throughput(bytesPerSecond, locale: locale)
        return ThroughputReading(
            symbolName: symbolName,
            accessibilityLabel: accessibilityLabel,
            text: text,
            accessibilityValue: text
        )
    }
}

/// The Network detail card inside the popover (PRD F11, 7.3).
///
/// Presentational: it reads nothing from the environment beyond the reduce
/// motion preference, so a preview or a test can render it from fixed inputs.
/// The vertical order comes from `NetworkCardModel.sections`, so the history
/// graph is last and there is no ring gauge and no stacked bar (NC-2).
///
/// The view tree is identical for a `nil` and a populated snapshot — no
/// conditional views, single-line texts of the same size — so the skeleton and
/// the filled card occupy the same height by construction (NC-7) and the
/// popover never resizes when the first reading lands.
struct NetworkCard: View {

    /// Latest reading, `nil` before the first counter read lands.
    let snapshot: NetworkSnapshot?

    /// Download rates in raw bytes per second, oldest first.
    let downloadHistory: MetricHistory

    /// Upload rates over the same windows.
    let uploadHistory: MetricHistory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Chrome shared with the CPU, memory and disk cards (NC-10). Internal and
    /// `nonisolated` so the parity is pinned as values by a non-main-actor
    /// test, exactly as `DiskCard`'s equivalents are.
    nonisolated static let cardPadding: CGFloat = 16
    nonisolated static let sectionSpacing: CGFloat = 14
    nonisolated static let rowSpacing: CGFloat = 6
    nonisolated static let headerSpacing: CGFloat = 6
    nonisolated static let headerFontSize: CGFloat = 13
    nonisolated static let graphHeight: CGFloat = 48

    private var readings: [(reading: ThroughputReading, color: Color)] {
        zip(NetworkCardModel.rateReadings(for: snapshot), NetworkCardModel.readingColors)
            .map { ($0, $1) }
    }

    private var rows: [NetworkCardRow] { NetworkCardModel.rows(for: snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            ForEach(NetworkCardModel.sections) { section in
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
    private func section(_ section: NetworkCardSection) -> some View {
        switch section {
        case .header: header
        case .ratesAndTotals: ratesAndTotals
        case .graph: graph
        }
    }

    private var header: some View {
        HStack(spacing: Self.headerSpacing) {
            Image(systemName: NetworkCardModel.headerSymbolName)
                .foregroundStyle(Palette.networkAccent)
            Text(NetworkCardModel.title)
                .font(.system(size: Self.headerFontSize, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    /// Rates on the left, since-boot totals on the right.
    ///
    /// Both columns are single-line 12 pt rows, so they align without a fixed
    /// height. Nothing in this section animates today — the texts are single
    /// lines and the graph redraws immediately — but the animation still comes
    /// from `NetworkCardModel` so a future animated element inherits the shared
    /// reduce-motion rule rather than inventing one (NC-13, decision 11).
    private var ratesAndTotals: some View {
        HStack(alignment: .top, spacing: Self.sectionSpacing) {
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                ForEach(readings, id: \.reading.id) { reading, color in
                    ThroughputLabel(reading: reading, color: color)
                }
                Spacer(minLength: 0)
            }

            VStack(spacing: Self.rowSpacing) {
                ForEach(rows) { row in
                    KeyValueRow(key: row.key, value: row.value)
                }
                Spacer(minLength: 0)
            }
        }
        .animation(NetworkCardModel.animation(reduceMotion: reduceMotion), value: snapshot)
    }

    private var graph: some View {
        HistoryGraph(
            series: NetworkCardModel.graphSeries(
                download: downloadHistory,
                upload: uploadHistory
            ),
            capacity: NetworkCardModel.graphCapacity
        )
        .equatable()
        .frame(height: Self.graphHeight)
    }
}

#Preview("Network card — reference reading") {
    var download = MetricHistory(capacity: NetworkCardModel.graphCapacity)
    var upload = MetricHistory(capacity: NetworkCardModel.graphCapacity)
    for step in 0..<NetworkCardModel.graphCapacity {
        download.append(5_000 + 3_000 * sin(Double(step) / 9))
        upload.append(78_000 + 20_000 * cos(Double(step) / 11))
    }

    return NetworkCard(
        snapshot: NetworkSnapshot(
            totalIn: 3_850_000_000,
            totalOut: 2_760_000_000,
            downloadBytesPerSecond: 5_000,
            uploadBytesPerSecond: 78_000
        ),
        downloadHistory: download,
        uploadHistory: upload
    )
    .padding()
    .frame(width: 296)
    .background(Palette.panelBackground)
}

#Preview("Network card — no reading yet") {
    NetworkCard(
        snapshot: nil,
        downloadHistory: MetricHistory(capacity: NetworkCardModel.graphCapacity),
        uploadHistory: MetricHistory(capacity: NetworkCardModel.graphCapacity)
    )
    .padding()
    .frame(width: 296)
    .background(Palette.panelBackground)
}
