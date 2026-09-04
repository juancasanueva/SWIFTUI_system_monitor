import Foundation

/// Performance class of a logical core.
///
/// `.unknown` is used whenever the hardware description cannot be trusted; a
/// topology is either fully resolved or fully unknown.
nonisolated enum PerformanceLevel: Sendable, Hashable, CaseIterable {
    case performance
    case efficiency
    case unknown
}

/// Maps every Mach processor index to its performance level.
nonisolated struct CoreTopology: Sendable, Equatable {

    /// Levels indexed by Mach processor index.
    let levels: [PerformanceLevel]

    var coreCount: Int { levels.count }

    /// `true` when at least one core resolved to a real performance level.
    var isSplit: Bool {
        levels.contains { $0 != .unknown }
    }

    /// Level of a core, or `.unknown` when the index is outside the topology.
    func level(of index: Int) -> PerformanceLevel {
        guard levels.indices.contains(index) else { return .unknown }
        return levels[index]
    }

    /// Degraded topology used whenever the level mapping cannot be verified.
    static func unknown(coreCount: Int) -> CoreTopology {
        CoreTopology(levels: Array(repeating: .unknown, count: max(0, coreCount)))
    }
}
