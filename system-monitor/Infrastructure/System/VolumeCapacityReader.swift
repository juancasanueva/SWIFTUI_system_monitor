import Foundation

/// Reads the capacity of one volume through `URLResourceValues`.
///
/// The boot volume is addressed by path (`/`) rather than by a bookmark, which
/// is what keeps the read available inside App Sandbox: reading resource values
/// of the root volume needs no security-scoped resource.
///
/// `free` comes from `volumeAvailableCapacityForImportantUsage`, the figure the
/// system also shows in Finder, so it accounts for purgeable space and can be
/// larger than the raw unallocated bytes. It is never derived from `total`.
///
/// Both properties arrive as optionals: a key the volume does not publish comes
/// back as `nil` instead of as a thrown error, and Foundation types them signed.
/// The conversion from that pair to a `VolumeCapacity` is therefore split out
/// into a pure static seam so its rejection rules are plain unit tests.
nonisolated struct VolumeCapacityReader: Sendable {

    /// Failure of the resource-value read or of its conversion.
    nonisolated enum ReadError: Error, Equatable {
        /// `URL.resourceValues(forKeys:)` threw. The `NSError` is reduced to its
        /// `domain` and `code` so the case stays `Equatable`.
        case resourceValues(domain: String, code: Int)
        /// The volume did not publish the key at all.
        case missingKey(URLResourceKey)
        /// The key was published with a value below 0.
        case negativeValue(URLResourceKey)
    }

    /// Keys requested in the single resource-value read.
    private static let keys: Set<URLResourceKey> = [
        .volumeTotalCapacityKey,
        .volumeAvailableCapacityForImportantUsageKey
    ]

    /// Volume to measure. The boot volume by default.
    private let volumeURL: URL

    init(volumeURL: URL = URL(fileURLWithPath: "/")) {
        self.volumeURL = volumeURL
    }

    /// Pure conversion seam (DM-13 "Missing or negative value rejected").
    ///
    /// A missing key is reported before a negative value, and the total is
    /// checked before the free space, so the reported key is deterministic.
    nonisolated static func capacity(total: Int?, free: Int64?) throws(ReadError) -> VolumeCapacity {
        guard let total else { throw ReadError.missingKey(.volumeTotalCapacityKey) }
        guard let free else {
            throw ReadError.missingKey(.volumeAvailableCapacityForImportantUsageKey)
        }
        guard total >= 0 else { throw ReadError.negativeValue(.volumeTotalCapacityKey) }
        guard free >= 0 else {
            throw ReadError.negativeValue(.volumeAvailableCapacityForImportantUsageKey)
        }

        return VolumeCapacity(total: UInt64(total), free: UInt64(free))
    }

    /// Reads both capacity values from the volume in one call.
    func read() throws -> VolumeCapacity {
        let values: URLResourceValues
        do {
            values = try volumeURL.resourceValues(forKeys: Self.keys)
        } catch {
            let error = error as NSError
            throw ReadError.resourceValues(domain: error.domain, code: error.code)
        }

        return try Self.capacity(
            total: values.volumeTotalCapacity,
            free: values.volumeAvailableCapacityForImportantUsage
        )
    }
}
