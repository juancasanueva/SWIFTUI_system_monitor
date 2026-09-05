import SwiftUI

/// One labelled colour of a stacked bar.
nonisolated struct LegendEntry: Sendable, Equatable, Identifiable {
    let label: String
    let color: Color

    var id: String { label }
}

/// Colour key placed under a `StackedBar`.
///
/// Metric-agnostic on purpose: the card model owns the vocabulary and hands
/// over plain labels and colours.
///
/// Labels never break inside a word: each one is a single fixed-size line, so
/// the legend wraps by whole entry instead. `ViewThatFits` keeps everything on
/// one row while the row fits the offered width and falls back to two rows
/// when it does not, preserving the entry order in both layouts.
struct SegmentLegend: View {

    /// Entries in the same order as the bar segments they describe.
    let entries: [LegendEntry]

    /// Layout constants, `nonisolated` so the geometry can be asserted from a
    /// non-main-actor test the way the other pure presentation values are.
    nonisolated static let entrySpacing: CGFloat = 10
    nonisolated static let rowSpacing: CGFloat = 6
    nonisolated static let dotSpacing: CGFloat = 4
    nonisolated static let dotSize: CGFloat = 8
    nonisolated static let labelFontSize: CGFloat = 11

    /// Entries kept on the first row when the legend wraps, so a five-entry
    /// legend reads three then two rather than four then one.
    private var splitIndex: Int { (entries.count + 1) / 2 }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(entries)
            VStack(alignment: .leading, spacing: Self.rowSpacing) {
                row(Array(entries.prefix(splitIndex)))
                row(Array(entries.dropFirst(splitIndex)))
            }
        }
    }

    private func row(_ entries: [LegendEntry]) -> some View {
        HStack(spacing: Self.entrySpacing) {
            ForEach(entries) { entry in
                HStack(spacing: Self.dotSpacing) {
                    Circle()
                        .fill(entry.color)
                        .frame(width: Self.dotSize, height: Self.dotSize)
                    Text(entry.label)
                        .font(.system(size: Self.labelFontSize))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

#Preview("Segment legend") {
    SegmentLegend(entries: [
        LegendEntry(label: "App", color: Palette.memAccent),
        LegendEntry(label: "Wired", color: Palette.memWired),
        LegendEntry(label: "Compressed", color: Palette.memCompressed),
        LegendEntry(label: "Cached", color: Palette.memCached),
        LegendEntry(label: "Free", color: Palette.memFree)
    ])
    .padding()
    .frame(width: 296)
    .background(Palette.cardBackground)
}
