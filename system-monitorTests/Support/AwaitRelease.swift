import Foundation

/// Suspends on the main actor until `isReleased` reports `true`, or gives up at
/// `timeout` and returns `false` (MBW-12).
///
/// Why a wait exists at all: `NSStatusBar.removeStatusItem(_:)` does not drop
/// AppKit's own references to the item. Measured on the test host, a removed
/// item — even a bare one that never had a button, a length or a controller,
/// removed inside an explicit `autoreleasepool` — is still alive, still
/// `isVisible` and still in its status bar when the call returns. AppKit lets
/// go of it a couple of main-run-loop passes later, after a main-queue block
/// and a main-actor task enqueued *behind* the removal have already run. So no
/// fixed number of main-actor hops is enough: under a loaded parallel run a
/// single `await MainActor.run {}` regularly lands before that release.
///
/// A deadline rather than a sleep: the predicate is re-read every few
/// milliseconds while the main run loop is free to run AppKit's release, so a
/// passing case costs milliseconds, and an item that something genuinely keeps
/// alive still fails its case instead of passing on a lucky timing.
@MainActor
func awaitRelease(
    within timeout: Duration = .seconds(5),
    until isReleased: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while !isReleased() {
        guard clock.now < deadline else { return false }
        try? await clock.sleep(for: .milliseconds(5))
    }
    return true
}
