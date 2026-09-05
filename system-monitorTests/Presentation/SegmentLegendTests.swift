import AppKit
import SwiftUI
import Testing
@testable import system_monitor

// memory-card — MC-6 "Legend entries".
//
// The legend must wrap by whole entry. Five entries do not fit on one row at
// the width the memory card gives them, and the running app broke the labels
// inside the word instead ("Compre / ssed", "Cache / d"). These tests pin the
// rendered geometry: exactly two rows, each one text line tall.
@Suite("Segment legend layout")
struct SegmentLegendTests {

    private static let entries = MemoryCardModel.legend

    /// Width the legend actually gets on screen: the 296 pt card inside the
    /// 320 pt panel, minus the memory card's 16 pt padding on each side.
    private static let contentWidth: CGFloat = 264

    @MainActor
    private static func idealSize(of view: some View) -> CGSize {
        let hostingView = NSHostingView(rootView: view)
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    @MainActor
    private static func size(of view: some View, width: CGFloat) -> CGSize {
        let hostingView = NSHostingView(rootView: view.frame(width: width))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    /// Width one entry needs to render its dot and its label on a single line.
    @MainActor
    private static func idealEntryWidth(for label: String) -> CGFloat {
        let text = Text(label).font(.system(size: SegmentLegend.labelFontSize))
        return SegmentLegend.dotSize + SegmentLegend.dotSpacing + idealSize(of: text).width
    }

    @MainActor
    private static func idealSingleRowWidth() -> CGFloat {
        let entriesWidth = entries.reduce(CGFloat.zero) { $0 + idealEntryWidth(for: $1.label) }
        return entriesWidth + SegmentLegend.entrySpacing * CGFloat(entries.count - 1)
    }

    // memory-card — MC-6: the wrap is real, not hypothetical. If the labels
    // ever shrink enough to share one row this test tells us the two-row
    // expectation below stopped describing the card.
    @Test func theFiveEntriesCannotShareOneRowAtTheCardWidth() async {
        let needed = await Self.idealSingleRowWidth()

        #expect(
            needed > Self.contentWidth,
            "one row now fits: \(needed) pt of entries in \(Self.contentWidth) pt"
        )
    }

    // memory-card — MC-6: two rows of single-line entries. The lower bound
    // fails when the legend stays on one row and squeezes its labels; the
    // upper bound fails when any label breaks across lines, because a wrapped
    // row is two text lines tall.
    @Test func theLegendFillsExactlyTwoSingleLineRowsAtTheCardWidth() async {
        let legend = SegmentLegend(entries: Self.entries)
        let oneEntry = SegmentLegend(entries: Array(Self.entries.prefix(1)))

        let rowHeight = await Self.size(of: oneEntry, width: Self.contentWidth).height
        let measured = await Self.size(of: legend, width: Self.contentWidth).height
        let twoRows = rowHeight * 2 + SegmentLegend.rowSpacing

        #expect(
            measured >= twoRows - 0.5,
            "the legend is not wrapping by entry: \(measured) pt against \(twoRows) pt for two rows of \(rowHeight) pt"
        )
        #expect(
            measured <= twoRows + 0.5,
            "a label is breaking across lines: \(measured) pt against \(twoRows) pt"
        )
    }

    // memory-card — MC-6: a legend that fits keeps its single row, so the card
    // does not grow a second row it does not need.
    @Test func aLegendThatFitsStaysOnOneRow() async {
        let short = SegmentLegend(entries: Array(Self.entries.prefix(2)))
        let oneEntry = SegmentLegend(entries: Array(Self.entries.prefix(1)))

        let rowHeight = await Self.size(of: oneEntry, width: Self.contentWidth).height
        let measured = await Self.size(of: short, width: Self.contentWidth).height

        #expect(measured == rowHeight, "\(measured) pt against a single row of \(rowHeight) pt")
    }
}
