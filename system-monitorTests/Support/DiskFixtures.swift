import Foundation
@testable import system_monitor

/// Reusable disk counters, capacities and snapshots for the Domain,
/// Application and Presentation suites.
///
/// `ContinuousClock.Instant` cannot be built from a literal, so every stamp is
/// derived from a single `base` captured once via `advanced(by:)`. Tests must
/// therefore assert on differences between stamps, never on an absolute value.
nonisolated enum DiskFixtures {

    /// The one instant every fixture stamp is derived from.
    static let base = ContinuousClock.now

    /// `base` advanced by `seconds`, so scripted ticks stay deterministic.
    static func instant(_ seconds: Double) -> ContinuousClock.Instant {
        base.advanced(by: .seconds(seconds))
    }

    /// Cumulative counters stamped `seconds` after `base`.
    static func counters(
        read: UInt64,
        written: UInt64,
        driverCount: Int = 1,
        at seconds: Double
    ) -> DiskThroughputCounters {
        DiskThroughputCounters(
            bytesRead: read,
            bytesWritten: written,
            driverCount: driverCount,
            timestamp: instant(seconds)
        )
    }

    /// Value an empty throughput script reads: no driver was readable, so the
    /// rates are unavailable while the stamp stays valid.
    static let idle = counters(read: 0, written: 0, driverCount: 0, at: 0)

    /// disk-metrics DM-3 "Reference capacity": used 432_068_000_000,
    /// fraction 0.87401…
    static let referenceCapacity = VolumeCapacity(
        total: 494_354_000_000,
        free: 62_286_000_000
    )

    /// disk-metrics DM-4 "Reference rate", baseline half.
    static let referencePrevious = counters(
        read: 1_000_000_000,
        written: 500_000_000,
        at: 0
    )

    /// disk-metrics DM-4 "Reference rate", current half: 27.1 MB/s read and
    /// 2.2 MB/s write over the 1 s window.
    static let referenceCurrent = counters(
        read: 1_027_100_000,
        written: 502_200_000,
        at: 1
    )

    /// The reference capacity published with the reference rates.
    static let referenceSnapshot = DiskSnapshot(
        total: 494_354_000_000,
        free: 62_286_000_000,
        readBytesPerSecond: 27_100_000,
        writeBytesPerSecond: 2_200_000
    )

    /// Counters 1 s apart growing by the reference deltas every step, for loop
    /// suites that must never run dry.
    static func climbing(steps: Int = 400) -> [DiskThroughputCounters] {
        (0..<steps).map { step in
            counters(
                read: 1_000_000_000 + UInt64(step) * 27_100_000,
                written: 500_000_000 + UInt64(step) * 2_200_000,
                at: Double(step)
            )
        }
    }
}
