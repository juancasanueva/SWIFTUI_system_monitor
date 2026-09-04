import Foundation

/// Port that supplies raw CPU tick counters, one entry per logical core.
///
/// Implementations are driven from a background task, so they must be
/// `nonisolated` and `Sendable`. Reads may fail transiently; the sampler
/// treats a throw as a skipped window rather than a fatal condition.
nonisolated protocol CPUMetricsProvider: Sendable {
    func readTicks() throws -> CPUTickSample
}
