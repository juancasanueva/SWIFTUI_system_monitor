import Foundation
@testable import system_monitor

/// Records every panel open/close transition reported to it (MBW-13).
///
/// `true` means the panel opened. Main-actor bound because the transitions it
/// stands in for are delivered by `NSPopoverDelegate` callbacks, and it stands
/// in for `SamplingCadenceController` wherever a test only needs to know which
/// transitions were reported.
@MainActor
final class PanelVisibilitySpy: PanelVisibilityObserver {

    private(set) var events: [Bool] = []

    func panelDidOpen() {
        events.append(true)
    }

    func panelDidClose() {
        events.append(false)
    }
}

/// Collects the errors a controller would otherwise present in an `NSAlert`.
///
/// It is what lets a test assert that a failed `enable()` was surfaced exactly
/// once instead of crashing the app (LAL-4).
@MainActor
final class ErrorRecorder {

    private(set) var errors: [any Error] = []

    func record(_ error: any Error) {
        errors.append(error)
    }
}
