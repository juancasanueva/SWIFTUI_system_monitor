import Foundation
@testable import system_monitor

/// Reusable tick samples and topologies for the Domain and Application suites.
nonisolated enum TickFixtures {

    /// A sample whose cores all carry the same counters.
    static func sample(
        coreCount: Int,
        user: UInt32,
        system: UInt32,
        idle: UInt32,
        nice: UInt32
    ) -> CPUTickSample {
        CPUTickSample(
            cores: Array(
                repeating: CPUTicks(user: user, system: system, idle: idle, nice: nice),
                count: coreCount
            )
        )
    }

    /// A sample built from explicit per-core counters.
    static func sample(cores: [(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)]) -> CPUTickSample {
        CPUTickSample(
            cores: cores.map { CPUTicks(user: $0.user, system: $0.system, idle: $0.idle, nice: $0.nice) }
        )
    }

    /// Counters close enough to the ceiling that the next sample wraps.
    static func nearOverflowSample(coreCount: Int) -> CPUTickSample {
        sample(coreCount: coreCount, user: 0, system: 0, idle: UInt32.max - 5, nice: 0)
    }

    /// Two efficiency cores followed by two performance cores.
    static let efficiencyFirstTopology = CoreTopology(
        levels: [.efficiency, .efficiency, .performance, .performance]
    )

    /// Two performance cores followed by two efficiency cores.
    static let performanceFirstTopology = CoreTopology(
        levels: [.performance, .performance, .efficiency, .efficiency]
    )

    static func allUnknownTopology(coreCount: Int) -> CoreTopology {
        CoreTopology.unknown(coreCount: coreCount)
    }
}
