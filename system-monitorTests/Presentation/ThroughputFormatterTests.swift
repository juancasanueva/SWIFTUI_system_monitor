import Foundation
import Testing
@testable import system_monitor

// disk-card — "Megabytes per second", "Decimal comma",
// "Whole values keep one fraction digit"
@Suite("Throughput formatting")
struct ThroughputFormatterTests {

    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    /// The same normaliser `ByteFormatterTests` uses: ICU may separate a number
    /// from its unit with a narrow or regular non-breaking space, which is
    /// locale-legal but invisible in a diff.
    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    // disk-card — "Megabytes per second"
    @Test(arguments: zip(
        [27_100_000, 2_200_000] as [Double],
        ["27.1 MB/s", "2.2 MB/s"]
    ))
    func megabyteRatesCarryOneFractionDigit(rate: Double, expected: String) {
        let text = ByteFormatter.throughput(rate, locale: Self.english)

        #expect(Self.normalized(text) == expected)
    }

    // disk-card — "Decimal comma"
    @Test(arguments: zip(
        [27_100_000, 1_000_000_000] as [Double],
        ["27,1 MB/s", "1,0 GB/s"]
    ))
    func theThroughputDecimalSeparatorComesFromTheLocale(rate: Double, expected: String) {
        let text = ByteFormatter.throughput(rate, locale: Self.german)

        #expect(Self.normalized(text) == expected)
    }

    // disk-card — "Whole values keep one fraction digit"
    @Test(arguments: zip(
        [1_000_000_000, 1_000_000_000_000, 1_000] as [Double],
        ["1.0 GB/s", "1.0 TB/s", "1.0 kB/s"]
    ))
    func aWholeValueStillShowsItsFractionDigit(rate: Double, expected: String) {
        let text = ByteFormatter.throughput(rate, locale: Self.english)

        #expect(Self.normalized(text) == expected)
    }

    // disk-card — design decision 3: below 1 kB the integer byte count, with no
    // fraction digit, because a fractional byte is meaningless.
    @Test(arguments: zip(
        [512, 999] as [Double],
        ["512 B/s", "999 B/s"]
    ))
    func ratesBelowOneKilobyteRenderAsWholeBytes(rate: Double, expected: String) {
        let text = ByteFormatter.throughput(rate, locale: Self.english)

        #expect(Self.normalized(text) == expected)
    }

    // disk-card — design decision 3: the unit is the smallest one whose value,
    // rounded to one fraction digit, still stays below 1000. The two rates
    // below straddle that boundary by a single byte per second.
    @Test func theUnitStepsUpBeforeTheValueWouldReachFourDigits() {
        let below = ByteFormatter.throughput(999_949, locale: Self.english)
        let above = ByteFormatter.throughput(999_950, locale: Self.english)

        #expect(Self.normalized(below) == "999.9 kB/s")
        #expect(Self.normalized(above) == "1.0 MB/s")
    }

    // disk-card — design decision 3: zero reads as idle, which is what the
    // value means, and it is the same string in both locales.
    @Test func anIdleDiskReadsAsZeroBytesPerSecond() {
        #expect(Self.normalized(ByteFormatter.throughput(0, locale: Self.english)) == "0 B/s")
        #expect(Self.normalized(ByteFormatter.throughput(0, locale: Self.german)) == "0 B/s")
    }

    // disk-card — design decision 3: a rate can only be produced by the Domain
    // calculator, which never emits a negative one, so a negative or non-finite
    // input is a corrupt reading and renders idle rather than nonsense.
    @Test(arguments: [-1, -27_100_000, Double.nan, .infinity, -.infinity] as [Double])
    func aCorruptRateRendersAsZeroRatherThanNonsense(rate: Double) {
        let text = ByteFormatter.throughput(rate, locale: Self.english)

        #expect(Self.normalized(text) == "0 B/s")
    }
}
