import Foundation
import Synchronization
@testable import system_monitor

/// Scripted `LaunchAtLoginService` double (LAL-2).
///
/// `Sendable` without `@unchecked` because the only stored property is a `let`
/// `Mutex`. Every `status` read is counted, which is how LAL-4 proves the menu
/// reads the registration state live at build time instead of caching it.
nonisolated final class FakeLaunchAtLoginService: LaunchAtLoginService {

    /// Error thrown on the call indexes configured through `throwOnEnable` and
    /// `throwOnDisable`.
    nonisolated struct ScriptedError: Error, Equatable {}

    nonisolated private struct Script: Sendable {
        var status: LaunchAtLoginStatus
        var enableCalls = 0
        var disableCalls = 0
        var openLoginItemsCalls = 0
        var statusReads = 0
        var throwOnEnable: Set<Int>
        var throwOnDisable: Set<Int>
    }

    private let script: Mutex<Script>

    init(
        status: LaunchAtLoginStatus = .notRegistered,
        throwOnEnable: Set<Int> = [],
        throwOnDisable: Set<Int> = []
    ) {
        self.script = Mutex(
            Script(status: status, throwOnEnable: throwOnEnable, throwOnDisable: throwOnDisable)
        )
    }

    var status: LaunchAtLoginStatus {
        script.withLock { script in
            script.statusReads += 1
            return script.status
        }
    }

    /// Throws `ScriptedError` on the zero-based call indexes in `throwOnEnable`.
    /// A throwing call still advances `enableCalls` but leaves the status alone,
    /// mirroring a registration the system refused.
    func enable() throws {
        try script.withLock { script in
            let call = script.enableCalls
            script.enableCalls += 1

            if script.throwOnEnable.contains(call) {
                throw ScriptedError()
            }

            script.status = .enabled
        }
    }

    /// Mirror of `enable()` for the `throwOnDisable` set.
    func disable() throws {
        try script.withLock { script in
            let call = script.disableCalls
            script.disableCalls += 1

            if script.throwOnDisable.contains(call) {
                throw ScriptedError()
            }

            script.status = .notRegistered
        }
    }

    func openLoginItemsSettings() {
        script.withLock { $0.openLoginItemsCalls += 1 }
    }

    /// Test-side rescripting, used to change the system state between two menu
    /// builds without going through `enable()`/`disable()`.
    func setStatus(_ status: LaunchAtLoginStatus) {
        script.withLock { $0.status = status }
    }

    var enableCalls: Int {
        script.withLock { $0.enableCalls }
    }

    var disableCalls: Int {
        script.withLock { $0.disableCalls }
    }

    var openLoginItemsCalls: Int {
        script.withLock { $0.openLoginItemsCalls }
    }

    var statusReads: Int {
        script.withLock { $0.statusReads }
    }
}
