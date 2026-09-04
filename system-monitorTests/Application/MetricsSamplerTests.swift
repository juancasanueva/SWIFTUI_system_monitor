import Foundation
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
        topology: CoreTopology = TickFixtures.performanceFirstTopology
    ) -> MetricsSampler {
        MetricsSampler(
            state: state,
            cpuProvider: provider,
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
}

// Swift Testing only accepts whole minutes for `.timeLimit`; the per-test
// polling deadlines below keep every case well under a few seconds.
@Suite("MetricsSampler loop", .timeLimit(.minutes(1)))
struct MetricsSamplerLoopTests {

    /// A long script so a fast loop never runs out of distinct samples.
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

    /// Polls a condition until it holds or the deadline passes.
    private func waitUntil(
        timeout: Duration,
        _ condition: @Sendable () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return await condition()
    }

    @MainActor
    private func makeSampler(
        state: MetricsState,
        provider: FakeCPUProvider,
        interval: Duration = .milliseconds(10)
    ) -> MetricsSampler {
        MetricsSampler(
            state: state,
            cpuProvider: provider,
            topologyProvider: FakeCoreTopologyProvider(result: TickFixtures.performanceFirstTopology),
            interval: interval
        )
    }

    // cpu-metrics — "Real value within 200 ms"
    @Test func startPublishesARealValueWithinTwoHundredMilliseconds() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.start()
        defer { Task { @MainActor in sampler.stop() } }

        let published = await waitUntil(timeout: .milliseconds(200)) {
            await state.cpu != nil
        }

        #expect(published)
        #expect(await state.cpuHistory.count >= 1)
        #expect(await sampler.isRunning)
    }

    // cpu-metrics — "Injected interval drives the loop"
    @Test func theInjectedIntervalKeepsTheLoopPublishing() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.start()
        defer { Task { @MainActor in sampler.stop() } }

        let keptPublishing = await waitUntil(timeout: .milliseconds(1500)) {
            await state.cpuHistory.count >= 5
        }

        #expect(keptPublishing)
        let total = await state.cpu?.total
        #expect(total != nil)
    }

    // cpu-metrics — "Stop cancels"
    @Test func stopFreezesThePublishedCount() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.start()
        _ = await waitUntil(timeout: .milliseconds(1500)) {
            await state.cpuHistory.count >= 2
        }
        await sampler.stop()

        // Let any in-flight iteration land before taking the reference count.
        try? await Task.sleep(for: .milliseconds(50))
        let frozen = await state.cpuHistory.count

        // Five further intervals must not add anything.
        try? await Task.sleep(for: .milliseconds(150))

        #expect(frozen >= 2)
        #expect(await state.cpuHistory.count == frozen)
        #expect(await sampler.isRunning == false)
    }

    @Test func startIsIdempotentSoStopHaltsEveryIteration() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.start()
        await sampler.start()
        _ = await waitUntil(timeout: .milliseconds(1500)) {
            await state.cpuHistory.count >= 2
        }
        await sampler.stop()

        try? await Task.sleep(for: .milliseconds(50))
        let frozen = await state.cpuHistory.count
        let callsAfterStop = provider.callCount

        try? await Task.sleep(for: .milliseconds(150))

        // A second loop would have survived the single cancellation.
        #expect(await state.cpuHistory.count == frozen)
        #expect(provider.callCount == callsAfterStop)
    }

    // cpu-metrics — "Off-main sampling"
    @Test func everyReadHappensOffTheMainThread() async {
        let state = await MetricsState()
        let provider = FakeCPUProvider(samples: climbingSamples())
        let sampler = await makeSampler(state: state, provider: provider)

        await sampler.start()
        _ = await waitUntil(timeout: .milliseconds(1500)) {
            await state.cpuHistory.count >= 2
        }
        await sampler.stop()

        let recorded = provider.readOnMainThread
        #expect(recorded.count >= 2)
        #expect(recorded.allSatisfy { $0 == false })
    }
}
