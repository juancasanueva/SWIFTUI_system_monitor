import SwiftUI

/// One directional throughput reading: an icon, its spoken name and the value
/// already formatted for display.
///
/// Metric-agnostic on purpose, like `LegendEntry`: the card model owns the
/// vocabulary and the formatting and hands over plain strings, so the view
/// cannot invent a unit or a fallback of its own.
nonisolated struct ThroughputReading: Sendable, Equatable, Identifiable {

    /// SF Symbol drawn before the value.
    let symbolName: String

    /// What assistive technology announces for the reading, `"Read"` or
    /// `"Write"`.
    let accessibilityLabel: String

    /// Value text, an em dash when the rate is unavailable (DC-7).
    let text: String

    /// What assistive technology announces instead of the em dash.
    let accessibilityValue: String

    var id: String { accessibilityLabel }
}

/// Icon-then-value footer item used by the disk card (DC-7).
///
/// The icon carries the direction and the colour, the value carries the
/// number; the pair is one accessibility element so VoiceOver reads
/// "Read, 27.1 MB/s" instead of stopping on the glyph.
struct ThroughputLabel: View {

    /// Pre-formatted reading, derived by the card model.
    let reading: ThroughputReading

    /// Accent applied to the icon; the value keeps the primary text colour.
    let color: Color

    /// Layout constants, `nonisolated` so the geometry can be asserted from a
    /// non-main-actor test the way `SegmentLegend`'s are (design decision 5).
    ///
    /// The icon follows `SegmentLegend.labelFontSize` and the value follows
    /// the key/value row size, so the footer reads as the rows' sibling.
    nonisolated static let iconSpacing: CGFloat = 4
    nonisolated static let iconFontSize: CGFloat = 11
    nonisolated static let valueFontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: Self.iconSpacing) {
            Image(systemName: reading.symbolName)
                .font(.system(size: Self.iconFontSize))
                .foregroundStyle(color)
            Text(reading.text)
                .font(.system(size: Self.valueFontSize).monospacedDigit())
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(reading.accessibilityLabel)
        .accessibilityValue(reading.accessibilityValue)
    }
}

#Preview("Throughput labels") {
    HStack(spacing: 16) {
        ThroughputLabel(
            reading: ThroughputReading(
                symbolName: DiskCardModel.readSymbolName,
                accessibilityLabel: "Read",
                text: "27.1 MB/s",
                accessibilityValue: "27.1 MB/s"
            ),
            color: Palette.diskAccent
        )
        ThroughputLabel(
            reading: ThroughputReading(
                symbolName: DiskCardModel.writeSymbolName,
                accessibilityLabel: "Write",
                text: DiskCardModel.unavailableText,
                accessibilityValue: DiskCardModel.unavailableAccessibilityValue
            ),
            color: Palette.diskAccent
        )
        Spacer()
    }
    .padding()
    .frame(width: 296)
    .background(Palette.cardBackground)
}
