import Foundation
@testable import system_monitor

/// Reusable page counts for the Domain, Application and Presentation suites.
///
/// Every fixture is expressed in raw pages so the tests exercise the real
/// widening and saturation paths of `MemoryUsageCalculator` instead of
/// hand-built byte values.
nonisolated enum MemoryFixtures {

    /// Kernel page size on Apple Silicon, used by every fixture but
    /// `freePlusCachedExceedTotal` and `overflowingCounts`.
    static let pageSize: UInt64 = 16_384

    /// memory-metrics MM-2 "Reference counts at 16 KiB pages", on an 8 GiB machine.
    ///
    /// Derived bytes: app 2_949_120_000, wired 1_966_080_000, compressed
    /// 1_474_560_000, cached 983_040_000, free 819_200_000, used
    /// 6_787_694_592 (fraction 0.79019…), unattributedUsed 397_934_592
    /// (24_288 pages). The six stacked-bar segments sum to 8_589_934_592
    /// exactly.
    static let reference = MemoryPageCounts(
        freeCount: 60_000,
        wireCount: 120_000,
        purgeableCount: 20_000,
        speculativeCount: 10_000,
        compressorPageCount: 90_000,
        externalPageCount: 50_000,
        internalPageCount: 200_000,
        pageSize: pageSize,
        totalBytes: 8_589_934_592
    )

    /// 8 GiB machine reproducing the reference card (memory-card MC-4):
    /// Used 5.52 GB / 69.0%, Wired 1.85 GB, Compressed 1.82 GB.
    ///
    /// Derived bytes: app 1_460_961_280, wired 1_986_560_000, compressed
    /// 1_954_283_520, cached 901_120_000, free 1_762_721_792, used
    /// 5_926_092_800 (fraction 0.68989…), unattributedUsed 524_288_000.
    static let eightGiB = MemoryPageCounts(
        freeCount: 112_588,
        wireCount: 121_250,
        purgeableCount: 10_000,
        speculativeCount: 5_000,
        compressorPageCount: 119_280,
        externalPageCount: 50_000,
        internalPageCount: 99_170,
        pageSize: pageSize,
        totalBytes: 8_589_934_592
    )

    /// Every counter and the total at zero: the snapshot must read all zeroes
    /// with a fraction of exactly 0 rather than NaN (MM-3 "Zero total").
    static let zero = MemoryPageCounts(
        freeCount: 0,
        wireCount: 0,
        purgeableCount: 0,
        speculativeCount: 0,
        compressorPageCount: 0,
        externalPageCount: 0,
        internalPageCount: 0,
        pageSize: pageSize,
        totalBytes: 0
    )

    /// MM-2 "Purgeable exceeds internal": internal 10, purgeable 20 → app 0.
    /// Purgeable pages no longer reach Cached, so cached stays at 0 and the
    /// 20 purgeable pages remain inside Used, exactly as Activity Monitor
    /// reports them.
    static let purgeableExceedsInternal = MemoryPageCounts(
        freeCount: 0,
        wireCount: 0,
        purgeableCount: 20,
        speculativeCount: 0,
        compressorPageCount: 0,
        externalPageCount: 0,
        internalPageCount: 10,
        pageSize: pageSize,
        totalBytes: 8_589_934_592
    )

    /// MM-2 "Speculative exceeds free": free 10, speculative 20 → free 0.
    /// The 20 speculative pages still land in Cached, so this fixture also
    /// pins that Cached is not bounded by `freeCount`.
    static let speculativeExceedsFree = MemoryPageCounts(
        freeCount: 10,
        wireCount: 0,
        purgeableCount: 0,
        speculativeCount: 20,
        compressorPageCount: 0,
        externalPageCount: 0,
        internalPageCount: 0,
        pageSize: pageSize,
        totalBytes: 8_589_934_592
    )

    /// MM-2 "Free plus file-backed pages exceed Total": free 960 + cached 640
    /// over a total of 1 000 bytes → used 0 and fraction 0.
    static let freePlusCachedExceedTotal = MemoryPageCounts(
        freeCount: 60,
        wireCount: 0,
        purgeableCount: 0,
        speculativeCount: 0,
        compressorPageCount: 0,
        externalPageCount: 40,
        internalPageCount: 0,
        pageSize: 16,
        totalBytes: 1_000
    )

    /// MM-2 "Large 32-bit counts do not overflow": `UInt32.max` wired pages at
    /// 16 KiB → wired == 70_368_744_161_280 exactly, without saturating.
    static let uint32MaxWired = MemoryPageCounts(
        freeCount: 0,
        wireCount: UInt64(UInt32.max),
        purgeableCount: 0,
        speculativeCount: 0,
        compressorPageCount: 0,
        externalPageCount: 0,
        internalPageCount: 0,
        pageSize: pageSize,
        totalBytes: 8_589_934_592
    )

    /// Extra triangulation beyond any real host: counters and page size at the
    /// `UInt64` ceiling, so the saturating add and multiply both trigger and no
    /// operation traps.
    static let overflowingCounts = MemoryPageCounts(
        freeCount: .max,
        wireCount: .max,
        purgeableCount: UInt64.max / 2,
        speculativeCount: UInt64.max / 4,
        compressorPageCount: .max,
        externalPageCount: .max,
        internalPageCount: .max,
        pageSize: .max,
        totalBytes: .max
    )

    /// Convenience over the production calculator, so presentation fixtures do
    /// not restate the formula.
    static func snapshot(from counts: MemoryPageCounts) -> MemorySnapshot {
        MemoryUsageCalculator.snapshot(from: counts)
    }
}
