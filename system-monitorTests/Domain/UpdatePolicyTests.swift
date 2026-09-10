import Foundation
import Testing
@testable import system_monitor

// app-updates — AU-4 "Automatic checks stay off until the user asks" (the
// launch-time write) and AU-5 "An explicit update check is always reachable"
// (the enablement rule).
//
// Both are decisions — a `Bool` in, a `Bool` out — with no framework in them,
// which is why they live in the Domain and are asserted over `FakeAppUpdater`
// rather than by a source sweep. A scenario whose only evidence is a source
// sweep is a scenario nobody can fail on purpose.
@MainActor
@Suite("Update policy", .timeLimit(.minutes(1)))
struct UpdatePolicyTests {

    // app-updates — AU-4 "The persisted preference is written to the updater at
    // launch". Each case starts from an updater that *disagrees* with the
    // preference: a policy that only wrote when it already matched would pass a
    // test that started from agreement, and would leave a framework-persisted
    // `true` intact on a machine where the user turned checking off.
    @Test(arguments: [true, false])
    func thePersistedPreferenceIsWrittenToTheUpdater(preference: Bool) {
        let updater = FakeAppUpdater(automaticallyChecksForUpdates: !preference)

        AutomaticUpdateChecksPolicy.apply(preference: preference, to: updater)

        #expect(updater.automaticallyChecksForUpdates == preference)
        #expect(updater.automaticWriteCount == 1)
    }

    // app-updates — AU-4: one write, not two. An update check is network
    // egress, so a policy that wrote `true` on the way to `false` would let the
    // updater schedule a check in between, on a launch where the user said no.
    @Test func applyingThePreferenceWritesExactlyOnce() {
        let updater = FakeAppUpdater(automaticallyChecksForUpdates: true)

        AutomaticUpdateChecksPolicy.apply(preference: false, to: updater)

        #expect(updater.automaticWriteCount == 1)
        #expect(updater.automaticallyChecksForUpdates == false)
    }

    // app-updates — AU-4: the idempotent case, asserted separately because it
    // is the one a "only write when it differs" optimisation would silently
    // change. The write count would drop to zero and the requirement — at every
    // launch the app writes its own setting — would quietly stop holding.
    @Test func anOffRunLeavesAutomaticCheckingOff() {
        let updater = FakeAppUpdater(automaticallyChecksForUpdates: false)

        AutomaticUpdateChecksPolicy.apply(preference: false, to: updater)

        #expect(updater.automaticallyChecksForUpdates == false)
        #expect(updater.automaticWriteCount == 1)
    }

    // app-updates — AU-5 "The command is enabled exactly while a check can
    // run". Table-driven over the whole domain of the input, which is two
    // values.
    @Test(arguments: [true, false])
    func theCommandIsEnabledExactlyWhileTheUpdaterCanCheck(canCheck: Bool) {
        #expect(UpdateCommandEnablement.isEnabled(canCheckForUpdates: canCheck) == canCheck)
    }

    // app-updates — AU-5: two updaters differing *only* in their automatic-check
    // flag produce the same enablement, which is the half of the requirement a
    // table over a bare `Bool` cannot state.
    @Test func automaticCheckingDoesNotDecideEnablement() {
        let automaticOff = FakeAppUpdater(canCheckForUpdates: true, automaticallyChecksForUpdates: false)
        let automaticOn = FakeAppUpdater(canCheckForUpdates: true, automaticallyChecksForUpdates: true)
        let inFlight = FakeAppUpdater(canCheckForUpdates: false, automaticallyChecksForUpdates: false)

        #expect(UpdateCommandEnablement.isEnabled(canCheckForUpdates: automaticOff.canCheckForUpdates))
        #expect(UpdateCommandEnablement.isEnabled(canCheckForUpdates: automaticOn.canCheckForUpdates))
        #expect(UpdateCommandEnablement.isEnabled(canCheckForUpdates: inFlight.canCheckForUpdates) == false)
    }
}
