import Foundation
@testable import system_monitor

/// Reusable network counters and snapshots for the Domain, Application and
/// Presentation suites.
///
/// `ContinuousClock.Instant` cannot be built from a literal, so every stamp is
/// derived from a single `base` captured once via `advanced(by:)`. Tests must
/// therefore assert on differences between stamps, never on an absolute value.
nonisolated enum NetworkFixtures {

    /// The one instant every fixture stamp is derived from.
    static let base = ContinuousClock.now

    /// `base` advanced by `seconds`, so scripted ticks stay deterministic.
    static func instant(_ seconds: Double) -> ContinuousClock.Instant {
        base.advanced(by: .seconds(seconds))
    }

    /// Cumulative counters stamped `seconds` after `base`.
    static func counters(
        in bytesIn: UInt64,
        out bytesOut: UInt64,
        interfaceCount: Int = 1,
        at seconds: Double
    ) -> NetworkThroughputCounters {
        NetworkThroughputCounters(
            bytesIn: bytesIn,
            bytesOut: bytesOut,
            interfaceCount: interfaceCount,
            timestamp: instant(seconds)
        )
    }

    /// Value an empty network script reads: no interface passed the filter, so
    /// the rates are unavailable while the stamp stays valid.
    static let idle = counters(in: 0, out: 0, interfaceCount: 0, at: 0)

    /// Shared reference fixture of both specs (network-metrics:7,
    /// network-card:7), baseline half: two admitted interfaces.
    static let referencePrevious = counters(
        in: 3_849_995_000,
        out: 2_759_922_000,
        interfaceCount: 2,
        at: 0
    )

    /// Reference fixture, current half: 5.0 kB/s down and 78.0 kB/s up over the
    /// 1 s window.
    static let referenceCurrent = counters(
        in: 3_850_000_000,
        out: 2_760_000_000,
        interfaceCount: 2,
        at: 1
    )

    /// The reference totals published with the reference rates; the card
    /// renders them as "3.85 GB" / "2.76 GB" and "5.0 kB/s" / "78.0 kB/s".
    static let referenceSnapshot = NetworkSnapshot(
        totalIn: 3_850_000_000,
        totalOut: 2_760_000_000,
        downloadBytesPerSecond: 5_000,
        uploadBytesPerSecond: 78_000
    )

    /// Counters 1 s apart growing by the reference deltas every step, for loop
    /// suites that must never run dry. Step 0 is `referencePrevious` and step 1
    /// is `referenceCurrent`.
    static func climbing(steps: Int = 400) -> [NetworkThroughputCounters] {
        (0..<steps).map { step in
            counters(
                in: 3_849_995_000 + UInt64(step) * 5_000,
                out: 2_759_922_000 + UInt64(step) * 78_000,
                interfaceCount: 2,
                at: Double(step)
            )
        }
    }
}
