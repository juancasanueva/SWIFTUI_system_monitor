import AppKit
import CoreGraphics
import Foundation
import SwiftUI
import Testing
@testable import system_monitor

// disk-card — DC-2 "Sections", DC-3 "One-decimal gauge", "Locale decimal
// separator", "Header symbol resolves", DC-4 "Three rows", "Rows under de_DE",
// DC-7 "Populated footer", "Distinct icons resolve", "Unavailable rates",
// DC-8 "Nil model", DC-9 "Chrome parity", DC-10 "Reduce motion", "Motion allowed"
@Suite("Disk card presentation model")
struct DiskCardModelTests {

    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    /// Non-breaking spaces are locale-legal inside byte strings (convention 7,
    /// the same normaliser `ByteFormatterTests` carries).
    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    /// The reference reading: 494.354 GB total, 62.286 GB free, 27.1 MB/s read
    /// and 2.2 MB/s write.
    private static let reference = DiskFixtures.referenceSnapshot

    /// The reference capacity with no rates yet, the state every first tick and
    /// every throughput failure publishes.
    private static let withoutRates = DiskSnapshot(
        total: DiskFixtures.referenceCapacity.total,
        free: DiskFixtures.referenceCapacity.free,
        readBytesPerSecond: nil,
        writeBytesPerSecond: nil
    )

    /// A full volume, so the gauge has to render `100.0%` rather than clamping.
    private static let full = DiskSnapshot(
        total: DiskFixtures.referenceCapacity.total,
        free: 0,
        readBytesPerSecond: nil,
        writeBytesPerSecond: nil
    )

    private static let emDash = "\u{2014}"

    // MARK: - DC-2 Section order without graph or bar

    // disk-card — "Sections"
    @Test func theCardHasAHeaderAGaugeWithRowsAndAThroughputFooter() {
        #expect(DiskCardModel.sections == [.header, .gaugeAndRows, .throughput])
        #expect(Set(DiskCardModel.sections) == Set(DiskCardSection.allCases))
    }

    // MARK: - DC-3 Header and ring gauge

    // disk-card — "One-decimal gauge"
    @Test(arguments: zip(
        [DiskCardModelTests.reference, DiskCardModelTests.full],
        ["87.4%", "100.0%"]
    ))
    func theGaugeShowsOneFractionDigit(snapshot: DiskSnapshot, expected: String) {
        #expect(DiskCardModel.gaugeText(for: snapshot, locale: Self.english) == expected)
    }

    // disk-card — "Locale decimal separator"
    @Test func theGaugeUsesTheLocaleDecimalSeparator() {
        #expect(DiskCardModel.gaugeText(for: Self.reference, locale: Self.german) == "87,4%")
    }

    @Test func theGaugeFractionFollowsTheSnapshot() {
        #expect(DiskCardModel.gaugeFraction(for: Self.reference) == Self.reference.fraction)
        #expect(abs(DiskCardModel.gaugeFraction(for: Self.reference) - 0.874) < 0.0005)
        #expect(DiskCardModel.gaugeFraction(for: Self.full) == 1)
        #expect(DiskCardModel.gaugeFraction(for: nil) == 0)
    }

    // disk-card — "Header symbol resolves"
    @Test func theHeaderSymbolResolvesAsAnSFSymbol() {
        let image = NSImage(
            systemSymbolName: DiskCardModel.headerSymbolName,
            accessibilityDescription: "Disk"
        )

        #expect(image != nil, "\(DiskCardModel.headerSymbolName) is not an SF Symbol on this SDK")
    }

    // MARK: - DC-4 Key/value rows

    // disk-card — "Three rows"
    @Test func theRowsReadUsedFreeAndTotalFromTheSnapshot() {
        let rows = DiskCardModel.rows(for: Self.reference, locale: Self.english)

        #expect(rows.map(\.key) == ["Used", "Free", "Total"])
        #expect(rows.map { Self.normalized($0.value) } == [
            "432.07 GB",
            "62.29 GB",
            "494.35 GB"
        ])
    }

    // disk-card — "Rows under de_DE"
    @Test func theRowValuesFollowTheInjectedLocale() {
        let rows = DiskCardModel.rows(for: Self.reference, locale: Self.german)

        #expect(rows.map { Self.normalized($0.value) } == [
            "432,07 GB",
            "62,29 GB",
            "494,35 GB"
        ])
    }

    // MARK: - DC-7 Throughput footer

    // disk-card — "Populated footer"
    @Test func theFooterReadsThenWrites() {
        let readings = DiskCardModel.throughputReadings(for: Self.reference, locale: Self.english)

        #expect(readings.map(\.accessibilityLabel) == ["Read", "Write"])
        #expect(readings.map { Self.normalized($0.text) } == ["27.1 MB/s", "2.2 MB/s"])
        #expect(readings.map { Self.normalized($0.accessibilityValue) } == ["27.1 MB/s", "2.2 MB/s"])
    }

    @Test func theFooterValuesFollowTheInjectedLocale() {
        let readings = DiskCardModel.throughputReadings(for: Self.reference, locale: Self.german)

        #expect(Self.normalized(readings[0].text) == "27,1 MB/s")
    }

    // disk-card — "Distinct icons resolve"
    @Test func theReadAndWriteSymbolsDifferAndResolve() {
        let read = NSImage(
            systemSymbolName: DiskCardModel.readSymbolName,
            accessibilityDescription: "Read"
        )
        let write = NSImage(
            systemSymbolName: DiskCardModel.writeSymbolName,
            accessibilityDescription: "Write"
        )

        #expect(DiskCardModel.readSymbolName != DiskCardModel.writeSymbolName)
        #expect(read != nil, "\(DiskCardModel.readSymbolName) is not an SF Symbol on this SDK")
        #expect(write != nil, "\(DiskCardModel.writeSymbolName) is not an SF Symbol on this SDK")
    }

    @Test func theFooterCarriesTheSymbolOfEachDirection() {
        let readings = DiskCardModel.throughputReadings(for: Self.reference, locale: Self.english)

        #expect(readings.map(\.symbolName) == [
            DiskCardModel.readSymbolName,
            DiskCardModel.writeSymbolName
        ])
    }

    // disk-card — "Unavailable rates"
    @Test func missingRatesRenderEmDashesWithoutLosingTheirLabels() {
        let readings = DiskCardModel.throughputReadings(for: Self.withoutRates, locale: Self.english)

        #expect(readings.map(\.text) == [Self.emDash, Self.emDash])
        #expect(readings.map(\.accessibilityValue) == ["unavailable", "unavailable"])
        #expect(readings.map(\.accessibilityLabel) == ["Read", "Write"])
    }

    // MARK: - DC-8 Nil-snapshot skeleton (model half)

    // disk-card — "Nil model"
    @Test func theNilSnapshotKeepsTheFullSkeletonWithEmDashes() {
        let gauge = DiskCardModel.gaugeText(for: nil, locale: Self.english)
        let rows = DiskCardModel.rows(for: nil, locale: Self.english)
        let readings = DiskCardModel.throughputReadings(for: nil, locale: Self.english)

        #expect(gauge == Self.emDash)
        #expect(gauge != "0%")
        #expect(gauge != "0.0%")
        #expect(DiskCardModel.gaugeFraction(for: nil) == 0)
        #expect(
            DiskCardModel.gaugeAccessibilityValue(for: nil, locale: Self.english) == "unavailable"
        )
        #expect(rows.map(\.key) == ["Used", "Free", "Total"])
        #expect(rows.map(\.value) == [Self.emDash, Self.emDash, Self.emDash])
        #expect(readings.map(\.text) == [Self.emDash, Self.emDash])
    }

    @Test func aPopulatedGaugeSpeaksItsPercentage() {
        let spoken = DiskCardModel.gaugeAccessibilityValue(for: Self.reference, locale: Self.english)

        #expect(spoken == "87.4%")
    }

    // MARK: - DC-10 Reduce motion

    // disk-card — "Reduce motion", "Motion allowed"
    @Test func theGaugeAnimationDelegatesToTheCPUCard() {
        #expect(DiskCardModel.gaugeAnimation(reduceMotion: true) == nil)
        #expect(
            DiskCardModel.gaugeAnimation(reduceMotion: false)
                == CPUCardModel.gaugeAnimation(reduceMotion: false)
        )
        #expect(DiskCardModel.gaugeAnimation(reduceMotion: false) != nil)
    }

    // MARK: - DC-9 Card chrome

    // disk-card — "Chrome parity". `MemoryCard`'s equivalents are `private
    // static` (MemoryCard.swift:171-177), so parity is pinned as the literal
    // values both cards use.
    @Test func theCardChromeMatchesTheOtherPanelCards() {
        #expect(DiskCard.cardPadding == 16)
        #expect(DiskCard.sectionSpacing == 14)
        #expect(DiskCard.rowSpacing == 6)
        #expect(DiskCard.headerSpacing == 6)
        #expect(DiskCard.headerFontSize == 13)
        #expect(DiskCard.footerSpacing == 16)
        #expect(Palette.cardCornerRadius == 12)
    }

    // Design decision 5: the footer reads as the rows' sibling, so its icon
    // follows the legend label size and its value the key/value row size.
    @Test func theThroughputLabelGeometryFollowsTheExistingComponents() {
        #expect(ThroughputLabel.iconSpacing == 4)
        #expect(ThroughputLabel.iconFontSize == 11)
        #expect(ThroughputLabel.valueFontSize == 12)
        #expect(ThroughputLabel.iconFontSize == SegmentLegend.labelFontSize)
    }
}
