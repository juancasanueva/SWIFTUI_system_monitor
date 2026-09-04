import Foundation

/// Port that describes the performance level of every logical core.
///
/// Resolution never fails: when the hardware description cannot be trusted the
/// implementation returns an all-`.unknown` topology instead of throwing.
nonisolated protocol CoreTopologyProvider: Sendable {
    func topology() -> CoreTopology
}
