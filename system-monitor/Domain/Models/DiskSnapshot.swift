import Foundation

/// One disk reading: boot-volume capacity plus the throughput rates measured
/// over the window that ended with it.
///
/// `used` is stored rather than derived, exactly like `MemorySnapshot`, so the
/// saturating subtraction lives in one initialiser instead of every read. Both
/// rates are optional together: the calculator either produces the pair or
/// nothing, so "a read rate without a write rate" is unrepresentable.
nonisolated struct DiskSnapshot: Sendable, Equatable {

    /// Total capacity in bytes.
    let total: UInt64

    /// Available capacity in bytes.
    let free: UInt64

    /// Total − Free, saturating at 0.
    let used: UInt64

    /// Bytes read per second over the last window, `nil` when unavailable.
    let readBytesPerSecond: Double?

    /// Bytes written per second over the last window, `nil` when unavailable.
    let writeBytesPerSecond: Double?

    /// Used share of total, `0` when `total` is `0` and never above `1`.
    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(Double(used) / Double(total), 1)
    }
}

extension DiskSnapshot {

    /// Builds a snapshot from a capacity reading, computing `used` once.
    ///
    /// Declared in an extension so the memberwise initialiser survives: the
    /// tests need to hand-build an inconsistent `used` that this initialiser
    /// can never produce, in order to pin the `fraction` clamp. The extension
    /// does not inherit the type's isolation, so `nonisolated` is spelled out
    /// here as well (convention 1): the sampling step builds snapshots on a
    /// utility task.
    nonisolated init(
        total: UInt64,
        free: UInt64,
        readBytesPerSecond: Double?,
        writeBytesPerSecond: Double?
    ) {
        self.init(
            total: total,
            free: free,
            used: total - min(total, free),
            readBytesPerSecond: readBytesPerSecond,
            writeBytesPerSecond: writeBytesPerSecond
        )
    }
}
