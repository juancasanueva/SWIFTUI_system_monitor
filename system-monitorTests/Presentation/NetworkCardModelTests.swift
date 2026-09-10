import AppKit
import Foundation
import SwiftUI
import Testing
@testable import system_monitor

// network-card — NC-2 "Sections", NC-3 "Header symbol resolves", "Header title
// and tint", NC-4 "Populated readings under en_US", "Readings under de_DE",
// "Distinct icons resolve", NC-5 "Two rows under en_US", "Rows under de_DE",
// "Extreme totals do not trap", NC-6 "Rates unavailable, totals present",
// NC-7 "Nil model", NC-8 "Shared divisor keeps the ratio", "Floor flattens an
// idle link", "Values stay clamped", NC-10 "Chrome parity", NC-13 "Reduce
// motion", "Motion allowed"
@Suite("Network card presentation model")
struct NetworkCardModelTests {

    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    /// Non-breaking spaces are locale-legal inside byte strings (convention 6,
    /// the same normaliser `DiskCardModelTests` and `ByteFormatterTests` carry).
    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private static let emDash = "\u{2014}"

    /// The shared reference fixture: 3.85 GB in, 2.76 GB out, 5.0 kB/s down and
    /// 78.0 kB/s up.
    private static let reference = NetworkFixtures.referenceSnapshot

    /// The reference totals with no rates yet: what the first tick after a
    /// start and every re-seed tick publishes (NC-6).
    private static let withoutRates = NetworkSnapshot(
        totalIn: 3_850_000_000,
        totalOut: 2_760_000_000,
        downloadBytesPerSecond: nil,
        uploadBytesPerSecond: nil
    )

    /// Builds a history of `samples`, oldest first, at the card's capacity.
    private static func history(_ samples: [Double]) -> MetricHistory {
        var history = MetricHistory(capacity: NetworkCardModel.graphCapacity)
        for sample in samples {
            history.append(sample)
        }
        return history
    }

    /// Whether the SF Symbol resolves on this SDK, the NC-3/NC-4 gate.
    private static func resolves(_ symbolName: String) -> Bool {
        NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) != nil
    }

    // MARK: - NC-2 Section order

    // network-card — "Sections"
    @Test func theCardHasAHeaderARatesAndTotalsRowAndAGraphLast() {
        #expect(NetworkCardModel.sections == [.header, .ratesAndTotals, .graph])
        #expect(Set(NetworkCardModel.sections) == Set(NetworkCardSection.allCases))
    }

    // MARK: - NC-3 Header

    // network-card — "Header title and tint"
    @Test func theHeaderTitleIsNetwork() {
        #expect(NetworkCardModel.title == "Network")
    }

    // network-card — "Header symbol resolves"
    @Test func theHeaderSymbolResolvesAsAnSFSymbol() {
        #expect(
            Self.resolves(NetworkCardModel.headerSymbolName),
            "\(NetworkCardModel.headerSymbolName) is not an SF Symbol on this SDK"
        )
    }

    // MARK: - NC-4 Rate readings

    // network-card — "Populated readings under en_US"
    @Test func theReadingsShowDownloadThenUploadUnderEnglish() {
        let readings = NetworkCardModel.rateReadings(for: Self.reference, locale: Self.english)

        #expect(readings.map { Self.normalized($0.text) } == ["5.0 kB/s", "78.0 kB/s"])
        #expect(readings.map(\.accessibilityLabel) == ["Download", "Upload"])
        #expect(readings.map { Self.normalized($0.accessibilityValue) } == ["5.0 kB/s", "78.0 kB/s"])
    }

    // network-card — "Readings under de_DE"
    @Test func theReadingsFollowTheInjectedLocaleDecimalSeparator() {
        let readings = NetworkCardModel.rateReadings(for: Self.reference, locale: Self.german)

        #expect(readings.map { Self.normalized($0.text) } == ["5,0 kB/s", "78,0 kB/s"])
    }

    // network-card — "Distinct icons resolve"
    @Test func theDirectionIconsDifferAndBothResolve() {
        #expect(NetworkCardModel.downloadSymbolName != NetworkCardModel.uploadSymbolName)
        #expect(
            Self.resolves(NetworkCardModel.downloadSymbolName),
            "\(NetworkCardModel.downloadSymbolName) is not an SF Symbol on this SDK"
        )
        #expect(
            Self.resolves(NetworkCardModel.uploadSymbolName),
            "\(NetworkCardModel.uploadSymbolName) is not an SF Symbol on this SDK"
        )
    }

    // network-card — "Populated readings under en_US"
    @Test func eachReadingCarriesItsOwnDirectionIcon() {
        let readings = NetworkCardModel.rateReadings(for: Self.reference, locale: Self.english)

        #expect(
            readings.map(\.symbolName)
                == [NetworkCardModel.downloadSymbolName, NetworkCardModel.uploadSymbolName]
        )
    }

    // network-card — NC-4's colour clause: the download icon uses
    // `networkDownload` and the upload icon uses `networkUpload`, in the order
    // `rateReadings` returns them, so each badge matches its own graph line.
    //
    // The value text is deliberately not asserted here: `ThroughputLabel` paints
    // it `Palette.textPrimary` for the Disk card (DC-7) and the Network card
    // reuses that component unchanged, so only the icon carries the direction
    // token — which is what the amended NC-4 requires.
    @Test func theReadingColoursAreDownloadThenUpload() {
        #expect(NetworkCardModel.readingColors == [Palette.networkDownload, Palette.networkUpload])
        #expect(
            NetworkCardModel.readingColors.count
                == NetworkCardModel.rateReadings(for: Self.reference, locale: Self.english).count,
            "every reading must have a colour to zip against"
        )
    }

    // MARK: - NC-5 Total In / Total Out rows

    // network-card — "Two rows under en_US"
    @Test func theRowsAreTotalInThenTotalOutUnderEnglish() {
        let rows = NetworkCardModel.rows(for: Self.reference, locale: Self.english)

        #expect(rows.map(\.key) == ["Total In", "Total Out"])
        #expect(rows.map { Self.normalized($0.value) } == ["3.85 GB", "2.76 GB"])
    }

    // network-card — "Rows under de_DE"
    @Test func theRowValuesFollowTheInjectedLocale() {
        let rows = NetworkCardModel.rows(for: Self.reference, locale: Self.german)

        #expect(rows.map { Self.normalized($0.value) } == ["3,85 GB", "2,76 GB"])
    }

    // network-card — "Extreme totals do not trap"
    @Test func anExtremeTotalFormatsInsteadOfTrapping() {
        let extreme = NetworkSnapshot(
            totalIn: 0,
            totalOut: UInt64.max,
            downloadBytesPerSecond: nil,
            uploadBytesPerSecond: nil
        )

        let rows = NetworkCardModel.rows(for: extreme, locale: Self.english)
        let values = rows.map { Self.normalized($0.value) }

        #expect(values.count == 2)
        #expect(values[0].hasPrefix("0"), "a zero total must render digits, not an em dash")
        #expect(values[1] != Self.emDash, "the saturated total must format rather than fall back")
        #expect(values[1].hasSuffix("B"), "the saturated total lost its unit")
    }

    // MARK: - NC-6 Unavailable rates

    // network-card — "Rates unavailable, totals present"
    @Test func unavailableRatesRenderEmDashesWhileTheTotalsStillFormat() {
        let readings = NetworkCardModel.rateReadings(for: Self.withoutRates, locale: Self.english)
        let rows = NetworkCardModel.rows(for: Self.withoutRates, locale: Self.english)

        #expect(readings.map(\.text) == [Self.emDash, Self.emDash])
        #expect(readings.map(\.accessibilityValue) == ["unavailable", "unavailable"])
        #expect(readings.map(\.accessibilityLabel) == ["Download", "Upload"])
        #expect(
            readings.map(\.symbolName)
                == [NetworkCardModel.downloadSymbolName, NetworkCardModel.uploadSymbolName],
            "the icons must survive an unavailable rate"
        )
        #expect(rows.map { Self.normalized($0.value) } == ["3.85 GB", "2.76 GB"])
    }

    // network-card — "Rates unavailable, totals present"
    @Test func anUnavailableRateIsNeverRenderedAsZero() {
        let readings = NetworkCardModel.rateReadings(for: Self.withoutRates, locale: Self.english)

        #expect(readings.allSatisfy { !$0.text.contains("0 B/s") })
    }

    // MARK: - NC-7 Nil-snapshot skeleton

    // network-card — "Nil model"
    @Test func aNilSnapshotRendersTheFullSkeleton() {
        let readings = NetworkCardModel.rateReadings(for: nil, locale: Self.english)
        let rows = NetworkCardModel.rows(for: nil, locale: Self.english)
        let series = NetworkCardModel.graphSeries(
            download: Self.history([]),
            upload: Self.history([])
        )

        #expect(readings.map(\.text) == [Self.emDash, Self.emDash])
        #expect(readings.map(\.accessibilityValue) == ["unavailable", "unavailable"])
        #expect(rows.map(\.key) == ["Total In", "Total Out"])
        #expect(rows.map(\.value) == [Self.emDash, Self.emDash])
        #expect(series.count == 2)
        #expect(series.allSatisfy { $0.samples.isEmpty })
    }

    // MARK: - NC-8 Shared graph scale

    // network-card — "Shared divisor keeps the ratio"
    @Test func bothSeriesDivideByTheSharedMaximum() {
        let scale = NetworkCardModel.graphScale(download: [5_000], upload: [78_000])
        let series = NetworkCardModel.graphSeries(
            download: Self.history([5_000]),
            upload: Self.history([78_000])
        )

        #expect(scale == 78_000)
        #expect(series[1].samples == [1.0])
        #expect(series[0].samples == [5_000.0 / 78_000.0])
    }

    // network-card — "Floor flattens an idle link"
    @Test func theFloorFlattensAnIdleLinkInsteadOfAmplifyingNoise() {
        let scale = NetworkCardModel.graphScale(download: [500], upload: [800])
        let series = NetworkCardModel.graphSeries(
            download: Self.history([120, 500, 310]),
            upload: Self.history([90, 800, 240])
        )

        #expect(scale == NetworkCardModel.graphFloorBytesPerSecond)
        #expect(scale == 10_000)
        #expect(
            series.flatMap(\.samples).allSatisfy { $0 < 0.1 },
            "idle chatter was amplified to full scale"
        )
        #expect(series.flatMap(\.samples).contains { $0 > 0 }, "the idle lines collapsed to zero")
    }

    // network-card — "Values stay clamped"
    @Test func normalisationKeepsEveryValueWithinTheUnitRange() {
        let normalised = NetworkCardModel.normalised([0, 5_000, 78_000], scale: 78_000)

        #expect(normalised == [0, 5_000.0 / 78_000.0, 1.0])
        #expect(normalised.allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    // network-card — "Values stay clamped"
    @Test func aSingleSpikeStaysClampedAndTheSeriesKeepTheirLength() {
        let download = Self.history([200, 400, 12_000_000, 300, 250])
        let upload = Self.history([100, 150, 900, 120, 110])

        let series = NetworkCardModel.graphSeries(download: download, upload: upload)

        #expect(series.count == 2)
        #expect(series[0].samples.count == series[1].samples.count)
        #expect(series[0].samples.count == 5)
        #expect(series.flatMap(\.samples).allSatisfy { $0 >= 0 && $0 <= 1 })
        #expect(series[0].samples[2] == 1.0, "the spike must define the shared scale")
    }

    // network-card — "Values stay clamped"
    @Test func theSeriesAreTruncatedToTheVisibleCapacity() {
        let samples = (0..<(NetworkCardModel.graphCapacity + 40)).map { Double($0) * 1_000 }
        let series = NetworkCardModel.graphSeries(
            download: Self.history(samples),
            upload: Self.history(samples)
        )

        #expect(series[0].samples.count == NetworkCardModel.graphCapacity)
        #expect(series[1].samples.count == NetworkCardModel.graphCapacity)
        #expect(series.flatMap(\.samples).allSatisfy { $0 >= 0 && $0 <= 1 })
    }

    // network-card — "Shared divisor keeps the ratio"
    @Test func theSeriesCarryTheDirectionTokensAndStrokeWithoutAFill() {
        let series = NetworkCardModel.graphSeries(
            download: Self.history([5_000]),
            upload: Self.history([78_000])
        )

        #expect(series.map(\.color) == [Palette.networkDownload, Palette.networkUpload])
        #expect(series.map(\.fillOpacity) == [0, 0])
    }

    // MARK: - NC-10 Card chrome

    // network-card — "Chrome parity"
    @Test func theCardChromeMatchesTheDiskCard() {
        #expect(NetworkCard.cardPadding == 16)
        #expect(NetworkCard.sectionSpacing == 14)
        #expect(NetworkCard.rowSpacing == 6)
        #expect(NetworkCard.graphHeight == 48)
        #expect(NetworkCard.cardPadding == DiskCard.cardPadding)
        #expect(NetworkCard.sectionSpacing == DiskCard.sectionSpacing)
        #expect(NetworkCard.rowSpacing == DiskCard.rowSpacing)
        #expect(Palette.cardCornerRadius == 12)
    }

    // MARK: - NC-13 Reduce motion

    // network-card — "Reduce motion"
    @Test func reducedMotionRemovesTheAnimation() {
        #expect(NetworkCardModel.animation(reduceMotion: true) == nil)
    }

    // network-card — "Motion allowed"
    @Test func theCardBorrowsTheCPUCardAnimationWhenMotionIsAllowed() {
        let animation = NetworkCardModel.animation(reduceMotion: false)

        #expect(animation != nil)
        #expect(animation == CPUCardModel.gaugeAnimation(reduceMotion: false))
    }
}
