import Foundation
import Observation

/// Observable snapshot of the metrics the UI renders.
///
/// The state lives on the main actor: the sampling loop runs elsewhere and hops
/// here with plain `CPUSnapshot` and `MemorySnapshot` values, so views never
/// observe a partially updated reading.
///
/// Each metric owns an independent pair of properties. `@Observable` tracks
/// access per property, and the two `apply` overloads never touch each other's
/// state, so a failing provider only stalls its own metric.
@MainActor
@Observable
final class MetricsState {

    /// Most recent CPU reading, `nil` until the second sample completes.
    private(set) var cpu: CPUSnapshot?

    /// Recent CPU totals, oldest first, bounded by the configured capacity.
    private(set) var cpuHistory: MetricHistory

    /// Most recent memory reading, `nil` until the first sample lands.
    private(set) var memory: MemorySnapshot?

    /// Recent memory fractions, oldest first, bounded by the same capacity.
    private(set) var memoryHistory: MetricHistory

    init(historyCapacity: Int = 120) {
        self.cpuHistory = MetricHistory(capacity: historyCapacity)
        self.memoryHistory = MetricHistory(capacity: historyCapacity)
    }

    /// Publishes a CPU reading and records its total in the history.
    func apply(cpu snapshot: CPUSnapshot) {
        cpu = snapshot
        cpuHistory.append(snapshot.total)
    }

    /// Publishes a memory reading and records its used fraction in the history.
    ///
    /// Memory is an absolute reading, so the very first sample is already a
    /// real value and nothing here depends on a previous one.
    func apply(memory snapshot: MemorySnapshot) {
        memory = snapshot
        memoryHistory.append(snapshot.fraction)
    }
}
