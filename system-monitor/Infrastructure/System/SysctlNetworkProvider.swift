import Darwin
import Foundation

/// Reads the cumulative network byte counters from the interface MIB.
///
/// The kernel publishes per-interface statistics under
/// `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, <index>, IFDATA_GENERAL}`
/// as a `struct ifmibdata` (`net/if_mib.h`), whose `ifmd_data` is an
/// `if_data64` carrying `ifi_ibytes` and `ifi_obytes`. These are the counters
/// `netstat -ib` reports, and on this platform they are the only ones that are
/// genuinely 64-bit.
///
/// **Why not the routing socket.** The obvious source, `NET_RT_IFLIST2` with its
/// `RTM_IFINFO2` messages, also declares `ifi_ibytes` as `u_int64_t`, but this
/// machine's driver fills only the low 32 bits: a probe on 2026-09-10 watched
/// `en1` go from 4 287 352 832 to 8 851 456 in one 250 ms tick, and a direct
/// comparison read 13 563 204 219 through this MIB against 678 301 696 through
/// the routing socket for the same interface at the same moment — exactly the
/// low 32 bits of the true value. Every 4 GB the routing-socket counter wraps,
/// the summed delta goes negative, and the Domain rule correctly discards the
/// tick — so the card showed an em dash and the totals appeared to reset. The
/// declared width of a field is not evidence that the driver fills it.
///
/// The whole machine's throughput is the sum over the physical interfaces, so
/// the adapter reads every index and filters by interface type: tunnels,
/// bridges and loopback mirror traffic that another interface already counted,
/// and summing them would double count every VPN byte. That decision is a pure
/// seam (`includes(type:flags:)`) so its truth table is a unit test.
///
/// No interface passing the filter is a valid reading (`interfaceCount == 0`,
/// totals 0), not a failure — the Domain rate rule turns it into "no rate
/// available" and the card shows an em dash. Only a failed count query, or a
/// per-index read failing for a reason other than "no such interface", throws.
///
/// The adapter is stateless and allocates nothing that outlives a read, so it is
/// trivially `Sendable`; the sampling loop calls it from its detached task and
/// it stamps `ContinuousClock.now` itself, on that task.
nonisolated struct SysctlNetworkProvider: NetworkMetricsProvider {

    /// Failure of the interface MIB read itself.
    nonisolated enum ReadError: Error, Equatable {
        /// The interface-count `sysctl` returned -1.
        case countQuery(errno: Int32)
        /// A per-interface `sysctl` failed for a reason other than a missing
        /// index. A missing index is a gap in a sparse table, not an error.
        case interfaceRead(index: Int32, errno: Int32)
    }

    /// `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT}` — the
    /// number of interface rows. `IFMIB_SYSTEM = 1` (`net/if_mib.h:79`),
    /// `IFMIB_IFCOUNT = 1` (`:94`), `NETLINK_GENERIC = 0` (`:100`).
    private static let countMIB: [Int32] = [
        CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT
    ]

    /// `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL}`
    /// — one interface's general statistics. `IFMIB_IFDATA = 2`
    /// (`net/if_mib.h:80`), `IFDATA_GENERAL = 1` (`:86`).
    private static func dataMIB(index: Int32) -> [Int32] {
        [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL]
    }

    /// Ethernet family: en*, awdl0, llw0. `IFT_ETHER = 0x6`,
    /// `net/if_types.h:81`.
    private static let ethernetType = UInt8(IFT_ETHER)

    /// Packet data over cellular, as exposed by a tethered iPhone.
    /// `IFT_CELLULAR = 0xff`, `net/if_types.h:149`.
    private static let cellularType = UInt8(IFT_CELLULAR)

    /// Loopback flag. `IFF_LOOPBACK = 0x8`, `net/if.h:96`.
    private static let loopbackFlag = Int32(IFF_LOOPBACK)

    init() {}

    /// Decides whether one interface contributes to the machine totals.
    ///
    /// Only Ethernet-family and cellular interfaces are summed, and the
    /// loopback flag rejects an interface whose type would otherwise be
    /// admitted. Every other type — loopback, tunnel (utun*), bridge, gif, stf
    /// — is rejected, so traffic that a physical interface already counted is
    /// never counted a second time.
    ///
    /// Link state is deliberately not part of the decision: neither `IFF_UP`
    /// nor `IFF_RUNNING` is required, so a configured but currently down
    /// Ethernet interface still contributes its lifetime counters and
    /// unplugging a cable does not look like a counter reset.
    ///
    /// The seam takes the raw bits rather than a message so it is a plain unit
    /// test with no `sysctl` in sight (NM-11).
    nonisolated static func includes(type: UInt8, flags: Int32) -> Bool {
        guard type == ethernetType || type == cellularType else { return false }
        return flags & loopbackFlag == 0
    }

    /// Whether a failed per-index read means "there is no interface at this
    /// index" rather than a real failure.
    ///
    /// The count is an upper bound on the indices, not a dense range: interfaces
    /// destroyed since boot leave holes, and a hole answers `ENOENT`, `ENXIO` or
    /// `EINVAL` depending on how far the lookup got. Treating those as failures
    /// would make an ordinary machine with a removed VPN interface unable to
    /// report any network reading at all, so they are skipped. Any other errno
    /// is a genuine failure and must not be swallowed.
    ///
    /// A pure seam for the same reason `includes` is one: the truth table is a
    /// unit test, with no interface table in sight.
    nonisolated static func isMissingInterface(errno code: Int32) -> Bool {
        code == ENOENT || code == ENXIO || code == EINVAL
    }

    /// Adds two lifetime totals, saturating instead of trapping.
    ///
    /// Overflow needs sixteen exabytes of traffic, but a wrapped sum would look
    /// like a counter reset and the Domain would discard a real rate for it, so
    /// the sum is pinned at the maximum instead. Internal rather than private
    /// so NM-10 "Sums saturate" is a unit test (`IOKitDiskProvider` precedent).
    nonisolated static func saturatingSum(_ total: UInt64, _ addition: UInt64) -> UInt64 {
        let (sum, overflowed) = total.addingReportingOverflow(addition)
        return overflowed ? UInt64.max : sum
    }

    /// Sums the byte counters over every interface the filter admits.
    ///
    /// One fixed-size read per interface index, rather than the routing
    /// socket's single variable-length buffer. That costs a syscall per
    /// interface — about twenty on a Mac — but `ifmibdata` has a known size, so
    /// there is no sizing call, no allocation, no message walk and no unaligned
    /// loads: the whole class of length and stride errors the routing-socket
    /// walk had to guard against cannot arise.
    ///
    /// The stamp is taken after the loop, so it describes the instant the whole
    /// reading was complete rather than the instant the first `sysctl` started.
    func readCounters() throws -> NetworkThroughputCounters {
        var countMIB = Self.countMIB
        var count: Int32 = 0
        var countSize = MemoryLayout<Int32>.size

        guard sysctl(&countMIB, u_int(countMIB.count), &count, &countSize, nil, 0) == 0 else {
            throw ReadError.countQuery(errno: errno)
        }

        // No interface row at all is a valid reading covering no interface.
        guard count > 0 else { return Self.empty() }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var interfaceCount = 0

        for index in 1...count {
            guard let data = try Self.interface(at: index) else { continue }

            guard
                Self.includes(
                    type: data.ifmd_data.ifi_type,
                    flags: Int32(bitPattern: data.ifmd_flags)
                )
            else { continue }

            bytesIn = Self.saturatingSum(bytesIn, data.ifmd_data.ifi_ibytes)
            bytesOut = Self.saturatingSum(bytesOut, data.ifmd_data.ifi_obytes)
            interfaceCount += 1
        }

        return NetworkThroughputCounters(
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            interfaceCount: interfaceCount,
            timestamp: ContinuousClock.now
        )
    }

    /// One interface's general statistics, or `nil` when no interface occupies
    /// that index.
    ///
    /// `ifmibdata` is a fixed-size C struct, so it is read straight into a
    /// zeroed value with no intermediate buffer and no unaligned access.
    private static func interface(at index: Int32) throws -> ifmibdata? {
        var mib = dataMIB(index: index)
        var data = ifmibdata()
        var size = MemoryLayout<ifmibdata>.size

        guard sysctl(&mib, u_int(mib.count), &data, &size, nil, 0) == 0 else {
            let code = errno
            guard isMissingInterface(errno: code) else {
                throw ReadError.interfaceRead(index: index, errno: code)
            }
            return nil
        }

        return data
    }

    /// A valid reading that covers no interface.
    private static func empty() -> NetworkThroughputCounters {
        NetworkThroughputCounters(
            bytesIn: 0,
            bytesOut: 0,
            interfaceCount: 0,
            timestamp: ContinuousClock.now
        )
    }
}
