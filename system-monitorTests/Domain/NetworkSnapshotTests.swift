import Foundation
import Testing
@testable import system_monitor

// network-metrics — NM-2 "Timestamp participates in equality", "Summed
// counters carry the interface count"; NM-3 "Rates travel together", "Totals
// without rates".
//
// Every stamp comes from `NetworkFixtures.base`, so the assertions only ever
// depend on the difference between two instants.
@Suite("NetworkSnapshot")
struct NetworkSnapshotTests {

    // network-metrics — NM-2 "Timestamp participates in equality"
    @Test func countersOneMillisecondApartAreNotEqual() {
        let first = NetworkFixtures.counters(in: 1_000, out: 500, at: 0)
        let second = NetworkFixtures.counters(in: 1_000, out: 500, at: 0.001)

        #expect(first != second)
    }

    @Test func countersWithTheSameFieldsAndStampAreEqual() {
        let first = NetworkFixtures.counters(in: 1_000, out: 500, at: 0)
        let second = NetworkFixtures.counters(in: 1_000, out: 500, at: 0)

        #expect(first == second)
    }

    @Test func theTwoReferenceHalvesAreNotEqual() {
        #expect(NetworkFixtures.referencePrevious != NetworkFixtures.referenceCurrent)
    }

    // network-metrics — NM-2 "Summed counters carry the interface count"
    @Test func summedCountersCarryTheInterfaceCountAndTheSummedBytes() {
        let firstInterface = (bytesIn: UInt64(3_849_000_000), bytesOut: UInt64(2_759_000_000))
        let secondInterface = (bytesIn: UInt64(1_000_000), bytesOut: UInt64(922_000))

        let summed = NetworkFixtures.counters(
            in: firstInterface.bytesIn + secondInterface.bytesIn,
            out: firstInterface.bytesOut + secondInterface.bytesOut,
            interfaceCount: 2,
            at: 0
        )

        #expect(summed.interfaceCount == 2)
        #expect(summed.bytesIn == 3_850_000_000)
        #expect(summed.bytesOut == 2_759_922_000)
    }

    @Test func aDifferentInterfaceCountBreaksEquality() {
        let first = NetworkFixtures.counters(in: 1_000, out: 500, interfaceCount: 1, at: 0)
        let second = NetworkFixtures.counters(in: 1_000, out: 500, interfaceCount: 2, at: 0)

        #expect(first != second)
    }

    // network-metrics — NM-3 "Rates travel together"
    @Test func theReferenceSnapshotCarriesBothTotalsAndBothRates() {
        let snapshot = NetworkFixtures.referenceSnapshot

        #expect(snapshot.totalIn == 3_850_000_000)
        #expect(snapshot.totalOut == 2_760_000_000)
        #expect(snapshot.downloadBytesPerSecond == 5_000)
        #expect(snapshot.uploadBytesPerSecond == 78_000)
    }

    // network-metrics — NM-3 "Totals without rates"
    @Test func aSnapshotWithoutRatesStillCarriesBothTotals() {
        let snapshot = NetworkSnapshot(
            totalIn: NetworkFixtures.referenceCurrent.bytesIn,
            totalOut: NetworkFixtures.referenceCurrent.bytesOut,
            downloadBytesPerSecond: nil,
            uploadBytesPerSecond: nil
        )

        #expect(snapshot.totalIn == 3_850_000_000)
        #expect(snapshot.totalOut == 2_760_000_000)
        #expect(snapshot.downloadBytesPerSecond == nil)
        #expect(snapshot.uploadBytesPerSecond == nil)
    }

    // network-metrics — NM-1: the network value types are `Equatable`, and the
    // rates take part in equality just as the totals do.
    @Test func snapshotsCompareByValueIncludingTheRates() {
        let withRates = NetworkSnapshot(
            totalIn: 3_850_000_000,
            totalOut: 2_760_000_000,
            downloadBytesPerSecond: 5_000,
            uploadBytesPerSecond: 78_000
        )
        let withoutRates = NetworkSnapshot(
            totalIn: 3_850_000_000,
            totalOut: 2_760_000_000,
            downloadBytesPerSecond: nil,
            uploadBytesPerSecond: nil
        )

        #expect(withRates == NetworkFixtures.referenceSnapshot)
        #expect(withRates != withoutRates)
        #expect(withoutRates != NetworkFixtures.referenceSnapshot)
    }

    // The empty-script value every fake falls back to: a valid reading that
    // carries no interface, so no rate can ever be derived from it.
    @Test func theIdleFixtureIsAValidReadingWithoutInterfaces() {
        #expect(NetworkFixtures.idle.interfaceCount == 0)
        #expect(NetworkFixtures.idle.bytesIn == 0)
        #expect(NetworkFixtures.idle.bytesOut == 0)
    }
}
