import Foundation
import Testing
@testable import system_monitor

// network-metrics — NM-1 "Fake provider returns scripted counters in order",
// "Scripted failure is observable".
//
// The port has a single read, so the fake keeps one script, one cursor and one
// call count; the throw indexes are zero-based and a throwing call advances the
// count without advancing the cursor.
@Suite("Network metrics port doubles")
struct NetworkMetricsProviderPortTests {

    private func provider(throwOnCall: Set<Int> = []) -> FakeNetworkProvider {
        FakeNetworkProvider(
            counters: [NetworkFixtures.referencePrevious, NetworkFixtures.referenceCurrent],
            throwOnCall: throwOnCall
        )
    }

    // network-metrics — NM-1 "Fake provider returns scripted counters in order"
    @Test func scriptedCountersAreReturnedInOrder() throws {
        let fake = provider()

        let first = try fake.readCounters()
        let second = try fake.readCounters()

        #expect(first == NetworkFixtures.referencePrevious)
        #expect(second == NetworkFixtures.referenceCurrent)
        #expect(fake.callCount == 2)
    }

    @Test func anExhaustedScriptRepeatsTheLastValue() throws {
        let fake = provider()

        _ = try fake.readCounters()
        _ = try fake.readCounters()
        let third = try fake.readCounters()

        #expect(third == NetworkFixtures.referenceCurrent)
        #expect(fake.callCount == 3)
    }

    // network-metrics — NM-1 "Scripted failure is observable": call 0 succeeds,
    // call 1 throws, and the cursor holds so the remaining script is still
    // delivered in order.
    @Test func aScriptedFailureThrowsOnItsCallWhileTheCursorHolds() throws {
        let fake = provider(throwOnCall: [1])

        let first = try fake.readCounters()
        #expect(first == NetworkFixtures.referencePrevious)

        #expect(throws: FakeNetworkProvider.ScriptedError.self) {
            _ = try fake.readCounters()
        }

        let third = try fake.readCounters()

        #expect(third == NetworkFixtures.referenceCurrent)
        #expect(fake.callCount == 3)
    }

    @Test func anEmptyScriptReadsTheIdleFixture() throws {
        let fake = FakeNetworkProvider(counters: [])

        let counters = try fake.readCounters()

        #expect(counters == NetworkFixtures.idle)
        #expect(counters.interfaceCount == 0)
        #expect(fake.callCount == 1)
    }

    // NM-7 relies on this recording; here it only proves the fake captures the
    // thread of every read.
    @Test func theFakeRecordsTheThreadOfEveryRead() throws {
        let fake = provider()

        let expected = Thread.isMainThread
        _ = try fake.readCounters()
        _ = try fake.readCounters()

        #expect(fake.readOnMainThread == [expected, expected])
    }

    @Test func theFakeIsUsableThroughThePortItself() throws {
        let port: any NetworkMetricsProvider = provider()

        let previous = try port.readCounters()
        let current = try port.readCounters()

        let rates = try #require(
            NetworkThroughputCalculator.rates(previous: previous, current: current)
        )

        #expect(rates.downloadBytesPerSecond == 5_000)
        #expect(rates.uploadBytesPerSecond == 78_000)
    }

    // The loop suites script `climbing()` so they never run dry; step 1 must be
    // the reference current half for their rate expectations to hold.
    @Test func theClimbingScriptStartsAtTheReferenceWindow() throws {
        let fake = FakeNetworkProvider(counters: NetworkFixtures.climbing(steps: 3))

        let first = try fake.readCounters()
        let second = try fake.readCounters()

        #expect(first == NetworkFixtures.referencePrevious)
        #expect(second == NetworkFixtures.referenceCurrent)
    }
}
