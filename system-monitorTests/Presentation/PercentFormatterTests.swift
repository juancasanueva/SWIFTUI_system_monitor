import Foundation
import Testing
@testable import system_monitor

// menu-bar-widget — "Integer percentage value"; cpu-card — "Header and gauge"
@Suite("PercentFormatter")
struct PercentFormatterTests {

    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    // menu-bar-widget — "Integer formatting"
    @Test(arguments: zip(
        [0.264, 0.266, 0.0, 1.0],
        ["26%", "27%", "0%", "100%"]
    ))
    func integerRoundsToTheNearestWholePercent(fraction: Double, expected: String) {
        #expect(PercentFormatter.integer(fraction) == expected)
    }

    @Test func integerRoundsHalvesAwayFromZero() {
        #expect(PercentFormatter.integer(0.265) == "27%")
        #expect(PercentFormatter.integer(0.255) == "26%")
    }

    @Test(arguments: zip(
        [-0.5, -0.0001, 1.5, 42.0],
        ["0%", "0%", "100%", "100%"]
    ))
    func integerClampsOutsideTheUnitRange(fraction: Double, expected: String) {
        #expect(PercentFormatter.integer(fraction) == expected)
    }

    @Test func anUndefinedFractionRendersAsZero() {
        #expect(PercentFormatter.integer(.nan) == "0%")
        #expect(PercentFormatter.oneDecimal(.nan, locale: Self.english) == "0.0%")
    }

    @Test func integerUsesAsciiDigitsRegardlessOfTheCurrentLocale() {
        let text = PercentFormatter.integer(0.5)
        let isPlainAscii = text.allSatisfy(\.isASCII)

        #expect(text == "50%")
        #expect(isPlainAscii)
    }

    // cpu-card — "One-decimal formatting"
    @Test(arguments: zip(
        [0.402, 0.4, 1.0, 0.0],
        ["40.2%", "40.0%", "100.0%", "0.0%"]
    ))
    func oneDecimalUsesASingleFractionDigitUnderEnglish(fraction: Double, expected: String) {
        #expect(PercentFormatter.oneDecimal(fraction, locale: Self.english) == expected)
    }

    // cpu-card — "Locale decimal separator"
    @Test func oneDecimalUsesTheLocaleDecimalSeparator() {
        #expect(PercentFormatter.oneDecimal(0.402, locale: Self.german) == "40,2%")
        #expect(PercentFormatter.oneDecimal(1.0, locale: Self.german) == "100,0%")
    }

    @Test(arguments: zip(
        [-0.5, 1.5],
        ["0.0%", "100.0%"]
    ))
    func oneDecimalClampsOutsideTheUnitRange(fraction: Double, expected: String) {
        #expect(PercentFormatter.oneDecimal(fraction, locale: Self.english) == expected)
    }

    @Test func oneDecimalRoundsToTheNearestTenthOfAPercent() {
        #expect(PercentFormatter.oneDecimal(0.30649, locale: Self.english) == "30.6%")
        #expect(PercentFormatter.oneDecimal(0.09649, locale: Self.english) == "9.6%")
        #expect(PercentFormatter.oneDecimal(0.09849, locale: Self.english) == "9.8%")
    }
}
