import Foundation
import Synchronization
@testable import system_monitor

/// Scripted `CPUMetricsProvider` double.
///
/// It is `Sendable` without `@unchecked` because the only stored property is a
/// `let` `Mutex`, which lets the sampler's detached loop and the test thread
/// read the recorded calls safely.
nonisolated final class FakeCPUProvider: CPUMetricsProvider {

    /// Error thrown on the call indexes configured through `throwOnCall`.
    nonisolated struct ScriptedError: Error, Equatable {}

    nonisolated private struct Script: Sendable {
        var samples: [CPUTickSample]
        var cursor = 0
        var throwOnCall: Set<Int>
        var callCount = 0
        /// `Thread.isMainThread` recorded at each `readTicks()` call.
        var readOnMainThread: [Bool] = []
    }

    private let script: Mutex<Script>

    init(samples: [CPUTickSample], throwOnCall: Set<Int> = []) {
        self.script = Mutex(Script(samples: samples, throwOnCall: throwOnCall))
    }

    /// Returns the next scripted sample, repeating the last one once exhausted.
    ///
    /// Throws `ScriptedError` on the zero-based call indexes in `throwOnCall`.
    /// A throwing call still advances `callCount` but never the sample cursor.
    func readTicks() throws -> CPUTickSample {
        try script.withLock { script in
            let call = script.callCount
            script.callCount += 1
            script.readOnMainThread.append(Thread.isMainThread)

            if script.throwOnCall.contains(call) {
                throw ScriptedError()
            }

            guard !script.samples.isEmpty else {
                return CPUTickSample(cores: [])
            }

            let index = min(script.cursor, script.samples.count - 1)
            script.cursor = index + 1
            return script.samples[index]
        }
    }

    var callCount: Int {
        script.withLock { $0.callCount }
    }

    var readOnMainThread: [Bool] {
        script.withLock { $0.readOnMainThread }
    }
}
