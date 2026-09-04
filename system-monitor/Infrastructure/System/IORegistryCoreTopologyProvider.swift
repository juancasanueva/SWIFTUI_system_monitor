import Foundation
import IOKit

/// Resolves the performance level of every logical core from the IORegistry.
///
/// The platform expert (`AppleARMPE`) publishes one `cpuN` child per logical
/// core carrying a `cluster-type` (`"P"` / `"E"`) and a `logical-cpu-id`. Those
/// entries are cross-checked against the sysctl per-level counts by
/// `CoreTopologyResolver`; anything unreadable or inconsistent degrades to an
/// all-`.unknown` topology sized to the Mach core count (core-topology R3.6).
///
/// The provider never throws and never reads from the main thread on behalf of
/// the caller: the sampling loop calls it once from its detached task.
nonisolated struct IORegistryCoreTopologyProvider: CoreTopologyProvider {

    /// IOKit class publishing the per-core device tree on Apple Silicon.
    private static let platformExpertClass = "AppleARMPE"

    /// Name prefix of the per-core children, followed by decimal digits.
    private static let coreEntryPrefix = "cpu"

    private static let clusterTypeKey = "cluster-type"
    private static let logicalCPUIDKey = "logical-cpu-id"

    /// Number of performance levels a P/E split machine publishes.
    private static let splitPerformanceLevelCount = 2

    private let sysctl: SysctlReader

    init(sysctl: SysctlReader = SysctlReader()) {
        self.sysctl = sysctl
    }

    func topology() -> CoreTopology {
        let coreCount = sysctl.logicalCPUCount ?? 0
        let degraded = CoreTopology.unknown(coreCount: coreCount)

        guard sysctl.performanceLevelCount == Self.splitPerformanceLevelCount else { return degraded }
        guard let entries = Self.readCoreEntries() else { return degraded }

        return CoreTopologyResolver.resolve(
            entries: entries,
            expectedPerformance: sysctl.logicalCPUCount(perfLevel: 0),
            expectedEfficiency: sysctl.logicalCPUCount(perfLevel: 1),
            expectedTotal: coreCount
        )
    }

    /// Collects one entry per `cpuN` child of the platform expert.
    ///
    /// Returns `nil` when the platform expert is absent, the child iterator
    /// cannot be created, or a matching child is missing either property.
    private static func readCoreEntries() -> [CoreTopologyResolver.Entry]? {
        guard let matching = IOServiceMatching(platformExpertClass) else { return nil }

        // IOServiceGetMatchingService consumes the matching dictionary.
        let root = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard root != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(root) }

        var iterator: io_iterator_t = IO_OBJECT_NULL
        guard IORegistryEntryGetChildIterator(root, kIOServicePlane, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var entries: [CoreTopologyResolver.Entry] = []
        while case let child = IOIteratorNext(iterator), child != IO_OBJECT_NULL {
            defer { IOObjectRelease(child) }
            guard isCoreEntryName(name(of: child)) else { continue }
            guard
                let logicalID = logicalCPUID(of: child),
                let clusterType = clusterType(of: child)
            else {
                return nil
            }
            entries.append(CoreTopologyResolver.Entry(logicalID: logicalID, clusterType: clusterType))
        }

        return entries
    }

    private static func name(of entry: io_registry_entry_t) -> String? {
        var buffer = [CChar](repeating: 0, count: MemoryLayout<io_name_t>.size)
        guard IORegistryEntryGetNameInPlane(entry, kIOServicePlane, &buffer) == KERN_SUCCESS else {
            return nil
        }
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    /// `true` for `cpu0`, `cpu13`, … and `false` for siblings such as `cpus`.
    private static func isCoreEntryName(_ name: String?) -> Bool {
        guard let name, name.hasPrefix(coreEntryPrefix) else { return false }
        let index = name.dropFirst(coreEntryPrefix.count)
        return !index.isEmpty && index.allSatisfy { $0.isASCII && $0.isNumber }
    }

    /// Reads `cluster-type`, published as one-byte ASCII data.
    private static func clusterType(of entry: io_registry_entry_t) -> String? {
        guard let value = property(clusterTypeKey, of: entry) else { return nil }
        if let data = value as? Data {
            guard let first = data.first, first != 0 else { return "" }
            return String(UnicodeScalar(first))
        }
        if let text = value as? String {
            return String(text.prefix(1))
        }
        return nil
    }

    /// Reads `logical-cpu-id`, published either as a number or as little-endian data.
    private static func logicalCPUID(of entry: io_registry_entry_t) -> Int? {
        guard let value = property(logicalCPUIDKey, of: entry) else { return nil }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let data = value as? Data, data.count >= MemoryLayout<UInt32>.size {
            let raw = Data(data.prefix(MemoryLayout<UInt32>.size))
            return Int(UInt32(littleEndian: raw.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        }
        return nil
    }

    private static func property(_ key: String, of entry: io_registry_entry_t) -> Any? {
        IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue()
    }
}
