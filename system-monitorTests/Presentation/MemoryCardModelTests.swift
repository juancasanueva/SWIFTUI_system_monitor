import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import system_monitor

// memory-card — "Header and ring gauge", "Key/value rows", "Stacked bar",
// "Legend", "History graph at the bottom", "No-snapshot placeholder"
@Suite("Memory card presentation model")
struct MemoryCardModelTests {

    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    /// Non-breaking spaces are locale-legal inside byte strings (MC-2).
    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private static func snapshot(
        total: UInt64,
        app: UInt64 = 0,
        wired: UInt64 = 0,
        compressed: UInt64 = 0,
        cached: UInt64 = 0,
        free: UInt64 = 0,
        used: UInt64
    ) -> MemorySnapshot {
        MemorySnapshot(
            total: total,
            app: app,
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: free,
            used: used
        )
    }

    private static func history(_ values: [Double]) -> MetricHistory {
        var history = MetricHistory(capacity: MemoryCardModel.graphCapacity)
        for value in values {
            history.append(value)
        }
        return history
    }

    // MARK: - MC-3 Header and ring gauge

    // memory-card — "One-decimal gauge"
    @Test(arguments: zip(
        [UInt64(690), UInt64(1_000), UInt64(0)],
        ["69.0%", "100.0%", "0.0%"]
    ))
    func theGaugeShowsOneFractionDigit(used: UInt64, expected: String) {
        let reading = Self.snapshot(total: 1_000, used: used)

        #expect(MemoryCardModel.gaugeText(for: reading, locale: Self.english) == expected)
    }

    // memory-card — "Locale decimal separator"
    @Test func theGaugeUsesTheLocaleDecimalSeparator() {
        let reading = Self.snapshot(total: 1_000, used: 690)

        #expect(MemoryCardModel.gaugeText(for: reading, locale: Self.german) == "69,0%")
    }

    @Test func theGaugeFractionFollowsTheSnapshot() {
        let reading = Self.snapshot(total: 1_000, used: 690)

        #expect(MemoryCardModel.gaugeFraction(for: reading) == 0.69)
        #expect(MemoryCardModel.gaugeFraction(for: nil) == 0)
    }

    // MARK: - MC-4 Key/value rows

    // memory-card — "Four rows"
    @Test func theRowsReadUsedTotalWiredAndCompressedFromTheSnapshot() {
        let reading = MemoryFixtures.snapshot(from: MemoryFixtures.eightGiB)

        let rows = MemoryCardModel.rows(for: reading, locale: Self.english)

        #expect(rows.map(\.key) == ["Used", "Total", "Wired", "Compressed"])
        #expect(rows.map { Self.normalized($0.value) } == [
            "5.52 GB",
            "8 GB",
            "1.85 GB",
            "1.82 GB"
        ])
    }

    @Test func theRowValuesFollowTheInjectedLocale() {
        let reading = MemoryFixtures.snapshot(from: MemoryFixtures.eightGiB)

        let rows = MemoryCardModel.rows(for: reading, locale: Self.german)

        #expect(Self.normalized(rows[0].value) == "5,52 GB")
    }

    // MARK: - MC-5 Stacked bar

    // memory-card — "Segments sum to Total"
    @Test func theBarSplitsTotalIntoSixSegmentsInProductOrder() {
        let reading = MemoryFixtures.snapshot(from: MemoryFixtures.reference)

        let segments = MemoryCardModel.segments(for: reading)

        #expect(segments.map(\.kind) == [.app, .unattributed, .wired, .compressed, .cached, .free])
        #expect(segments.map(\.color) == [
            Palette.memAccent,
            Palette.memAccent,
            Palette.memWired,
            Palette.memCompressed,
            Palette.memCached,
            Palette.memFree
        ])
        #expect(segments.map(\.bytes) == [
            2_949_120_000,
            397_934_592,
            1_966_080_000,
            1_474_560_000,
            983_040_000,
            819_200_000
        ])
        #expect(segments.reduce(0) { $0 + $1.bytes } == reading.total)
    }

    // memory-card — "Segments sum to Total"
    @Test func theSegmentFractionsSumToOneAndTheAppColourCoversTheUnattributedUse() {
        let reading = MemoryFixtures.snapshot(from: MemoryFixtures.reference)

        let segments = MemoryCardModel.segments(for: reading)
        let sum = segments.reduce(0) { $0 + $1.fraction }
        let accentWidth = segments
            .filter { $0.color == Palette.memAccent }
            .reduce(0) { $0 + $1.fraction }
        let expectedAccent = Double(reading.used - reading.wired - reading.compressed)
            / Double(reading.total)

        #expect(abs(sum - 1) < 1e-9)
        #expect(abs(accentWidth - expectedAccent) < 1e-9)
    }

    // memory-card — "Components exceed Used"
    @Test func componentsLargerThanUsedLeaveNoRemainderAndStayInsideTheBar() {
        let reading = Self.snapshot(
            total: 1_000,
            app: 400,
            wired: 300,
            compressed: 300,
            cached: 200,
            free: 100,
            used: 700
        )

        let segments = MemoryCardModel.segments(for: reading)
        let unattributed = segments.first { $0.kind == .unattributed }
        let rects = StackedBarGeometry.rects(
            fractions: segments.map(\.fraction),
            in: CGSize(width: 100, height: 8)
        )

        #expect(unattributed?.bytes == 0)
        #expect(unattributed?.fraction == 0)
        #expect(segments.allSatisfy { $0.fraction >= 0 })
        #expect(rects.allSatisfy { $0.maxX <= 100 })
    }

    // memory-card — "No snapshot"
    @Test func aMissingSnapshotOrAnEmptyMachineDrawsNoSegments() {
        #expect(MemoryCardModel.segments(for: nil).isEmpty)
        #expect(MemoryCardModel.segments(for: Self.snapshot(total: 0, used: 0)).isEmpty)
    }

    @Test func everySegmentKindResolvesToItsPaletteToken() {
        #expect(MemoryCardModel.color(for: .app) == Palette.memAccent)
        #expect(MemoryCardModel.color(for: .unattributed) == Palette.memAccent)
        #expect(MemoryCardModel.color(for: .wired) == Palette.memWired)
        #expect(MemoryCardModel.color(for: .compressed) == Palette.memCompressed)
        #expect(MemoryCardModel.color(for: .cached) == Palette.memCached)
        #expect(MemoryCardModel.color(for: .free) == Palette.memFree)
    }

    // MARK: - MC-6 Legend

    // memory-card — "Legend entries"
    @Test func theLegendNamesFiveSegmentsAndSurvivesAMissingSnapshot() {
        #expect(MemoryCardModel.legend.map(\.label) == [
            "App",
            "Wired",
            "Compressed",
            "Cached",
            "Free"
        ])
        #expect(MemoryCardModel.legend.map(\.color) == [
            Palette.memAccent,
            Palette.memWired,
            Palette.memCompressed,
            Palette.memCached,
            Palette.memFree
        ])
        #expect(MemoryCardModel.segments(for: nil).isEmpty)
        #expect(MemoryCardModel.legend.count == 5)
    }

    // MARK: - MC-7 Section order and graph

    // memory-card — "Section order"
    @Test func theCardLaysOutItsSectionsWithTheGraphLast() {
        #expect(MemoryCardModel.sections == [.header, .gaugeAndRows, .stackedBar, .legend, .graph])
        #expect(MemoryCardModel.sections.last == .graph)
        #expect(Set(MemoryCardModel.sections) == Set(MemoryCardSection.allCases))
    }

    // memory-card — "Full history", "Short and empty history"
    @Test func theGraphTakesTheNewestSamplesOldestFirst() {
        let values = (0..<MemoryCardModel.graphCapacity).map { Double($0) / 120 }

        let full = MemoryCardModel.graphSamples(for: Self.history(values))
        let short = MemoryCardModel.graphSamples(for: Self.history([0.1, 0.2, 0.3]))
        let empty = MemoryCardModel.graphSamples(for: Self.history([]))

        #expect(full == values)
        #expect(full.count == 120)
        #expect(short == [0.1, 0.2, 0.3])
        #expect(empty.isEmpty)
    }

    // MARK: - MC-8 No-snapshot placeholder

    // memory-card — "Nil snapshot"
    @Test func aMissingSnapshotRendersAZeroedCardWithItsLegend() {
        let rows = MemoryCardModel.rows(for: nil, locale: Self.english)

        #expect(MemoryCardModel.gaugeText(for: nil, locale: Self.english) == "0.0%")
        #expect(rows.map(\.key) == ["Used", "Total", "Wired", "Compressed"])
        #expect(rows.allSatisfy { Self.normalized($0.value).hasPrefix("0") })
        #expect(rows.allSatisfy { Self.normalized($0.value) == "0 bytes" })
        #expect(MemoryCardModel.segments(for: nil).isEmpty)
        #expect(MemoryCardModel.graphSamples(for: Self.history([])).isEmpty)
        #expect(MemoryCardModel.legend.count == 5)
    }
}
