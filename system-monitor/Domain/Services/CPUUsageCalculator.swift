import Foundation

/// Pure conversion of two consecutive tick samples into a `CPUSnapshot`.
///
/// Usage is always a ratio over a window, so the calculator needs both a
/// previous and a current sample. Aggregates come from the deltas summed across
/// cores, which matches how the system reports overall load; the mean of the
/// per-core ratios would weigh an idle core the same as a saturated one.
nonisolated enum CPUUsageCalculator {

    /// Computes usage over the window between two samples.
    ///
    /// Returns `nil` when there is no previous sample or when the two samples
    /// describe a different number of cores. A topology whose size differs from
    /// the sample cannot be trusted and is treated as all-`.unknown`.
    static func snapshot(
        previous: CPUTickSample?,
        current: CPUTickSample,
        topology: CoreTopology
    ) -> CPUSnapshot? {
        guard let previous, previous.coreCount == current.coreCount else { return nil }

        let trustedTopology = topology.coreCount == current.coreCount
            ? topology
            : CoreTopology.unknown(coreCount: current.coreCount)

        let deltas = zip(current.cores, previous.cores).map { $0.delta(since: $1) }
        let cores = coreUsages(deltas: deltas, topology: trustedTopology)

        return CPUSnapshot(
            total: totalUsage(deltas: deltas),
            user: userShare(deltas: deltas),
            system: systemShare(deltas: deltas),
            performanceAverage: average(of: cores, at: .performance),
            efficiencyAverage: average(of: cores, at: .efficiency),
            cores: ordered(cores)
        )
    }

    // MARK: - Per core

    private static func coreUsages(deltas: [CPUTicks], topology: CoreTopology) -> [CoreUsage] {
        deltas.enumerated().map { index, delta in
            CoreUsage(
                index: index,
                usage: busyFraction(of: delta),
                level: topology.level(of: index)
            )
        }
    }

    /// Busy share of one core's window, `0` when the counters did not advance.
    private static func busyFraction(of delta: CPUTicks) -> Double {
        let total = delta.total
        guard total > 0 else { return 0 }
        return 1 - Double(delta.idle) / Double(total)
    }

    /// Performance cores first, then efficiency, then unknown; ascending Mach
    /// index inside each group.
    private static func ordered(_ cores: [CoreUsage]) -> [CoreUsage] {
        let groups: [PerformanceLevel] = [.performance, .efficiency, .unknown]
        return groups.flatMap { level in
            cores.filter { $0.level == level }
        }
    }

    // MARK: - Aggregates

    private static func totalUsage(deltas: [CPUTicks]) -> Double {
        let total = summedTotal(deltas)
        guard total > 0 else { return 0 }
        let idle = deltas.reduce(UInt64(0)) { $0 + UInt64($1.idle) }
        return 1 - Double(idle) / Double(total)
    }

    /// User share including nice ticks, which are user work at a lower priority.
    private static func userShare(deltas: [CPUTicks]) -> Double {
        let total = summedTotal(deltas)
        guard total > 0 else { return 0 }
        let user = deltas.reduce(UInt64(0)) { $0 + UInt64($1.user) + UInt64($1.nice) }
        return Double(user) / Double(total)
    }

    private static func systemShare(deltas: [CPUTicks]) -> Double {
        let total = summedTotal(deltas)
        guard total > 0 else { return 0 }
        let system = deltas.reduce(UInt64(0)) { $0 + UInt64($1.system) }
        return Double(system) / Double(total)
    }

    private static func summedTotal(_ deltas: [CPUTicks]) -> UInt64 {
        deltas.reduce(UInt64(0)) { $0 + $1.total }
    }

    /// Mean usage of the cores at one level, `nil` when the level has no cores.
    private static func average(of cores: [CoreUsage], at level: PerformanceLevel) -> Double? {
        let usages = cores.filter { $0.level == level }.map(\.usage)
        guard !usages.isEmpty else { return nil }
        return usages.reduce(0, +) / Double(usages.count)
    }
}
