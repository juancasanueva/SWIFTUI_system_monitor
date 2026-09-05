import Foundation

/// Port that supplies the raw kernel page counters behind a memory reading.
///
/// Implementations are driven from a background task, so they must be
/// `nonisolated` and `Sendable`. A read may fail transiently; the sampler
/// treats a throw as a skipped iteration rather than a fatal condition.
nonisolated protocol MemoryMetricsProvider: Sendable {
    func readCounts() throws -> MemoryPageCounts
}
