import Foundation

/// Thin adapter over `sysctlbyname` for the integer keys the CPU module needs.
///
/// Every read is best effort: an absent or unreadable key returns `nil` so the
/// callers can degrade instead of failing (core-topology R3.6).
nonisolated struct SysctlReader: Sendable {

    init() {}

    /// Reads an integer sysctl by name, or `nil` when it is absent or has an
    /// unexpected width.
    ///
    /// The kernel publishes these keys as either `Int32` or `Int64` depending
    /// on the key, so the value is decoded from the length `sysctlbyname`
    /// reports rather than from an assumed type.
    func integer(_ name: String) -> Int? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        var readSize = size
        let status = buffer.withUnsafeMutableBytes { raw in
            sysctlbyname(name, raw.baseAddress, &readSize, nil, 0)
        }
        guard status == 0 else { return nil }

        switch readSize {
        case MemoryLayout<Int32>.size:
            return Int(buffer.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) })
        case MemoryLayout<Int64>.size:
            let wide = buffer.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) }
            return Int(exactly: wide)
        default:
            return nil
        }
    }

    /// Number of logical cores the host exposes (`hw.logicalcpu`).
    var logicalCPUCount: Int? { integer("hw.logicalcpu") }

    /// Number of published performance levels (`hw.nperflevels`); absent on Intel.
    var performanceLevelCount: Int? { integer("hw.nperflevels") }

    /// Logical cores in one performance level (`hw.perflevel{N}.logicalcpu`).
    ///
    /// Level 0 is the performance cluster and level 1 the efficiency cluster.
    func logicalCPUCount(perfLevel level: Int) -> Int? {
        guard level >= 0 else { return nil }
        return integer("hw.perflevel\(level).logicalcpu")
    }
}
