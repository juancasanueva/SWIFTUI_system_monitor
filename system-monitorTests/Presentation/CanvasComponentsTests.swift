import CoreGraphics
import SwiftUI
import Testing
@testable import system_monitor

// menu-bar-widget — "Sixty-sample sparkline"; cpu-card — "History graph"
@Suite("Sparkline geometry")
struct SparklineGeometryTests {

    private static let size = CGSize(width: 100, height: 10)

    @Test func aFullHistorySpansTheWholeWidthOldestFirst() {
        let points = SparklineGeometry.points(
            samples: [0, 0.5, 1],
            capacity: 3,
            size: Self.size
        )

        #expect(points == [
            CGPoint(x: 0, y: 10),
            CGPoint(x: 50, y: 5),
            CGPoint(x: 100, y: 0)
        ])
    }

    // menu-bar-widget — "Partial history"
    @Test func aPartialHistoryIsRightAlignedAtTheCapacityStep() {
        let points = SparklineGeometry.points(
            samples: [1, 0],
            capacity: 3,
            size: Self.size
        )

        #expect(points == [
            CGPoint(x: 50, y: 0),
            CGPoint(x: 100, y: 10)
        ])
    }

    // menu-bar-widget — "Last 60 of 120"
    @Test func onlyTheNewestCapacitySamplesAreDrawn() {
        let points = SparklineGeometry.points(
            samples: [0.1, 0.2, 0, 1],
            capacity: 2,
            size: Self.size
        )

        #expect(points == [
            CGPoint(x: 0, y: 10),
            CGPoint(x: 100, y: 0)
        ])
    }

    // menu-bar-widget — "Empty history"
    @Test func anEmptyHistoryProducesNoPoints() {
        #expect(SparklineGeometry.points(samples: [], capacity: 60, size: Self.size).isEmpty)
    }

    @Test func aSingleSampleCapacitySitsAtTheRightEdge() {
        let points = SparklineGeometry.points(samples: [0.25], capacity: 1, size: Self.size)

        #expect(points == [CGPoint(x: 100, y: 7.5)])
    }

    @Test func valuesOutsideTheUnitRangeAreClampedToTheDrawingArea() {
        let points = SparklineGeometry.points(
            samples: [-2, 5],
            capacity: 2,
            size: Self.size
        )

        #expect(points == [
            CGPoint(x: 0, y: 10),
            CGPoint(x: 100, y: 0)
        ])
    }

    @Test(arguments: [
        CGSize(width: 0, height: 10),
        CGSize(width: 100, height: 0),
        CGSize(width: -5, height: -5)
    ])
    func aDegenerateDrawingAreaProducesNoPoints(size: CGSize) {
        #expect(SparklineGeometry.points(samples: [0.5, 0.5], capacity: 2, size: size).isEmpty)
    }

    @Test func aNonPositiveCapacityProducesNoPoints() {
        #expect(SparklineGeometry.points(samples: [0.5], capacity: 0, size: Self.size).isEmpty)
    }
}

// menu-bar-widget — "Equal data compares equal"
@Suite("Canvas components skip redraw on equal data")
struct CanvasComponentEqualityTests {

    @Test func sparklinesWithTheSameSamplesCompareEqual() async {
        await MainActor.run {
            let base = Sparkline(samples: [0.1, 0.2], capacity: 60, color: Palette.cpuAccent)
            let same = Sparkline(samples: [0.1, 0.2], capacity: 60, color: Palette.cpuAccent)
            let differentSamples = Sparkline(samples: [0.1, 0.3], capacity: 60, color: Palette.cpuAccent)
            let differentCapacity = Sparkline(samples: [0.1, 0.2], capacity: 120, color: Palette.cpuAccent)

            #expect(base == same)
            #expect(base != differentSamples)
            #expect(base != differentCapacity)
        }
    }

    @Test func historyGraphsWithTheSameSamplesCompareEqual() async {
        await MainActor.run {
            let base = HistoryGraph(samples: [0.4, 0.5], capacity: 120, color: Palette.cpuAccent)
            let same = HistoryGraph(samples: [0.4, 0.5], capacity: 120, color: Palette.cpuAccent)
            let different = HistoryGraph(samples: [0.4], capacity: 120, color: Palette.cpuAccent)

            #expect(base == same)
            #expect(base != different)
        }
    }

    @Test func ringGaugesWithTheSameReadingCompareEqual() async {
        await MainActor.run {
            let base = RingGauge(fraction: 0.4, color: Palette.cpuAccent, valueText: "40.0%", subtitle: "CPU")
            let same = RingGauge(fraction: 0.4, color: Palette.cpuAccent, valueText: "40.0%", subtitle: "CPU")
            let different = RingGauge(fraction: 0.9, color: Palette.cpuAccent, valueText: "90.0%", subtitle: "CPU")

            #expect(base == same)
            #expect(base != different)
        }
    }

    @Test func coreBarsWithTheSameUsageCompareEqual() async {
        await MainActor.run {
            let base = CoreBar(usage: 0.734, color: Palette.cpuAccent, label: "73%")
            let same = CoreBar(usage: 0.734, color: Palette.cpuAccent, label: "73%")
            let different = CoreBar(usage: 0.734, color: Palette.cpuEfficiency, label: "73%")

            #expect(base == same)
            #expect(base != different)
        }
    }
}
