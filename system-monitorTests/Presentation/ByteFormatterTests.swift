import Foundation
import Testing
@testable import system_monitor

// memory-card — "Locale-aware byte formatting"
@Suite("ByteFormatter")
struct ByteFormatterTests {

    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    /// ICU separates the number from its unit with a non-breaking space, which
    /// is locale-legal but invisible in a diff. Mapping both narrow and regular
    /// non-breaking spaces to a plain space keeps the expectations readable
    /// without weakening the comparison.
    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    // memory-card — "Two decimals under en_US"
    @Test(arguments: zip(
        [5_926_000_000, 5_926_092_800, 1_986_560_000, 1_954_283_520] as [UInt64],
        ["5.52 GB", "5.52 GB", "1.85 GB", "1.82 GB"]
    ))
    func gigabyteValuesKeepTwoFractionDigitsUnderEnglish(bytes: UInt64, expected: String) {
        let text = ByteFormatter.memory(bytes, locale: Self.english)

        #expect(Self.normalized(text) == expected)
    }

    // memory-card — "Decimal comma under de_DE"
    @Test func theDecimalSeparatorComesFromTheLocale() {
        let text = ByteFormatter.memory(5_926_092_800, locale: Self.german)

        #expect(Self.normalized(text) == "5,52 GB")
    }

    // memory-card — "Exact multiple has no trailing zeros"
    @Test(arguments: zip(
        [8_589_934_592, 1_073_741_824, 1_048_576] as [UInt64],
        ["8 GB", "1 GB", "1 MB"]
    ))
    func anExactMultipleDropsItsFractionDigits(bytes: UInt64, expected: String) {
        let text = ByteFormatter.memory(bytes, locale: Self.english)

        #expect(Self.normalized(text) == expected)
    }

    // memory-card — "Zero and clamping"
    @Test func zeroRendersWithDigitsRatherThanBeingSpelledOut() {
        let text = Self.normalized(ByteFormatter.memory(0, locale: Self.english))

        #expect(text.hasPrefix("0"))
        #expect(text == "0 bytes")
    }

    // memory-card — "Zero and clamping"
    //
    // `UInt64.max` cannot be represented as `Int64`, so the formatter clamps
    // instead of trapping: the largest input and `Int64.max` format alike.
    @Test func valuesAboveTheSignedRangeClampInsteadOfTrapping() {
        let clamped = ByteFormatter.memory(.max, locale: Self.english)
        let signedMaximum = ByteFormatter.memory(UInt64(Int64.max), locale: Self.english)

        #expect(clamped == signedMaximum)
        #expect(Self.normalized(clamped) == "8,192 PB")
    }

    // disk-card — "Two decimals under en_US"
    //
    // Capacity is base 1000, not the base-1024 memory style: a 494.35 GB volume
    // is what the vendor and Finder call it, so the same byte count would read
    // "460.4 GB" through `memory(_:)`.
    @Test(arguments: zip(
        [432_068_000_000, 62_286_000_000, 494_354_000_000] as [UInt64],
        ["432.07 GB", "62.29 GB", "494.35 GB"]
    ))
    func capacityValuesKeepTwoFractionDigitsUnderEnglish(bytes: UInt64, expected: String) {
        let text = ByteFormatter.capacity(bytes, locale: Self.english)

        #expect(Self.normalized(text) == expected)
    }

    // disk-card — "Decimal comma under de_DE"
    @Test(arguments: zip(
        [432_068_000_000, 62_286_000_000, 494_354_000_000] as [UInt64],
        ["432,07 GB", "62,29 GB", "494,35 GB"]
    ))
    func theCapacityDecimalSeparatorComesFromTheLocale(bytes: UInt64, expected: String) {
        let text = ByteFormatter.capacity(bytes, locale: Self.german)

        #expect(Self.normalized(text) == expected)
    }

    // disk-card — "Exact multiple and clamping"
    @Test func anExactDecimalMultipleDropsItsFractionDigits() {
        let text = ByteFormatter.capacity(512_000_000_000, locale: Self.english)

        #expect(Self.normalized(text) == "512 GB")
    }

    // disk-card — "Exact multiple and clamping"
    //
    // The exact strings are the ones ICU emits for this style; they are pinned
    // rather than assumed, and they differ between the two locales.
    @Test func capacityZeroRendersWithDigitsRatherThanBeingSpelledOut() {
        let english = Self.normalized(ByteFormatter.capacity(0, locale: Self.english))
        let german = Self.normalized(ByteFormatter.capacity(0, locale: Self.german))

        #expect(english.hasPrefix("0"))
        #expect(german.hasPrefix("0"))
        #expect(english == "0 bytes")
        #expect(german == "0 Byte")
    }

    // disk-card — "Exact multiple and clamping"
    //
    // A corrupt volume read must not trap the panel: `UInt64.max` has no `Int64`
    // representation, so it clamps and formats like `Int64.max`.
    @Test func capacitiesAboveTheSignedRangeClampInsteadOfTrapping() {
        let clamped = ByteFormatter.capacity(.max, locale: Self.english)
        let signedMaximum = ByteFormatter.capacity(UInt64(Int64.max), locale: Self.english)

        #expect(clamped == signedMaximum)
        #expect(Self.normalized(clamped) == "9,223.37 PB")
    }
}
