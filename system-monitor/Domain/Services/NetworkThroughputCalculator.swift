import Foundation

/// Converts two consecutive cumulative counter readings into byte rates.
///
/// A deliberate sibling of `DiskThroughputCalculator` rather than a shared
/// generic: the two rules share only the four-line window helper, while their
/// vocabulary (`bytesIn`/`bytesOut` against `bytesRead`/`bytesWritten`) and
/// their reasons for a falling counter differ. Pure by construction: the window
/// comes from the stamps the adapter already recorded, so the rule never reads a
/// clock and every scenario is reproducible without hardware.
nonisolated enum NetworkThroughputCalculator {

    /// Both rates, or neither.
    ///
    /// Wrapping the pair in one optional makes "a download rate without an
    /// upload rate" unrepresentable, which is what NM-3 and NM-4 require of
    /// every caller.
    nonisolated struct Rates: Sendable, Equatable {

        /// Bytes received per second over the window.
        let downloadBytesPerSecond: Double

        /// Bytes sent per second over the window.
        let uploadBytesPerSecond: Double
    }

    /// Rates over the window between `previous` and `current`, or `nil`.
    ///
    /// The result is `nil` when there is no baseline yet, when **either** reading
    /// covers no interface, when the window is not positive, or when either
    /// counter fell — summed counters can only fall when an interface
    /// disappeared between two reads, and dividing that difference would invent
    /// a spike. The caller always re-seeds its baseline with `current`, so such
    /// churn costs exactly one tick.
    ///
    /// Both ends are checked because interface churn has two halves. The
    /// disappearing half is caught by the falling-counter guard below; the
    /// reappearing half is caught here. A reading covering no interface is valid
    /// and carries zero totals, so using it as a baseline would subtract from
    /// zero and report the machine's entire since-boot totals as one window of
    /// traffic — a fabricated pair that would then set the shared graph scale.
    /// A zero-interface reading is a gap in the series, never one end of a
    /// window.
    static func rates(
        previous: NetworkThroughputCounters?,
        current: NetworkThroughputCounters
    ) -> Rates? {
        guard
            let previous,
            previous.interfaceCount > 0,
            current.interfaceCount > 0
        else { return nil }

        guard
            current.bytesIn >= previous.bytesIn,
            current.bytesOut >= previous.bytesOut
        else { return nil }

        let elapsed = seconds(previous.timestamp.duration(to: current.timestamp))
        guard elapsed > 0 else { return nil }

        return Rates(
            downloadBytesPerSecond: Double(current.bytesIn - previous.bytesIn) / elapsed,
            uploadBytesPerSecond: Double(current.bytesOut - previous.bytesOut) / elapsed
        )
    }

    /// `Duration` as fractional seconds, keeping the attosecond remainder so a
    /// sub-second window still scales the rate.
    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
