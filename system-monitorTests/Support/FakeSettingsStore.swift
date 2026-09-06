import Foundation
import Synchronization
@testable import system_monitor

/// Scripted `SettingsStore` double (ST-2).
///
/// It mirrors `FakeMemoryProvider`: `Sendable` without `@unchecked` because the
/// only stored property is a `let` `Mutex`, so a main-actor `SettingsState` and
/// a test thread can inspect the recorded calls safely.
nonisolated final class FakeSettingsStore: SettingsStore {

    /// Error thrown on the save indexes configured through `throwOnSave`.
    nonisolated struct ScriptedError: Error, Equatable {}

    nonisolated private struct Script: Sendable {
        var stored: Settings?
        var saved: [Settings] = []
        var throwOnSave: Set<Int>
        var loadCount = 0
        var saveCount = 0
        /// `Thread.isMainThread` recorded at each `save(_:)` call.
        var savedOnMainThread: [Bool] = []
    }

    private let script: Mutex<Script>

    init(stored: Settings? = nil, throwOnSave: Set<Int> = []) {
        self.script = Mutex(Script(stored: stored, throwOnSave: throwOnSave))
    }

    /// Returns the seeded value, or the ST-1 defaults when nothing was seeded.
    func load() -> Settings {
        script.withLock { script in
            script.loadCount += 1
            return script.stored ?? Settings()
        }
    }

    /// Records the calling thread, then throws `ScriptedError` on the
    /// zero-based call indexes in `throwOnSave`. A throwing call still advances
    /// `saveCount` but records neither the value nor a new stored state.
    func save(_ settings: Settings) throws {
        try script.withLock { script in
            let call = script.saveCount
            script.saveCount += 1
            script.savedOnMainThread.append(Thread.isMainThread)

            if script.throwOnSave.contains(call) {
                throw ScriptedError()
            }

            script.saved.append(settings)
            script.stored = settings
        }
    }

    var saved: [Settings] {
        script.withLock { $0.saved }
    }

    var loadCount: Int {
        script.withLock { $0.loadCount }
    }

    var saveCount: Int {
        script.withLock { $0.saveCount }
    }

    var savedOnMainThread: [Bool] {
        script.withLock { $0.savedOnMainThread }
    }
}
