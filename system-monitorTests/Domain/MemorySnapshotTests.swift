import Foundation
import Testing
@testable import system_monitor

// memory-metrics — MM-3 "Fraction", "Zero total".
//
// `used` is a stored field (design decision 1), so these tests build snapshots
// directly instead of going through the calculator; that is the only way to
// pin the guards `fraction` and `unattributedUsed` apply to inconsistent input.
@Suite("MemorySnapshot")
struct MemorySnapshotTests {

    private func snapshot(
        total: UInt64,
        app: UInt64 = 0,
        wired: UInt64 = 0,
        compressed: UInt64 = 0,
        cached: UInt64 = 0,
        free: UInt64 = 0,
        used: UInt64
    ) -> MemorySnapshot {
        MemorySnapshot(
            total: total,
            app: app,
            wired: wired,
            compressed: compressed,
            cached: cached,
            free: free,
            used: used
        )
    }

    // memory-metrics — MM-3 "Fraction"
    @Test func fractionIsTheUsedShareOfTotal() {
        let value = snapshot(total: 8_589_934_592, used: 6_623_854_592)

        #expect(abs(value.fraction - 0.7711) < 0.0001)
    }

    // memory-metrics — MM-3 "Zero total"
    @Test func fractionIsExactlyZeroWhenTotalIsZero() {
        let value = snapshot(total: 0, used: 0)

        #expect(value.fraction == 0)
        #expect(value.fraction.isNaN == false)
        #expect(value.fraction.isInfinite == false)
    }

    @Test func fractionStaysZeroWhenTotalIsZeroButUsedIsNot() {
        let value = snapshot(total: 0, used: 4_096)

        #expect(value.fraction == 0)
        #expect(value.fraction.isNaN == false)
    }

    // memory-metrics — MM-2 "Free plus Cached exceed Total" reads the same
    // clamp from the other side: a hand-built `used > total` never exceeds 1.
    @Test func fractionClampsToOneWhenUsedExceedsTotal() {
        let value = snapshot(total: 1_000, used: 4_000)

        #expect(value.fraction == 1)
    }

    @Test func fractionIsOneWhenUsedEqualsTotal() {
        let value = snapshot(total: 2_048, used: 2_048)

        #expect(value.fraction == 1)
    }

    @Test func unattributedUsedIsWhatUsedKeepsBeyondAppWiredAndCompressed() {
        let value = snapshot(
            total: 8_589_934_592,
            app: 2_949_120_000,
            wired: 1_966_080_000,
            compressed: 1_474_560_000,
            used: 6_623_854_592
        )

        #expect(value.unattributedUsed == 234_094_592)
    }

    @Test func unattributedUsedIsZeroWhenTheLabelledComponentsCoverUsed() {
        let value = snapshot(
            total: 8_589_934_592,
            app: 4_000_000_000,
            wired: 3_000_000_000,
            compressed: 2_000_000_000,
            used: 1_000_000_000
        )

        #expect(value.unattributedUsed == 0)
    }

    @Test func unattributedUsedSaturatesInsteadOfTrappingOnHugeComponents() {
        let value = snapshot(
            total: UInt64.max,
            app: UInt64.max,
            wired: UInt64.max,
            compressed: UInt64.max,
            used: UInt64.max
        )

        #expect(value.unattributedUsed == 0)
    }

    @Test func snapshotsWithTheSameFieldsAreEqual() {
        let left = snapshot(
            total: 8_589_934_592,
            app: 1_460_961_280,
            wired: 1_986_560_000,
            compressed: 1_954_283_520,
            cached: 983_040_000,
            free: 1_680_801_792,
            used: 5_926_092_800
        )
        let right = snapshot(
            total: 8_589_934_592,
            app: 1_460_961_280,
            wired: 1_986_560_000,
            compressed: 1_954_283_520,
            cached: 983_040_000,
            free: 1_680_801_792,
            used: 5_926_092_800
        )

        #expect(left == right)
    }

    @Test func snapshotsDifferingInASingleFieldAreNotEqual() {
        let left = snapshot(total: 8_589_934_592, used: 5_926_092_800)
        let right = snapshot(total: 8_589_934_592, used: 5_926_092_801)

        #expect(left != right)
    }

    // memory-metrics — MM-1: the raw counts value carries the seven counters
    // plus page size and total, and compares by value.
    @Test func pageCountsExposeEveryCounterFromTheMemberwiseInit() {
        let counts = MemoryPageCounts(
            freeCount: 60_000,
            wireCount: 120_000,
            purgeableCount: 20_000,
            speculativeCount: 10_000,
            compressorPageCount: 90_000,
            externalPageCount: 50_000,
            internalPageCount: 200_000,
            pageSize: 16_384,
            totalBytes: 8_589_934_592
        )

        #expect(counts.freeCount == 60_000)
        #expect(counts.wireCount == 120_000)
        #expect(counts.purgeableCount == 20_000)
        #expect(counts.speculativeCount == 10_000)
        #expect(counts.compressorPageCount == 90_000)
        #expect(counts.externalPageCount == 50_000)
        #expect(counts.internalPageCount == 200_000)
        #expect(counts.pageSize == 16_384)
        #expect(counts.totalBytes == 8_589_934_592)
    }

    @Test func pageCountsDifferingInOneCounterAreNotEqual() {
        let left = MemoryPageCounts(
            freeCount: 1,
            wireCount: 2,
            purgeableCount: 3,
            speculativeCount: 4,
            compressorPageCount: 5,
            externalPageCount: 6,
            internalPageCount: 7,
            pageSize: 16_384,
            totalBytes: 1_024
        )
        let right = MemoryPageCounts(
            freeCount: 1,
            wireCount: 2,
            purgeableCount: 3,
            speculativeCount: 4,
            compressorPageCount: 5,
            externalPageCount: 6,
            internalPageCount: 8,
            pageSize: 16_384,
            totalBytes: 1_024
        )

        #expect(left != right)
        #expect(left == left)
    }
}
