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

/// Stateful counterpart of `CPUSamplingStep` for the disk.
///
/// It carries three pieces of cross-tick state: the throughput baseline the
/// next rate is measured against, the last capacity that was read, and the
/// instant of that read. The instant is the tick's own throughput stamp rather
/// than a clock the step consults itself, so the cadence rule stays pure and
/// every scenario is reproducible from scripted counters alone.
///
/// Like `CPUSamplingStep` it declares no initialiser of its own: the
/// memberwise one is what both the detached loop and `sampleOnce()` use to
/// build a fresh step.
nonisolated struct DiskSamplingStep: Sendable {
    let provider: any DiskMetricsProvider
    let previous: DiskThroughputCounters?
    let capacity: VolumeCapacity?
    let capacityReadAt: ContinuousClock.Instant?

    /// Reads throughput on every tick, capacity only when the cadence rule
    /// allows it, and derives the snapshot for the elapsed window.
    ///
    /// Nothing is published until a capacity has been read at least once: the
    /// card renders a gauge, and a gauge without a total is not a reading.
    ///
    /// Both reads are swallowed, so a disk failure degrades this tick and never
    /// reaches the loop, the other metrics or the user (DM-10).
    func advanced() -> (snapshot: DiskSnapshot?, next: DiskSamplingStep) {
        guard let current = try? provider.readThroughput() else {
            return withoutThroughput()
        }

        var capacity = self.capacity
        var capacityReadAt = self.capacityReadAt

        if
            DiskCapacityCadence.shouldRefresh(lastReadAt: capacityReadAt, now: current.timestamp),
            let refreshed = try? provider.readCapacity()
        {
            capacity = refreshed
            capacityReadAt = current.timestamp
        }

        let rates = DiskThroughputCalculator.rates(previous: previous, current: current)

        // The baseline is always re-seeded with `current`, so a counter reset
        // costs exactly one tick of rates rather than a permanent gap (DM-4).
        let next = DiskSamplingStep(
            provider: provider,
            previous: current,
            capacity: capacity,
            capacityReadAt: capacityReadAt
        )

        guard let capacity else { return (nil, next) }

        return (snapshot(capacity: capacity, rates: rates), next)
    }

    /// Outcome of a tick whose throughput read threw.
    ///
    /// There is no stamp, so the cadence rule cannot be evaluated and the
    /// baseline is kept untouched: the next successful read simply measures a
    /// longer window. The cached capacity is republished with both rates `nil`,
    /// which is what keeps the gauge on screen while the rates fall back to the
    /// unavailable glyph (R10.9).
    ///
    /// When nothing was ever cached, capacity is read exactly once here so the
    /// card is not a permanent skeleton while throughput keeps failing. That is
    /// a deliberate deviation from DM-10's "SHOULD skip the cadence check"
    /// (design decision 2): `capacityReadAt` stays `nil`, so the read is not
    /// stamped and the next successful tick refreshes it — one extra read, once.
    private func withoutThroughput() -> (snapshot: DiskSnapshot?, next: DiskSamplingStep) {
        guard capacity == nil else {
            return (capacity.map { snapshot(capacity: $0, rates: nil) }, self)
        }

        guard let refreshed = try? provider.readCapacity() else {
            return (nil, self)
        }

        return (
            snapshot(capacity: refreshed, rates: nil),
            DiskSamplingStep(
                provider: provider,
                previous: previous,
                capacity: refreshed,
                capacityReadAt: nil
            )
        )
    }

    /// The published reading: a capacity, plus the rates when the window
    /// produced a pair. `nil` rates are what the card renders as unavailable.
    private func snapshot(
        capacity: VolumeCapacity,
        rates: DiskThroughputCalculator.Rates?
    ) -> DiskSnapshot {
        DiskSnapshot(
            total: capacity.total,
            free: capacity.free,
            readBytesPerSecond: rates?.readBytesPerSecond,
            writeBytesPerSecond: rates?.writeBytesPerSecond
        )
    }
}

/// Stateful counterpart of `DiskSamplingStep` without the capacity half.
///
/// Only the baseline crosses ticks: the totals are absolute, so a single read
/// is already a publishable reading, and the previous counters exist purely to
/// give the next one a window to divide by.
///
/// Like its siblings it declares no initialiser of its own: the memberwise one
/// is what both the detached loop and `sampleOnce()` use to build a fresh step.
nonisolated struct NetworkSamplingStep: Sendable {
    let provider: any NetworkMetricsProvider
    let previous: NetworkThroughputCounters?

    /// Reads the counters and derives the snapshot for the elapsed window.
    ///
    /// A successful read always publishes: the totals are absolute, so the
    /// first tick after a start shows them with both rates `nil` and the second
    /// one adds the rates. The baseline is always re-seeded with `current`, so
    /// a counter that fell costs exactly one tick of rates (NM-4).
    ///
    /// A failed read publishes nothing — there is no cached total worth
    /// republishing — and drops the baseline, which is where this parts company
    /// with `DiskSamplingStep`. The disk keeps its baseline and lets the next
    /// success measure a longer window, because its counters belong to a fixed
    /// set of drivers. Network counters are a sum over whichever interfaces
    /// passed the filter at read time, so a window spanning an unread tick may
    /// also span an interface appearing or disappearing, and the difference
    /// would be published as a spike. Dropping the baseline turns that into one
    /// rates-free tick instead (NM-8, design decision 3).
    func advanced() -> (snapshot: NetworkSnapshot?, next: NetworkSamplingStep) {
        guard let current = try? provider.readCounters() else {
            return (nil, NetworkSamplingStep(provider: provider, previous: nil))
        }

        let rates = NetworkThroughputCalculator.rates(previous: previous, current: current)

        return (
            NetworkSnapshot(
                totalIn: current.bytesIn,
                totalOut: current.bytesOut,
                downloadBytesPerSecond: rates?.downloadBytesPerSecond,
                uploadBytesPerSecond: rates?.uploadBytesPerSecond
            ),
            NetworkSamplingStep(provider: provider, previous: current)
        )
    }
}

/// Drives CPU, memory, disk and network sampling and publishes each reading to
/// `MetricsState`.
///
/// The sampler itself is main-actor bound so AppKit can start and stop it
/// synchronously, but the sampling work runs in a detached task; only the
/// resulting `CPUSnapshot`, `MemorySnapshot`, `DiskSnapshot` and
/// `NetworkSnapshot` values cross back to the main actor. All four providers
/// are read within the same iteration, before any publish, so the four readings
/// belong to the same tick.
///
/// The CPU delta, the disk throughput baseline and the network baseline all
/// live in the detached task, so a restart costs each of them exactly one
/// degraded tick: that is the whole price of an interval change (CM-2, DM-8,
/// NM-6).
@MainActor
final class MetricsSampler {

    private let state: MetricsState
    private let cpuProvider: any CPUMetricsProvider
    private let memoryProvider: any MemoryMetricsProvider
    private let diskProvider: any DiskMetricsProvider
    private let networkProvider: any NetworkMetricsProvider
    private let topologyProvider: any CoreTopologyProvider
    /// Cadence the loop sleeps for between iterations (CM-2).
    ///
    /// Mutable because the user can change it at runtime, but only through
    /// `apply(interval:)`: `start()` copies it into the detached task, so a
    /// silent assignment would not reach a running loop.
    private(set) var interval: Duration
    private let startupGap: Duration
    private let clock: any Clock<Duration>

    /// Step used by `sampleOnce()`; the detached loop keeps its own.
    private var inlineStep: CPUSamplingStep?

    /// Disk counterpart of `inlineStep`, so repeated `sampleOnce()` calls keep
    /// the throughput baseline and the cached capacity the way the loop does.
    private var inlineDiskStep: DiskSamplingStep?

    /// Network counterpart of `inlineDiskStep`, so repeated `sampleOnce()`
    /// calls keep the baseline the loop would have kept.
    private var inlineNetworkStep: NetworkSamplingStep?

    /// The running loop, `nil` while the sampler is stopped.
    private var task: Task<Void, Never>?

    init(
        state: MetricsState,
        cpuProvider: any CPUMetricsProvider,
        memoryProvider: any MemoryMetricsProvider,
        diskProvider: any DiskMetricsProvider,
        networkProvider: any NetworkMetricsProvider,
        topologyProvider: any CoreTopologyProvider,
        interval: Duration = .seconds(1),
        startupGap: Duration = .milliseconds(100),
        clock: any Clock<Duration> = ContinuousClock()
    ) {
        self.state = state
        self.cpuProvider = cpuProvider
        self.memoryProvider = memoryProvider
        self.diskProvider = diskProvider
        self.networkProvider = networkProvider
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
        let diskProvider = diskProvider
        let networkProvider = networkProvider
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
            // Built here rather than on the sampler so a restart always begins
            // with a fresh step: the first iteration of the new loop re-reads
            // capacity and re-seeds the throughput baseline, which is exactly
            // what DM-8 asks of an interval change, with no code in
            // `apply(interval:)` to say so.
            var diskStep = DiskSamplingStep(
                provider: diskProvider,
                previous: nil,
                capacity: nil,
                capacityReadAt: nil
            )
            // Built inside the closure for the same reason as the disk step,
            // and with the same price: a restart has no baseline, so its first
            // iteration publishes totals with both rates `nil` and the one
            // after it publishes rates again (NM-6).
            var networkStep = NetworkSamplingStep(provider: networkProvider, previous: nil)
            // The first CPU read only seeds `previous`, so the second one
            // follows after a short gap and a real value appears almost
            // immediately. Memory is absolute and publishes on iteration one;
            // disk publishes its capacity with no rates on that same iteration.
            var gap = startupGap

            while !Task.isCancelled {
                let (cpuSnapshot, next) = step.advanced()
                step = next

                // All four reads happen before any publish, so the four
                // readings belong to the same tick.
                let memorySnapshot = memoryStep.read()

                let (diskSnapshot, nextDisk) = diskStep.advanced()
                diskStep = nextDisk

                let (networkSnapshot, nextNetwork) = networkStep.advanced()
                networkStep = nextNetwork

                if let cpuSnapshot {
                    await state.apply(cpu: cpuSnapshot)
                }

                if let memorySnapshot {
                    await state.apply(memory: memorySnapshot)
                }

                if let diskSnapshot {
                    await state.apply(disk: diskSnapshot)
                }

                if let networkSnapshot {
                    await state.apply(network: networkSnapshot)
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

    /// Changes the sampling cadence at runtime (CM-2).
    ///
    /// The value is stored either way; a running loop is additionally restarted
    /// because `start()` copies the interval into the detached task and a task
    /// already parked in `clock.sleep` cannot pick up a new one. Applying the
    /// interval already in effect returns immediately, so an idle cadence
    /// refresh that resolves to the same value costs nothing.
    ///
    /// The restart re-seeds the CPU delta, so exactly one iteration after it
    /// publishes no CPU snapshot while memory still publishes on that same
    /// iteration (MM-5); the next iteration publishes CPU again. The disk step
    /// is discarded with it, so that same iteration publishes capacity with
    /// both rates `nil` and re-reads capacity regardless of its cadence (DM-8).
    /// The network step is discarded on the same terms and publishes its totals
    /// with both rates `nil` for one iteration (NM-6). That one degraded tick
    /// is the whole price of an interval change.
    func apply(interval newInterval: Duration) {
        guard newInterval != interval else { return }

        interval = newInterval

        guard isRunning else { return }

        stop()
        start()
    }

    /// Cancels the sampling loop. Calling it while stopped does nothing.
    func stop() {
        task?.cancel()
        task = nil
    }

    /// Test seam: runs one iteration inline on the main actor and publishes
    /// whatever it produced.
    ///
    /// It mirrors the loop body exactly — all four providers are read before
    /// any publish — except that it runs on the main actor, so it is never used
    /// to assert where a read happened.
    func sampleOnce() {
        let step = inlineStep ?? CPUSamplingStep(
            provider: cpuProvider,
            topology: topologyProvider.topology(),
            previous: nil
        )

        let (cpuSnapshot, next) = step.advanced()
        inlineStep = next

        let memorySnapshot = MemorySamplingStep(provider: memoryProvider).read()

        let diskStep = inlineDiskStep ?? DiskSamplingStep(
            provider: diskProvider,
            previous: nil,
            capacity: nil,
            capacityReadAt: nil
        )

        let (diskSnapshot, nextDisk) = diskStep.advanced()
        inlineDiskStep = nextDisk

        let networkStep = inlineNetworkStep ?? NetworkSamplingStep(
            provider: networkProvider,
            previous: nil
        )

        let (networkSnapshot, nextNetwork) = networkStep.advanced()
        inlineNetworkStep = nextNetwork

        if let cpuSnapshot {
            state.apply(cpu: cpuSnapshot)
        }

        if let memorySnapshot {
            state.apply(memory: memorySnapshot)
        }

        if let diskSnapshot {
            state.apply(disk: diskSnapshot)
        }

        if let networkSnapshot {
            state.apply(network: networkSnapshot)
        }
    }
}
