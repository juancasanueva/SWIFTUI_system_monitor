import Foundation

/// Usage of a single logical core over one sampling window.
nonisolated struct CoreUsage: Sendable, Equatable, Identifiable {

    /// Mach processor index, preserved even after the cores are reordered.
    let index: Int

    /// Busy fraction of the window, `0...1`.
    let usage: Double

    let level: PerformanceLevel

    var id: Int { index }
}

/// CPU usage computed from the delta between two consecutive tick samples.
///
/// Every fraction is in `0...1`. `cores` lists performance cores first, then
/// efficiency cores, then unknown ones, each group in ascending Mach index.
nonisolated struct CPUSnapshot: Sendable, Equatable {
    let total: Double
    let user: Double
    let system: Double

    /// Mean usage of the performance cores, `nil` when there are none.
    let performanceAverage: Double?

    /// Mean usage of the efficiency cores, `nil` when there are none.
    let efficiencyAverage: Double?

    let cores: [CoreUsage]

    /// `true` when the machine exposes a trusted performance/efficiency split.
    var hasPerformanceLevels: Bool {
        performanceAverage != nil || efficiencyAverage != nil
    }
}
