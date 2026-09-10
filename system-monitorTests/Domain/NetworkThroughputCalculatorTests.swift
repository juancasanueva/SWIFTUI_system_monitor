import Foundation
import Testing
@testable import system_monitor

// network-metrics — NM-4 "Reference rate", "Elapsed time scales the rate",
// "No baseline", "No interfaces", "Non-positive elapsed time", "Negative
// inbound delta nils both rates", "Negative outbound delta nils both rates",
// "Re-seeded baseline recovers on the next tick".
//
// Every stamp comes from `NetworkFixtures.base`, so the assertions only ever
// depend on the difference between two instants.
@Suite("NetworkThroughputCalculator")
struct NetworkThroughputCalculatorTests {

    // network-metrics — NM-4 "Reference rate"
    @Test func theReferenceWindowYieldsTheReferenceRates() throws {
        let rates = try #require(
            NetworkThroughputCalculator.rates(
                previous: NetworkFixtures.referencePrevious,
                current: NetworkFixtures.referenceCurrent
            )
        )

        #expect(rates == NetworkThroughputCalculator.Rates(
            downloadBytesPerSecond: 5_000,
            uploadBytesPerSecond: 78_000
        ))
    }

    // network-metrics — NM-4 "Elapsed time scales the rate"
    @Test func halvingTheWindowDoublesBothRates() throws {
        let current = NetworkFixtures.counters(
            in: 3_850_000_000,
            out: 2_760_000_000,
            interfaceCount: 2,
            at: 0.5
        )

        let rates = try #require(
            NetworkThroughputCalculator.rates(
                previous: NetworkFixtures.referencePrevious,
                current: current
            )
        )

        #expect(rates.downloadBytesPerSecond == 10_000)
        #expect(rates.uploadBytesPerSecond == 156_000)
    }

    // network-metrics — NM-4 "No baseline"
    @Test func noBaselineYieldsNoRates() {
        #expect(
            NetworkThroughputCalculator.rates(
                previous: nil,
                current: NetworkFixtures.referenceCurrent
            ) == nil
        )
    }

    // network-metrics — NM-4 "No interfaces"
    @Test func aReadingWithoutInterfacesYieldsNoRates() {
        let current = NetworkFixtures.counters(
            in: 3_850_000_000,
            out: 2_760_000_000,
            interfaceCount: 0,
            at: 1
        )

        #expect(
            NetworkThroughputCalculator.rates(
                previous: NetworkFixtures.referencePrevious,
                current: current
            ) == nil
        )
    }

    // network-metrics — NM-4 "Zero-interface baseline yields nil"
    //
    // The other half of interface churn. `SysctlNetworkProvider` returns a valid
    // reading with `interfaceCount 0` and zero totals when nothing passes the
    // filter, and the sampler re-seeds its baseline with it. If only the current
    // reading were checked, the next populated tick would subtract from zero and
    // publish the machine's entire since-boot totals as one second of traffic —
    // a gigabytes-per-second pair that would then become the shared graph
    // divisor and flatten the next 120 real samples.
    @Test func aZeroInterfaceBaselineYieldsNoRates() {
        let current = NetworkFixtures.counters(
            in: 3_850_000_000,
            out: 2_760_000_000,
            interfaceCount: 2,
            at: 1
        )

        #expect(
            NetworkThroughputCalculator.rates(
                previous: NetworkFixtures.idle,
                current: current
            ) == nil
        )
    }

    // network-metrics — NM-4 "Non-positive elapsed time", the zero half.
    @Test func aZeroWindowYieldsNoRates() {
        let current = NetworkFixtures.counters(
            in: 3_850_000_000,
            out: 2_760_000_000,
            interfaceCount: 2,
            at: 0
        )

        #expect(
            NetworkThroughputCalculator.rates(
                previous: NetworkFixtures.referencePrevious,
                current: current
            ) == nil
        )
    }

    // network-metrics — NM-4 "Non-positive elapsed time", the backwards half.
    @Test func aBackwardsWindowYieldsNoRates() {
        let current = NetworkFixtures.counters(
            in: 3_850_000_000,
            out: 2_760_000_000,
            interfaceCount: 2,
            at: -0.001
        )

        #expect(
            NetworkThroughputCalculator.rates(
                previous: NetworkFixtures.referencePrevious,
                current: current
            ) == nil
        )
    }

    // network-metrics — NM-4 "Negative inbound delta nils both rates"
    @Test func aFallingInboundCounterNilsBothRates() {
        let previous = NetworkFixtures.counters(in: 2_000_000, out: 500_000, at: 0)
        let current = NetworkFixtures.counters(in: 1_000_000, out: 600_000, at: 1)

        #expect(NetworkThroughputCalculator.rates(previous: previous, current: current) == nil)
    }

    // network-metrics — NM-4 "Negative outbound delta nils both rates"
    @Test func aFallingOutboundCounterNilsBothRates() {
        let previous = NetworkFixtures.counters(in: 1_000_000, out: 600_000, at: 0)
        let current = NetworkFixtures.counters(in: 1_100_000, out: 500_000, at: 1)

        #expect(NetworkThroughputCalculator.rates(previous: previous, current: current) == nil)
    }

    // network-metrics — NM-4 "Re-seeded baseline recovers on the next tick":
    // an interface disappearing makes the summed counters fall, and the caller
    // always re-seeds with `current`, so the gap costs exactly one tick.
    @Test func theReSeededBaselineRecoversOnTheNextTick() throws {
        let previous = NetworkFixtures.counters(in: 2_000_000, out: 600_000, at: 0)
        let reset = NetworkFixtures.counters(in: 1_000_000, out: 500_000, at: 1)

        #expect(NetworkThroughputCalculator.rates(previous: previous, current: reset) == nil)

        let recovered = NetworkFixtures.counters(in: 1_001_000, out: 501_000, at: 2)
        let rates = try #require(
            NetworkThroughputCalculator.rates(previous: reset, current: recovered)
        )

        #expect(rates.downloadBytesPerSecond == 1_000)
        #expect(rates.uploadBytesPerSecond == 1_000)
    }

    // An unchanged counter is a valid zero rate, not a missing one: it is what
    // an idle link reports and it must still render as 0 B/s rather than "—".
    @Test func unchangedCountersYieldZeroRatesRatherThanNil() throws {
        let previous = NetworkFixtures.counters(in: 1_000_000, out: 500_000, at: 0)
        let current = NetworkFixtures.counters(in: 1_000_000, out: 500_000, at: 1)

        let rates = try #require(
            NetworkThroughputCalculator.rates(previous: previous, current: current)
        )

        #expect(rates.downloadBytesPerSecond == 0)
        #expect(rates.uploadBytesPerSecond == 0)
    }
}
