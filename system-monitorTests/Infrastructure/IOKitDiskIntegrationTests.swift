import Foundation
import Testing
@testable import system_monitor

// disk-metrics — DM-12 "Sandboxed shape", "Counters are monotonic with
// advancing stamps", "Repeated reads".
//
// These run the real adapter inside the sandboxed test host, which is what
// proves the `IOBlockStorageDriver` `Statistics` dictionary is reachable under
// App Sandbox (`ENABLE_APP_SANDBOX = YES`). They assert shape and internal
// consistency, never specific hardware values, so they hold on any Mac the
// project is built on.
@Suite("IOKitDiskProvider against the real IORegistry", .tags(.integration), .timeLimit(.minutes(1)))
struct IOKitDiskIntegrationTests {

    // disk-metrics — DM-12 "Sandboxed shape"
    @Test func theSandboxedHostSeesAtLeastOneDriverWithBytesRead() throws {
        let counters = try IOKitDiskProvider().readThroughput()

        #expect(counters.driverCount >= 1)
        #expect(counters.bytesRead > 0)
    }

    // disk-metrics — DM-12 "Counters are monotonic with advancing stamps"
    @Test func twoReadsAreMonotonicAndTheStampAdvances() async throws {
        let provider = IOKitDiskProvider()

        let first = try provider.readThroughput()
        try await Task.sleep(for: .milliseconds(120))
        let second = try provider.readThroughput()

        #expect(second.bytesRead >= first.bytesRead)
        #expect(second.bytesWritten >= first.bytesWritten)
        #expect(second.timestamp > first.timestamp)
        #expect(second.timestamp - first.timestamp >= .milliseconds(120))
    }

    // disk-metrics — DM-12 "Repeated reads"
    @Test func fiftyConsecutiveReadsAllSucceed() throws {
        let provider = IOKitDiskProvider()

        var readings: [DiskThroughputCounters] = []
        for _ in 0..<50 {
            readings.append(try provider.readThroughput())
        }

        #expect(readings.count == 50)
        #expect(readings.allSatisfy { $0.driverCount >= 1 })
        #expect(readings.allSatisfy { $0.bytesRead > 0 })
    }

    @Test func theDriverCountIsStableBetweenReads() throws {
        let provider = IOKitDiskProvider()

        let first = try provider.readThroughput()
        let second = try provider.readThroughput()

        #expect(first.driverCount == second.driverCount)
    }

    /// The stamp is taken by the adapter, so it belongs to the same clock the
    /// Domain rate rule subtracts on.
    @Test func theStampSitsBetweenTheInstantsSurroundingTheRead() throws {
        let before = ContinuousClock.now
        let counters = try IOKitDiskProvider().readThroughput()
        let after = ContinuousClock.now

        #expect(counters.timestamp >= before)
        #expect(counters.timestamp <= after)
    }

    /// A real reading feeds the Domain rule without any adapter-side massaging:
    /// two live readings produce a non-negative rate pair.
    @Test func aLiveReadingPairProducesNonNegativeRates() async throws {
        let provider = IOKitDiskProvider()

        let previous = try provider.readThroughput()
        try await Task.sleep(for: .milliseconds(120))
        let current = try provider.readThroughput()

        let rates = try #require(
            DiskThroughputCalculator.rates(previous: previous, current: current)
        )

        #expect(rates.readBytesPerSecond >= 0)
        #expect(rates.writeBytesPerSecond >= 0)
    }
}
