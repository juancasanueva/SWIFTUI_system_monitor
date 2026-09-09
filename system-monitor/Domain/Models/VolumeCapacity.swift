import Foundation

/// Capacity of one volume in bytes.
///
/// `free` is the space the system reports as available for important usage,
/// which is what the user sees in Finder, so it can be smaller than the raw
/// unallocated space and is never derived from `total` here.
nonisolated struct VolumeCapacity: Sendable, Equatable {

    /// Total capacity in bytes.
    let total: UInt64

    /// Available capacity in bytes.
    let free: UInt64
}
