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

    // MARK: - Memory

    /// A snapshot whose `fraction` is exactly `fraction`, built by hand so the
    /// state tests do not depend on the calculator.
    private func memorySnapshot(fraction: Double) -> MemorySnapshot {
        let total: UInt64 = 1_000_000
        let used = UInt64((Double(total) * fraction).rounded())
        return MemorySnapshot(
            total: total,
            app: used,
            wired: 0,
            compressed: 0,
            cached: 0,
            free: total - used,
            used: used
        )
    }

    @Test func freshStateHasNoMemorySnapshotAndAnEmptyMemoryHistory() async {
        let state = await MetricsState()

        #expect(await state.memory == nil)
        #expect(await state.memoryHistory.count == 0)
        #expect(await state.memoryHistory.capacity == 120)
    }

    // memory-metrics — MM-4 "Apply stores and appends"
    @Test func applyingAMemorySnapshotStoresItAndAppendsItsFraction() async {
        let state = await MetricsState()
        let snapshot = memorySnapshot(fraction: 0.5)

        await state.apply(memory: snapshot)

        #expect(await state.memory == snapshot)
        #expect(await state.memoryHistory.ordered == [0.5])
        #expect(await state.memoryHistory.count == 1)
    }

    @Test func laterMemorySnapshotsReplaceTheCurrentValueAndExtendTheHistory() async {
        let state = await MetricsState()

        await state.apply(memory: memorySnapshot(fraction: 0.1))
        await state.apply(memory: memorySnapshot(fraction: 0.2))
        await state.apply(memory: memorySnapshot(fraction: 0.3))

        #expect(await state.memory?.fraction == 0.3)
        #expect(await state.memoryHistory.ordered == [0.1, 0.2, 0.3])
    }

    // memory-metrics — MM-4 "History bounded"
    @Test func memoryHistoryStaysBoundedAtOneHundredTwentySamples() async {
        let state = await MetricsState()

        for step in 1...130 {
            await state.apply(memory: memorySnapshot(fraction: Double(step) / 1_000))
        }

        #expect(await state.memoryHistory.count == 120)
        #expect(await state.memoryHistory.ordered.first == 0.011)
        #expect(await state.memoryHistory.ordered.last == 0.13)
        #expect(await state.memoryHistory.capacity == 120)
    }

    // memory-metrics — MM-4 "CPU state untouched"
    @Test func applyingMemoryLeavesTheCPUStateAlone() async {
        let state = await MetricsState()

        await state.apply(memory: memorySnapshot(fraction: 0.42))

        #expect(await state.cpu == nil)
        #expect(await state.cpuHistory.count == 0)
        #expect(await state.memory != nil)
    }

    @Test func applyingCPULeavesTheMemoryStateAlone() async {
        let state = await MetricsState()

        await state.apply(cpu: snapshot(total: 0.42))

        #expect(await state.memory == nil)
        #expect(await state.memoryHistory.count == 0)
        #expect(await state.cpu != nil)
    }

    @Test func memoryHistoryCapacityFollowsTheInjectedCapacity() async {
        let state = await MetricsState(historyCapacity: 2)

        await state.apply(memory: memorySnapshot(fraction: 0.1))
        await state.apply(memory: memorySnapshot(fraction: 0.2))
        await state.apply(memory: memorySnapshot(fraction: 0.3))

        #expect(await state.memoryHistory.ordered == [0.2, 0.3])
    }
}
