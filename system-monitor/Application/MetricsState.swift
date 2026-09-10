import Foundation
import Observation

/// Observable snapshot of the metrics the UI renders.
///
/// The state lives on the main actor: the sampling loop runs elsewhere and hops
/// here with plain `CPUSnapshot`, `MemorySnapshot`, `DiskSnapshot` and
/// `NetworkSnapshot` values, so views never observe a partially updated
/// reading.
///
/// Each metric owns an independent set of properties. `@Observable` tracks
/// access per property, and the `apply` overloads never touch each other's
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

    /// Most recent disk reading, `nil` until the first capacity read lands.
    ///
    /// There is deliberately no `MetricHistory` beside it (R10.8): the disk
    /// card renders a gauge and two instantaneous rates, and no view plots a
    /// disk series, so a history would only be memory nobody reads.
    private(set) var disk: DiskSnapshot?

    /// Most recent network reading, `nil` until the first counter read lands.
    private(set) var network: NetworkSnapshot?

    /// Recent download rates in raw bytes per second, oldest first.
    ///
    /// Raw rather than normalised: the card decides the shared scale both
    /// series are drawn against, and the state holds no unit and no colour.
    private(set) var networkDownloadHistory: MetricHistory

    /// Recent upload rates in raw bytes per second, over the same window.
    private(set) var networkUploadHistory: MetricHistory

    init(historyCapacity: Int = 120) {
        self.cpuHistory = MetricHistory(capacity: historyCapacity)
        self.memoryHistory = MetricHistory(capacity: historyCapacity)
        self.networkDownloadHistory = MetricHistory(capacity: historyCapacity)
        self.networkUploadHistory = MetricHistory(capacity: historyCapacity)
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

    /// Publishes a disk reading, replacing the previous one.
    ///
    /// It stores and nothing else: unlike CPU and memory, disk keeps no
    /// history (R10.8), so there is no series to append to here.
    func apply(disk snapshot: DiskSnapshot) {
        disk = snapshot
    }

    /// Publishes a network reading and records both rates in one call.
    ///
    /// The two histories are appended together, or not at all: the card draws
    /// them as two series over one x axis (R5.2), so a tick that could only
    /// contribute one of them would silently shift the other series against
    /// time. A snapshot without rates still publishes its totals, which is what
    /// keeps the card populated through a re-seed tick.
    func apply(network snapshot: NetworkSnapshot) {
        network = snapshot

        guard
            let download = snapshot.downloadBytesPerSecond,
            let upload = snapshot.uploadBytesPerSecond
        else { return }

        networkDownloadHistory.append(download)
        networkUploadHistory.append(upload)
    }
}
