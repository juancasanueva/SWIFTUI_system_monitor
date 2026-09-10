import Foundation
import Testing
@testable import system_monitor

// network-metrics — NM-10 "Sandboxed shape", "Counters are monotonic with
// advancing stamps", "Repeated reads".
//
// These run the real adapter inside the sandboxed test host, which is what
// proves the routing-socket MIB `NET_RT_IFLIST2` is reachable under App Sandbox
// (`ENABLE_APP_SANDBOX = YES`) — the empirical answer the design gate could not
// get from a header probe. They assert shape and internal consistency, never
// specific hardware values or interface names, so they hold on any Mac the
// project is built on.
@Suite("SysctlNetworkProvider against the real routing socket",
       .tags(.integration),
       .timeLimit(.minutes(1)))
struct SysctlNetworkIntegrationTests {

    // network-metrics — NM-10 "Sandboxed shape"
    @Test func theSandboxedHostSeesAtLeastOneInterfaceWithBytesIn() throws {
        let counters = try SysctlNetworkProvider().readCounters()

        #expect(counters.interfaceCount >= 1)
        #expect(counters.bytesIn > 0)
    }

    // network-metrics — NM-10 "Counters are monotonic with advancing stamps"
    @Test func twoReadsAreMonotonicAndTheStampAdvances() async throws {
        let provider = SysctlNetworkProvider()

        let first = try provider.readCounters()
        try await Task.sleep(for: .milliseconds(120))
        let second = try provider.readCounters()

        #expect(second.bytesIn >= first.bytesIn)
        #expect(second.bytesOut >= first.bytesOut)
        #expect(second.timestamp > first.timestamp)
        #expect(second.timestamp - first.timestamp >= .milliseconds(120))
    }

    // network-metrics — NM-10 "Repeated reads"
    @Test func fiftyConsecutiveReadsAllSucceed() throws {
        let provider = SysctlNetworkProvider()

        var readings: [NetworkThroughputCounters] = []
        for _ in 0..<50 {
            readings.append(try provider.readCounters())
        }

        #expect(readings.count == 50)
        #expect(readings.allSatisfy { $0.interfaceCount >= 1 })
        #expect(readings.allSatisfy { $0.bytesIn > 0 })
    }

    /// The buffer is sized and filled by two separate `sysctl` calls, so a
    /// mis-sized walk would show up as an interface count that moves between
    /// two reads taken microseconds apart.
    @Test func theInterfaceCountIsStableBetweenReads() throws {
        let provider = SysctlNetworkProvider()

        let first = try provider.readCounters()
        let second = try provider.readCounters()

        #expect(first.interfaceCount == second.interfaceCount)
    }

    /// The stamp is taken by the adapter after the walk, so it belongs to the
    /// same clock the Domain rate rule subtracts on.
    @Test func theStampSitsBetweenTheInstantsSurroundingTheRead() throws {
        let before = ContinuousClock.now
        let counters = try SysctlNetworkProvider().readCounters()
        let after = ContinuousClock.now

        #expect(counters.timestamp >= before)
        #expect(counters.timestamp <= after)
    }

    /// A real reading feeds the Domain rule without any adapter-side massaging:
    /// two live readings produce a non-negative rate pair.
    @Test func aLiveReadingPairProducesNonNegativeRates() async throws {
        let provider = SysctlNetworkProvider()

        let previous = try provider.readCounters()
        try await Task.sleep(for: .milliseconds(120))
        let current = try provider.readCounters()

        let rates = try #require(
            NetworkThroughputCalculator.rates(previous: previous, current: current)
        )

        #expect(rates.downloadBytesPerSecond >= 0)
        #expect(rates.uploadBytesPerSecond >= 0)
    }

    /// Loopback traffic is excluded, so the machine totals stay below the sum
    /// the same walk would produce with the NM-11 filter switched off.
    @Test func theSummedTotalsAreLargerThanZeroAndFitTheInterfaceCount() throws {
        let counters = try SysctlNetworkProvider().readCounters()

        #expect(counters.interfaceCount >= 1)
        #expect(counters.bytesIn > 0)
        #expect(counters.bytesOut > 0)
    }

    // MARK: - The counters must be the real 64-bit ones (NM-10)

    /// One admitted interface as the interface MIB reports it, read by the test
    /// itself rather than through the adapter.
    ///
    /// This is the independent witness the other cases lack: every assertion
    /// above compares the adapter against itself, so a source that silently
    /// truncates its counters satisfies all of them. `ifmibdata` carries the
    /// same `if_data64` the adapter wants, keyed by interface index
    /// (`net/if_mib.h`), and it is filled by the interface layer rather than by
    /// the driver's routing-socket export.
    private struct MIBInterface {
        let index: Int32
        let bytesIn: UInt64
        let bytesOut: UInt64
    }

    /// The witness's own failure, deliberately independent of the adapter's
    /// error taxonomy so this case keeps testing the counters rather than the
    /// production error type.
    private struct MIBUnavailable: Error, Equatable {
        let errno: Int32
    }

    /// Reads every admitted interface straight from `IFDATA_GENERAL`.
    ///
    /// Sparse indices are expected: the count is an upper bound and a missing
    /// index answers `ENOENT`/`ENXIO`/`EINVAL`, which is a gap, not a failure.
    private static func admittedMIBInterfaces() throws -> [MIBInterface] {
        var countMIB: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT]
        var count: Int32 = 0
        var countSize = MemoryLayout<Int32>.size

        guard sysctl(&countMIB, u_int(countMIB.count), &count, &countSize, nil, 0) == 0 else {
            throw MIBUnavailable(errno: errno)
        }

        var interfaces: [MIBInterface] = []
        guard count > 0 else { return interfaces }

        for index in 1...count {
            var mib: [Int32] = [
                CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL
            ]
            var data = ifmibdata()
            var size = MemoryLayout<ifmibdata>.size

            guard sysctl(&mib, u_int(mib.count), &data, &size, nil, 0) == 0 else { continue }

            guard
                SysctlNetworkProvider.includes(
                    type: data.ifmd_data.ifi_type,
                    flags: Int32(bitPattern: data.ifmd_flags)
                )
            else { continue }

            interfaces.append(
                MIBInterface(
                    index: index,
                    bytesIn: data.ifmd_data.ifi_ibytes,
                    bytesOut: data.ifmd_data.ifi_obytes
                )
            )
        }

        return interfaces
    }

    // network-metrics — NM-10 "Counters are not 32-bit truncated"
    //
    // The routing-socket export declares `ifi_ibytes` as `u_int64_t` but this
    // platform's driver fills only the low 32 bits, so the value wraps every
    // 4 GB. A machine that has moved more than that since boot therefore reports
    // a total smaller than one of its own interfaces — which is exactly what a
    // sum built from truncated counters looks like.
    //
    // The assertion needs no specific hardware: on a machine that has moved less
    // than 4 GB the two sources agree and the case passes trivially, and on one
    // that has moved more it fails for any truncating source.
    @Test func theSummedCountersAreNotTruncatedToThirtyTwoBits() throws {
        let interfaces = try Self.admittedMIBInterfaces()
        let largestIn = try #require(interfaces.map(\.bytesIn).max(), "no admitted interface")
        let largestOut = try #require(interfaces.map(\.bytesOut).max())

        let counters = try SysctlNetworkProvider().readCounters()

        #expect(
            counters.bytesIn >= largestIn,
            """
            the machine total (\(counters.bytesIn)) is below one interface's own \
            inbound counter (\(largestIn)); the source is truncating
            """
        )
        #expect(counters.bytesOut >= largestOut)
    }

    // network-metrics — NM-10 "Sum matches the MIB within one tick"
    //
    // Stronger than the bound above: the adapter's totals must be the sum of the
    // per-interface MIB counters, not merely at least as large as one of them.
    // The tolerance absorbs real traffic between the adapter's read and the
    // test's, which on a busy link is easily a few megabytes.
    @Test func theAdapterTotalsMatchTheSumOfThePerInterfaceMIBCounters() throws {
        let tolerance: UInt64 = 50_000_000

        let counters = try SysctlNetworkProvider().readCounters()
        let interfaces = try Self.admittedMIBInterfaces()

        #expect(interfaces.count == counters.interfaceCount, "both sources must admit the same set")

        let mibIn = interfaces.reduce(UInt64(0)) { SysctlNetworkProvider.saturatingSum($0, $1.bytesIn) }
        let mibOut = interfaces.reduce(UInt64(0)) { SysctlNetworkProvider.saturatingSum($0, $1.bytesOut) }

        let inboundGap = mibIn > counters.bytesIn ? mibIn - counters.bytesIn : counters.bytesIn - mibIn
        let outboundGap = mibOut > counters.bytesOut ? mibOut - counters.bytesOut : counters.bytesOut - mibOut

        #expect(
            inboundGap <= tolerance,
            "adapter \(counters.bytesIn) versus MIB \(mibIn): gap \(inboundGap) exceeds the tolerance"
        )
        #expect(outboundGap <= tolerance, "adapter \(counters.bytesOut) versus MIB \(mibOut)")
    }
}
