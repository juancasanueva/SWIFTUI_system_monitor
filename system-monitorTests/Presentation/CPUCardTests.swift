import Foundation
import SwiftUI
import Testing
@testable import system_monitor

// cpu-card — "Key/value rows", "Per-core bars grouped P then E", "Degraded 'Cores' layout",
// "No-snapshot placeholder", "History graph"
@Suite("CPU card presentation model")
struct CPUCardModelTests {

    private static let english = Locale(identifier: "en_US")

    private func cores(_ levels: [PerformanceLevel], usage: Double = 0.5) -> [CoreUsage] {
        levels.enumerated().map { index, level in
            CoreUsage(index: index, usage: usage, level: level)
        }
    }

    private func snapshot(
        total: Double = 0.402,
        user: Double = 0.306,
        system: Double = 0.096,
        performanceAverage: Double? = 0.706,
        efficiencyAverage: Double? = 0.098,
        cores: [CoreUsage] = []
    ) -> CPUSnapshot {
        CPUSnapshot(
            total: total,
            user: user,
            system: system,
            performanceAverage: performanceAverage,
            efficiencyAverage: efficiencyAverage,
            cores: cores
        )
    }

    // cpu-card — "Four rows on Apple Silicon"
    @Test func aSplitSnapshotProducesUserSystemAndBothLevelRows() {
        let rows = CPUCardModel.rows(for: snapshot(), locale: Self.english)

        #expect(rows.map(\.key) == ["User", "System", "P-Cores", "E-Cores"])
        #expect(rows.map(\.value) == ["30.6%", "9.6%", "70.6%", "9.8%"])
        #expect(rows[2].valueColor == Palette.cpuAccent)
        #expect(rows[3].valueColor == Palette.cpuEfficiency)
    }

    // cpu-card — "Two rows when levels unknown"
    @Test func aSnapshotWithoutLevelAveragesProducesOnlyUserAndSystem() {
        let rows = CPUCardModel.rows(
            for: snapshot(performanceAverage: nil, efficiencyAverage: nil),
            locale: Self.english
        )

        #expect(rows.map(\.key) == ["User", "System"])
        #expect(rows.map(\.value) == ["30.6%", "9.6%"])
    }

    @Test func aSnapshotWithOnlyPerformanceCoresHidesTheEfficiencyRow() {
        let rows = CPUCardModel.rows(
            for: snapshot(efficiencyAverage: nil),
            locale: Self.english
        )

        #expect(rows.map(\.key) == ["User", "System", "P-Cores"])
    }

    // cpu-card — "Nil snapshot"
    @Test func aMissingSnapshotStillProducesZeroedUserAndSystemRows() {
        let rows = CPUCardModel.rows(for: nil, locale: Self.english)

        #expect(rows.map(\.key) == ["User", "System"])
        #expect(rows.map(\.value) == ["0.0%", "0.0%"])
    }

    @Test func theGaugeTextIsTheTotalAtOneDecimal() {
        #expect(CPUCardModel.gaugeText(for: snapshot(total: 0.402), locale: Self.english) == "40.2%")
        #expect(CPUCardModel.gaugeText(for: snapshot(total: 1), locale: Self.english) == "100.0%")
    }

    // cpu-card — "Nil snapshot"
    @Test func theGaugeReadsZeroBeforeTheFirstSnapshot() {
        #expect(CPUCardModel.gaugeText(for: nil, locale: Self.english) == "0.0%")
        #expect(CPUCardModel.gaugeFraction(for: nil) == 0)
    }

    @Test func theGaugeFractionFollowsTheSnapshotTotal() {
        #expect(CPUCardModel.gaugeFraction(for: snapshot(total: 0.402)) == 0.402)
    }

    // cpu-card — "8 P + 4 E"
    @Test func aSplitSnapshotProducesAPerformanceGroupThenAnEfficiencyGroup() {
        let levels = Array(repeating: PerformanceLevel.performance, count: 8)
            + Array(repeating: PerformanceLevel.efficiency, count: 4)
        let groups = CPUCardModel.groups(for: snapshot(cores: cores(levels)))

        #expect(groups.map(\.title) == ["P-Cores", "E-Cores"])
        #expect(groups.map(\.cores.count) == [8, 4])
        #expect(groups[0].color == Palette.cpuAccent)
        #expect(groups[1].color == Palette.cpuEfficiency)
    }

    // cpu-card — "Intel or mismatch topology"
    @Test func anAllUnknownSnapshotProducesASingleCoresGroup() {
        let groups = CPUCardModel.groups(
            for: snapshot(
                performanceAverage: nil,
                efficiencyAverage: nil,
                cores: cores(Array(repeating: .unknown, count: 8))
            )
        )

        #expect(groups.map(\.title) == ["Cores"])
        #expect(groups[0].cores.count == 8)
        #expect(groups[0].color == Palette.cpuAccent)
        #expect(groups[0].cores.map(\.index) == Array(0...7))
    }

    @Test func aLevelWithoutCoresIsNotRenderedAsAnEmptyGroup() {
        let groups = CPUCardModel.groups(
            for: snapshot(
                efficiencyAverage: nil,
                cores: cores(Array(repeating: .performance, count: 4))
            )
        )

        #expect(groups.map(\.title) == ["P-Cores"])
    }

    // cpu-card — "Nil snapshot"
    @Test func aMissingSnapshotProducesNoBarGroups() {
        #expect(CPUCardModel.groups(for: nil).isEmpty)
    }

    @Test func aSnapshotWithoutCoresProducesNoBarGroups() {
        #expect(CPUCardModel.groups(for: snapshot(cores: [])).isEmpty)
    }

    // cpu-card — "Bar label"
    @Test func aBarLabelIsTheCoreUsageAsAWholePercent() {
        #expect(CPUCardModel.barLabel(for: 0.734) == "73%")
        #expect(CPUCardModel.barLabel(for: 0) == "0%")
    }

    // cpu-card — "Full history"
    @Test func theGraphUsesEveryHistoryValueOldestFirst() {
        var history = MetricHistory(capacity: CPUCardModel.graphCapacity)
        for step in 0..<CPUCardModel.graphCapacity {
            history.append(Double(step) / Double(CPUCardModel.graphCapacity))
        }

        let samples = CPUCardModel.graphSamples(for: history)

        #expect(CPUCardModel.graphCapacity == 120)
        #expect(samples.count == 120)
        #expect(samples == history.ordered)
        #expect(samples.first == 0)
    }

    // cpu-card — "Short history"
    @Test func theGraphToleratesFewerSamplesThanTheCapacity() {
        var history = MetricHistory(capacity: CPUCardModel.graphCapacity)
        history.append(0.1)
        history.append(0.2)
        history.append(0.3)

        #expect(CPUCardModel.graphSamples(for: history) == [0.1, 0.2, 0.3])
    }

    @Test func theGraphOfAnEmptyHistoryHasNoSamples() {
        let history = MetricHistory(capacity: CPUCardModel.graphCapacity)

        #expect(CPUCardModel.graphSamples(for: history).isEmpty)
    }

    // MARK: - Reduce motion

    // The animation choice is a model decision rather than a condition inside
    // `body`, so the accessibility rule is asserted here instead of by reading
    // the view. The view keeps reading the environment and passes the flag in.

    // cpu-card — "Reduce motion yields no animation"
    @Test func reduceMotionRemovesTheGaugeAnimation() {
        #expect(CPUCardModel.gaugeAnimation(reduceMotion: true) == nil)
    }

    // cpu-card — "Motion allowed yields the gauge animation": the card's
    // standard quarter-second ease-out, unchanged from the inline constant it
    // replaces.
    @Test func motionAllowedYieldsTheQuarterSecondEaseOut() {
        #expect(CPUCardModel.gaugeAnimation(reduceMotion: false) == Animation.easeOut(duration: 0.25))
    }

    // cpu-card — the two answers must differ, otherwise the flag is ignored.
    @Test func theTwoReduceMotionAnswersDiffer() {
        #expect(
            CPUCardModel.gaugeAnimation(reduceMotion: true)
                != CPUCardModel.gaugeAnimation(reduceMotion: false)
        )
    }
}
