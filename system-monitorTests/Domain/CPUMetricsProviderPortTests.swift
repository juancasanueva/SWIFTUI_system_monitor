import Foundation
import Testing
@testable import system_monitor

// cpu-metrics — "Fake provider satisfies the port"
@Suite("CPU metrics port doubles")
struct CPUMetricsProviderPortTests {

    @Test func scriptedFakeReturnsEachSampleInOrder() throws {
        let provider = FakeCPUProvider(samples: [
            TickFixtures.sample(coreCount: 2, user: 100, system: 50, idle: 800, nice: 50),
            TickFixtures.sample(coreCount: 2, user: 200, system: 100, idle: 1000, nice: 100)
        ])

        let first = try provider.readTicks()
        let second = try provider.readTicks()

        #expect(first.cores.count == 2)
        #expect(second.cores.count == 2)
        #expect(first.cores[0] == CPUTicks(user: 100, system: 50, idle: 800, nice: 50))
        #expect(second.cores[0] == CPUTicks(user: 200, system: 100, idle: 1000, nice: 100))
        #expect(provider.callCount == 2)
    }

    @Test func exhaustedScriptRepeatsTheLastSample() throws {
        let provider = FakeCPUProvider(samples: [
            TickFixtures.sample(coreCount: 1, user: 1, system: 1, idle: 1, nice: 1),
            TickFixtures.sample(coreCount: 1, user: 9, system: 9, idle: 9, nice: 9)
        ])

        _ = try provider.readTicks()
        _ = try provider.readTicks()
        let third = try provider.readTicks()

        #expect(third.cores[0] == CPUTicks(user: 9, system: 9, idle: 9, nice: 9))
        #expect(provider.callCount == 3)
    }

    @Test func scriptedCallsThrowAtTheRequestedZeroBasedIndex() throws {
        let provider = FakeCPUProvider(
            samples: [
                TickFixtures.sample(coreCount: 1, user: 1, system: 1, idle: 1, nice: 1),
                TickFixtures.sample(coreCount: 1, user: 2, system: 2, idle: 2, nice: 2)
            ],
            throwOnCall: [1]
        )

        let first = try provider.readTicks()
        #expect(first.cores[0].user == 1)

        #expect(throws: FakeCPUProvider.ScriptedError.self) {
            _ = try provider.readTicks()
        }

        let third = try provider.readTicks()
        #expect(third.cores[0].user == 2)
        #expect(provider.callCount == 3)
    }

    @Test func providerRecordsTheThreadOfEveryRead() throws {
        let provider = FakeCPUProvider(samples: [
            TickFixtures.sample(coreCount: 1, user: 1, system: 1, idle: 1, nice: 1)
        ])

        let expected = Thread.isMainThread
        _ = try provider.readTicks()
        _ = try provider.readTicks()

        #expect(provider.readOnMainThread == [expected, expected])
    }

    @Test func topologyFakeReturnsTheConfiguredTopology() {
        let provider = FakeCoreTopologyProvider(result: TickFixtures.performanceFirstTopology)

        #expect(provider.topology().levels == [.performance, .performance, .efficiency, .efficiency])
    }

    @Test func fixturesExposeEfficiencyFirstAndPerformanceFirstTopologies() {
        #expect(TickFixtures.efficiencyFirstTopology.levels == [.efficiency, .efficiency, .performance, .performance])
        #expect(TickFixtures.allUnknownTopology(coreCount: 4).levels == Array(repeating: .unknown, count: 4))
    }
}
