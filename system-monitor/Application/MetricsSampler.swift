import Foundation

/// One sampling step, modelled as a value so a single iteration can run inside
/// the detached loop or inline in a test without duplicating the logic.
nonisolated struct CPUSamplingStep: Sendable {
    let provider: any CPUMetricsProvider
    let topology: CoreTopology
    let previous: CPUTickSample?

    /// Reads the next sample and computes the snapshot for the elapsed window.
    ///
    /// A failed read yields `(nil, self)`, so the previous sample survives and
    /// the next successful read simply measures a longer window.
    func advanced() -> (snapshot: CPUSnapshot?, next: CPUSamplingStep) {
        guard let current = try? provider.readTicks() else {
            return (nil, self)
        }

        let snapshot = CPUUsageCalculator.snapshot(
            previous: previous,
            current: current,
            topology: topology
        )

        return (
            snapshot,
            CPUSamplingStep(provider: provider, topology: topology, previous: current)
        )
    }
}

/// Stateless counterpart of `CPUSamplingStep`.
///
/// Memory is an absolute reading rather than a delta over a window, so there is
/// no previous sample to carry and one read is already a complete snapshot.
nonisolated struct MemorySamplingStep: Sendable {
    let provider: any MemoryMetricsProvider

    /// Reads the counters and derives the snapshot, or `nil` when the read
    /// fails. Swallowing the error here is what keeps a transient memory
    /// failure from touching the CPU step or ending the loop.
    func read() -> MemorySnapshot? {
        guard let counts = try? provider.readCounts() else { return nil }
        return MemoryUsageCalculator.snapshot(from: counts)
    }
}

/// Drives CPU and memory sampling and publishes each reading to `MetricsState`.
///
/// The sampler itself is main-actor bound so AppKit can start and stop it
/// synchronously, but the sampling work runs in a detached task; only the
/// resulting `CPUSnapshot` and `MemorySnapshot` values cross back to the main
/// actor. Both providers are read within the same iteration, before either
/// publish, so the two readings belong to the same tick.
@MainActor
final class MetricsSampler {

    private let state: MetricsState
    private let cpuProvider: any CPUMetricsProvider
    private let memoryProvider: any MemoryMetricsProvider
    private let topologyProvider: any CoreTopologyProvider
    private let interval: Duration
    private let startupGap: Duration
    private let clock: any Clock<Duration>

    /// Step used by `sampleOnce()`; the detached loop keeps its own.
    private var inlineStep: CPUSamplingStep?

    /// The running loop, `nil` while the sampler is stopped.
    private var task: Task<Void, Never>?

    init(
        state: MetricsState,
        cpuProvider: any CPUMetricsProvider,
        memoryProvider: any MemoryMetricsProvider,
        topologyProvider: any CoreTopologyProvider,
        interval: Duration = .seconds(1),
        startupGap: Duration = .milliseconds(100),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.state = state
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.topologyProvider = topologyProvider
        self.interval = interval
        self.startupGap = startupGap
        self.clock = clock
    }

    var isRunning: Bool { task != nil }

    /// Starts the sampling loop. Calling it again while running does nothing.
    ///
    /// The loop is `Task.detached` on purpose: a plain `Task` would inherit the
    /// main actor under the project's default isolation and run the Mach reads
    /// on the UI thread. Only `Sendable` values are captured.
    func start() {
        guard task == nil else { return }

        let state = state
        let provider = cpuProvider
        let memoryProvider = memoryProvider
        let topologyProvider = topologyProvider
        let interval = interval
        let startupGap = startupGap
        let clock = clock

        task = Task.detached(priority: .utility) {
            var step = CPUSamplingStep(
                provider: provider,
                topology: topologyProvider.topology(),
                previous: nil
            )
            let memoryStep = MemorySamplingStep(provider: memoryProvider)
            // The first CPU read only seeds `previous`, so the second one
            // follows after a short gap and a real value appears almost
            // immediately. Memory is absolute and publishes on iteration one.
            var gap = startupGap

            while !Task.isCancelled {
                let (cpuSnapshot, next) = step.advanced()
                step = next

                // Both reads happen before either publish, so the two readings
                // belong to the same tick.
                let memorySnapshot = memoryStep.read()

                if let cpuSnapshot {
                    await state.apply(cpu: cpuSnapshot)
                }

                if let memorySnapshot {
                    await state.apply(memory: memorySnapshot)
                }

                do {
                    try await clock.sleep(for: gap)
                } catch {
                    break
                }

                gap = interval
            }
        }
    }

    /// Cancels the sampling loop. Calling it while stopped does nothing.
    func stop() {
        task?.cancel()
        task = nil
    }

    /// Test seam: runs one iteration inline on the main actor and publishes
    /// whatever it produced.
    ///
    /// It mirrors the loop body exactly — both providers are read before either
    /// publish — except that it runs on the main actor, so it is never used to
    /// assert where a read happened.
    func sampleOnce() {
        let step = inlineStep ?? CPUSamplingStep(
            provider: cpuProvider,
            topology: topologyProvider.topology(),
            previous: nil
        )

        let (cpuSnapshot, next) = step.advanced()
        inlineStep = next

        let memorySnapshot = MemorySamplingStep(provider: memoryProvider).read()

        if let cpuSnapshot {
            state.apply(cpu: cpuSnapshot)
        }

        if let memorySnapshot {
            state.apply(memory: memorySnapshot)
        }
    }
}
