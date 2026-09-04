import Foundation
import Testing
@testable import system_monitor

@Suite("CPUUsageCalculator")
struct CPUUsageCalculatorTests {

    /// Tick counters are integers but usage is a ratio, so comparisons use a
    /// tolerance instead of exact binary equality.
    private static let tolerance = 1e-9

    private func expectClose(
        _ actual: Double,
        _ expected: Double,
        _ comment: Comment? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            abs(actual - expected) < Self.tolerance,
            comment ?? "expected \(expected), got \(actual)",
            sourceLocation: sourceLocation
        )
    }

    /// Sample whose cores are all zero, so the next sample's counters are also
    /// its deltas.
    private func zeroed(coreCount: Int) -> CPUTickSample {
        TickFixtures.sample(coreCount: coreCount, user: 0, system: 0, idle: 0, nice: 0)
    }

    private func snapshot(
        previous: CPUTickSample?,
        current: CPUTickSample,
        topology: CoreTopology
    ) throws -> CPUSnapshot {
        try #require(
            CPUUsageCalculator.snapshot(previous: previous, current: current, topology: topology)
        )
    }

    // MARK: - Per-core usage from tick deltas

    // cpu-metrics — "Idle delta yields total usage"
    @Test func coreUsageIsOneMinusTheIdleShareOfTheDelta() throws {
        let previous = TickFixtures.sample(cores: [(user: 100, system: 50, idle: 800, nice: 50)])
        let current = TickFixtures.sample(cores: [(user: 200, system: 100, idle: 1000, nice: 100)])

        let result = try snapshot(
            previous: previous,
            current: current,
            topology: CoreTopology.unknown(coreCount: 1)
        )

        expectClose(result.cores[0].usage, 0.5)
        expectClose(result.total, 0.5)
    }

    // cpu-metrics — "Nice ticks fold into user"
    @Test func niceTicksAreReportedAsUserTime() throws {
        let current = TickFixtures.sample(cores: [(user: 30, system: 10, idle: 50, nice: 10)])

        let result = try snapshot(
            previous: zeroed(coreCount: 1),
            current: current,
            topology: CoreTopology.unknown(coreCount: 1)
        )

        expectClose(result.user, 0.4)
        expectClose(result.system, 0.1)
        expectClose(result.cores[0].usage, 0.5)
    }

    // cpu-metrics — "Counter wrap-around"
    @Test func wrappedCountersProduceTheShortDelta() throws {
        let previous = TickFixtures.sample(cores: [(user: 0, system: 0, idle: UInt32.max - 5, nice: 0)])
        let current = TickFixtures.sample(cores: [(user: 0, system: 0, idle: 4, nice: 0)])

        let result = try snapshot(
            previous: previous,
            current: current,
            topology: CoreTopology.unknown(coreCount: 1)
        )

        expectClose(result.cores[0].usage, 0)
        expectClose(result.total, 0)
        expectClose(result.user, 0)
    }

    // cpu-metrics — "Zero total delta"
    @Test func identicalSamplesReportZeroUsageInsteadOfNaN() throws {
        let sample = TickFixtures.sample(cores: [(user: 700, system: 200, idle: 900, nice: 5)])

        let result = try snapshot(
            previous: sample,
            current: sample,
            topology: CoreTopology.unknown(coreCount: 1)
        )

        #expect(result.cores[0].usage.isNaN == false)
        expectClose(result.cores[0].usage, 0)
        expectClose(result.total, 0)
        expectClose(result.user, 0)
        expectClose(result.system, 0)
    }

    // MARK: - Aggregates

    // cpu-metrics — "Unequal per-core deltas"
    @Test func aggregatesUseSummedDeltasNotTheMeanOfCoreRatios() throws {
        let current = TickFixtures.sample(cores: [
            (user: 90, system: 0, idle: 10, nice: 0),
            (user: 0, system: 0, idle: 100, nice: 0)
        ])

        let result = try snapshot(
            previous: zeroed(coreCount: 2),
            current: current,
            topology: CoreTopology.unknown(coreCount: 2)
        )

        expectClose(result.total, 0.45, "mean of core ratios would be 0.45 vs summed 90/200")
        expectClose(result.user, 0.45)
        expectClose(result.system, 0)
        expectClose(result.cores[0].usage, 0.9)
        expectClose(result.cores[1].usage, 0)
    }

    @Test func aggregatesAreZeroWhenNoCoreAdvanced() throws {
        let sample = zeroed(coreCount: 4)

        let result = try snapshot(
            previous: sample,
            current: sample,
            topology: CoreTopology.unknown(coreCount: 4)
        )

        expectClose(result.total, 0)
        expectClose(result.user, 0)
        expectClose(result.system, 0)
        #expect(result.cores.count == 4)
    }

    // MARK: - Per-level averages

    // cpu-metrics — "Mean per level"
    @Test func levelAveragesAreTheArithmeticMeanOfTheirCores() throws {
        // usage 0.2, 0.6 on the performance cores; 0.9 on the efficiency core.
        let current = TickFixtures.sample(cores: [
            (user: 20, system: 0, idle: 80, nice: 0),
            (user: 60, system: 0, idle: 40, nice: 0),
            (user: 90, system: 0, idle: 10, nice: 0)
        ])

        let result = try snapshot(
            previous: zeroed(coreCount: 3),
            current: current,
            topology: CoreTopology(levels: [.performance, .performance, .efficiency])
        )

        let performanceAverage = try #require(result.performanceAverage)
        let efficiencyAverage = try #require(result.efficiencyAverage)
        expectClose(performanceAverage, 0.4)
        expectClose(efficiencyAverage, 0.9)
        #expect(result.hasPerformanceLevels)
    }

    // cpu-metrics — "All cores unknown"
    @Test func unknownTopologyHasNoLevelAverages() throws {
        let current = TickFixtures.sample(coreCount: 4, user: 50, system: 0, idle: 50, nice: 0)

        let result = try snapshot(
            previous: zeroed(coreCount: 4),
            current: current,
            topology: CoreTopology.unknown(coreCount: 4)
        )

        #expect(result.performanceAverage == nil)
        #expect(result.efficiencyAverage == nil)
        #expect(result.hasPerformanceLevels == false)
    }

    @Test func aLevelWithoutCoresHasNoAverage() throws {
        let current = TickFixtures.sample(coreCount: 2, user: 50, system: 0, idle: 50, nice: 0)

        let result = try snapshot(
            previous: zeroed(coreCount: 2),
            current: current,
            topology: CoreTopology(levels: [.performance, .performance])
        )

        let performanceAverage = try #require(result.performanceAverage)
        expectClose(performanceAverage, 0.5)
        #expect(result.efficiencyAverage == nil)
    }

    // MARK: - Preconditions

    // cpu-metrics — "Missing previous sample"
    @Test func firstSampleProducesNoSnapshot() {
        let result = CPUUsageCalculator.snapshot(
            previous: nil,
            current: TickFixtures.sample(coreCount: 4, user: 1, system: 1, idle: 1, nice: 1),
            topology: CoreTopology.unknown(coreCount: 4)
        )

        #expect(result == nil)
    }

    // cpu-metrics — "Core count mismatch"
    @Test func mismatchedCoreCountsProduceNoSnapshot() {
        let result = CPUUsageCalculator.snapshot(
            previous: zeroed(coreCount: 4),
            current: TickFixtures.sample(coreCount: 8, user: 1, system: 1, idle: 1, nice: 1),
            topology: CoreTopology.unknown(coreCount: 8)
        )

        #expect(result == nil)
    }

    // MARK: - Core ordering

    // core-topology — "E-first fake topology"
    @Test func efficiencyFirstTopologyIsReorderedPerformanceFirst() throws {
        let current = TickFixtures.sample(coreCount: 4, user: 50, system: 0, idle: 50, nice: 0)

        let result = try snapshot(
            previous: zeroed(coreCount: 4),
            current: current,
            topology: TickFixtures.efficiencyFirstTopology
        )

        #expect(result.cores.map(\.index) == [2, 3, 0, 1])
        #expect(result.cores.map(\.level) == [.performance, .performance, .efficiency, .efficiency])
    }

    // core-topology — "P-first fake topology"
    @Test func performanceFirstTopologyKeepsItsOrder() throws {
        let current = TickFixtures.sample(coreCount: 4, user: 50, system: 0, idle: 50, nice: 0)

        let result = try snapshot(
            previous: zeroed(coreCount: 4),
            current: current,
            topology: TickFixtures.performanceFirstTopology
        )

        #expect(result.cores.map(\.index) == [0, 1, 2, 3])
        #expect(result.cores.map(\.level) == [.performance, .performance, .efficiency, .efficiency])
    }

    // core-topology — "All unknown keeps Mach order"
    @Test func unknownTopologyKeepsMachOrder() throws {
        let current = TickFixtures.sample(coreCount: 4, user: 50, system: 0, idle: 50, nice: 0)

        let result = try snapshot(
            previous: zeroed(coreCount: 4),
            current: current,
            topology: TickFixtures.allUnknownTopology(coreCount: 4)
        )

        #expect(result.cores.map(\.index) == [0, 1, 2, 3])
        #expect(result.cores.allSatisfy { $0.level == .unknown })
    }

    // core-topology — a topology that does not describe this sample is not trusted
    @Test func topologySizedDifferentlyFromTheSampleIsTreatedAsAllUnknown() throws {
        let current = TickFixtures.sample(coreCount: 4, user: 50, system: 0, idle: 50, nice: 0)

        let result = try snapshot(
            previous: zeroed(coreCount: 4),
            current: current,
            topology: CoreTopology(levels: [.performance, .efficiency])
        )

        #expect(result.cores.map(\.index) == [0, 1, 2, 3])
        #expect(result.cores.allSatisfy { $0.level == .unknown })
        #expect(result.performanceAverage == nil)
        #expect(result.efficiencyAverage == nil)
    }
}
