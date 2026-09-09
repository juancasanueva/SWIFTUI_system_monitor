import Foundation
import Testing
@testable import system_monitor

// disk-metrics — DM-1 "Fake provider satisfies both halves", "Scripted
// failures are independent".
//
// The two halves of the port are scripted separately, so these tests also pin
// that a failure on one kind never disturbs the cursor or the count of the
// other.
@Suite("Disk metrics port doubles")
struct DiskMetricsProviderPortTests {

    private func provider(
        throwThroughputOnCall: Set<Int> = [],
        throwCapacityOnCall: Set<Int> = []
    ) -> FakeDiskProvider {
        FakeDiskProvider(
            throughput: [DiskFixtures.referencePrevious, DiskFixtures.referenceCurrent],
            capacities: [DiskFixtures.referenceCapacity, VolumeCapacity(total: 1_000, free: 250)],
            throwThroughputOnCall: throwThroughputOnCall,
            throwCapacityOnCall: throwCapacityOnCall
        )
    }

    // disk-metrics — DM-1 "Fake provider satisfies both halves"
    @Test func eachKindReturnsItsOwnScriptedValuesInOrder() throws {
        let fake = provider()

        let firstThroughput = try fake.readThroughput()
        let firstCapacity = try fake.readCapacity()
        let secondThroughput = try fake.readThroughput()
        let secondCapacity = try fake.readCapacity()

        #expect(firstThroughput == DiskFixtures.referencePrevious)
        #expect(secondThroughput == DiskFixtures.referenceCurrent)
        #expect(firstCapacity == DiskFixtures.referenceCapacity)
        #expect(secondCapacity == VolumeCapacity(total: 1_000, free: 250))
        #expect(fake.throughputCallCount == 2)
        #expect(fake.capacityCallCount == 2)
    }

    @Test func exhaustedScriptsRepeatTheLastValueOfTheirOwnKind() throws {
        let fake = provider()

        _ = try fake.readThroughput()
        _ = try fake.readThroughput()
        let thirdThroughput = try fake.readThroughput()

        _ = try fake.readCapacity()
        _ = try fake.readCapacity()
        let thirdCapacity = try fake.readCapacity()

        #expect(thirdThroughput == DiskFixtures.referenceCurrent)
        #expect(thirdCapacity == VolumeCapacity(total: 1_000, free: 250))
        #expect(fake.throughputCallCount == 3)
        #expect(fake.capacityCallCount == 3)
    }

    // disk-metrics — DM-1 "Scripted failures are independent": the indexes are
    // zero-based and each kind counts its own calls.
    @Test func scriptedFailuresHitOneKindWithoutDisturbingTheOther() throws {
        let fake = provider(throwThroughputOnCall: [0], throwCapacityOnCall: [1])

        #expect(throws: FakeDiskProvider.ScriptedError.self) {
            _ = try fake.readThroughput()
        }
        let firstCapacity = try fake.readCapacity()

        let secondThroughput = try fake.readThroughput()
        #expect(throws: FakeDiskProvider.ScriptedError.self) {
            _ = try fake.readCapacity()
        }

        #expect(firstCapacity == DiskFixtures.referenceCapacity)
        #expect(secondThroughput == DiskFixtures.referencePrevious)
        #expect(fake.throughputCallCount == 2)
        #expect(fake.capacityCallCount == 2)
    }

    // A throwing call advances the call count but never the value cursor, so
    // the remaining script is still delivered in order.
    @Test func aThrowingCallKeepsTheRemainingScriptOfItsKind() throws {
        let fake = provider(throwThroughputOnCall: [1])

        let first = try fake.readThroughput()
        #expect(first == DiskFixtures.referencePrevious)

        #expect(throws: FakeDiskProvider.ScriptedError.self) {
            _ = try fake.readThroughput()
        }

        let third = try fake.readThroughput()

        #expect(third == DiskFixtures.referenceCurrent)
        #expect(fake.throughputCallCount == 3)
        #expect(fake.capacityCallCount == 0)
    }

    @Test func anEmptyThroughputScriptReadsTheIdleFixture() throws {
        let fake = FakeDiskProvider(throughput: [], capacities: [DiskFixtures.referenceCapacity])

        let counters = try fake.readThroughput()

        #expect(counters == DiskFixtures.idle)
        #expect(counters.driverCount == 0)
        #expect(fake.throughputCallCount == 1)
    }

    @Test func anEmptyCapacityScriptReadsTheReferenceCapacity() throws {
        let fake = FakeDiskProvider(throughput: [DiskFixtures.referenceCurrent], capacities: [])

        let capacity = try fake.readCapacity()

        #expect(capacity == DiskFixtures.referenceCapacity)
        #expect(fake.capacityCallCount == 1)
    }

    // disk-metrics — DM-9 relies on this recording; here it only proves the
    // fake captures the thread of every read of either kind.
    @Test func theFakeRecordsTheThreadOfEveryReadOfBothKinds() throws {
        let fake = provider()

        let expected = Thread.isMainThread
        _ = try fake.readThroughput()
        _ = try fake.readCapacity()
        _ = try fake.readThroughput()

        #expect(fake.readOnMainThread == [expected, expected, expected])
    }

    @Test func theFakeIsUsableThroughThePortItself() throws {
        let port: any DiskMetricsProvider = provider()

        let previous = try port.readThroughput()
        let current = try port.readThroughput()
        let capacity = try port.readCapacity()

        let rates = try #require(
            DiskThroughputCalculator.rates(previous: previous, current: current)
        )

        #expect(rates.readBytesPerSecond == 27_100_000)
        #expect(capacity == DiskFixtures.referenceCapacity)
    }
}
