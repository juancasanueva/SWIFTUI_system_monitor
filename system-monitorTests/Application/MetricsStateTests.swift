import Testing
@testable import system_monitor

@Suite("MetricsState")
struct MetricsStateTests {

    private func snapshot(total: Double) -> CPUSnapshot {
        CPUSnapshot(
            total: total,
            user: total,
            system: 0,
            performanceAverage: nil,
            efficiencyAverage: nil,
            cores: [CoreUsage(index: 0, usage: total, level: .unknown)]
        )
    }

    @Test func freshStateHasNoSnapshotAndAnEmptyHistory() async {
        let state = await MetricsState()

        #expect(await state.cpu == nil)
        #expect(await state.cpuHistory.count == 0)
        #expect(await state.cpuHistory.isEmpty)
    }

    // cpu-metrics — "Second step publishes": applying a snapshot stores it and
    // records its total.
    @Test func applyingASnapshotStoresItAndAppendsItsTotal() async {
        let state = await MetricsState()

        await state.apply(cpu: snapshot(total: 0.42))

        #expect(await state.cpu == snapshot(total: 0.42))
        #expect(await state.cpuHistory.ordered == [0.42])
        #expect(await state.cpuHistory.count == 1)
    }

    @Test func laterSnapshotsReplaceTheCurrentValueAndExtendTheHistory() async {
        let state = await MetricsState()

        await state.apply(cpu: snapshot(total: 0.1))
        await state.apply(cpu: snapshot(total: 0.2))
        await state.apply(cpu: snapshot(total: 0.3))

        #expect(await state.cpu?.total == 0.3)
        #expect(await state.cpuHistory.ordered == [0.1, 0.2, 0.3])
    }

    // cpu-metrics — "History stays bounded"
    @Test func historyStaysBoundedAtOneHundredTwentySamples() async {
        let state = await MetricsState()

        for step in 1...130 {
            await state.apply(cpu: snapshot(total: Double(step)))
        }

        #expect(await state.cpuHistory.count == 120)
        #expect(await state.cpuHistory.ordered.first == 11)
        #expect(await state.cpuHistory.ordered.last == 130)
        #expect(await state.cpuHistory.capacity == 120)
    }

    @Test func historyCapacityIsInjectable() async {
        let state = await MetricsState(historyCapacity: 2)

        await state.apply(cpu: snapshot(total: 0.1))
        await state.apply(cpu: snapshot(total: 0.2))
        await state.apply(cpu: snapshot(total: 0.3))

        #expect(await state.cpuHistory.ordered == [0.2, 0.3])
    }
}
