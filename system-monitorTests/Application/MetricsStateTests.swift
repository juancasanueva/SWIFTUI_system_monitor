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

    // MARK: - Disk

    /// A capacity-only snapshot whose `free` distinguishes it from its
    /// neighbours, built through the capacity initialiser the sampler uses.
    private func diskSnapshot(free: UInt64) -> DiskSnapshot {
        DiskSnapshot(
            total: 494_354_000_000,
            free: free,
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil
        )
    }

    @Test func freshStateHasNoDiskSnapshot() async {
        let state = await MetricsState()

        #expect(await state.disk == nil)
    }

    // disk-metrics — DM-11 "Apply stores the latest only"
    @Test func applyingTwoDiskSnapshotsKeepsOnlyTheSecond() async {
        let state = await MetricsState()
        let first = diskSnapshot(free: 62_286_000_000)
        let second = diskSnapshot(free: 12_000_000_000)

        await state.apply(disk: first)
        await state.apply(disk: second)

        #expect(await state.disk == second)
        #expect(await state.disk?.free == 12_000_000_000)
    }

    @Test func applyingADiskSnapshotStoresThatExactValue() async {
        let state = await MetricsState()

        await state.apply(disk: DiskFixtures.referenceSnapshot)

        #expect(await state.disk == DiskFixtures.referenceSnapshot)
        #expect(await state.disk?.readBytesPerSecond == 27_100_000)
    }

    // disk-metrics — DM-11 "Other state untouched"
    @Test func applyingDiskLeavesTheCPUAndMemoryStateAlone() async {
        let state = await MetricsState()

        await state.apply(disk: DiskFixtures.referenceSnapshot)

        #expect(await state.cpu == nil)
        #expect(await state.memory == nil)
        #expect(await state.cpuHistory.count == 0)
        #expect(await state.memoryHistory.count == 0)
        #expect(await state.disk != nil)
    }

    @Test func applyingCPUAndMemoryLeavesTheDiskStateAlone() async {
        let state = await MetricsState()

        await state.apply(cpu: snapshot(total: 0.42))
        await state.apply(memory: memorySnapshot(fraction: 0.42))

        #expect(await state.disk == nil)
        #expect(await state.cpu != nil)
        #expect(await state.memory != nil)
    }

    // disk-metrics — DM-11 "no disk history property exists". Reflection is the
    // only runtime evidence of an absence; the CPU label proves the mirror is
    // populated, so the disk assertion cannot pass vacuously.
    @Test func theStateExposesNoDiskHistoryProperty() async {
        let state = await MetricsState()

        let labels = await MainActor.run {
            Mirror(reflecting: state).children.compactMap(\.label)
        }

        #expect(labels.contains { $0.contains("cpuHistory") })
        #expect(labels.contains { $0.contains("memoryHistory") })
        #expect(
            labels.contains {
                let label = $0.lowercased()
                return label.contains("disk") && label.contains("history")
            } == false
        )
    }
}
