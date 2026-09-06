import Foundation

/// The R5.4 idle-cadence rule (CM-1) as a pure function.
///
/// The loop always runs; only its cadence changes. While the panel is closed
/// nobody reads a value more precise than the menu bar widget, so the sampler
/// falls back to a fixed idle interval; while the panel is open it follows the
/// interval the user configured. Keeping the rule pure means both the truth
/// table and the loop behaviour can be tested without a clock.
nonisolated enum SamplingCadence {

    /// Cadence used while the detail panel is closed.
    static let idleInterval: Duration = .seconds(2)

    /// The interval the sampler should actually run at.
    static func effective(configured: Duration, panelOpen: Bool) -> Duration {
        panelOpen ? configured : idleInterval
    }
}

/// Anything that wants to be told when the detail panel opens or closes.
///
/// The port exists so the AppKit popover delegate (MBW-13) depends on a
/// protocol rather than on the cadence controller: the same transitions also
/// drive test doubles and, later, any other panel-aware collaborator. It is
/// `@MainActor` because `NSPopoverDelegate` callbacks arrive there and every
/// implementor mutates main-actor state.
@MainActor
protocol PanelVisibilityObserver: AnyObject {
    func panelDidOpen()
    func panelDidClose()
}

/// Turns panel transitions and settings changes into the sampler's cadence
/// (CM-1, ST-7).
///
/// It is the single place where `SamplingCadence.effective(configured:panelOpen:)`
/// meets `MetricsSampler.apply(interval:)`, which is what keeps views out of
/// the sampler: the settings form only mutates `SettingsState`, and this
/// controller reacts. `apply(interval:)` is idempotent, so a refresh that
/// resolves to the interval already in effect — a repeated open, or a settings
/// change while the panel is closed — costs no restart.
@MainActor
final class SamplingCadenceController: PanelVisibilityObserver {

    private let sampler: MetricsSampler
    private let settings: SettingsState

    /// Last reported panel state; `false` until the popover says otherwise,
    /// matching the app's launch state.
    private(set) var isPanelOpen = false

    /// Subscribes to settings commits. The sampler is not refreshed here: the
    /// composition root seeds it with the closed cadence, so construction never
    /// restarts a loop that has not started yet.
    init(sampler: MetricsSampler, settings: SettingsState) {
        self.sampler = sampler
        self.settings = settings

        settings.observe { [weak self] _ in
            self?.refresh()
        }
    }

    func panelDidOpen() {
        isPanelOpen = true
        refresh()
    }

    func panelDidClose() {
        isPanelOpen = false
        refresh()
    }

    private func refresh() {
        sampler.apply(
            interval: SamplingCadence.effective(
                configured: settings.samplingInterval,
                panelOpen: isPanelOpen
            )
        )
    }
}
