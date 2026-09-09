import Foundation

/// Formats byte counts the way the system presents each kind of storage.
///
/// Memory uses `ByteCountFormatStyle(style: .memory)`, base-1024 with kB/MB/GB
/// labels and up to two fraction digits, so `8 GiB` reads as `"8 GB"` and a
/// partially used machine as `"5.52 GB"`. Volume capacity uses `style: .decimal`
/// instead, base-1000, because that is the size a disk is sold and reported
/// with: the same byte count reads `"494.35 GB"` there and `"460.4 GB"` through
/// the memory style. The locale is injected rather than read from the
/// environment so the panel and its tests format the same string.
nonisolated enum ByteFormatter {

    /// Locale-aware memory string, for example `"5.52 GB"` under `en_US` and
    /// `"5,52 GB"` under `de_DE`.
    ///
    /// Zero renders with digits rather than being spelled out. Counters arrive
    /// as `UInt64`, so the value is clamped into `Int64` instead of trapping on
    /// a corrupt read.
    static func memory(_ bytes: UInt64, locale: Locale = .current) -> String {
        Int64(clamping: bytes).formatted(
            .byteCount(
                style: .memory,
                allowedUnits: .all,
                spellsOutZero: false,
                includesActualByteCount: false
            )
            .locale(locale)
        )
    }

    /// Locale-aware volume capacity string, for example `"432.07 GB"` under
    /// `en_US` and `"432,07 GB"` under `de_DE`.
    ///
    /// Base-1000 so Used, Free and Total match the figures Finder and the disk
    /// vendor report. Zero renders with digits rather than being spelled out,
    /// and a capacity above the signed range clamps into `Int64` instead of
    /// trapping on a corrupt read.
    static func capacity(_ bytes: UInt64, locale: Locale = .current) -> String {
        Int64(clamping: bytes).formatted(
            .byteCount(
                style: .decimal,
                allowedUnits: .all,
                spellsOutZero: false,
                includesActualByteCount: false
            )
            .locale(locale)
        )
    }

    /// Locale-aware transfer rate string, for example `"27.1 MB/s"` under
    /// `en_US` and `"27,1 MB/s"` under `de_DE`.
    ///
    /// `ByteCountFormatStyle` is not used here: it picks its own fraction
    /// digits and has no per-second suffix. The vocabulary is decimal like the
    /// capacity strings it sits next to — `B`, `kB`, `MB`, `GB`, `TB` in
    /// 1000-steps — and the unit chosen is the smallest one whose value, once
    /// rounded for display, still stays below 1000, so the label never widens
    /// to four digits: 999 949 B/s reads `"999.9 kB/s"` and one byte more
    /// reads `"1.0 MB/s"`.
    ///
    /// A kilobyte and above carries exactly one fraction digit, so a whole
    /// value still reads `"1.0 GB/s"` and the label does not jitter between
    /// widths. Below a kilobyte the whole byte count is used instead, because a
    /// fractional byte is meaningless. Zero, a negative rate and a non-finite
    /// one all render `"0 B/s"`: the Domain calculator only ever produces a
    /// non-negative rate, so anything else is a corrupt reading, and an idle
    /// disk is exactly what zero means.
    static func throughput(_ bytesPerSecond: Double, locale: Locale = .current) -> String {
        var value = bytesPerSecond.isFinite && bytesPerSecond > 0 ? bytesPerSecond : 0
        var unit = 0

        while unit < throughputUnits.count - 1,
              rounded(value, fractionDigits: throughputFractionDigits(for: unit)) >= throughputStep {
            value /= throughputStep
            unit += 1
        }

        let number = value.formatted(
            .number
                .precision(.fractionLength(throughputFractionDigits(for: unit)))
                .grouping(.never)
                .locale(locale)
        )
        return "\(number) \(throughputUnits[unit])/s"
    }

    /// Throughput units, smallest first. Each step is `throughputStep` bytes.
    private static let throughputUnits = ["B", "kB", "MB", "GB", "TB"]

    /// Decimal step between two adjacent throughput units.
    private static let throughputStep = 1000.0

    /// Fraction digits the throughput string shows at `unit`.
    private static func throughputFractionDigits(for unit: Int) -> Int {
        unit == 0 ? 0 : 1
    }

    /// The value as it will be displayed, so the unit is chosen from the
    /// rounded number rather than from the raw one.
    private static func rounded(_ value: Double, fractionDigits: Int) -> Double {
        let scale = pow(10, Double(fractionDigits))
        return (value * scale).rounded() / scale
    }
}
