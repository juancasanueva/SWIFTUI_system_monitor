import Foundation

/// Port that supplies the two independent halves of a disk reading.
///
/// Throughput and capacity come from different system facilities and are read
/// on different cadences, so they are separate calls: either may throw without
/// affecting the other, and the sampler treats a throw as a degraded tick
/// rather than a fatal condition.
///
/// Implementations are driven from a background task, so they must be
/// `nonisolated` and `Sendable`.
nonisolated protocol DiskMetricsProvider: Sendable {

    /// Cumulative byte counters summed over every readable storage driver,
    /// stamped by the implementation at read time.
    func readThroughput() throws -> DiskThroughputCounters

    /// Capacity of the boot volume.
    func readCapacity() throws -> VolumeCapacity
}
