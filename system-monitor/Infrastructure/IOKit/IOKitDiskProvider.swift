import Foundation
import IOKit
import IOKit.storage

/// Reads the cumulative block-storage byte counters from the IORegistry.
///
/// Every `IOBlockStorageDriver` service publishes a `Statistics` dictionary
/// holding lifetime totals for its device. The whole machine's throughput is
/// the sum over those drivers, so the adapter iterates all of them rather than
/// picking one: an external volume and the boot disk each own a driver.
///
/// A driver whose dictionary cannot be read is skipped and not counted, which
/// keeps `driverCount` an honest description of what the sum covers. No driver
/// at all is a valid reading (`driverCount == 0`), not a failure — the Domain
/// rate rule turns it into "no rate available" and the card shows an em dash.
///
/// Every IOKit handle is released in a `defer`; the matching dictionary is
/// consumed by `IOServiceGetMatchingServices` and must not be released here.
///
/// Capacity comes from a different facility altogether, so the adapter composes
/// a `VolumeCapacityReader` and delegates that half of the port to it. The
/// composition stays inside Infrastructure, which is why the collaborator is a
/// default argument rather than a second port on the sampler.
nonisolated struct IOKitDiskProvider: DiskMetricsProvider {

    /// Failure of the IOKit lookup itself. Reading an individual driver never
    /// fails the whole call.
    nonisolated enum ReadError: Error, Equatable {
        /// `IOServiceMatching` could not build the matching dictionary.
        case matchingUnavailable
        /// `IOServiceGetMatchingServices` returned other than `KERN_SUCCESS`.
        case ioKitCall(kern_return_t)
    }

    /// IOKit class publishing per-device block-storage statistics.
    /// `IOKit/storage/IOBlockStorageDriver.h:41`
    private static let driverClass = kIOBlockStorageDriverClass

    /// Property holding the per-driver statistics table.
    /// `IOKit/storage/IOBlockStorageDriver.h:54`
    private static let statisticsKey = kIOBlockStorageDriverStatisticsKey

    /// Cumulative bytes read, inside the statistics table.
    /// `IOKit/storage/IOBlockStorageDriver.h:68`
    private static let bytesReadKey = kIOBlockStorageDriverStatisticsBytesReadKey

    /// Cumulative bytes written, inside the statistics table.
    /// `IOKit/storage/IOBlockStorageDriver.h:82`
    private static let bytesWrittenKey = kIOBlockStorageDriverStatisticsBytesWrittenKey

    /// Reader supplying the other half of the port.
    private let capacity: VolumeCapacityReader

    init(capacity: VolumeCapacityReader = VolumeCapacityReader()) {
        self.capacity = capacity
    }

    /// Sums the byte counters over every readable block-storage driver.
    ///
    /// The stamp is taken after the sum, so it describes the instant the whole
    /// reading was complete rather than the instant iteration started.
    func readThroughput() throws -> DiskThroughputCounters {
        guard let matching = IOServiceMatching(Self.driverClass) else {
            throw ReadError.matchingUnavailable
        }

        // IOServiceGetMatchingServices consumes the matching dictionary.
        var iterator: io_iterator_t = IO_OBJECT_NULL
        let status = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard status == KERN_SUCCESS else { throw ReadError.ioKitCall(status) }

        // KERN_SUCCESS with a null iterator means nothing matched.
        guard iterator != IO_OBJECT_NULL else { return Self.empty() }
        defer { IOObjectRelease(iterator) }

        var bytesRead: UInt64 = 0
        var bytesWritten: UInt64 = 0
        var driverCount = 0

        while case let driver = IOIteratorNext(iterator), driver != IO_OBJECT_NULL {
            defer { IOObjectRelease(driver) }
            guard let statistics = Self.statistics(of: driver) else { continue }

            bytesRead = Self.saturatingSum(bytesRead, Self.counter(Self.bytesReadKey, in: statistics))
            bytesWritten = Self.saturatingSum(
                bytesWritten,
                Self.counter(Self.bytesWrittenKey, in: statistics)
            )
            driverCount += 1
        }

        return DiskThroughputCounters(
            bytesRead: bytesRead,
            bytesWritten: bytesWritten,
            driverCount: driverCount,
            timestamp: ContinuousClock.now
        )
    }

    /// Capacity of the boot volume.
    ///
    /// The reader's own `ReadError` reaches the caller unchanged: wrapping it in
    /// this adapter's vocabulary would couple two independent facilities for
    /// nothing, because the port is untyped and the sampler only distinguishes
    /// a successful read from a failed one.
    func readCapacity() throws -> VolumeCapacity {
        try capacity.read()
    }

    /// A valid reading that covers no driver.
    private static func empty() -> DiskThroughputCounters {
        DiskThroughputCounters(
            bytesRead: 0,
            bytesWritten: 0,
            driverCount: 0,
            timestamp: ContinuousClock.now
        )
    }

    /// Reads one driver's statistics table, or `nil` when it publishes none.
    private static func statistics(of driver: io_registry_entry_t) -> [String: Any]? {
        IORegistryEntryCreateCFProperty(driver, statisticsKey as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any]
    }

    /// One counter from a statistics table. An absent counter reads as 0 while
    /// the driver still counts, because the table exists and was read.
    private static func counter(_ key: String, in statistics: [String: Any]) -> UInt64 {
        (statistics[key] as? NSNumber)?.uint64Value ?? 0
    }

    /// Adds two lifetime totals, saturating instead of trapping.
    ///
    /// Overflow needs sixteen exabytes of traffic, but a wrapped sum would look
    /// like a counter reset and the Domain would discard a real rate for it, so
    /// the sum is pinned at the maximum instead.
    private static func saturatingSum(_ total: UInt64, _ addition: UInt64) -> UInt64 {
        let (sum, overflowed) = total.addingReportingOverflow(addition)
        return overflowed ? UInt64.max : sum
    }
}
