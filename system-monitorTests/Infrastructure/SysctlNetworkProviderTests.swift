import Foundation
import Testing
@testable import system_monitor

// network-metrics — NM-11 "Admitted interfaces", "Rejected interfaces",
// "Loopback flag overrides an admitted type", "Link state is not required";
// NM-10 "Sums saturate".
//
// Both seams are pure: the interface decision takes only the type and the flag
// bits, and the sum takes two integers, so neither needs a routing socket and
// neither suite carries the `.integration` tag. The live `NET_RT_IFLIST2` walk
// that feeds them is proved separately by `SysctlNetworkIntegrationTests` in
// the sandboxed test host.
@Suite("SysctlNetworkProvider pure seams", .timeLimit(.minutes(1)))
struct SysctlNetworkProviderTests {

    /// One row of the NM-11 truth table.
    ///
    /// `type` and `flags` are the raw bit patterns a real `if_msghdr2` carries
    /// for that interface, so each row reads like the interface it describes
    /// rather than like a constant expression.
    nonisolated struct InterfaceCase: Sendable, CustomStringConvertible {

        /// Interface the bit pattern was taken from, for the failure message.
        let name: String

        /// `ifi_type`, `net/if_types.h`.
        let type: UInt8

        /// `ifm_flags`: the `IFF_*` bits, `net/if.h:93` onwards.
        let flags: Int32

        /// What `includes(type:flags:)` must answer for this row.
        let admitted: Bool

        var description: String { name }
    }

    /// The NM-11 truth table, verbatim from the design's per-requirement test
    /// map. Ethernet and cellular are summed; loopback, tunnel, bridge, gif and
    /// stf are not, so VPN traffic is never counted twice.
    static let interfaceCases: [InterfaceCase] = [
        // IFT_ETHER (0x6) up and running: the ordinary Wi-Fi / Ethernet case.
        InterfaceCase(name: "en0", type: 0x6, flags: 0x8863, admitted: true),
        // IFT_ETHER with neither IFF_UP nor IFF_RUNNING: a configured but down
        // Ethernet interface still contributes its lifetime counters.
        InterfaceCase(name: "down Ethernet", type: 0x6, flags: 0x0, admitted: true),
        // IFT_ETHER carrying IFF_LOOPBACK (0x8): the flag wins over the type.
        InterfaceCase(name: "loopback-flagged Ethernet", type: 0x6, flags: 0x8, admitted: false),
        // IFT_CELLULAR (0xff): the iPhone / iPad tether path.
        InterfaceCase(name: "cellular", type: 0xff, flags: 0x0, admitted: true),
        // IFT_LOOP (0x18) with IFF_LOOPBACK set.
        InterfaceCase(name: "lo0", type: 0x18, flags: 0x8049, admitted: false),
        // IFT_OTHER (0x1): utun*, the VPN tunnels.
        InterfaceCase(name: "utun", type: 0x1, flags: 0x8051, admitted: false),
        // IFT_BRIDGE (0xd1): bridge0 mirrors member traffic.
        InterfaceCase(name: "bridge0", type: 0xd1, flags: 0x8863, admitted: false),
        // IFT_GIF (0x37) and IFT_STF (0x39): tunnelling pseudo-interfaces.
        InterfaceCase(name: "gif0", type: 0x37, flags: 0x0, admitted: false),
        InterfaceCase(name: "stf0", type: 0x39, flags: 0x0, admitted: false)
    ]

    // network-metrics — NM-11 "Admitted interfaces", "Rejected interfaces"
    @Test(
        "The interface filter matches the NM-11 truth table",
        arguments: SysctlNetworkProviderTests.interfaceCases
    )
    func theFilterMatchesTheTruthTable(interface: InterfaceCase) {
        let admitted = SysctlNetworkProvider.includes(type: interface.type, flags: interface.flags)

        #expect(admitted == interface.admitted, "\(interface.name) was decided the wrong way")
    }

    // network-metrics — NM-11 "Loopback flag overrides an admitted type"
    @Test func theLoopbackFlagRejectsAnOtherwiseAdmittedType() {
        #expect(SysctlNetworkProvider.includes(type: 0x6, flags: 0x8863))
        #expect(SysctlNetworkProvider.includes(type: 0x6, flags: 0x8863 | 0x8) == false)
    }

    // network-metrics — NM-11 "Link state is not required"
    @Test func neitherUpNorRunningIsRequired() {
        // IFF_UP is 0x1 and IFF_RUNNING is 0x40; neither is set here.
        #expect(SysctlNetworkProvider.includes(type: 0x6, flags: 0x0))
        #expect(SysctlNetworkProvider.includes(type: 0xff, flags: 0x0))
    }

    // network-metrics — NM-10 "Sums saturate"
    @Test func twoOrdinaryTotalsAddUpExactly() {
        #expect(SysctlNetworkProvider.saturatingSum(1, 2) == 3)
        #expect(SysctlNetworkProvider.saturatingSum(3_849_995_000, 2_759_922_000) == 6_609_917_000)
    }

    // network-metrics — NM-10 "Sums saturate"
    @Test func anOverflowingSumPinsAtTheMaximumInsteadOfWrapping() {
        #expect(SysctlNetworkProvider.saturatingSum(UInt64.max, 1) == UInt64.max)
        #expect(SysctlNetworkProvider.saturatingSum(UInt64.max, UInt64.max) == UInt64.max)
    }

    // network-metrics — NM-10 "Sums saturate"
    @Test func theLastSumThatStillFitsIsNotSaturated() {
        #expect(SysctlNetworkProvider.saturatingSum(UInt64.max - 1, 1) == UInt64.max)
        #expect(SysctlNetworkProvider.saturatingSum(UInt64.max - 1, 0) == UInt64.max - 1)
    }

    @Test func addingZeroLeavesATotalUnchanged() {
        #expect(SysctlNetworkProvider.saturatingSum(0, 0) == 0)
        #expect(SysctlNetworkProvider.saturatingSum(0, 78_000) == 78_000)
        #expect(SysctlNetworkProvider.saturatingSum(5_000, 0) == 5_000)
    }

    // MARK: - Sparse index classification (NM-10)

    // network-metrics — NM-10 "A missing index is a gap, not a failure": the
    // interface count is an upper bound and destroyed interfaces leave holes, so
    // the three "no such interface" errnos are skipped while every other errno
    // must still surface as a thrown read failure.
    @Test(
        arguments: [
            (ENOENT, true),
            (ENXIO, true),
            (EINVAL, true),
            (EPERM, false),
            (EACCES, false),
            (ENOMEM, false),
            (EFAULT, false),
            (0, false)
        ] as [(Int32, Bool)]
    )
    func theMissingInterfaceErrnosAreSkippedAndEveryOtherOneIsNot(code: Int32, skipped: Bool) {
        #expect(SysctlNetworkProvider.isMissingInterface(errno: code) == skipped)
    }
}
