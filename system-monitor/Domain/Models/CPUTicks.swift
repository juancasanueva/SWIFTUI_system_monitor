import Foundation

/// Raw CPU tick counters for one logical core, as published by the host.
///
/// Counters are monotonic 32-bit values that wrap; `delta(since:)` is the only
/// supported way to compare two samples.
nonisolated struct CPUTicks: Sendable, Hashable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    /// Sum of every counter, widened so four `UInt32.max` values cannot overflow.
    var total: UInt64 {
        UInt64(user) + UInt64(system) + UInt64(idle) + UInt64(nice)
    }

    /// Per-field wrapping difference against an earlier sample.
    ///
    /// Wrapping subtraction keeps the delta correct when a counter rolls over
    /// past `UInt32.max` between two reads.
    func delta(since previous: CPUTicks) -> CPUTicks {
        CPUTicks(
            user: user &- previous.user,
            system: system &- previous.system,
            idle: idle &- previous.idle,
            nice: nice &- previous.nice
        )
    }
}

/// One tick reading across every logical core, indexed by Mach processor index.
nonisolated struct CPUTickSample: Sendable, Equatable {
    let cores: [CPUTicks]

    var coreCount: Int { cores.count }
}
