import CoreGraphics
import SwiftUI
import Testing
@testable import system_monitor

// network-card — NC-9 "Two series equal two single-series geometries",
// "Fewer samples and empty series", "Existing call sites unchanged"
@Suite("Multi-series history graph geometry")
struct HistoryGraphSeriesTests {

    private static let panelSize = CGSize(width: 120, height: 48)

    // NC-9 — "Two series equal two single-series geometries"
    @Test func twoSeriesProduceTheTwoSingleSeriesPointArrays() {
        let size = CGSize(width: 100, height: 10)
        let download = HistoryGraphSeries(samples: [0, 0.5, 1], color: Palette.networkDownload)
        let upload = HistoryGraphSeries(samples: [1, 0.25, 0], color: Palette.networkUpload)

        let points = HistoryGraph.points(series: [download, upload], capacity: 3, size: size)

        #expect(points == [
            [CGPoint(x: 0, y: 10), CGPoint(x: 50, y: 5), CGPoint(x: 100, y: 0)],
            [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 7.5), CGPoint(x: 100, y: 10)]
        ])

        // The same values a caller would get by laying out each series alone.
        #expect(points == [
            SparklineGeometry.points(samples: download.samples, capacity: 3, size: size),
            SparklineGeometry.points(samples: upload.samples, capacity: 3, size: size)
        ])
    }

    // The draw order is the array order, so the first series ends up underneath.
    @Test func theSeriesOrderIsThePointArrayOrder() {
        let bottom = HistoryGraphSeries(samples: [0], color: Palette.networkDownload)
        let top = HistoryGraphSeries(samples: [1], color: Palette.networkUpload)

        let points = HistoryGraph.points(series: [bottom, top], capacity: 1, size: Self.panelSize)
        let reversed = HistoryGraph.points(series: [top, bottom], capacity: 1, size: Self.panelSize)

        #expect(points == [[CGPoint(x: 120, y: 48)], [CGPoint(x: 120, y: 0)]])
        #expect(reversed == [[CGPoint(x: 120, y: 0)], [CGPoint(x: 120, y: 48)]])
    }

    // NC-9 — "Fewer samples and empty series"
    @Test func aPartialSeriesBesideAnEmptySeriesKeepsItsOwnGeometry() async {
        let partial = HistoryGraphSeries(samples: (0..<7).map { Double($0) / 6 }, color: Palette.networkDownload)
        let empty = HistoryGraphSeries(samples: [], color: Palette.networkUpload)

        let points = HistoryGraph.points(series: [partial, empty], capacity: 120, size: Self.panelSize)

        #expect(points.count == 2)
        #expect(points[0].count == 7)
        // A partial history is right-aligned, so the newest sample sits on the
        // right edge and the series never stretches to fill the width.
        #expect(points[0].last?.x == Self.panelSize.width)
        #expect(points[0].first?.x ?? 0 > 0)
        #expect(points[0].allSatisfy { (0...Self.panelSize.height).contains($0.y) })
        #expect(points[1].isEmpty)

        // The graph accepts the pair without trapping.
        await MainActor.run {
            let graph = HistoryGraph(series: [partial, empty], capacity: 120)
            #expect(graph.series.count == 2)
        }
    }

    @Test func aSeriesWithNoSamplesProducesOneEmptyPointArray() {
        let empty = HistoryGraphSeries(samples: [], color: Palette.networkUpload)

        #expect(HistoryGraph.points(series: [empty], capacity: 120, size: Self.panelSize) == [[]])
        #expect(HistoryGraph.points(series: [], capacity: 120, size: Self.panelSize).isEmpty)
    }

    // NC-9 — "Existing call sites unchanged": the CPU and Memory cards keep
    // calling `init(samples:capacity:color:)` and get the one-series graph.
    @Test func theSingleSeriesConvenienceBuildsTheOneSeriesGraph() async {
        await MainActor.run {
            let convenience = HistoryGraph(samples: [0.4, 0.5], capacity: 120, color: Palette.cpuAccent)
            let explicit = HistoryGraph(
                series: [HistoryGraphSeries(samples: [0.4, 0.5], color: Palette.cpuAccent)],
                capacity: 120
            )

            #expect(convenience == explicit)
        }
    }

    // Decision 5: the fill is per series, so the network card strokes two bare
    // lines while the CPU and Memory cards keep their filled area.
    @Test func theFillOpacityDefaultsToTheSparklineFillAndCanBeSwitchedOff() {
        let filled = HistoryGraphSeries(samples: [0.5], color: Palette.cpuAccent)
        let strokeOnly = HistoryGraphSeries(samples: [0.5], color: Palette.networkDownload, fillOpacity: 0)

        #expect(filled.fillOpacity == SparklineGeometry.fillOpacity)
        #expect(strokeOnly.fillOpacity == 0)
        #expect(filled != strokeOnly)
    }
}
