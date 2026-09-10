import Foundation
import Testing
@testable import system_monitor

// app-updates — AU-1 "Updater port".
//
// The seam every update surface speaks to, driven over `FakeAppUpdater`. The
// concrete checker is the one file allowed to name Sparkle, so the contract is
// stated here and asserted without it: a suite that imported the framework
// could not fail on the day the port grew a fifth member.
@MainActor
@Suite("App updating", .timeLimit(.minutes(1)))
struct AppUpdatingTests {

    // app-updates — AU-5 "Invoking the command starts exactly one check".
    //
    // Two invocations as well as one: an implementation that ignored the call
    // would satisfy "not more than one", and one that latched after the first
    // would satisfy "at least one".
    @Test func eachInvocationStartsExactlyOneCheck() {
        let updater = FakeAppUpdater()

        #expect(updater.checkCount == 0)
        updater.checkForUpdates()
        #expect(updater.checkCount == 1)
        updater.checkForUpdates()
        #expect(updater.checkCount == 2)
    }

    // app-updates — AU-1: the automatic flag is readable and writable through
    // the seam, because the launch wiring writes it and the settings toggle
    // reads it back. A write-only or read-only seam leaves one of them lying.
    @Test func theAutomaticCheckFlagRoundTrips() {
        let updater = FakeAppUpdater(automaticallyChecksForUpdates: false)

        #expect(updater.automaticallyChecksForUpdates == false)
        updater.automaticallyChecksForUpdates = true
        #expect(updater.automaticallyChecksForUpdates)
        updater.automaticallyChecksForUpdates = false
        #expect(updater.automaticallyChecksForUpdates == false)
    }

    // app-updates — AU-5: whether a check can run is unrelated to whether
    // automatic checking is on. The explicit command stays live while automatic
    // checking is off, and goes dark only while a check is genuinely in flight.
    @Test func whetherACheckCanRunIsIndependentOfAutomaticChecking() {
        let idle = FakeAppUpdater(canCheckForUpdates: true, automaticallyChecksForUpdates: false)
        let inFlight = FakeAppUpdater(canCheckForUpdates: false, automaticallyChecksForUpdates: true)

        #expect(idle.canCheckForUpdates)
        #expect(idle.automaticallyChecksForUpdates == false)
        #expect(inFlight.canCheckForUpdates == false)
        #expect(inFlight.automaticallyChecksForUpdates)
    }

    // app-updates — AU-6 "No update surface states something untrue": a fresh
    // updater has never checked and says so through the seam.
    @Test func theRecordedCheckDateFollowsARecordedCheck() {
        let updater = FakeAppUpdater()
        let checked = Date(timeIntervalSince1970: 1_787_000_000)

        #expect(updater.lastUpdateCheckDate == nil)
        updater.recordCheck(at: checked)
        #expect(updater.lastUpdateCheckDate == checked)
    }
}
