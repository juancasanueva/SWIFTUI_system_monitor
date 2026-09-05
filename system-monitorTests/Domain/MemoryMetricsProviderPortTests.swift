import Foundation
import Testing
@testable import system_monitor

// memory-metrics — MM-1 "Fake provider satisfies the port", "Scripted failure"
@Suite("Memory metrics port doubles")
struct MemoryMetricsProviderPortTests {

    @Test func scriptedFakeReturnsEachCountsValueInOrder() throws {
        let provider = FakeMemoryProvider(counts: [MemoryFixtures.reference, MemoryFixtures.eightGiB])

        let first = try provider.readCounts()
        let second = try provider.readCounts()

        #expect(first == MemoryFixtures.reference)
        #expect(second == MemoryFixtures.eightGiB)
        #expect(provider.callCount == 2)
    }

    @Test func exhaustedScriptRepeatsTheLastValue() throws {
        let provider = FakeMemoryProvider(counts: [MemoryFixtures.reference, MemoryFixtures.eightGiB])

        _ = try provider.readCounts()
        _ = try provider.readCounts()
        let third = try provider.readCounts()

        #expect(third == MemoryFixtures.eightGiB)
        #expect(provider.callCount == 3)
    }

    // memory-metrics — MM-1 "Scripted failure": the index is zero-based, and a
    // throwing call advances the call count without consuming a scripted value.
    @Test func scriptedCallsThrowAtTheRequestedZeroBasedIndex() throws {
        let provider = FakeMemoryProvider(
            counts: [MemoryFixtures.reference, MemoryFixtures.eightGiB],
            throwOnCall: [0]
        )

        #expect(throws: FakeMemoryProvider.ScriptedError.self) {
            _ = try provider.readCounts()
        }

        let second = try provider.readCounts()

        #expect(second == MemoryFixtures.reference)
        #expect(provider.callCount == 2)
    }

    @Test func aThrowingCallInTheMiddleKeepsTheRemainingScript() throws {
        let provider = FakeMemoryProvider(
            counts: [MemoryFixtures.reference, MemoryFixtures.eightGiB],
            throwOnCall: [1]
        )

        let first = try provider.readCounts()
        #expect(first == MemoryFixtures.reference)

        #expect(throws: FakeMemoryProvider.ScriptedError.self) {
            _ = try provider.readCounts()
        }

        let third = try provider.readCounts()
        #expect(third == MemoryFixtures.eightGiB)
        #expect(provider.callCount == 3)
    }

    // memory-metrics — MM-8 relies on this recording; here it only proves the
    // fake captures the thread of every call.
    @Test func providerRecordsTheThreadOfEveryRead() throws {
        let provider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])

        let expected = Thread.isMainThread
        _ = try provider.readCounts()
        _ = try provider.readCounts()

        #expect(provider.readOnMainThread == [expected, expected])
    }

    @Test func anEmptyScriptReadsTheZeroFixture() throws {
        let provider = FakeMemoryProvider(counts: [])

        let counts = try provider.readCounts()

        #expect(counts == MemoryFixtures.zero)
        #expect(provider.callCount == 1)
    }

    @Test func theFakeIsUsableThroughThePortItself() throws {
        let provider: any MemoryMetricsProvider = FakeMemoryProvider(counts: [MemoryFixtures.reference])

        let counts = try provider.readCounts()
        let snapshot = MemoryUsageCalculator.snapshot(from: counts)

        #expect(snapshot.used == 6_787_694_592)
    }
}
