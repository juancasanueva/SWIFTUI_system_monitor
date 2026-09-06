import Foundation
import ServiceManagement
import Testing
@testable import system_monitor

/// One system status and the Domain case LAL-3 requires for it.
nonisolated struct LaunchAtLoginMappingCase: Sendable, CustomTestStringConvertible {
    let name: String
    let system: SMAppService.Status
    let expected: LaunchAtLoginStatus

    var testDescription: String { name }

    static let all: [LaunchAtLoginMappingCase] = [
        LaunchAtLoginMappingCase(name: "notRegistered", system: .notRegistered, expected: .notRegistered),
        LaunchAtLoginMappingCase(name: "enabled", system: .enabled, expected: .enabled),
        LaunchAtLoginMappingCase(name: "requiresApproval", system: .requiresApproval, expected: .requiresApproval),
        LaunchAtLoginMappingCase(name: "notFound", system: .notFound, expected: .notFound),
    ]
}

// launch-at-login — LAL-3 "Status mapping table".
//
// The mapping is a pure static function, so the whole table runs without ever
// touching `SMAppService`. No test in this file calls `enable()`, `disable()`
// or `openLoginItemsSettings()` on the real adapter (convention 11): the first
// two would register the test host as a login item on the developer's machine,
// and the third would open System Settings mid-run.
@Suite("SMAppServiceLaunchAtLogin mapping", .timeLimit(.minutes(1)))
struct SMAppServiceLaunchAtLoginMappingTests {

    // launch-at-login — LAL-3 "Status mapping table": each system status
    // becomes the LAL-1 case of the same name.
    @Test(arguments: LaunchAtLoginMappingCase.all)
    func eachSystemStatusMapsToTheDomainCaseOfTheSameName(testCase: LaunchAtLoginMappingCase) {
        #expect(SMAppServiceLaunchAtLogin.map(testCase.system) == testCase.expected)
    }

    // launch-at-login — LAL-3: the four system cases map onto four distinct
    // Domain cases, so the table cannot collapse to a constant.
    @Test func theFourSystemStatusesMapToFourDistinctDomainCases() {
        let mapped = LaunchAtLoginMappingCase.all.map { SMAppServiceLaunchAtLogin.map($0.system) }

        #expect(mapped == [.notRegistered, .enabled, .requiresApproval, .notFound])
        #expect(Set(mapped).count == 4)
    }

    // launch-at-login — LAL-3: `SMAppServiceStatus` is an `NS_ENUM`, so a
    // future SDK can add a case and this SDK already accepts a raw value it
    // does not declare. The `@unknown default` arm must degrade to the safe
    // "not a login item" answer rather than claim the app is enabled.
    @Test func aStatusTheSDKDoesNotDeclareDegradesToNotRegistered() throws {
        let unknown = try #require(
            SMAppService.Status(rawValue: 99),
            "an undeclared raw value must be constructible for the @unknown default arm to be reachable"
        )

        #expect(SMAppServiceLaunchAtLogin.map(unknown) == .notRegistered)
    }

    // launch-at-login — LAL-3: the adapter is a `LaunchAtLoginService`, which
    // is how the composition root and `StatusItemController` consume it.
    //
    // The binding itself is the conformance assertion, and the dynamic type
    // proves the existential really holds the adapter rather than some other
    // conformer. `status` is deliberately not read here: that live system call
    // belongs to the `.integration` suite below, so this untagged suite keeps
    // its promise of never touching `SMAppService`.
    @Test func theAdapterSatisfiesTheDomainPort() {
        let service: any LaunchAtLoginService = SMAppServiceLaunchAtLogin()

        #expect(type(of: service) == SMAppServiceLaunchAtLogin.self)
    }
}

// launch-at-login — LAL-3 "Live status read in the sandbox".
//
// These run the real adapter inside the sandboxed test host, which is what
// proves `SMAppService.mainApp.status` is reachable under App Sandbox
// (convention 8). They assert shape and stability, never a particular
// registration, so they hold whether or not the developer has the app
// registered as a login item.
@Suite("SMAppServiceLaunchAtLogin against the real system", .tags(.integration), .timeLimit(.minutes(1)))
struct SMAppServiceLaunchAtLoginIntegrationTests {

    // launch-at-login — LAL-3 "Live status read in the sandbox": two reads
    // succeed, return one of the four cases, and agree with each other.
    @Test func readingTheStatusTwiceSucceedsAndReturnsOneOfTheFourCases() {
        let adapter = SMAppServiceLaunchAtLogin()

        let first = adapter.status
        let second = adapter.status

        #expect(LaunchAtLoginStatus.allCases.contains(first))
        #expect(LaunchAtLoginStatus.allCases.contains(second))
        #expect(first == second, "the registration cannot change between two immediate reads")
    }

    // launch-at-login — LAL-3: nothing is cached, so a second adapter reports
    // the same live answer as the first. A stateful adapter would let the two
    // instances drift.
    @Test func twoAdaptersReportTheSameLiveStatus() {
        #expect(SMAppServiceLaunchAtLogin().status == SMAppServiceLaunchAtLogin().status)
    }

    // launch-at-login — LAL-3: the reported status is the mapped system status
    // of this exact moment, not a constant the adapter chose. On a machine
    // where the app is registered this fails for any hardcoded answer.
    @Test func theReportedStatusIsTheMappedSystemStatus() {
        let systemStatus = SMAppService.mainApp.status

        #expect(SMAppServiceLaunchAtLogin().status == SMAppServiceLaunchAtLogin.map(systemStatus))
    }
}
