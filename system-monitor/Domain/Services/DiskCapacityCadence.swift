import Foundation

/// Decides when the boot-volume capacity is worth reading again.
///
/// Capacity moves slowly and the available-for-important-usage query is the
/// expensive half of a disk reading, so it runs on its own cadence instead of
/// every sampling tick. The rule is pure over two instants: the caller owns
/// the clock and the cached state, which keeps the sampler's scenarios
/// deterministic.
nonisolated enum DiskCapacityCadence {

    /// Shortest gap between two capacity reads.
    static let minimumInterval: Duration = .seconds(10)

    /// `true` when capacity was never read, or when at least `minimum` has
    /// elapsed since the last successful read.
    ///
    /// A `now` that precedes `lastReadAt` yields a negative elapsed duration
    /// and therefore `false`, so a clock that moved backwards cannot force an
    /// extra read.
    static func shouldRefresh(
        lastReadAt: ContinuousClock.Instant?,
        now: ContinuousClock.Instant,
        minimum: Duration = minimumInterval
    ) -> Bool {
        guard let lastReadAt else { return true }
        return lastReadAt.duration(to: now) >= minimum
    }
}
