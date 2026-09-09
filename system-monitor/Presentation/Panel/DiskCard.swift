import SwiftUI

/// One key/value line of the disk card.
nonisolated struct DiskCardRow: Sendable, Equatable, Identifiable {
    let key: String
    let value: String

    var id: String { key }
}

/// Vertical order of the disk card.
///
/// The view derives its `VStack` from `DiskCardModel.sections`, so "there is no
/// history graph and no stacked bar" (DC-2) is an assertion on a pure array
/// rather than a rendering inspection, and the layout cannot drift.
nonisolated enum DiskCardSection: Sendable, Equatable, CaseIterable, Identifiable {
    case header
    case gaugeAndRows
    case throughput

    var id: Self { self }
}

/// Pure derivation of everything the disk card renders.
///
/// Mirrors `MemoryCardModel`: the mapping lives outside `body`, so every
/// disk-card scenario is testable without rendering and the view stays a thin
/// layout. The locale is injected rather than read from the environment.
///
/// Unlike the CPU and memory models this one distinguishes "no reading yet"
/// from "zero": a missing snapshot renders em dashes, never `0%` or `0 B/s`
/// (DC-7, DC-8), because a disk that has not been measured is not an idle disk.
nonisolated enum DiskCardModel {

    /// Card sections top to bottom (DC-2). There is no graph and no bar.
    static let sections: [DiskCardSection] = [.header, .gaugeAndRows, .throughput]

    /// Header glyph, resolved as an SF Symbol by the DC-3 test.
    static let headerSymbolName = "internaldrive"

    /// Footer glyphs. Read points down like a download, write points up, so
    /// the direction is legible without reading the label (design decision 6).
    static let readSymbolName = "arrow.down.doc"
    static let writeSymbolName = "arrow.up.doc"

    /// What an unavailable value renders as, and what is spoken in its place.
    static let unavailableText = "\u{2014}"
    static let unavailableAccessibilityValue = "unavailable"

    private static let usedKey = "Used"
    private static let freeKey = "Free"
    private static let totalKey = "Total"
    private static let readLabel = "Read"
    private static let writeLabel = "Write"

    /// Rows in display order, em dashes before the first reading (DC-4, DC-8).
    static func rows(for snapshot: DiskSnapshot?, locale: Locale = .current) -> [DiskCardRow] {
        let byteValues: [(String, UInt64?)] = [
            (usedKey, snapshot?.used),
            (freeKey, snapshot?.free),
            (totalKey, snapshot?.total)
        ]

        return byteValues.map { key, bytes in
            DiskCardRow(key: key, value: capacityText(bytes, locale: locale))
        }
    }

    /// Gauge value text, an em dash before the first reading (DC-8).
    static func gaugeText(for snapshot: DiskSnapshot?, locale: Locale = .current) -> String {
        guard let snapshot else { return unavailableText }
        return PercentFormatter.oneDecimal(snapshot.fraction, locale: locale)
    }

    /// Gauge fill fraction, zero before the first reading.
    static func gaugeFraction(for snapshot: DiskSnapshot?) -> Double {
        snapshot?.fraction ?? 0
    }

    /// What the gauge announces: its percentage, or "unavailable" while the
    /// ring is empty because nothing has been measured yet (DC-8).
    static func gaugeAccessibilityValue(
        for snapshot: DiskSnapshot?,
        locale: Locale = .current
    ) -> String {
        guard snapshot != nil else { return unavailableAccessibilityValue }
        return gaugeText(for: snapshot, locale: locale)
    }

    /// Footer readings, read then write (DC-7).
    static func throughputReadings(
        for snapshot: DiskSnapshot?,
        locale: Locale = .current
    ) -> [ThroughputReading] {
        [
            reading(
                symbolName: readSymbolName,
                accessibilityLabel: readLabel,
                bytesPerSecond: snapshot?.readBytesPerSecond,
                locale: locale
            ),
            reading(
                symbolName: writeSymbolName,
                accessibilityLabel: writeLabel,
                bytesPerSecond: snapshot?.writeBytesPerSecond,
                locale: locale
            )
        ]
    }

    /// The ring gauge animation, or `nil` under reduced motion (DC-10).
    ///
    /// DC-10 requires the same mechanism and the same animation as the CPU
    /// card, so this delegates rather than repeating the constant, exactly as
    /// `MemoryCardModel` does: the three can never drift apart.
    static func gaugeAnimation(reduceMotion: Bool) -> Animation? {
        CPUCardModel.gaugeAnimation(reduceMotion: reduceMotion)
    }

    /// Decimal capacity string, or the em dash when there is no reading.
    private static func capacityText(_ bytes: UInt64?, locale: Locale) -> String {
        guard let bytes else { return unavailableText }
        return ByteFormatter.capacity(bytes, locale: locale)
    }

    /// One footer reading. The unavailable rate is substituted here rather than
    /// passed to the formatter as a sentinel: `throughput(0)` renders
    /// `"0 B/s"`, which DC-7 forbids for a rate nobody measured.
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

/// The Disk detail card inside the popover (PRD F10, 7.3).
///
/// Presentational: it reads nothing from the environment beyond the reduce
/// motion preference, so a preview or a test can render it from fixed inputs.
/// The vertical order comes from `DiskCardModel.sections`, and there is no
/// history graph and no stacked bar (R10.8).
///
/// The view tree is identical for a `nil` and a populated snapshot — no
/// conditional views, single-line texts of the same size — so the skeleton and
/// the filled card occupy the same height by construction (DC-8) and the
/// popover never resizes when the first reading lands.
struct DiskCard: View {

    /// Latest reading, `nil` before the first capacity read lands.
    let snapshot: DiskSnapshot?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Chrome shared with the CPU and memory cards (DC-9). Internal and
    /// `nonisolated` so the parity is pinned as values by a non-main-actor
    /// test; `MemoryCard`'s equivalents are private and cannot be referenced.
    nonisolated static let cardPadding: CGFloat = 16
    nonisolated static let sectionSpacing: CGFloat = 14
    nonisolated static let rowSpacing: CGFloat = 6
    nonisolated static let headerSpacing: CGFloat = 6
    nonisolated static let headerFontSize: CGFloat = 13
    nonisolated static let footerSpacing: CGFloat = 16

    private var rows: [DiskCardRow] { DiskCardModel.rows(for: snapshot) }

    private var readings: [ThroughputReading] { DiskCardModel.throughputReadings(for: snapshot) }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.sectionSpacing) {
            ForEach(DiskCardModel.sections) { section in
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
    private func section(_ section: DiskCardSection) -> some View {
        switch section {
        case .header: header
        case .gaugeAndRows: gaugeAndRows
        case .throughput: throughputFooter
        }
    }

    private var header: some View {
        HStack(spacing: Self.headerSpacing) {
            Image(systemName: DiskCardModel.headerSymbolName)
                .foregroundStyle(Palette.diskAccent)
            Text("Disk")
                .font(.system(size: Self.headerFontSize, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private var gaugeAndRows: some View {
        HStack(alignment: .top, spacing: Self.sectionSpacing) {
            RingGauge(
                fraction: DiskCardModel.gaugeFraction(for: snapshot),
                color: Palette.diskAccent,
                valueText: DiskCardModel.gaugeText(for: snapshot),
                subtitle: "Disk"
            )
            .equatable()
            .accessibilityValue(DiskCardModel.gaugeAccessibilityValue(for: snapshot))
            .animation(
                DiskCardModel.gaugeAnimation(reduceMotion: reduceMotion),
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

    private var throughputFooter: some View {
        HStack(spacing: Self.footerSpacing) {
            ForEach(readings) { reading in
                ThroughputLabel(reading: reading, color: Palette.diskAccent)
            }
            Spacer(minLength: 0)
        }
    }
}

#Preview("Disk card — boot volume") {
    DiskCard(
        snapshot: DiskSnapshot(
            total: 494_354_000_000,
            free: 62_286_000_000,
            readBytesPerSecond: 27_100_000,
            writeBytesPerSecond: 2_200_000
        )
    )
    .padding(12)
    .frame(width: 320)
    .background(Palette.panelBackground)
}

#Preview("Disk card — no snapshot") {
    DiskCard(snapshot: nil)
        .padding(12)
        .frame(width: 320)
        .background(Palette.panelBackground)
}
