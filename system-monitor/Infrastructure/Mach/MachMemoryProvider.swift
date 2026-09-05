import Darwin
import Foundation

/// Reads the kernel virtual-memory page counters from the Mach host.
///
/// Unlike `host_processor_info`, `host_statistics64` fills a buffer the caller
/// owns, so there is nothing to `vm_deallocate`. The field count is passed
/// in-out: the kernel writes back how many `integer_t` fields it filled, which
/// may be fewer than the struct holds on an older kernel. A short reply would
/// leave the later counters — `internal_page_count` among them — at whatever
/// the struct was initialised with, so the returned count is validated before
/// any field is read.
///
/// The counters are `natural_t` (32 bit); every one of them is widened to
/// `UInt64` here so the Domain calculator never multiplies in 32 bits.
nonisolated struct MachMemoryProvider: MemoryMetricsProvider {

    /// Failure of the underlying Mach calls.
    nonisolated enum ReadError: Error, Equatable {
        /// `host_statistics64` returned a status other than `KERN_SUCCESS`.
        case machCall(kern_return_t)
        /// The reply did not cover `internal_page_count`.
        case truncatedStatistics(mach_msg_type_number_t)
        /// `host_page_size` failed or reported a page size of 0 at init.
        case invalidPageSize
    }

    /// Smallest `integer_t` count that still covers `internal_page_count`.
    ///
    /// Exposed as a static seam so the truncation rule is a plain unit test
    /// instead of a branch that only a broken kernel could reach.
    nonisolated static let requiredFieldCount: mach_msg_type_number_t = {
        let offset = MemoryLayout<vm_statistics64_data_t>.offset(of: \.internal_page_count) ?? 0
        return mach_msg_type_number_t(offset / MemoryLayout<integer_t>.stride + 1)
    }()

    /// Number of `integer_t` fields the whole struct holds.
    private static let fullFieldCount = mach_msg_type_number_t(
        MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
    )

    /// Rejects a reply that does not reach `internal_page_count`.
    nonisolated static func validate(returnedCount: mach_msg_type_number_t) throws(ReadError) {
        guard returnedCount >= requiredFieldCount else {
            throw ReadError.truncatedStatistics(returnedCount)
        }
    }

    /// Cached host port. `mach_host_self()` returns a send right on every call,
    /// so it is acquired once instead of per sample.
    private let host: host_t

    /// Kernel page size in bytes, `0` when `host_page_size` failed.
    ///
    /// This is the page size the counters are expressed in. The C globals
    /// `vm_kernel_page_size` and `vm_page_size` are mutable shared state under
    /// Swift 6 and `hw.pagesize` reports the task map page size, so neither is
    /// used here.
    private let pageSize: UInt64

    /// Physical memory in bytes, read once at init.
    private let totalBytes: UInt64

    init() {
        let host = mach_host_self()
        self.host = host

        var size: vm_size_t = 0
        let status = host_page_size(host, &size)
        self.pageSize = status == KERN_SUCCESS ? UInt64(size) : 0

        self.totalBytes = ProcessInfo.processInfo.physicalMemory
    }

    func readCounts() throws -> MemoryPageCounts {
        guard pageSize > 0 else { throw ReadError.invalidPageSize }

        var stats = vm_statistics64_data_t()
        var count = Self.fullFieldCount

        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(host, host_flavor_t(HOST_VM_INFO64), rebound, &count)
            }
        }

        guard status == KERN_SUCCESS else { throw ReadError.machCall(status) }
        try Self.validate(returnedCount: count)

        return MemoryPageCounts(
            freeCount: UInt64(stats.free_count),
            wireCount: UInt64(stats.wire_count),
            purgeableCount: UInt64(stats.purgeable_count),
            speculativeCount: UInt64(stats.speculative_count),
            compressorPageCount: UInt64(stats.compressor_page_count),
            externalPageCount: UInt64(stats.external_page_count),
            internalPageCount: UInt64(stats.internal_page_count),
            pageSize: pageSize,
            totalBytes: totalBytes
        )
    }
}
