import Foundation

/// Formats memory byte counts the way Activity Monitor presents them.
///
/// `ByteCountFormatStyle(style: .memory)` is base-1024 with kB/MB/GB labels and
/// up to two fraction digits, so `8 GiB` reads as `"8 GB"` and a partially used
/// machine as `"5.52 GB"`. The locale is injected rather than read from the
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
}
