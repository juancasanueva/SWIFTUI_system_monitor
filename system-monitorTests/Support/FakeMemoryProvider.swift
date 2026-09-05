import Foundation
import Synchronization
@testable import system_monitor

/// Scripted `MemoryMetricsProvider` double.
///
/// It mirrors `FakeCPUProvider`: `Sendable` without `@unchecked` because the
/// only stored property is a `let` `Mutex`, which lets the sampler's detached
/// loop and the test thread read the recorded calls safely.
nonisolated final class FakeMemoryProvider: MemoryMetricsProvider {

    /// Error thrown on the call indexes configured through `throwOnCall`.
    nonisolated struct ScriptedError: Error, Equatable {}

    nonisolated private struct Script: Sendable {
        var counts: [MemoryPageCounts]
        var cursor = 0
        var throwOnCall: Set<Int>
        var callCount = 0
        /// `Thread.isMainThread` recorded at each `readCounts()` call.
        var readOnMainThread: [Bool] = []
    }

    private let script: Mutex<Script>

    init(counts: [MemoryPageCounts], throwOnCall: Set<Int> = []) {
        self.script = Mutex(Script(counts: counts, throwOnCall: throwOnCall))
    }

    /// Returns the next scripted value, repeating the last one once exhausted.
    ///
    /// Throws `ScriptedError` on the zero-based call indexes in `throwOnCall`.
    /// A throwing call still advances `callCount` but never the value cursor.
    /// An empty script reads `MemoryFixtures.zero`.
    func readCounts() throws -> MemoryPageCounts {
        try script.withLock { script in
            let call = script.callCount
            script.callCount += 1
            script.readOnMainThread.append(Thread.isMainThread)

            if script.throwOnCall.contains(call) {
                throw ScriptedError()
            }

            guard !script.counts.isEmpty else {
                return MemoryFixtures.zero
            }

            let index = min(script.cursor, script.counts.count - 1)
            script.cursor = index + 1
            return script.counts[index]
        }
    }

    var callCount: Int {
        script.withLock { $0.callCount }
    }

    var readOnMainThread: [Bool] {
        script.withLock { $0.readOnMainThread }
    }
}
