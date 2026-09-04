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

/// Drives CPU sampling and publishes each reading to `MetricsState`.
///
/// The sampler itself is main-actor bound so AppKit can start and stop it
/// synchronously, but the sampling work runs in a detached task; only the
/// resulting `CPUSnapshot` value crosses back to the main actor.
@MainActor
final class MetricsSampler {

    private let state: MetricsState
    private let cpuProvider: any CPUMetricsProvider
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
        topologyProvider: any CoreTopologyProvider,
        interval: Duration = .seconds(1),
        startupGap: Duration = .milliseconds(100),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.state = state
        self.cpuProvider = cpuProvider
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
            // The first read only seeds `previous`, so the second one follows
            // after a short gap and a real value appears almost immediately.
            var gap = startupGap

            while !Task.isCancelled {
                let (snapshot, next) = step.advanced()
                step = next

                if let snapshot {
                    await state.apply(cpu: snapshot)
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

    /// Test seam: advances one step inline on the main actor and publishes the
    /// resulting snapshot, if any.
    func sampleOnce() {
        let step = inlineStep ?? CPUSamplingStep(
            provider: cpuProvider,
            topology: topologyProvider.topology(),
            previous: nil
        )

        let (snapshot, next) = step.advanced()
        inlineStep = next

        if let snapshot {
            state.apply(cpu: snapshot)
        }
    }
}
