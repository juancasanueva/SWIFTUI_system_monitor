import Foundation

/// Pure conversion of raw kernel page counters into a `MemorySnapshot`.
///
/// This is the single place the Activity Monitor formula lives:
/// App = internal − purgeable, Wired = wire, Compressed = compressor,
/// Cached = external + speculative, Free = free − speculative and
/// Used = Total − Free − Cached (equivalently Total − free − external).
///
/// Only free and file-backed pages leave Used. Purgeable pages are
/// deducted from App but stay inside Used, and speculative pages are deducted
/// from Free while staying inside Cached, which is what Activity Monitor
/// reports: its "Memory Used" is the total minus the free and file-backed
/// pages, so purgeable and speculative memory shows up in the unattributed
/// remainder rather than in App, Wired or Compressed.
///
/// The counters are sampled independently by the kernel, so a later field can
/// legitimately exceed an earlier one within the same read. Every subtraction
/// therefore saturates at 0 and every addition and multiplication saturates at
/// `UInt64.max`: an inconsistent read yields a clamped snapshot instead of a
/// wrapped value or a trap.
nonisolated enum MemoryUsageCalculator {

    static func snapshot(from counts: MemoryPageCounts) -> MemorySnapshot {
        let pageSize = counts.pageSize

        let app = bytes(pages: subtracting(counts.internalPageCount, counts.purgeableCount), pageSize: pageSize)
        let wired = bytes(pages: counts.wireCount, pageSize: pageSize)
        let compressed = bytes(pages: counts.compressorPageCount, pageSize: pageSize)
        let cached = bytes(pages: adding(counts.externalPageCount, counts.speculativeCount), pageSize: pageSize)
        let free = bytes(pages: subtracting(counts.freeCount, counts.speculativeCount), pageSize: pageSize)
        // Free and Cached share the speculative pages, so this is exactly
        // Total − (free + external) × pageSize while keeping the
        // Used + Cached + Free == Total invariant true by construction.
        let used = subtracting(subtracting(counts.totalBytes, free), cached)

        return MemorySnapshot(
            total: counts.totalBytes,
            app: app,
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: free,
            used: used
        )
    }

    // MARK: - Saturating arithmetic

    /// `lhs - rhs`, clamped at 0.
    private static func subtracting(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        lhs > rhs ? lhs - rhs : 0
    }

    /// `lhs + rhs`, clamped at `UInt64.max`.
    private static func adding(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (sum, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : sum
    }

    /// `pages * pageSize`, clamped at `UInt64.max`.
    ///
    /// The counters arrive already widened from `natural_t`, so a realistic
    /// host never reaches the clamp; it exists so a corrupt read cannot trap.
    private static func bytes(pages: UInt64, pageSize: UInt64) -> UInt64 {
        let (product, overflow) = pages.multipliedReportingOverflow(by: pageSize)
        return overflow ? .max : product
    }
}
