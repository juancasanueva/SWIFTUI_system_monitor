import Foundation
import Synchronization
@testable import system_monitor

/// Scripted `DiskMetricsProvider` double.
///
/// It mirrors `FakeMemoryProvider`: `Sendable` without `@unchecked` because the
/// only stored property is a `let` `Mutex`, which lets the sampler's detached
/// loop and the test thread read the recorded calls safely. The two halves of
/// the port keep independent scripts, cursors and counters, so a scripted
/// throughput failure never disturbs the capacity script.
nonisolated final class FakeDiskProvider: DiskMetricsProvider {

    /// Error thrown on the call indexes configured through
    /// `throwThroughputOnCall` and `throwCapacityOnCall`.
    nonisolated struct ScriptedError: Error, Equatable {}

    nonisolated private struct Script: Sendable {
        var throughput: [DiskThroughputCounters]
        var throughputCursor = 0
        var throwThroughputOnCall: Set<Int>
        var throughputCallCount = 0

        var capacities: [VolumeCapacity]
        var capacityCursor = 0
        var throwCapacityOnCall: Set<Int>
        var capacityCallCount = 0

        /// `Thread.isMainThread` recorded at every read of either kind.
        var readOnMainThread: [Bool] = []
    }

    private let script: Mutex<Script>

    init(
        throughput: [DiskThroughputCounters],
        capacities: [VolumeCapacity],
        throwThroughputOnCall: Set<Int> = [],
        throwCapacityOnCall: Set<Int> = []
    ) {
        self.script = Mutex(
            Script(
                throughput: throughput,
                throwThroughputOnCall: throwThroughputOnCall,
                capacities: capacities,
                throwCapacityOnCall: throwCapacityOnCall
            )
        )
    }

    /// Returns the next scripted counters, repeating the last ones once
    /// exhausted.
    ///
    /// Throws `ScriptedError` on the zero-based call indexes in
    /// `throwThroughputOnCall`. A throwing call still advances
    /// `throughputCallCount` but never the value cursor. An empty script reads
    /// `DiskFixtures.idle`, whose `driverCount` of 0 keeps the rates `nil`.
    func readThroughput() throws -> DiskThroughputCounters {
        try script.withLock { script in
            let call = script.throughputCallCount
            script.throughputCallCount += 1
            script.readOnMainThread.append(Thread.isMainThread)

            if script.throwThroughputOnCall.contains(call) {
                throw ScriptedError()
            }

            guard !script.throughput.isEmpty else {
                return DiskFixtures.idle
            }

            let index = min(script.throughputCursor, script.throughput.count - 1)
            script.throughputCursor = index + 1
            return script.throughput[index]
        }
    }

    /// Returns the next scripted capacity, repeating the last one once
    /// exhausted.
    ///
    /// Throws `ScriptedError` on the zero-based call indexes in
    /// `throwCapacityOnCall`, with the same count-advances/cursor-holds rule as
    /// the throughput half. An empty script reads
    /// `DiskFixtures.referenceCapacity`.
    func readCapacity() throws -> VolumeCapacity {
        try script.withLock { script in
            let call = script.capacityCallCount
            script.capacityCallCount += 1
            script.readOnMainThread.append(Thread.isMainThread)

            if script.throwCapacityOnCall.contains(call) {
                throw ScriptedError()
            }

            guard !script.capacities.isEmpty else {
                return DiskFixtures.referenceCapacity
            }

            let index = min(script.capacityCursor, script.capacities.count - 1)
            script.capacityCursor = index + 1
            return script.capacities[index]
        }
    }

    var throughputCallCount: Int {
        script.withLock { $0.throughputCallCount }
    }

    var capacityCallCount: Int {
        script.withLock { $0.capacityCallCount }
    }

    var readOnMainThread: [Bool] {
        script.withLock { $0.readOnMainThread }
    }
}
