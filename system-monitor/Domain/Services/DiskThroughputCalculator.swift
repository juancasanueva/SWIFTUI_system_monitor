import Foundation

/// Converts two consecutive cumulative counter readings into byte rates.
///
/// Pure by construction: the window comes from the stamps the adapter already
/// recorded, so the rule never reads a clock and every scenario is reproducible
/// without hardware.
nonisolated enum DiskThroughputCalculator {

    /// Both rates, or neither.
    ///
    /// Wrapping the pair in one optional makes "a read rate without a write
    /// rate" unrepresentable, which is what DM-4 requires of every caller.
    nonisolated struct Rates: Sendable, Equatable {

        /// Bytes read per second over the window.
        let readBytesPerSecond: Double

        /// Bytes written per second over the window.
        let writeBytesPerSecond: Double
    }

    /// Rates over the window between `previous` and `current`, or `nil`.
    ///
    /// The result is `nil` when there is no baseline yet, when the current
    /// reading covers no driver, when the window is not positive, or when
    /// either counter fell — a counter can only fall when a volume was ejected
    /// or a driver reset, and dividing a wrapped difference would invent a
    /// spike. The caller always re-seeds its baseline with `current`, so such
    /// a reset costs exactly one tick.
    static func rates(
        previous: DiskThroughputCounters?,
        current: DiskThroughputCounters
    ) -> Rates? {
        guard let previous, current.driverCount > 0 else { return nil }

        guard
            current.bytesRead >= previous.bytesRead,
            current.bytesWritten >= previous.bytesWritten
        else { return nil }

        let elapsed = seconds(previous.timestamp.duration(to: current.timestamp))
        guard elapsed > 0 else { return nil }

        return Rates(
            readBytesPerSecond: Double(current.bytesRead - previous.bytesRead) / elapsed,
            writeBytesPerSecond: Double(current.bytesWritten - previous.bytesWritten) / elapsed
        )
    }

    /// `Duration` as fractional seconds, keeping the attosecond remainder so a
    /// sub-second window still scales the rate.
    private static func seconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
