import Testing
@testable import system_monitor

// core-topology — "Topology model and port"
@Suite("CoreTopology model")
struct CoreTopologyTests {

    // core-topology — "Level lookup"
    @Test func levelLookupReturnsTheLevelStoredAtThatIndex() {
        let topology = CoreTopology(levels: [.efficiency, .performance])

        #expect(topology.level(of: 1) == .performance)
        #expect(topology.level(of: 0) == .efficiency)
        #expect(topology.coreCount == 2)
    }

    // core-topology — "Missing index"
    @Test func levelLookupOutsideTheCoreRangeIsUnknown() {
        let topology = CoreTopology(levels: [.efficiency, .performance])

        #expect(topology.level(of: 7) == .unknown)
        #expect(topology.level(of: -1) == .unknown)
    }

    @Test func topologyWithAnyResolvedLevelIsSplit() {
        #expect(CoreTopology(levels: [.unknown, .performance]).isSplit)
        #expect(CoreTopology(levels: [.efficiency, .efficiency]).isSplit)
    }

    @Test func topologyWithOnlyUnknownLevelsIsNotSplit() {
        #expect(CoreTopology(levels: [.unknown, .unknown]).isSplit == false)
        #expect(CoreTopology(levels: []).isSplit == false)
    }

    @Test func unknownFactoryProducesOneUnknownLevelPerCore() {
        let topology = CoreTopology.unknown(coreCount: 4)

        #expect(topology.levels == [.unknown, .unknown, .unknown, .unknown])
        #expect(topology.coreCount == 4)
        #expect(topology.isSplit == false)
    }

    @Test func unknownFactoryWithoutCoresIsEmpty() {
        let topology = CoreTopology.unknown(coreCount: 0)

        #expect(topology.levels.isEmpty)
        #expect(topology.coreCount == 0)
    }
}

@Suite("CPUTicks values")
struct CPUTicksTests {

    @Test func totalSumsEveryTickField() {
        let ticks = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)

        #expect(ticks.total == 1000)
    }

    @Test func totalDoesNotOverflowNearTheUInt32Ceiling() {
        let ticks = CPUTicks(user: .max, system: .max, idle: .max, nice: .max)

        #expect(ticks.total == UInt64(UInt32.max) * 4)
    }

    @Test func deltaSubtractsEveryFieldAgainstThePreviousSample() {
        let previous = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        let current = CPUTicks(user: 200, system: 100, idle: 1000, nice: 100)

        let delta = current.delta(since: previous)

        #expect(delta == CPUTicks(user: 100, system: 50, idle: 200, nice: 50))
        #expect(delta.total == 400)
    }

    @Test func deltaWrapsAroundWhenTheCounterOverflows() {
        let previous = CPUTicks(user: 0, system: 0, idle: UInt32.max - 5, nice: 0)
        let current = CPUTicks(user: 0, system: 0, idle: 4, nice: 0)

        let delta = current.delta(since: previous)

        #expect(delta.idle == 10)
        #expect(delta.total == 10)
    }

    @Test func sampleReportsOneEntryPerCore() {
        let sample = CPUTickSample(cores: [
            CPUTicks(user: 1, system: 1, idle: 1, nice: 1),
            CPUTicks(user: 2, system: 2, idle: 2, nice: 2)
        ])

        #expect(sample.coreCount == 2)
        #expect(sample.cores[1].user == 2)
    }
}

@Suite("CPUSnapshot values")
struct CPUSnapshotTests {

    @Test func coreUsageIsIdentifiedByItsMachIndex() {
        let core = CoreUsage(index: 3, usage: 0.5, level: .efficiency)

        #expect(core.id == 3)
    }

    @Test func snapshotHasPerformanceLevelsWhenEitherAverageIsPresent() {
        let performanceOnly = CPUSnapshot(
            total: 0.5, user: 0.3, system: 0.2,
            performanceAverage: 0.5, efficiencyAverage: nil, cores: []
        )
        let efficiencyOnly = CPUSnapshot(
            total: 0.5, user: 0.3, system: 0.2,
            performanceAverage: nil, efficiencyAverage: 0.5, cores: []
        )

        #expect(performanceOnly.hasPerformanceLevels)
        #expect(efficiencyOnly.hasPerformanceLevels)
    }

    @Test func snapshotWithoutLevelAveragesHasNoPerformanceLevels() {
        let snapshot = CPUSnapshot(
            total: 0.5, user: 0.3, system: 0.2,
            performanceAverage: nil, efficiencyAverage: nil,
            cores: [CoreUsage(index: 0, usage: 0.5, level: .unknown)]
        )

        #expect(snapshot.hasPerformanceLevels == false)
    }
}
