import Foundation

/// Raw `vm_statistics64` page counters plus the two facts needed to turn them
/// into bytes.
///
/// Field names mirror the Mach struct. The kernel publishes the counters as
/// `natural_t` (32 bit); the adapter widens every one of them to `UInt64` so
/// each subtraction the calculator performs happens in 64 bits and a large
/// count multiplied by the page size cannot overflow.
nonisolated struct MemoryPageCounts: Sendable, Equatable {

    /// Pages on the free list. Includes the speculative pages.
    let freeCount: UInt64

    /// Pages wired into physical memory and never paged out.
    let wireCount: UInt64

    /// Pages the kernel may reclaim on demand; part of both App and Cached.
    let purgeableCount: UInt64

    /// Free pages read ahead speculatively, which the system still counts free.
    let speculativeCount: UInt64

    /// Pages held by the compressor.
    let compressorPageCount: UInt64

    /// File-backed pages.
    let externalPageCount: UInt64

    /// Anonymous pages.
    let internalPageCount: UInt64

    /// Bytes per page, read from `host_page_size()`.
    let pageSize: UInt64

    /// Physical memory in bytes, read from `ProcessInfo.processInfo.physicalMemory`.
    let totalBytes: UInt64
}
