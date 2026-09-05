import Foundation
import Testing
@testable import system_monitor

/// One fully derived expectation, so the two complete fixtures run through the
/// same parameterized assertions.
nonisolated struct MemoryCalculatorCase: Sendable, CustomTestStringConvertible {
    let name: String
    let counts: MemoryPageCounts
    let app: UInt64
    let wired: UInt64
    let compressed: UInt64
    let cached: UInt64
    let free: UInt64
    let used: UInt64
    let unattributedUsed: UInt64
    let fraction: Double

    var testDescription: String { name }

    static let reference = MemoryCalculatorCase(
        name: "reference",
        counts: MemoryFixtures.reference,
        app: 2_949_120_000,
        wired: 1_966_080_000,
        compressed: 1_474_560_000,
        cached: 983_040_000,
        free: 819_200_000,
        used: 6_787_694_592,
        unattributedUsed: 397_934_592,
        fraction: 0.7902
    )

    static let eightGiB = MemoryCalculatorCase(
        name: "eightGiB",
        counts: MemoryFixtures.eightGiB,
        app: 1_460_961_280,
        wired: 1_986_560_000,
        compressed: 1_954_283_520,
        cached: 901_120_000,
        free: 1_762_721_792,
        used: 5_926_092_800,
        unattributedUsed: 524_288_000,
        fraction: 0.6899
    )

    static let all: [MemoryCalculatorCase] = [.reference, .eightGiB]
}

// memory-metrics — MM-2 "Byte components from page counts".
@Suite("MemoryUsageCalculator")
struct MemoryUsageCalculatorTests {

    // memory-metrics — MM-2 "Reference counts at 16 KiB pages"
    @Test(arguments: MemoryCalculatorCase.all)
    func everyByteComponentFollowsTheActivityMonitorFormula(testCase: MemoryCalculatorCase) {
        let snapshot = MemoryUsageCalculator.snapshot(from: testCase.counts)

        #expect(snapshot.total == testCase.counts.totalBytes)
        #expect(snapshot.app == testCase.app)
        #expect(snapshot.wired == testCase.wired)
        #expect(snapshot.compressed == testCase.compressed)
        #expect(snapshot.cached == testCase.cached)
        #expect(snapshot.free == testCase.free)
        #expect(snapshot.used == testCase.used)
    }

    // memory-metrics — MM-3: `used` is Total − Free − Cached, never the sum of
    // App, Wired and Compressed.
    @Test(arguments: MemoryCalculatorCase.all)
    func usedIsTotalMinusFreeMinusCached(testCase: MemoryCalculatorCase) {
        let snapshot = MemoryUsageCalculator.snapshot(from: testCase.counts)

        #expect(snapshot.used == snapshot.total - snapshot.free - snapshot.cached)
        #expect(snapshot.used != snapshot.app + snapshot.wired + snapshot.compressed)
    }

    @Test(arguments: MemoryCalculatorCase.all)
    func unattributedUsedIsTheRemainderTheLabelledComponentsDoNotCover(testCase: MemoryCalculatorCase) {
        let snapshot = MemoryUsageCalculator.snapshot(from: testCase.counts)

        #expect(snapshot.unattributedUsed == testCase.unattributedUsed)
        #expect(
            snapshot.app + snapshot.unattributedUsed + snapshot.wired
                + snapshot.compressed + snapshot.cached + snapshot.free
                == snapshot.total
        )
    }

    @Test(arguments: MemoryCalculatorCase.all)
    func fractionMatchesTheUsedShareOfTotal(testCase: MemoryCalculatorCase) {
        let snapshot = MemoryUsageCalculator.snapshot(from: testCase.counts)

        #expect(abs(snapshot.fraction - testCase.fraction) < 0.0001)
    }

    // memory-metrics — MM-2: Cached is the file-backed cache plus the
    // speculative pages the kernel reads ahead. Purgeable pages are neither
    // App nor Cached: they stay inside Used, which is what Activity Monitor
    // reports as "Memory Used".
    @Test(arguments: MemoryCalculatorCase.all)
    func cachedCountsSpeculativePagesAndKeepsPurgeableOnesInsideUsed(testCase: MemoryCalculatorCase) {
        let counts = testCase.counts
        let snapshot = MemoryUsageCalculator.snapshot(from: counts)

        #expect(
            snapshot.cached
                == (counts.externalPageCount + counts.speculativeCount) * counts.pageSize
        )
        #expect(snapshot.used + snapshot.cached + snapshot.free == snapshot.total)
        #expect(snapshot.unattributedUsed >= counts.purgeableCount * counts.pageSize)
    }

    // memory-metrics — MM-2 "Purgeable exceeds internal"
    //
    // Purgeable pages are not file-backed cache: they leave App but stay inside
    // Used, so Cached does not move and Used keeps the whole total.
    @Test func appSaturatesAtZeroWhenPurgeableExceedsInternal() {
        let snapshot = MemoryUsageCalculator.snapshot(from: MemoryFixtures.purgeableExceedsInternal)

        #expect(snapshot.app == 0)
        #expect(snapshot.cached == 0)
        #expect(snapshot.used == snapshot.total)
    }

    // memory-metrics — MM-2 "Speculative exceeds free"
    //
    // Speculative pages are cache, not free memory: Free saturates at 0 while
    // the same pages appear in Cached and leave Used.
    @Test func freeSaturatesAtZeroWhenSpeculativeExceedsFree() {
        let snapshot = MemoryUsageCalculator.snapshot(from: MemoryFixtures.speculativeExceedsFree)

        #expect(snapshot.free == 0)
        #expect(snapshot.cached == 20 * MemoryFixtures.pageSize)
        #expect(snapshot.used == snapshot.total - 20 * MemoryFixtures.pageSize)
    }

    // memory-metrics — MM-2 "Free plus file-backed pages exceed Total"
    @Test func usedSaturatesAtZeroWhenFreePlusCachedExceedTotal() {
        let snapshot = MemoryUsageCalculator.snapshot(from: MemoryFixtures.freePlusCachedExceedTotal)

        #expect(snapshot.free == 960)
        #expect(snapshot.cached == 640)
        #expect(snapshot.used == 0)
        #expect(snapshot.fraction == 0)
    }

    // memory-metrics — MM-2 "Large 32-bit counts do not overflow"
    @Test func aFullThirtyTwoBitWiredCountWidensWithoutSaturating() {
        let snapshot = MemoryUsageCalculator.snapshot(from: MemoryFixtures.uint32MaxWired)

        #expect(snapshot.wired == 70_368_744_161_280)
        #expect(snapshot.wired != UInt64.max)
    }

    @Test func countsAtTheSixtyFourBitCeilingSaturateInsteadOfTrapping() {
        let snapshot = MemoryUsageCalculator.snapshot(from: MemoryFixtures.overflowingCounts)

        #expect(snapshot.app == UInt64.max)
        #expect(snapshot.wired == UInt64.max)
        #expect(snapshot.compressed == UInt64.max)
        #expect(snapshot.cached == UInt64.max)
        #expect(snapshot.free == UInt64.max)
        #expect(snapshot.used == 0)
    }

    // memory-metrics — MM-3 "Zero total"
    @Test func anEmptyHostReadsAllZeroesWithoutANotANumberFraction() {
        let snapshot = MemoryUsageCalculator.snapshot(from: MemoryFixtures.zero)

        #expect(snapshot.total == 0)
        #expect(snapshot.app == 0)
        #expect(snapshot.wired == 0)
        #expect(snapshot.compressed == 0)
        #expect(snapshot.cached == 0)
        #expect(snapshot.free == 0)
        #expect(snapshot.used == 0)
        #expect(snapshot.fraction == 0)
        #expect(snapshot.fraction.isNaN == false)
    }

    @Test func theFixtureHelperReturnsTheSameSnapshotAsTheCalculator() {
        #expect(
            MemoryFixtures.snapshot(from: MemoryFixtures.reference)
                == MemoryUsageCalculator.snapshot(from: MemoryFixtures.reference)
        )
    }
}
