import Foundation
import Testing
@testable import system_monitor

// app-updates — AU-4 "Automatic update checks stay off until the user asks".
//
// Driven against a scratch defaults suite rather than `.standard`, the way
// `UserDefaultsSettingsStoreTests` is (convention 14): a test run never reads or
// writes the developer's real preferences, and the fresh-install case is
// genuinely fresh instead of left over from a previous run.
@MainActor
@Suite("Automatic update checks", .timeLimit(.minutes(1)))
struct AutomaticUpdateChecksTests {

    /// A defaults domain that exists only for this test, and is removed after it.
    private func withScratchSuite(_ body: (UserDefaults, String) throws -> Void) rethrows {
        let name = "system-monitor-tests-updates-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            Issue.record("could not create the scratch defaults suite")
            return
        }
        defer { defaults.removePersistentDomain(forName: name) }
        try body(defaults, name)
    }

    // app-updates — AU-4 "A fresh install does not check automatically". A
    // missing key reads `false`: an update check is network egress, and "we
    // never asked" must not be storable as "they said yes".
    @Test func aFreshInstallReadsAsOff() {
        withScratchSuite { defaults, _ in
            let preference = AutomaticUpdateChecks(defaults: defaults)

            #expect(defaults.object(forKey: AutomaticUpdateChecks.key) == nil)
            #expect(preference.isEnabled == false)
        }
    }

    // app-updates — AU-4 "The user's choice survives a relaunch". A second
    // instance over the same suite is what makes this a persistence test rather
    // than a property test: an implementation that cached the value in memory
    // would pass a single-instance round trip and lose the answer next launch.
    @Test func theChoiceSurvivesARelaunchInBothDirections() {
        withScratchSuite { defaults, name in
            AutomaticUpdateChecks(defaults: defaults).isEnabled = true
            let afterEnabling = UserDefaults(suiteName: name)
            #expect(AutomaticUpdateChecks(defaults: afterEnabling ?? defaults).isEnabled)

            AutomaticUpdateChecks(defaults: defaults).isEnabled = false
            let afterDisabling = UserDefaults(suiteName: name)
            #expect(AutomaticUpdateChecks(defaults: afterDisabling ?? defaults).isEnabled == false)
        }
    }

    // app-updates — AU-4: turning it off writes a stored `false` rather than
    // removing the key. Both read as off today; they stop being the same the
    // moment anything distinguishes "never answered" from "answered no".
    @Test func turningItOffRecordsAStoredFalse() {
        withScratchSuite { defaults, _ in
            let preference = AutomaticUpdateChecks(defaults: defaults)
            preference.isEnabled = true
            preference.isEnabled = false

            #expect(defaults.object(forKey: AutomaticUpdateChecks.key) as? Bool == false)
        }
    }

    // app-updates — AU-4: exactly one key, named. The whole domain is read back,
    // so this is a claim about what the type wrote rather than what it was asked
    // to write. A stray companion key — a timestamp, a migration marker, a
    // cached mirror of the framework's own flag — would fail it.
    @Test func thePreferenceWritesExactlyOneKeyAndNothingElse() {
        withScratchSuite { defaults, name in
            AutomaticUpdateChecks(defaults: defaults).isEnabled = true

            let domain = defaults.persistentDomain(forName: name) ?? [:]
            #expect(domain.keys.sorted() == [AutomaticUpdateChecks.key])
            #expect(AutomaticUpdateChecks.key == "updates.automaticChecksEnabled")
        }
    }
}
