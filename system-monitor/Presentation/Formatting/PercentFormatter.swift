import Foundation

/// Formats usage fractions (`0...1`) as percentage strings.
///
/// The menu bar uses whole percentages so its fixed-width value frame never
/// jitters; the panel uses one decimal. Both clamp their input, so a reading
/// that drifts slightly outside the unit range never renders as `-0%` or `101%`.
nonisolated enum PercentFormatter {

    private static let percentSign = "%"

    /// Whole-percent text such as `"26%"`, independent of the current locale.
    ///
    /// The menu bar value is measured once against `"100%"`, so it must not
    /// pick up locale digits, grouping separators, or a spaced percent sign.
    static func integer(_ fraction: Double) -> String {
        let percent = Int(scaled(fraction).rounded())
        return "\(percent)\(percentSign)"
    }

    /// One-decimal text such as `"40.2%"`, using the locale decimal separator.
    static func oneDecimal(_ fraction: Double, locale: Locale = .current) -> String {
        let percent = scaled(fraction).formatted(
            .number
                .precision(.fractionLength(1))
                .grouping(.never)
                .locale(locale)
        )
        return "\(percent)\(percentSign)"
    }

    /// Clamps to `0...1` and scales to a percentage, mapping NaN to zero.
    private static func scaled(_ fraction: Double) -> Double {
        guard !fraction.isNaN else { return 0 }
        return min(max(fraction, 0), 1) * 100
    }
}
