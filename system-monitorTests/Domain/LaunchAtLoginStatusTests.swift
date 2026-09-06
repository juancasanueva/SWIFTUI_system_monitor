import Foundation
import Testing
@testable import system_monitor

// launch-at-login — LAL-1 "Launch-at-login status value".
@Suite("LaunchAtLoginStatus")
struct LaunchAtLoginStatusTests {

    // launch-at-login — LAL-1 "Only enabled counts as enabled".
    @Test(arguments: LaunchAtLoginStatus.allCases)
    func isEnabledIsTrueOnlyForTheEnabledCase(status: LaunchAtLoginStatus) {
        #expect(status.isEnabled == (status == .enabled))
    }

    // launch-at-login — LAL-1 "Only requiresApproval needs approval".
    @Test(arguments: LaunchAtLoginStatus.allCases)
    func needsApprovalIsTrueOnlyForTheRequiresApprovalCase(status: LaunchAtLoginStatus) {
        #expect(status.needsApproval == (status == .requiresApproval))
    }

    // launch-at-login — LAL-1: the enum mirrors the four `SMAppService.Status`
    // cases and nothing else.
    @Test func theEnumHasExactlyTheFourSystemCases() {
        #expect(LaunchAtLoginStatus.allCases.count == 4)
        #expect(LaunchAtLoginStatus.allCases == [.notRegistered, .enabled, .requiresApproval, .notFound])
    }
}

// launch-at-login — LAL-2 "Launch-at-login port". The Domain has no adapter, so
// the Mutex-backed double is what proves the port contract.
@Suite("LaunchAtLoginService port")
struct LaunchAtLoginServicePortTests {

    // launch-at-login — LAL-2 "Fake reports the scripted status". Every read is
    // counted, which is what later proves the menu reads the status live.
    @Test func theFakeReportsTheScriptedStatusAndCountsEveryRead() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)

        #expect(service.status == .requiresApproval)
        #expect(service.status == .requiresApproval)
        #expect(service.statusReads == 2)
    }

    // launch-at-login — LAL-2 "Fake records and throws on demand": the throw set
    // is zero-based and a throwing call still advances the call counter.
    @Test func theFirstEnableThrowsAndTheSecondSucceeds() throws {
        let service = FakeLaunchAtLoginService(throwOnEnable: [0])

        #expect(throws: FakeLaunchAtLoginService.ScriptedError.self) {
            try service.enable()
        }
        #expect(service.status == .notRegistered)

        try service.enable()

        #expect(service.enableCalls == 2)
        #expect(service.status == .enabled)
    }

    @Test func disableUnregistersAndRecordsTheCall() throws {
        let service = FakeLaunchAtLoginService(status: .enabled)

        try service.disable()

        #expect(service.disableCalls == 1)
        #expect(service.status == .notRegistered)
    }

    @Test func aScriptedDisableFailureLeavesTheStatusUntouched() {
        let service = FakeLaunchAtLoginService(status: .enabled, throwOnDisable: [0])

        #expect(throws: FakeLaunchAtLoginService.ScriptedError.self) {
            try service.disable()
        }

        #expect(service.disableCalls == 1)
        #expect(service.status == .enabled)
    }

    @Test func openLoginItemsSettingsIsRecordedAndTogglesNothing() {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)

        service.openLoginItemsSettings()

        #expect(service.openLoginItemsCalls == 1)
        #expect(service.enableCalls == 0)
        #expect(service.disableCalls == 0)
        #expect(service.status == .requiresApproval)
    }

    // launch-at-login — LAL-2: the test side can rescript the status between two
    // reads, which LAL-4 needs to prove the menu rebuilds from a live read.
    @Test func setStatusRescriptsTheServiceBetweenReads() {
        let service = FakeLaunchAtLoginService(status: .notRegistered)

        #expect(service.status == .notRegistered)
        service.setStatus(.enabled)

        #expect(service.status == .enabled)
        #expect(service.statusReads == 2)
    }
}
