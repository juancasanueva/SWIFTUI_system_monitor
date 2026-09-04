import Foundation
import Observation

/// Observable snapshot of the metrics the UI renders.
///
/// The state lives on the main actor: the sampling loop runs elsewhere and hops
/// here with a plain `CPUSnapshot` value, so views never observe a partially
/// updated reading.
@MainActor
@Observable
final class MetricsState {

    /// Most recent CPU reading, `nil` until the second sample completes.
    private(set) var cpu: CPUSnapshot?

    /// Recent CPU totals, oldest first, bounded by the configured capacity.
    private(set) var cpuHistory: MetricHistory

    init(historyCapacity: Int = 120) {
        self.cpuHistory = MetricHistory(capacity: historyCapacity)
    }

    /// Publishes a CPU reading and records its total in the history.
    func apply(cpu snapshot: CPUSnapshot) {
        cpu = snapshot
        cpuHistory.append(snapshot.total)
    }
}
