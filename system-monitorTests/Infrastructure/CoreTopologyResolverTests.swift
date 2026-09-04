import Testing
@testable import system_monitor

// core-topology — "Level resolution from the hardware description" and "Count cross-check"
@Suite("CoreTopologyResolver")
struct CoreTopologyResolverTests {

    /// Registry entries whose logical ids run `0..<clusterTypes.count` in order.
    private func entries(_ clusterTypes: [String]) -> [CoreTopologyResolver.Entry] {
        clusterTypes.enumerated().map { index, type in
            CoreTopologyResolver.Entry(logicalID: index, clusterType: type)
        }
    }

    private func clusterTypes(performance: Int, efficiency: Int) -> [String] {
        Array(repeating: "P", count: performance) + Array(repeating: "E", count: efficiency)
    }

    // core-topology — "Cluster type mapping"
    @Test(arguments: zip(
        ["P", "E", "M", "X", "", "p", "e"],
        [
            PerformanceLevel.performance,
            .efficiency,
            .unknown,
            .unknown,
            .unknown,
            .unknown,
            .unknown
        ]
    ))
    func clusterTypeMapsToItsPerformanceLevel(clusterType: String, expected: PerformanceLevel) {
        #expect(CoreTopologyResolver.level(forClusterType: clusterType) == expected)
    }

    // core-topology — "Consistent counts"
    @Test func matchingCountsProduceAFullyResolvedTopology() {
        let topology = CoreTopologyResolver.resolve(
            entries: entries(clusterTypes(performance: 8, efficiency: 4)),
            expectedPerformance: 8,
            expectedEfficiency: 4,
            expectedTotal: 12
        )

        #expect(topology.coreCount == 12)
        #expect(topology.levels.filter { $0 == .performance }.count == 8)
        #expect(topology.levels.filter { $0 == .efficiency }.count == 4)
        #expect(topology.levels.contains(.unknown) == false)
        #expect(topology.isSplit)
    }

    @Test func eachEntryLandsAtTheIndexOfItsLogicalID() {
        let shuffled: [CoreTopologyResolver.Entry] = [
            .init(logicalID: 3, clusterType: "P"),
            .init(logicalID: 0, clusterType: "E"),
            .init(logicalID: 2, clusterType: "P"),
            .init(logicalID: 1, clusterType: "E")
        ]

        let topology = CoreTopologyResolver.resolve(
            entries: shuffled,
            expectedPerformance: 2,
            expectedEfficiency: 2,
            expectedTotal: 4
        )

        #expect(topology.levels == [.efficiency, .efficiency, .performance, .performance])
    }

    @Test func performanceFirstLayoutIsResolvedWithoutAssumingAnOrder() {
        let topology = CoreTopologyResolver.resolve(
            entries: entries(["P", "P", "E", "E"]),
            expectedPerformance: 2,
            expectedEfficiency: 2,
            expectedTotal: 4
        )

        #expect(topology.levels == [.performance, .performance, .efficiency, .efficiency])
    }

    // core-topology — "P count mismatch"
    @Test func aPerformanceCountMismatchYieldsAnAllUnknownTopology() {
        let topology = CoreTopologyResolver.resolve(
            entries: entries(clusterTypes(performance: 6, efficiency: 6)),
            expectedPerformance: 8,
            expectedEfficiency: 4,
            expectedTotal: 12
        )

        #expect(topology.levels == Array(repeating: .unknown, count: 12))
        #expect(topology.isSplit == false)
    }

    @Test func anEfficiencyCountMismatchYieldsAnAllUnknownTopology() {
        let topology = CoreTopologyResolver.resolve(
            entries: entries(clusterTypes(performance: 8, efficiency: 4)),
            expectedPerformance: 8,
            expectedEfficiency: 5,
            expectedTotal: 12
        )

        #expect(topology.levels == Array(repeating: .unknown, count: 12))
    }

    // core-topology — "Total mismatch against Mach"
    @Test func aTotalMismatchYieldsAnAllUnknownTopologySizedToTheExpectedTotal() {
        let topology = CoreTopologyResolver.resolve(
            entries: entries(clusterTypes(performance: 8, efficiency: 4)),
            expectedPerformance: 8,
            expectedEfficiency: 4,
            expectedTotal: 10
        )

        #expect(topology.coreCount == 10)
        #expect(topology.levels == Array(repeating: .unknown, count: 10))
    }

    // core-topology — "One 'M' entry poisons the topology"
    @Test func aSingleUnrecognisedClusterTypePoisonsTheWholeTopology() {
        let types = Array(repeating: "P", count: 7) + ["M"] + Array(repeating: "E", count: 4)

        let topology = CoreTopologyResolver.resolve(
            entries: entries(types),
            expectedPerformance: 8,
            expectedEfficiency: 4,
            expectedTotal: 12
        )

        #expect(topology.levels == Array(repeating: .unknown, count: 12))
    }

    @Test func duplicateLogicalIDsYieldAnAllUnknownTopology() {
        let duplicated: [CoreTopologyResolver.Entry] = [
            .init(logicalID: 0, clusterType: "P"),
            .init(logicalID: 0, clusterType: "P"),
            .init(logicalID: 2, clusterType: "E"),
            .init(logicalID: 3, clusterType: "E")
        ]

        let topology = CoreTopologyResolver.resolve(
            entries: duplicated,
            expectedPerformance: 2,
            expectedEfficiency: 2,
            expectedTotal: 4
        )

        #expect(topology.levels == Array(repeating: .unknown, count: 4))
    }

    @Test(arguments: [-1, 4, 99])
    func anOutOfRangeLogicalIDYieldsAnAllUnknownTopology(strayID: Int) {
        let stray: [CoreTopologyResolver.Entry] = [
            .init(logicalID: 0, clusterType: "P"),
            .init(logicalID: 1, clusterType: "P"),
            .init(logicalID: 2, clusterType: "E"),
            .init(logicalID: strayID, clusterType: "E")
        ]

        let topology = CoreTopologyResolver.resolve(
            entries: stray,
            expectedPerformance: 2,
            expectedEfficiency: 2,
            expectedTotal: 4
        )

        #expect(topology.levels == Array(repeating: .unknown, count: 4))
    }

    // core-topology — "No perflevel split"
    @Test func aMissingPerformanceCountYieldsAnAllUnknownTopology() {
        let topology = CoreTopologyResolver.resolve(
            entries: entries(clusterTypes(performance: 4, efficiency: 4)),
            expectedPerformance: nil,
            expectedEfficiency: 4,
            expectedTotal: 8
        )

        #expect(topology.levels == Array(repeating: .unknown, count: 8))
    }

    @Test func aMissingEfficiencyCountYieldsAnAllUnknownTopology() {
        let topology = CoreTopologyResolver.resolve(
            entries: entries(clusterTypes(performance: 4, efficiency: 4)),
            expectedPerformance: 4,
            expectedEfficiency: nil,
            expectedTotal: 8
        )

        #expect(topology.levels == Array(repeating: .unknown, count: 8))
    }

    // core-topology — "Registry unreadable"
    @Test func noEntriesAtAllYieldAnAllUnknownTopologySizedToTheMachCount() {
        let topology = CoreTopologyResolver.resolve(
            entries: [],
            expectedPerformance: 8,
            expectedEfficiency: 4,
            expectedTotal: 12
        )

        #expect(topology.coreCount == 12)
        #expect(topology.levels == Array(repeating: .unknown, count: 12))
    }

    @Test func anExpectedTotalOfZeroProducesAnEmptyTopology() {
        let topology = CoreTopologyResolver.resolve(
            entries: [],
            expectedPerformance: nil,
            expectedEfficiency: nil,
            expectedTotal: 0
        )

        #expect(topology.levels.isEmpty)
        #expect(topology.coreCount == 0)
    }
}
