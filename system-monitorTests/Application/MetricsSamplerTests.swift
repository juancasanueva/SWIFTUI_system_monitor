import Foundation
import Synchronization
import Testing
@testable import system_monitor

@Suite("MetricsSampler sampling steps")
struct MetricsSamplerStepTests {

    /// Two samples 100 tick units apart, half of them idle.
    private func risingSamples(coreCount: Int = 2) -> [CPUTickSample] {
        [
            TickFixtures.sample(coreCount: coreCount, user: 0, system: 0, idle: 0, nice: 0),
            TickFixtures.sample(coreCount: coreCount, user: 50, system: 0, idle: 50, nice: 0),
            TickFixtures.sample(coreCount: coreCount, user: 100, system: 0, idle: 100, nice: 0)
        ]
    }

    @MainActor
    private func makeSampler(
        state: MetricsState,
        provider: FakeCPUProvider,
        memoryProvider: FakeMemoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB]),
        diskProvider: FakeDiskProvider = FakeDiskProvider(
            throughput: [],
            capacities: [DiskFixtures.referenceCapacity]
        ),
        topology: CoreTopology = TickFixtures.performanceFirstTopology
    ) -> MetricsSampler {
        MetricsSampler(
            state: state,
            cpuProvider: provider,
            memoryProvider: memoryProvider,
            diskProvider: diskProvider,
            topologyProvider: FakeCoreTopologyProvider(result: topology)
        )
    }

    // cpu-metrics — "One step publishes nothing"
    @Test func theFirstStepOnlyRetainsTheSample() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: risingSamples())
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.sampleOnce()

        #expect(await state.cpu == nil)
        #expect(await state.cpuHistory.count == 0)
        #expect(provider.callCount == 1)
    }

    // cpu-metrics — "Second step publishes"
    @Test func theSecondStepPublishesExactlyOneSnapshot() async throws {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: risingSamples(coreCount: 4))
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        let snapshot = try #require(await state.cpu)
        #expect(abs(snapshot.total - 0.5) < 1e-9)
        #expect(snapshot.cores.count == 4)
        #expect(await state.cpuHistory.count == 1)
        #expect(provider.callCount == 2)
    }

    @Test func eachFurtherStepPublishesOneMoreSnapshot() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: risingSamples())
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()
        await sampler.sampleOnce()

        #expect(await state.cpuHistory.count == 2)
    }

    @Test func snapshotCoresFollowTheTopologyFromTheProvider() async throws {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: risingSamples(coreCount: 4))
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            topology: TickFixtures.efficiencyFirstTopology
        )

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        let snapshot = try #require(await state.cpu)
        #expect(snapshot.cores.map(\.index) == [2, 3, 0, 1])
    }

    // cpu-metrics — "Throwing provider keeps looping"
    @Test func aThrowingReadPublishesNothingAndKeepsThePreviousSample() async throws {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: risingSamples(), throwOnCall: [1])
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.sampleOnce()   // retains sample 0
        await sampler.sampleOnce()   // throws, publishes nothing

        #expect(await state.cpu == nil)
        #expect(await state.cpuHistory.count == 0)

        await sampler.sampleOnce()   // succeeds over the longer window

        let snapshot = try #require(await state.cpu)
        #expect(abs(snapshot.total - 0.5) < 1e-9)
        #expect(await state.cpuHistory.count == 1)
        #expect(provider.callCount == 3)
    }

    @Test func stepAdvancesToTheNextPreviousSampleOnSuccess() throws {
        let samples = risingSamples()
        let provider = FakeCPUProvider(samples: samples)
        let step = CPUSamplingStep(
            provider: provider,
            topology: TickFixtures.performanceFirstTopology,
            previous: nil
        )

        let first = step.advanced()
        #expect(first.snapshot == nil)
        #expect(first.next.previous == samples[0])

        let second = first.next.advanced()
        let snapshot = try #require(second.snapshot)
        #expect(abs(snapshot.total - 0.5) < 1e-9)
        #expect(second.next.previous == samples[1])
    }

    @Test func stepKeepsItsPreviousSampleWhenTheReadThrows() {
        let samples = risingSamples()
        let provider = FakeCPUProvider(samples: samples, throwOnCall: [0])
        let step = CPUSamplingStep(
            provider: provider,
            topology: TickFixtures.performanceFirstTopology,
            previous: samples[0]
        )

        let result = step.advanced()

        #expect(result.snapshot == nil)
        #expect(result.next.previous == samples[0])
    }

    // MARK: - Memory

    // memory-metrics — MM-5: memory is absolute, so one read is a full reading.
    @Test func theMemoryStepConvertsOneReadIntoASnapshot() throws {
        let provider = FakeMemoryProvider(counts: [MemoryFixtures.reference])
        let step = MemorySamplingStep(provider: provider)

        let snapshot = try #require(step.read())

        #expect(snapshot.used == 6_787_694_592)
        #expect(snapshot.total == 8_589_934_592)
        #expect(provider.callCount == 1)
    }

    // memory-metrics — MM-7: a throwing read is swallowed into `nil`.
    @Test func theMemoryStepReadsNilWhenTheProviderThrows() {
        let provider = FakeMemoryProvider(counts: [MemoryFixtures.reference], throwOnCall: [0])
        let step = MemorySamplingStep(provider: provider)

        #expect(step.read() == nil)
        #expect(provider.callCount == 1)
    }

    // memory-metrics — MM-5 "First step publishes memory only"
    @Test func theFirstStepPublishesMemoryWhileTheCPUIsStillSeeding() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let memoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])
        let sampler = await makeSampler(state: state, provider: cpuProvider, memoryProvider: memoryProvider)

        await sampler.sampleOnce()

        let memory = try #require(await state.memory)
        #expect(memory.used == 5_926_092_800)
        #expect(await state.memoryHistory.count == 1)
        #expect(await state.cpu == nil)
        #expect(await state.cpuHistory.count == 0)
    }

    // memory-metrics — MM-5 "Second step publishes both"
    @Test func theSecondStepPublishesBothMetrics() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let memoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])
        let sampler = await makeSampler(state: state, provider: cpuProvider, memoryProvider: memoryProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        let cpu = try #require(await state.cpu)
        #expect(abs(cpu.total - 0.5) < 1e-9)
        #expect(await state.memory != nil)
        #expect(await state.memoryHistory.count == 2)
    }

    // memory-metrics — MM-6 "Call counts advance together"
    @Test func bothProvidersAreReadOncePerStep() async {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let memoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])
        let sampler = await makeSampler(state: state, provider: cpuProvider, memoryProvider: memoryProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()
        await sampler.sampleOnce()

        #expect(cpuProvider.callCount == 3)
        #expect(memoryProvider.callCount == 3)
    }

    // memory-metrics — MM-7 "Memory throws twice then recovers"
    @Test func aThrowingMemoryReadPublishesNothingAndRecoversOnTheNextStep() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let memoryProvider = FakeMemoryProvider(
            counts: [MemoryFixtures.eightGiB],
            throwOnCall: [0, 1]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, memoryProvider: memoryProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        #expect(await state.memory == nil)
        #expect(await state.memoryHistory.count == 0)
        #expect(await state.cpu != nil)

        await sampler.sampleOnce()

        let memory = try #require(await state.memory)
        #expect(memory.used == 5_926_092_800)
        #expect(await state.memoryHistory.count == 1)
    }

    // memory-metrics — MM-7 "Memory always throws"
    @Test func aPermanentlyFailingMemoryProviderNeverStopsTheCPU() async {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let memoryProvider = FakeMemoryProvider(
            counts: [MemoryFixtures.eightGiB],
            throwOnCall: [0, 1, 2, 3]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, memoryProvider: memoryProvider)

        for _ in 0..<4 {
            await sampler.sampleOnce()
        }

        #expect(await state.memory == nil)
        #expect(await state.memoryHistory.count == 0)
        #expect(await state.cpu != nil)
        #expect(await state.cpuHistory.count == 3)
        #expect(memoryProvider.callCount == 4)
    }

    // memory-metrics — MM-7 "CPU throws, memory still publishes"
    @Test func aThrowingCPUReadDoesNotPreventTheMemoryPublish() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples(), throwOnCall: [0])
        let memoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])
        let sampler = await makeSampler(state: state, provider: cpuProvider, memoryProvider: memoryProvider)

        await sampler.sampleOnce()

        let memory = try #require(await state.memory)
        #expect(memory.used == 5_926_092_800)
        #expect(await state.memoryHistory.count == 1)
        #expect(await state.cpu == nil)
        #expect(await state.cpuHistory.count == 0)
    }

    // MARK: - Disk
    //
    // Every scenario below drives `sampleOnce()` with scripted
    // `ContinuousClock.Instant`s derived from `DiskFixtures.base`, so the
    // cadence and the rates are read off the counters' own stamps and no case
    // waits on wall-clock time (convention 19).

    /// A capacity distinguishable from `DiskFixtures.referenceCapacity`, for
    /// the cases that must tell a refreshed reading from a cached one.
    private var refreshedCapacity: VolumeCapacity {
        VolumeCapacity(total: 494_354_000_000, free: 40_000_000_000)
    }

    // disk-metrics — DM-6 "First step publishes capacity without throughput"
    @Test func theFirstDiskStepPublishesCapacityWithBothRatesNil() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: [DiskFixtures.referencePrevious],
            capacities: [DiskFixtures.referenceCapacity]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()

        let disk = try #require(await state.disk)
        #expect(disk.total == 494_354_000_000)
        #expect(disk.free == 62_286_000_000)
        #expect(disk.readBytesPerSecond == nil)
        #expect(disk.writeBytesPerSecond == nil)
        #expect(await state.memory != nil)
        #expect(await state.cpu == nil)
    }

    // disk-metrics — DM-6 "Second step publishes rates"
    @Test func theSecondDiskStepPublishesTheReferenceRates() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: [DiskFixtures.referencePrevious, DiskFixtures.referenceCurrent],
            capacities: [DiskFixtures.referenceCapacity]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        let disk = try #require(await state.disk)
        #expect(disk.readBytesPerSecond == 27_100_000)
        #expect(disk.writeBytesPerSecond == 2_200_000)
        #expect(await state.cpu != nil)
    }

    // disk-metrics — DM-6 "Call counts advance together"
    @Test func allThreeProvidersAreReadOncePerStep() async {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let memoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])
        let diskProvider = FakeDiskProvider(
            throughput: DiskFixtures.climbing(steps: 3),
            capacities: [DiskFixtures.referenceCapacity]
        )
        let sampler = await makeSampler(
            state: state,
            provider: cpuProvider,
            memoryProvider: memoryProvider,
            diskProvider: diskProvider
        )

        await sampler.sampleOnce()
        await sampler.sampleOnce()
        await sampler.sampleOnce()

        #expect(cpuProvider.callCount == 3)
        #expect(memoryProvider.callCount == 3)
        #expect(diskProvider.throughputCallCount == 3)
    }

    // disk-metrics — DM-7 "One capacity read under 10 s"
    @Test func capacityIsReadOnceWhileEveryStampStaysUnderTenSeconds() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: [0, 1, 2, 9.999].map { seconds in
                DiskFixtures.counters(read: 1_000_000_000, written: 500_000_000, at: seconds)
            },
            capacities: [DiskFixtures.referenceCapacity, refreshedCapacity]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        var published: [UInt64] = []
        for _ in 0..<4 {
            await sampler.sampleOnce()
            published.append(try #require(await state.disk).free)
        }

        #expect(diskProvider.capacityCallCount == 1)
        #expect(diskProvider.throughputCallCount == 4)
        #expect(published == Array(repeating: 62_286_000_000, count: 4))
    }

    // disk-metrics — DM-7 "Refresh once the cadence is crossed"
    @Test func capacityIsReadAgainOnTheFirstStampTenSecondsLater() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: [0, 1, 2, 9.999, 10, 11].map { seconds in
                DiskFixtures.counters(read: 1_000_000_000, written: 500_000_000, at: seconds)
            },
            capacities: [DiskFixtures.referenceCapacity, refreshedCapacity]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        var published: [UInt64] = []
        for _ in 0..<6 {
            await sampler.sampleOnce()
            published.append(try #require(await state.disk).free)
        }

        #expect(diskProvider.capacityCallCount == 2)
        #expect(diskProvider.throughputCallCount == 6)
        #expect(published.prefix(4) == ArraySlice(Array(repeating: 62_286_000_000, count: 4)))
        #expect(published.suffix(2) == [40_000_000_000, 40_000_000_000])
    }

    // disk-metrics — DM-6, DM-7 at the value level: the step carries the
    // baseline, the cached capacity and the instant of the last capacity read
    // forward, exactly as `CPUSamplingStep` carries its previous sample.
    @Test func theDiskStepCarriesTheBaselineAndTheCapacityStampForward() throws {
        let counters = [DiskFixtures.referencePrevious, DiskFixtures.referenceCurrent]
        let provider = FakeDiskProvider(
            throughput: counters,
            capacities: [DiskFixtures.referenceCapacity]
        )
        let step = DiskSamplingStep(
            provider: provider,
            previous: nil,
            capacity: nil,
            capacityReadAt: nil
        )

        let first = step.advanced()
        let firstSnapshot = try #require(first.snapshot)
        #expect(firstSnapshot.readBytesPerSecond == nil)
        #expect(firstSnapshot.total == 494_354_000_000)
        #expect(first.next.previous == counters[0])
        #expect(first.next.capacity == DiskFixtures.referenceCapacity)
        #expect(first.next.capacityReadAt == counters[0].timestamp)

        let second = first.next.advanced()
        let secondSnapshot = try #require(second.snapshot)
        #expect(secondSnapshot.readBytesPerSecond == 27_100_000)
        #expect(second.next.previous == counters[1])
        #expect(second.next.capacityReadAt == counters[0].timestamp)
        #expect(provider.capacityCallCount == 1)
    }

    // MARK: - Disk failure isolation (DM-10)

    /// Counters whose read and write totals grow by the reference deltas at
    /// every scripted stamp, so any two of them produce non-nil rates.
    private func climbingCounters(at stamps: [Double]) -> [DiskThroughputCounters] {
        stamps.enumerated().map { index, seconds in
            DiskFixtures.counters(
                read: 1_000_000_000 + UInt64(index) * 27_100_000,
                written: 500_000_000 + UInt64(index) * 2_200_000,
                at: seconds
            )
        }
    }

    // disk-metrics — DM-10 "Throughput throws, capacity keeps rendering"
    @Test func aThroughputThrowStillPublishesTheCachedCapacity() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: climbingCounters(at: [0, 1]),
            capacities: [DiskFixtures.referenceCapacity],
            throwThroughputOnCall: [1]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        let disk = try #require(await state.disk)
        #expect(disk.free == 62_286_000_000)
        #expect(disk.readBytesPerSecond == nil)
        #expect(disk.writeBytesPerSecond == nil)
        #expect(await state.cpu != nil)
        #expect(diskProvider.throughputCallCount == 2)
    }

    // disk-metrics — DM-10, triangulating the case above: after a tick that
    // published real rates, the throwing tick must replace them with `nil`
    // rather than leave the stale pair on screen.
    @Test func aThroughputThrowReplacesPublishedRatesWithNil() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: climbingCounters(at: [0, 1, 2]),
            capacities: [DiskFixtures.referenceCapacity],
            throwThroughputOnCall: [2]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        #expect(try #require(await state.disk).readBytesPerSecond == 27_100_000)

        await sampler.sampleOnce()

        let disk = try #require(await state.disk)
        #expect(disk.readBytesPerSecond == nil)
        #expect(disk.writeBytesPerSecond == nil)
        #expect(disk.free == 62_286_000_000)
    }

    // disk-metrics — DM-10 "Throughput throw skips the refresh that tick"
    @Test func aThroughputThrowSkipsThatTicksCapacityRefresh() async {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: climbingCounters(at: [0, 11]),
            capacities: [DiskFixtures.referenceCapacity, refreshedCapacity],
            throwThroughputOnCall: [1]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()
        #expect(diskProvider.capacityCallCount == 1)

        await sampler.sampleOnce()   // the tick that would have crossed 10 s throws
        #expect(diskProvider.capacityCallCount == 1)

        await sampler.sampleOnce()   // stamped 11 s, so the refresh happens here
        #expect(diskProvider.capacityCallCount == 2)
        #expect(await state.disk?.free == 40_000_000_000)
    }

    // disk-metrics — DM-10 "Capacity throws before any success"
    @Test func aCapacityThrowBeforeAnySuccessPublishesNothingForDisk() async {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: climbingCounters(at: [0, 1]),
            capacities: [DiskFixtures.referenceCapacity],
            throwCapacityOnCall: [0, 1]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        #expect(await state.disk == nil)
        #expect(await state.memory != nil)
        #expect(diskProvider.capacityCallCount == 2)
        #expect(diskProvider.throughputCallCount == 2)
    }

    // disk-metrics — DM-10 "Capacity throws after a success"
    @Test func aCapacityThrowAfterASuccessKeepsTheCachedCapacity() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: climbingCounters(at: [0, 10]),
            capacities: [DiskFixtures.referenceCapacity, refreshedCapacity],
            throwCapacityOnCall: [1]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()
        await sampler.sampleOnce()

        let disk = try #require(await state.disk)
        #expect(disk.free == 62_286_000_000)
        #expect(disk.readBytesPerSecond == 2_710_000)
        #expect(diskProvider.capacityCallCount == 2)
    }

    // disk-metrics — DM-10 "CPU throws, disk still publishes"
    @Test func aThrowingCPUReadDoesNotPreventTheDiskPublish() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples(), throwOnCall: [0])
        let diskProvider = FakeDiskProvider(
            throughput: climbingCounters(at: [0]),
            capacities: [DiskFixtures.referenceCapacity]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()

        #expect(await state.disk != nil)
        #expect(await state.cpu == nil)
        #expect(await state.memory != nil)
    }

    // disk-metrics — the design's documented deviation from DM-10's SHOULD
    // (decision 2, `design.md:206`): a throwing first tick has no stamp, so it
    // reads capacity once, publishes it with nil rates, and leaves
    // `capacityReadAt` unset so the next stamped tick reads capacity again.
    @Test func aThroughputThrowWithNothingCachedReadsCapacityExactlyOnce() async throws {
        let state = await MetricsState()
        let cpuProvider = FakeCPUProvider(samples: risingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: climbingCounters(at: [5]),
            capacities: [DiskFixtures.referenceCapacity, refreshedCapacity],
            throwThroughputOnCall: [0]
        )
        let sampler = await makeSampler(state: state, provider: cpuProvider, diskProvider: diskProvider)

        await sampler.sampleOnce()

        let firstDisk = try #require(await state.disk)
        #expect(firstDisk.free == 62_286_000_000)
        #expect(firstDisk.readBytesPerSecond == nil)
        #expect(diskProvider.capacityCallCount == 1)

        await sampler.sampleOnce()

        #expect(diskProvider.capacityCallCount == 2)
        #expect(await state.disk?.free == 40_000_000_000)
    }

    // The same deviation at the value level: the step returned by a throwing
    // first tick carries the capacity but no stamp for it.
    @Test func theStepFromAThrowingFirstTickCachesCapacityWithoutAStamp() throws {
        let provider = FakeDiskProvider(
            throughput: [DiskFixtures.referencePrevious],
            capacities: [DiskFixtures.referenceCapacity],
            throwThroughputOnCall: [0]
        )
        let step = DiskSamplingStep(
            provider: provider,
            previous: nil,
            capacity: nil,
            capacityReadAt: nil
        )

        let result = step.advanced()

        #expect(try #require(result.snapshot).total == 494_354_000_000)
        #expect(result.next.capacity == DiskFixtures.referenceCapacity)
        #expect(result.next.capacityReadAt == nil)
        #expect(result.next.previous == nil)
        #expect(provider.capacityCallCount == 1)
    }
}

// cpu-metrics — CM-1, CM-2 and CM-3.
//
// The whole suite runs on `ManualClock`: no case sleeps on wall-clock time and
// none polls a wall-clock source, so every timing claim is read off the clock's
// own sleepers instead of raced against a real deadline (debt W1/W5 retired).
// The `.timeLimit` is the only safety net left (convention 5); each wait is the
// deterministic rendezvous `awaitSleepCount(_:)`.
//
// Clock time advances one interval at a time, always followed by a rendezvous:
// the loop registers its next sleep only after it has run, so a single large
// advance would resume one iteration rather than replay the ones it skipped.
@Suite("MetricsSampler loop", .timeLimit(.minutes(1)))
struct MetricsSamplerLoopTests {

    /// A long script so a fast or restarting loop never runs out of distinct
    /// samples and starts reporting zero deltas.
    private func climbingSamples(coreCount: Int = 2, steps: Int = 400) -> [CPUTickSample] {
        (0..<steps).map { step in
            TickFixtures.sample(
                coreCount: coreCount,
                user: UInt32(step * 50),
                system: 0,
                idle: UInt32(step * 50),
                nice: 0
            )
        }
    }

    /// The clock is required rather than defaulted: a wall-clock sampler has no
    /// place in this suite any more.
    @MainActor
    private func makeSampler(
        state: MetricsState,
        provider: FakeCPUProvider,
        memoryProvider: FakeMemoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB]),
        diskProvider: FakeDiskProvider = FakeDiskProvider(
            throughput: [],
            capacities: [DiskFixtures.referenceCapacity]
        ),
        interval: Duration = .seconds(1),
        clock: ManualClock
    ) -> MetricsSampler {
        MetricsSampler(
            state: state,
            cpuProvider: provider,
            memoryProvider: memoryProvider,
            diskProvider: diskProvider,
            topologyProvider: FakeCoreTopologyProvider(result: TickFixtures.performanceFirstTopology),
            interval: interval,
            clock: clock
        )
    }

    /// A store seeded with the configured cadence, for the cases that drive the
    /// loop through `SamplingCadenceController`.
    private func settingsStore(configured: Duration) -> FakeSettingsStore {
        FakeSettingsStore(
            stored: Settings(samplingInterval: configured, menuBarModules: [.cpu, .memory])
        )
    }

    // MARK: - Startup, cadence and cancellation

    // cpu-metrics — CM-3 "Startup under a manual clock" and "Real value within
    // 200 ms": the first iteration only seeds the CPU delta and publishes
    // memory; the second, one startup gap later, publishes a real CPU value.
    @Test func startSeedsTheDeltaThenPublishesAfterTheStartupGap() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)

        #expect(await state.cpu == nil)
        #expect(await state.cpuHistory.count == 0)
        #expect(await state.memoryHistory.count == 1)
        #expect(clock.pendingDeadlines == [.milliseconds(100)])

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        #expect(await state.cpu != nil)
        #expect(await state.cpuHistory.count == 1)
        #expect(clock.pendingDeadlines == [.milliseconds(1100)])

        clock.advance(by: .seconds(1))
        await clock.awaitSleepCount(3)

        #expect(await state.cpuHistory.count == 2)
        #expect(await sampler.isRunning)

        await sampler.stop()
    }

    // cpu-metrics — "Injected interval drives the loop": the next sample lands
    // on the injected interval and not a millisecond before it.
    @Test func theInjectedIntervalIsExactlyWhenTheNextSampleLands() async {
        let interval = Duration.seconds(2)
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: interval,
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        var published = await state.cpuHistory.count
        #expect(published == 1)

        for round in 0..<3 {
            clock.advance(by: interval - .milliseconds(1))

            // One millisecond short of the deadline nothing has been resumed,
            // so the count cannot have moved.
            #expect(await state.cpuHistory.count == published)

            clock.advance(by: .milliseconds(1))
            await clock.awaitSleepCount(3 + round)
            published += 1

            #expect(await state.cpuHistory.count == published)
        }

        #expect(await state.cpuHistory.count == 4)

        await sampler.stop()
    }

    // cpu-metrics — "Stop cancels" and CM-3 "Stop under a manual clock":
    // cancellation unparks the sleeper, so no later advance can wake it.
    @Test func stopUnparksTheLoopAndFreezesEveryCount() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        let frozenCPU = await state.cpuHistory.count
        let frozenMemory = await state.memoryHistory.count
        let reads = provider.callCount
        #expect(frozenCPU == 1)
        #expect(frozenMemory == 2)

        await sampler.stop()

        #expect(await sampler.isRunning == false)
        #expect(clock.pendingDeadlines.isEmpty)

        clock.advance(by: .seconds(5))

        #expect(await state.cpuHistory.count == frozenCPU)
        #expect(await state.memoryHistory.count == frozenMemory)
        #expect(provider.callCount == reads)
    }

    // cpu-metrics — a second `start()` must not create a second loop, or the
    // single `stop()` would leave an orphan publishing forever.
    @Test func startIsIdempotentSoOnlyOneLoopEverRuns() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await sampler.start()
        await clock.awaitSleepCount(1)

        // A second loop would have parked its own sleeper at the same deadline.
        #expect(clock.pendingDeadlines == [.milliseconds(100)])

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        #expect(clock.sleepCount == 2)
        #expect(clock.pendingDeadlines == [.milliseconds(1100)])
        #expect(await state.cpuHistory.count == 1)

        await sampler.stop()

        let frozen = await state.cpuHistory.count
        clock.advance(by: .seconds(5))

        #expect(clock.pendingDeadlines.isEmpty)
        #expect(await state.cpuHistory.count == frozen)
    }

    // cpu-metrics — "Off-main sampling"; memory-metrics — MM-8 "Off-main read".
    //
    // `sampleOnce()` runs inline on the main actor by design, so the loop is the
    // only place where either read's thread can be asserted.
    @Test func everyReadHappensOffTheMainThread() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let memoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])
        let diskProvider = FakeDiskProvider(
            throughput: DiskFixtures.climbing(),
            capacities: [DiskFixtures.referenceCapacity]
        )
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            memoryProvider: memoryProvider,
            diskProvider: diskProvider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)
        await sampler.stop()

        let recorded = provider.readOnMainThread
        #expect(recorded.count == 2)
        #expect(recorded.allSatisfy { $0 == false })

        let memoryReads = memoryProvider.readOnMainThread
        #expect(memoryReads.count == 2)
        #expect(memoryReads.allSatisfy { $0 == false })
        #expect(await state.memory != nil)

        // disk-metrics — DM-9 "Off-main reads". Both halves of the port append
        // to one list in call order, so its length is the two throughput reads
        // plus the single capacity read the cadence allowed.
        let diskReads = diskProvider.readOnMainThread
        #expect(diskProvider.throughputCallCount == 2)
        #expect(diskProvider.capacityCallCount == 1)
        #expect(diskReads.count == 3)
        #expect(diskReads.allSatisfy { $0 == false })
        #expect(await state.disk != nil)
    }

    // cpu-metrics — CM-3 "No wall-clock dependency": ten published snapshots,
    // ten advances, and not a microsecond of real waiting.
    @Test func tenIterationsRunWithoutAnyWallClockTime() async {
        let interval = Duration.seconds(5)
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: interval,
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)

        // The startup gap has not elapsed yet: nothing but memory is published.
        #expect(await state.cpuHistory.count == 0)

        for iteration in 1...10 {
            clock.advance(by: interval)
            await clock.awaitSleepCount(iteration + 1)

            #expect(await state.cpuHistory.count == iteration)
        }

        #expect(await state.cpuHistory.count == 10)
        #expect(clock.now == ManualClock.Instant(offset: .seconds(50)))
        #expect(await sampler.isRunning)

        await sampler.stop()
    }

    // cpu-metrics — CM-1 "Loop keeps running while closed": the loop never
    // stops with the panel, it only slows to the idle cadence.
    @Test func theLoopKeepsRunningAtTheIdleCadenceWhileThePanelIsClosed() async {
        let idle = SamplingCadence.effective(configured: .seconds(1), panelOpen: false)
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: idle,
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        let baseline = await state.cpuHistory.count
        #expect(baseline == 1)

        for round in 1...5 {
            clock.advance(by: idle)
            await clock.awaitSleepCount(2 + round)
        }

        // Ten seconds of clock time produced five samples, not ten.
        #expect(clock.now == ManualClock.Instant(offset: .milliseconds(10_100)))
        #expect(await state.cpuHistory.count == baseline + 5)
        #expect(await sampler.isRunning)

        await sampler.stop()
    }

    // cpu-metrics — CM-1 "Opening the panel restarts at the configured rate":
    // the transition arrives through `SamplingCadenceController`, exactly as the
    // popover delegate delivers it in the app.
    @Test func openingThePanelRestartsTheLoopAtTheConfiguredRate() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let settings = await SettingsState(store: settingsStore(configured: .seconds(1)))
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: SamplingCadence.effective(configured: .seconds(1), panelOpen: false),
            clock: clock
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        let beforeOpen = await state.cpuHistory.count
        #expect(clock.pendingDeadlines == [.milliseconds(2100)])

        await controller.panelDidOpen()
        await clock.awaitSleepCount(3)

        // Exactly one restart, parked at the new loop's startup gap; the
        // re-seeded CPU delta means nothing new has been published yet.
        #expect(clock.sleepCount == 3)
        #expect(clock.pendingDeadlines == [.milliseconds(200)])
        #expect(await state.cpuHistory.count == beforeOpen)

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(4)

        #expect(await state.cpuHistory.count == beforeOpen + 1)
        #expect(clock.pendingDeadlines == [.milliseconds(1200)])

        await sampler.stop()
    }

    // MARK: - CM-2 runtime interval change
    //
    // Every case below drives the same `ManualClock`, so "the next gap is 3 s"
    // is read straight off `pendingDeadlines` rather than inferred from elapsed
    // time. The loop is always parked on a registered sleep before an assertion
    // runs, which is what `awaitSleepCount(_:)` guarantees.

    // cpu-metrics — CM-2 "Stored while stopped": nothing runs, the value is
    // simply what the next `start()` will use.
    @Test func anIntervalAppliedWhileStoppedIsUsedByTheNextStart() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.apply(interval: .seconds(3))

        #expect(await sampler.interval == .seconds(3))
        #expect(await sampler.isRunning == false)
        #expect(clock.sleepCount == 0)

        await sampler.start()
        await clock.awaitSleepCount(1)

        #expect(clock.pendingDeadlines == [.milliseconds(100)])

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        // The gap after the startup gap is the stored 3 s, not the 1 s the
        // sampler was constructed with.
        #expect(clock.pendingDeadlines == [.milliseconds(3100)])
        #expect(await state.cpuHistory.count == 1)

        await sampler.stop()
    }

    // cpu-metrics — CM-2 "One restart while running": exactly one new sleeper
    // appears, parked at the restarted loop's startup gap.
    @Test func anIntervalAppliedWhileRunningRestartsTheLoopExactlyOnce() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        #expect(clock.pendingDeadlines == [.milliseconds(1100)])

        await sampler.apply(interval: .seconds(2))
        await clock.awaitSleepCount(3)

        #expect(await sampler.interval == .seconds(2))
        #expect(await sampler.isRunning)
        #expect(clock.sleepCount == 3)
        #expect(clock.pendingDeadlines == [.milliseconds(200)])

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(4)

        #expect(clock.pendingDeadlines == [.milliseconds(2200)])

        await sampler.stop()
    }

    // cpu-metrics — CM-2 "Restart costs one publish-free CPU tick": the new
    // task re-seeds the CPU delta, so its first iteration publishes memory only.
    @Test func aRestartCostsOnePublishFreeCPUTickAndNoMemoryGap() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let memoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            memoryProvider: memoryProvider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        #expect(await state.cpuHistory.count == 1)
        #expect(await state.memoryHistory.count == 2)

        await sampler.apply(interval: .seconds(2))
        await clock.awaitSleepCount(3)

        #expect(await state.cpuHistory.count == 1)
        #expect(await state.memoryHistory.count == 3)

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(4)

        // The iteration after the restart's startup gap publishes CPU again.
        #expect(await state.cpuHistory.count == 2)
        #expect(await state.memoryHistory.count == 4)

        await sampler.stop()
    }

    // cpu-metrics — CM-2 "Unchanged interval is a no-op": no restart means no
    // new sleeper and no extra provider read, so the CPU delta survives.
    @Test func applyingTheIntervalAlreadyInEffectDoesNotRestartTheLoop() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        let readsBefore = provider.callCount

        await sampler.apply(interval: .seconds(1))

        #expect(clock.sleepCount == 2)
        #expect(clock.pendingDeadlines == [.milliseconds(1100)])
        #expect(provider.callCount == readsBefore)
        #expect(await state.cpuHistory.count == 1)

        await sampler.stop()
    }

    // MARK: - DM-8 runtime interval change, disk half

    // disk-metrics — DM-8 "Restart costs one throughput-unavailable tick": the
    // restarted loop builds a fresh `DiskSamplingStep`, so its first iteration
    // has no baseline and no capacity stamp. It mirrors
    // `aRestartCostsOnePublishFreeCPUTickAndNoMemoryGap`, except that disk
    // still publishes — the capacity, with both rates `nil`.
    @Test func aRestartCostsOneThroughputUnavailableDiskTick() async throws {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: DiskFixtures.climbing(),
            capacities: [DiskFixtures.referenceCapacity]
        )
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            diskProvider: diskProvider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        #expect(try #require(await state.disk).readBytesPerSecond == 27_100_000)
        #expect(diskProvider.capacityCallCount == 1)

        await sampler.apply(interval: .seconds(2))
        await clock.awaitSleepCount(3)

        let afterRestart = try #require(await state.disk)
        #expect(afterRestart.readBytesPerSecond == nil)
        #expect(afterRestart.writeBytesPerSecond == nil)
        #expect(afterRestart.total == 494_354_000_000)
        #expect(diskProvider.capacityCallCount == 2)

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(4)

        let recovered = try #require(await state.disk)
        #expect(recovered.readBytesPerSecond == 27_100_000)
        #expect(recovered.writeBytesPerSecond == 2_200_000)
        #expect(diskProvider.capacityCallCount == 2)

        await sampler.stop()
    }

    // disk-metrics — DM-8 "Unchanged interval keeps the baseline": no restart,
    // so the running loop keeps the step it already has.
    @Test func applyingTheIntervalAlreadyInEffectKeepsTheDiskBaseline() async throws {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let diskProvider = FakeDiskProvider(
            throughput: DiskFixtures.climbing(),
            capacities: [DiskFixtures.referenceCapacity]
        )
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: provider,
            diskProvider: diskProvider,
            interval: .seconds(1),
            clock: clock
        )

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        await sampler.apply(interval: .seconds(1))

        clock.advance(by: .seconds(1))
        await clock.awaitSleepCount(3)

        let disk = try #require(await state.disk)
        #expect(disk.readBytesPerSecond == 27_100_000)
        #expect(disk.writeBytesPerSecond == 2_200_000)
        #expect(diskProvider.capacityCallCount == 1)
        #expect(clock.sleepCount == 3)

        await sampler.stop()
    }
}

/// Mutex-backed box shared with detached tasks.
///
/// A bare `Mutex` local cannot be captured by an escaping closure because it is
/// non-copyable, so the recorded value lives behind a `final class` exactly as
/// the fakes do.
nonisolated final class ClockProbe<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>

    init(_ value: Value) {
        self.storage = Mutex(value)
    }

    var value: Value {
        storage.withLock { $0 }
    }

    func mutate(_ body: (inout Value) -> Void) {
        storage.withLock { body(&$0) }
    }
}

// cpu-metrics — CM-3 harness self-check. `ManualClock` is the prerequisite for
// every loop test, so its own advance, rendezvous and cancellation semantics are
// pinned here before any suite depends on them.
@Suite("ManualClock", .timeLimit(.minutes(1)))
struct ManualClockTests {

    // cpu-metrics — CM-3: `advance` moves `now` and nothing else.
    @Test func advanceMovesNowAndTheClockHasNoResolutionFloor() {
        let clock = ManualClock()

        #expect(clock.now == ManualClock.Instant(offset: .zero))
        #expect(clock.minimumResolution == .zero)

        clock.advance(by: .milliseconds(250))

        #expect(clock.now == ManualClock.Instant(offset: .milliseconds(250)))
        #expect(clock.sleepCount == 0)
        #expect(clock.pendingDeadlines.isEmpty)
    }

    // cpu-metrics — CM-3: `advance` resumes only the sleepers whose deadline it
    // reached; a later one stays parked with its deadline intact.
    @Test func advanceResumesDueSleepersAndLeavesLaterOnesParked() async {
        let clock = ManualClock()
        let woken = ClockProbe<[String]>([])

        let late = Task.detached {
            try? await clock.sleep(for: .seconds(3))
            woken.mutate { $0.append("late") }
        }
        let early = Task.detached {
            try? await clock.sleep(for: .seconds(1))
            woken.mutate { $0.append("early") }
        }

        await clock.awaitSleepCount(2)
        #expect(clock.pendingDeadlines == [.seconds(1), .seconds(3)])

        clock.advance(by: .seconds(1))
        await early.value

        #expect(woken.value == ["early"])
        #expect(clock.pendingDeadlines == [.seconds(3)])

        clock.advance(by: .seconds(2))
        await late.value

        #expect(woken.value == ["early", "late"])
        #expect(clock.pendingDeadlines.isEmpty)
        #expect(clock.sleepCount == 2)
    }

    // cpu-metrics — CM-3: one large advance resumes only the sleeper parked at
    // that moment, so a loop can never replay iterations it never ran. This is
    // why the loop tests advance one interval at a time.
    @Test func oneLargeAdvanceResumesOnlyTheSleeperParkedAtThatMoment() async {
        let clock = ManualClock()
        let iterations = ClockProbe<Int>(0)

        let loop = Task.detached {
            while !Task.isCancelled {
                iterations.mutate { $0 += 1 }
                do {
                    try await clock.sleep(for: .seconds(1))
                } catch {
                    break
                }
            }
        }

        await clock.awaitSleepCount(1)
        #expect(iterations.value == 1)

        clock.advance(by: .seconds(10))
        await clock.awaitSleepCount(2)

        #expect(iterations.value == 2)
        #expect(clock.pendingDeadlines == [.seconds(11)])

        loop.cancel()
        await loop.value
    }

    // cpu-metrics — CM-3: the rendezvous returns immediately once the count is
    // already reached, so a test never polls.
    @Test func awaitSleepCountReturnsImmediatelyOnceTheCountIsReached() async {
        let clock = ManualClock()
        let sleeper = Task.detached { try? await clock.sleep(for: .seconds(1)) }

        await clock.awaitSleepCount(1)
        await clock.awaitSleepCount(1)

        #expect(clock.sleepCount == 1)

        clock.advance(by: .seconds(1))
        await sleeper.value

        #expect(clock.pendingDeadlines.isEmpty)
    }

    // cpu-metrics — CM-3: cancelling a parked sleeper resumes it with
    // `CancellationError` and unparks it, which is how `stop()` ends the loop.
    @Test func cancellingAParkedSleeperThrowsCancellationErrorAndUnparksIt() async {
        let clock = ManualClock()
        let outcome = ClockProbe<String>("pending")

        let sleeper = Task.detached {
            do {
                try await clock.sleep(for: .seconds(5))
                outcome.mutate { $0 = "completed" }
            } catch is CancellationError {
                outcome.mutate { $0 = "cancelled" }
            } catch {
                outcome.mutate { $0 = "other" }
            }
        }

        await clock.awaitSleepCount(1)
        #expect(clock.pendingDeadlines == [.seconds(5)])

        sleeper.cancel()
        await sleeper.value

        #expect(outcome.value == "cancelled")
        #expect(clock.pendingDeadlines.isEmpty)
    }

    // cpu-metrics — CM-3: a deadline that already passed never parks.
    @Test func aDeadlineInThePastResumesWithoutParking() async throws {
        let clock = ManualClock()
        clock.advance(by: .seconds(10))

        try await clock.sleep(until: ManualClock.Instant(offset: .seconds(1)), tolerance: nil)

        #expect(clock.sleepCount == 1)
        #expect(clock.pendingDeadlines.isEmpty)
    }
}
