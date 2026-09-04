import Foundation
@testable import system_monitor

/// `CoreTopologyProvider` double returning a fixed topology.
nonisolated struct FakeCoreTopologyProvider: CoreTopologyProvider {
    let result: CoreTopology

    func topology() -> CoreTopology { result }
}
