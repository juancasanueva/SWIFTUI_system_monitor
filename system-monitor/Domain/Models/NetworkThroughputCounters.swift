import Foundation

/// One reading of the cumulative network byte counters.
///
/// The values are lifetime totals summed over every interface that passed the
/// adapter's filter, so a rate only exists between two readings. The adapter
/// stamps `timestamp` at read time: the Domain never reads a clock, which keeps
/// the rate rule pure and the sampler's scenarios deterministic.
nonisolated struct NetworkThroughputCounters: Sendable, Equatable {

    /// Cumulative bytes received, summed over every interface in
    /// `interfaceCount`.
    let bytesIn: UInt64

    /// Cumulative bytes sent, summed over the same interfaces.
    let bytesOut: UInt64

    /// Number of interfaces that passed the filter. `0` means the reading is
    /// valid but carries no data, so no rate can be derived from it.
    let interfaceCount: Int

    /// Instant the adapter stamped when it finished summing the counters.
    let timestamp: ContinuousClock.Instant
}
