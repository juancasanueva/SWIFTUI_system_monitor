import Foundation

/// One reading of the cumulative block-storage byte counters.
///
/// The values are lifetime totals summed over every readable storage driver,
/// so a rate only exists between two readings. The adapter stamps `timestamp`
/// at read time: the Domain never reads a clock, which keeps the rate rule
/// pure and the sampler's scenarios deterministic.
nonisolated struct DiskThroughputCounters: Sendable, Equatable {

    /// Cumulative bytes read, summed over every driver in `driverCount`.
    let bytesRead: UInt64

    /// Cumulative bytes written, summed over the same drivers.
    let bytesWritten: UInt64

    /// Number of drivers whose statistics were actually read. `0` means the
    /// reading is valid but carries no data, so no rate can be derived from it.
    let driverCount: Int

    /// Instant the adapter stamped when it finished summing the counters.
    let timestamp: ContinuousClock.Instant
}
