import Foundation
import Testing
@testable import system_monitor

// disk-metrics — DM-2 "Timestamp participates in equality" and DM-3
// "Reference capacity", "Free exceeds total", "Zero total", "Full volume".
//
// `used` is stored and computed once by the capacity initialiser, so the
// saturating subtraction is asserted through that initialiser while the
// `fraction` clamp is also pinned on a hand-built snapshot the initialiser
// itself can never produce.
@Suite("DiskSnapshot")
struct DiskSnapshotTests {

    // disk-metrics — DM-2 "Timestamp participates in equality"
    @Test func countersOneMillisecondApartAreNotEqual() {
        let first = DiskFixtures.counters(read: 1_000, written: 500, at: 0)
        let second = DiskFixtures.counters(read: 1_000, written: 500, at: 0.001)

        #expect(first != second)
    }

    @Test func countersWithTheSameFieldsAndStampAreEqual() {
        let first = DiskFixtures.counters(read: 1_000, written: 500, at: 0)
        let second = DiskFixtures.counters(read: 1_000, written: 500, at: 0)

        #expect(first == second)
    }

    @Test func aDifferentDriverCountBreaksEquality() {
        let first = DiskFixtures.counters(read: 1_000, written: 500, driverCount: 1, at: 0)
        let second = DiskFixtures.counters(read: 1_000, written: 500, driverCount: 2, at: 0)

        #expect(first != second)
    }

    // disk-metrics — DM-3 "Reference capacity"
    @Test func theReferenceCapacityDerivesUsedAndFraction() {
        let snapshot = DiskSnapshot(
            total: DiskFixtures.referenceCapacity.total,
            free: DiskFixtures.referenceCapacity.free,
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil
        )

        #expect(snapshot.used == 432_068_000_000)
        #expect(abs(snapshot.fraction - 0.874) < 0.0005)
    }

    // disk-metrics — DM-3 "Free exceeds total"
    @Test func freeAboveTotalSaturatesUsedAtZeroWithoutWraparound() {
        let snapshot = DiskSnapshot(
            total: 1_000,
            free: 1_500,
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil
        )

        #expect(snapshot.used == 0)
        #expect(snapshot.fraction == 0)
    }

    // disk-metrics — DM-3 "Zero total"
    @Test func aZeroTotalKeepsTheFractionExactlyZero() {
        let snapshot = DiskSnapshot(
            total: 0,
            free: 0,
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil
        )

        #expect(snapshot.fraction == 0)
        #expect(snapshot.fraction.isNaN == false)
        #expect(snapshot.fraction.isInfinite == false)
    }

    // disk-metrics — DM-3 "Full volume"
    @Test func aFullVolumeReportsFractionExactlyOne() {
        let snapshot = DiskSnapshot(
            total: 1_000,
            free: 0,
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil
        )

        #expect(snapshot.used == 1_000)
        #expect(snapshot.fraction == 1)
    }

    // The capacity initialiser cannot produce `used > total`, so the clamp is
    // pinned through the memberwise initialiser the extension-declared
    // convenience initialiser deliberately preserves.
    @Test func aHandBuiltUsedAboveTotalClampsTheFractionToOne() {
        let snapshot = DiskSnapshot(
            total: 1_000,
            free: 0,
            used: 4_000,
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil
        )

        #expect(snapshot.fraction == 1)
    }

    // disk-metrics — DM-1: the disk value types are `Equatable`.
    @Test func capacitiesCompareByValue() {
        let capacity = VolumeCapacity(total: 494_354_000_000, free: 62_286_000_000)

        #expect(capacity == DiskFixtures.referenceCapacity)
        #expect(capacity != VolumeCapacity(total: 494_354_000_000, free: 62_286_000_001))
    }

    @Test func snapshotsCompareByValueIncludingTheRates() {
        let withRates = DiskSnapshot(
            total: 494_354_000_000,
            free: 62_286_000_000,
            readBytesPerSecond: 27_100_000,
            writeBytesPerSecond: 2_200_000
        )
        let withoutRates = DiskSnapshot(
            total: 494_354_000_000,
            free: 62_286_000_000,
            readBytesPerSecond: nil,
            writeBytesPerSecond: nil
        )

        #expect(withRates == DiskFixtures.referenceSnapshot)
        #expect(withRates != withoutRates)
    }
}
