import Foundation

/// Turns raw hardware-description entries plus the sysctl core counts into a
/// `CoreTopology`.
///
/// The resolution is pure so every degradation rule can be unit tested without
/// touching IOKit. The result is all-or-nothing: either every core resolves to
/// a real performance level and all cross-checks agree, or the whole topology
/// collapses to `.unknown` (core-topology "Count cross-check", R3.6).
nonisolated enum CoreTopologyResolver {

    /// One logical core as published by the hardware description.
    nonisolated struct Entry: Sendable, Equatable {

        /// Value of the `logical-cpu-id` property, expected to match the Mach
        /// processor index.
        let logicalID: Int

        /// Value of the `cluster-type` property: `"P"`, `"E"`, or anything else.
        let clusterType: String
    }

    /// Maps a raw `cluster-type` value to a performance level.
    ///
    /// Only the exact upper-case `"P"` and `"E"` markers are trusted; every
    /// other value (including the `"M"` cluster of newer chips) is `.unknown`.
    static func level(forClusterType clusterType: String) -> PerformanceLevel {
        switch clusterType {
        case "P": .performance
        case "E": .efficiency
        default: .unknown
        }
    }

    /// Resolves the entries into a topology, degrading to all-`.unknown`
    /// whenever the description cannot be trusted.
    ///
    /// The topology collapses when the entry count differs from `expectedTotal`,
    /// when a logical id is duplicated or outside `0..<expectedTotal`, when an
    /// expected count is missing, when a cluster type does not resolve, or when
    /// the resolved per-level counts disagree with the sysctl values.
    static func resolve(
        entries: [Entry],
        expectedPerformance: Int?,
        expectedEfficiency: Int?,
        expectedTotal: Int
    ) -> CoreTopology {
        let degraded = CoreTopology.unknown(coreCount: expectedTotal)

        guard
            let expectedPerformance,
            let expectedEfficiency,
            expectedTotal > 0,
            entries.count == expectedTotal
        else {
            return degraded
        }

        var levels = [PerformanceLevel](repeating: .unknown, count: expectedTotal)
        var assigned = Set<Int>()

        for entry in entries {
            let level = level(forClusterType: entry.clusterType)
            guard
                level != .unknown,
                levels.indices.contains(entry.logicalID),
                assigned.insert(entry.logicalID).inserted
            else {
                return degraded
            }
            levels[entry.logicalID] = level
        }

        let performanceCount = levels.count { $0 == .performance }
        let efficiencyCount = levels.count { $0 == .efficiency }
        guard
            performanceCount == expectedPerformance,
            efficiencyCount == expectedEfficiency
        else {
            return degraded
        }

        return CoreTopology(levels: levels)
    }
}
