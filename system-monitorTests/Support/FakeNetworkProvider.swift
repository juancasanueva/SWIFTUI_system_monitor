import Foundation
import Synchronization
@testable import system_monitor

/// Scripted `NetworkMetricsProvider` double.
///
/// It mirrors `FakeDiskProvider`: `Sendable` without `@unchecked` because the
/// only stored property is a `let` `Mutex`, which lets the sampler's detached
/// loop and the test thread read the recorded calls safely. The port has one
/// read, so there is a single script, cursor and call count.
nonisolated final class FakeNetworkProvider: NetworkMetricsProvider {

    /// Error thrown on the call indexes configured through `throwOnCall`.
    nonisolated struct ScriptedError: Error, Equatable {}

    nonisolated private struct Script: Sendable {
        var counters: [NetworkThroughputCounters]
        var cursor = 0
        var throwOnCall: Set<Int>
        var callCount = 0

        /// `Thread.isMainThread` recorded at every read.
        var readOnMainThread: [Bool] = []
    }

    private let script: Mutex<Script>

    init(counters: [NetworkThroughputCounters], throwOnCall: Set<Int> = []) {
        self.script = Mutex(Script(counters: counters, throwOnCall: throwOnCall))
    }

    /// Returns the next scripted counters, repeating the last ones once
    /// exhausted.
    ///
    /// Throws `ScriptedError` on the zero-based call indexes in `throwOnCall`.
    /// A throwing call still advances `callCount` but never the value cursor.
    /// An empty script reads `NetworkFixtures.idle`, whose `interfaceCount` of
    /// 0 keeps the rates `nil`.
    func readCounters() throws -> NetworkThroughputCounters {
        try script.withLock { script in
            let call = script.callCount
            script.callCount += 1
            script.readOnMainThread.append(Thread.isMainThread)

            if script.throwOnCall.contains(call) {
                throw ScriptedError()
            }

            guard !script.counters.isEmpty else {
                return NetworkFixtures.idle
            }

            let index = min(script.cursor, script.counters.count - 1)
            script.cursor = index + 1
            return script.counters[index]
        }
    }

    var callCount: Int {
        script.withLock { $0.callCount }
    }

    var readOnMainThread: [Bool] {
        script.withLock { $0.readOnMainThread }
    }
}
