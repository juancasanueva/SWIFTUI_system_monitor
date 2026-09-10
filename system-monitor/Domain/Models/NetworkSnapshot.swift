import Foundation

/// One network reading: the since-boot byte totals plus the throughput rates
/// measured over the window that ended with it.
///
/// Both rates are optional together: the calculator either produces the pair or
/// nothing, so "a download rate without an upload rate" is unrepresentable.
/// Totals are absolute rather than derived, so the first tick after a start
/// already publishes them while the rates are still unavailable.
///
/// Only the memberwise initialiser exists, exactly like `DiskSnapshot`, so the
/// tests can hand-build the edge cases the sampler would never produce.
nonisolated struct NetworkSnapshot: Sendable, Equatable {

    /// Bytes received since boot, summed over every included interface.
    let totalIn: UInt64

    /// Bytes sent since boot, summed over the same interfaces.
    let totalOut: UInt64

    /// Bytes received per second over the last window, `nil` when unavailable.
    let downloadBytesPerSecond: Double?

    /// Bytes sent per second over the last window, `nil` when unavailable.
    let uploadBytesPerSecond: Double?
}
