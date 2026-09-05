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
}
