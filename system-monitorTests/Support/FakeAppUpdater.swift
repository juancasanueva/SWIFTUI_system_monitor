import Foundation
import Observation
@testable import system_monitor

/// In-memory `AppUpdating` double (AU-1).
///
/// It exists because the updater framework ships no test harness: everything
/// the app asks of an updater is asked of this instead, so the whole contract
/// runs without Sparkle, without a network and without a real bundle.
///
/// `@MainActor` and `@Observable` for the same reasons the port is: the module
/// compiles under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, and a surface
/// holding `any AppUpdating` only re-renders while the existential is observable.
///
/// The counters are numbers rather than impressions. "Exactly one check" and
/// "the launch wiring writes the preference exactly once" are claims about how
/// many times something happened, and only something that counted can fail them.
@MainActor
@Observable
final class FakeAppUpdater: AppUpdating {

    private(set) var checkCount = 0

    var canCheckForUpdates: Bool

    private(set) var lastUpdateCheckDate: Date?

    /// How many times the automatic-check flag was written, not merely what it
    /// ends up as: a policy that wrote `false`, then `true`, then `false` again
    /// leaves the same final value and flips the updater's schedule on twice on
    /// the way there.
    @ObservationIgnored private(set) var automaticWriteCount = 0

    @ObservationIgnored private var storedAutomaticChecks: Bool

    var automaticallyChecksForUpdates: Bool {
        get { storedAutomaticChecks }
        set {
            storedAutomaticChecks = newValue
            automaticWriteCount += 1
        }
    }

    init(canCheckForUpdates: Bool = true, automaticallyChecksForUpdates: Bool = false) {
        self.canCheckForUpdates = canCheckForUpdates
        self.storedAutomaticChecks = automaticallyChecksForUpdates
    }

    func checkForUpdates() {
        checkCount += 1
    }

    /// Test-side rescripting of the recorded check date, used to move the
    /// last-checked label from "never" to a date without running a real check.
    func recordCheck(at date: Date) {
        lastUpdateCheckDate = date
    }
}
