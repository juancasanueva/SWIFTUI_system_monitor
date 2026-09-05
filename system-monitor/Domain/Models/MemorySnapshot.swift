import Foundation

/// One memory reading in bytes, as Activity Monitor presents it.
///
/// `used` is stored rather than derived: with the confirmed formula it is
/// Total − Free − Cached, a first-class observation that is not the sum of
/// `app`, `wired` and `compressed`. Keeping it stored leaves the saturating
/// formula in exactly one place (`MemoryUsageCalculator`) and lets tests build
/// snapshots that exercise the guards below.
nonisolated struct MemorySnapshot: Sendable, Equatable {

    /// Physical memory in bytes.
    let total: UInt64

    /// Anonymous pages excluding the purgeable ones.
    let app: UInt64

    /// Wired bytes.
    let wired: UInt64

    /// Bytes held by the compressor.
    let compressed: UInt64

    /// File-backed plus purgeable bytes, reclaimable under pressure.
    let cached: UInt64

    /// Free bytes excluding the speculative read-ahead pages.
    let free: UInt64

    /// Total − Free − Cached (saturating), set by `MemoryUsageCalculator`.
    let used: UInt64

    /// Used share of total, `0` when `total` is `0` and never above `1`.
    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(Double(used) / Double(total), 1)
    }

    /// Part of `used` that the labelled components do not account for.
    ///
    /// Activity Monitor's Used carries kernel allocations beyond App, Wired and
    /// Compressed; the stacked bar renders this remainder as its own segment so
    /// every labelled segment stays proportional to the value it names.
    var unattributedUsed: UInt64 {
        let (appAndWired, appOverflow) = app.addingReportingOverflow(wired)
        guard !appOverflow else { return 0 }

        let (attributed, overflow) = appAndWired.addingReportingOverflow(compressed)
        guard !overflow else { return 0 }

        return used - min(used, attributed)
    }
}
