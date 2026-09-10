import Foundation

/// Port that supplies the cumulative network byte counters.
///
/// One read is enough: unlike the disk port, network has no second facility to
/// query, so the whole reading is a single summed pair with its stamp. The port
/// exposes no rate, no formatted string and no colour — the rate is a Domain
/// rule and the presentation is the card's business.
///
/// Implementations are driven from a background task, so they must be
/// `nonisolated` and `Sendable`.
nonisolated protocol NetworkMetricsProvider: Sendable {

    /// Cumulative byte counters summed over every interface that passed the
    /// adapter's filter, stamped by the implementation at read time.
    func readCounters() throws -> NetworkThroughputCounters
}
