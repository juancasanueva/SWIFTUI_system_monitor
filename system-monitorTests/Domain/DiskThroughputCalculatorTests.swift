import Foundation
import Testing
@testable import system_monitor

// disk-metrics — DM-4 "Reference rate", "Elapsed time scales the rate",
// "No baseline", "No drivers", "Non-positive elapsed time", "Negative read
// delta nils both rates", "Negative write delta nils both rates", "Re-seeded
// baseline recovers on the next tick".
//
// Every stamp comes from `DiskFixtures.base`, so the assertions only ever
// depend on the difference between two instants.
@Suite("DiskThroughputCalculator")
struct DiskThroughputCalculatorTests {

    // disk-metrics — DM-4 "Reference rate"
    @Test func theReferenceWindowYieldsTheReferenceRates() throws {
        let rates = try #require(
            DiskThroughputCalculator.rates(
                previous: DiskFixtures.referencePrevious,
                current: DiskFixtures.referenceCurrent
            )
        )

        #expect(rates == DiskThroughputCalculator.Rates(
            readBytesPerSecond: 27_100_000,
            writeBytesPerSecond: 2_200_000
        ))
    }

    // disk-metrics — DM-4 "Elapsed time scales the rate"
    @Test func halvingTheWindowDoublesBothRates() throws {
        let current = DiskFixtures.counters(
            read: 1_027_100_000,
            written: 502_200_000,
            at: 0.5
        )

        let rates = try #require(
            DiskThroughputCalculator.rates(
                previous: DiskFixtures.referencePrevious,
                current: current
            )
        )

        #expect(rates.readBytesPerSecond == 54_200_000)
        #expect(rates.writeBytesPerSecond == 4_400_000)
    }

    // disk-metrics — DM-4 "No baseline"
    @Test func noBaselineYieldsNoRates() {
        #expect(
            DiskThroughputCalculator.rates(
                previous: nil,
                current: DiskFixtures.referenceCurrent
            ) == nil
        )
    }

    // disk-metrics — DM-4 "No drivers"
    @Test func aReadingWithoutDriversYieldsNoRates() {
        let current = DiskFixtures.counters(
            read: 1_027_100_000,
            written: 502_200_000,
            driverCount: 0,
            at: 1
        )

        #expect(
            DiskThroughputCalculator.rates(
                previous: DiskFixtures.referencePrevious,
                current: current
            ) == nil
        )
    }

    // disk-metrics — DM-4 "Non-positive elapsed time"
    @Test func aZeroWindowYieldsNoRates() {
        let current = DiskFixtures.counters(
            read: 1_027_100_000,
            written: 502_200_000,
            at: 0
        )

        #expect(
            DiskThroughputCalculator.rates(
                previous: DiskFixtures.referencePrevious,
                current: current
            ) == nil
        )
    }

    // disk-metrics — DM-4 "Non-positive elapsed time", the backwards half.
    @Test func aBackwardsWindowYieldsNoRates() {
        let previous = DiskFixtures.counters(read: 1_000_000_000, written: 500_000_000, at: 0)
        let current = DiskFixtures.counters(read: 1_027_100_000, written: 502_200_000, at: -0.001)

        #expect(DiskThroughputCalculator.rates(previous: previous, current: current) == nil)
    }

    // disk-metrics — DM-4 "Negative read delta nils both rates"
    @Test func aFallingReadCounterNilsBothRates() {
        let previous = DiskFixtures.counters(read: 2_000_000, written: 500_000, at: 0)
        let current = DiskFixtures.counters(read: 1_000_000, written: 600_000, at: 1)

        #expect(DiskThroughputCalculator.rates(previous: previous, current: current) == nil)
    }

    // disk-metrics — DM-4 "Negative write delta nils both rates"
    @Test func aFallingWriteCounterNilsBothRates() {
        let previous = DiskFixtures.counters(read: 1_000_000, written: 600_000, at: 0)
        let current = DiskFixtures.counters(read: 1_100_000, written: 500_000, at: 1)

        #expect(DiskThroughputCalculator.rates(previous: previous, current: current) == nil)
    }

    // disk-metrics — DM-4 "Re-seeded baseline recovers on the next tick"
    @Test func theReSeededBaselineRecoversOnTheNextTick() throws {
        let previous = DiskFixtures.counters(read: 2_000_000, written: 600_000, at: 0)
        let reset = DiskFixtures.counters(read: 1_000_000, written: 500_000, at: 1)

        #expect(DiskThroughputCalculator.rates(previous: previous, current: reset) == nil)

        let recovered = DiskFixtures.counters(read: 1_001_000, written: 501_000, at: 2)
        let rates = try #require(
            DiskThroughputCalculator.rates(previous: reset, current: recovered)
        )

        #expect(rates.readBytesPerSecond == 1_000)
        #expect(rates.writeBytesPerSecond == 1_000)
    }

    // An unchanged counter is a valid zero rate, not a missing one: it is what
    // an idle disk reports and it must still render as 0 B/s rather than "—".
    @Test func unchangedCountersYieldZeroRatesRatherThanNil() throws {
        let previous = DiskFixtures.counters(read: 1_000_000, written: 500_000, at: 0)
        let current = DiskFixtures.counters(read: 1_000_000, written: 500_000, at: 1)

        let rates = try #require(
            DiskThroughputCalculator.rates(previous: previous, current: current)
        )

        #expect(rates.readBytesPerSecond == 0)
        #expect(rates.writeBytesPerSecond == 0)
    }
}
