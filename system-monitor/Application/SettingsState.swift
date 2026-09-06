import Foundation
import Observation

/// Observable owner of the user's `Settings` (ST-4).
///
/// It is the second `@Observable` object in Application next to `MetricsState`,
/// and the only place settings are mutated. Views read the pass-throughs and
/// call the intent methods; nothing outside can assign a `Settings` value, so
/// every exposed value has already been through the ST-1 normalisation.
///
/// Persistence is synchronous and main-actor bound: the store port is cheap
/// (`UserDefaults`) and keeping it on the same actor means a commit, its save
/// and the observer notifications are one indivisible step for callers.
@MainActor
@Observable
final class SettingsState {

    /// The current value. Read-only from the outside; mutations go through the
    /// intent methods so the ST-1 invariants cannot be bypassed.
    private(set) var settings: Settings

    /// Cadence pass-through, so views and the cadence controller do not have to
    /// reach through `settings`.
    var samplingInterval: Duration { settings.samplingInterval }

    /// Menu bar module pass-through, in the user's chosen order.
    var menuBarModules: [MetricModule] { settings.menuBarModules }

    /// Error from the last `save`; `nil` after a successful save. The in-memory
    /// value is kept either way, so a read-only store degrades to "settings work
    /// for this session" instead of crashing or silently reverting.
    private(set) var lastSaveError: (any Error)?

    @ObservationIgnored private let store: any SettingsStore

    /// Called synchronously after each accepted commit. Registration order is
    /// preserved; observers never outlive the object that registered them.
    @ObservationIgnored private var observers: [@MainActor (Settings) -> Void] = []

    /// Loads the persisted value. Nothing is written back: a first launch with
    /// an empty store keeps the store empty until the user changes something.
    init(store: any SettingsStore) {
        self.store = store
        self.settings = store.load()
    }

    /// Registers an observer for accepted commits (used by the cadence
    /// controller and the status item controller).
    func observe(_ observer: @escaping @MainActor (Settings) -> Void) {
        observers.append(observer)
    }

    /// Sets the sampling cadence; out-of-range values are clamped by ST-1.
    func setInterval(_ interval: Duration) {
        commit(settings.withSamplingInterval(interval))
    }

    /// Shows or hides a menu bar module. Hiding the last visible one is a
    /// no-op: `Settings.hiding(_:)` returns the same value, so the unchanged
    /// guard in `commit(_:)` swallows it and nothing is persisted.
    func setModule(_ module: MetricModule, visible: Bool) {
        commit(visible ? settings.showing(module) : settings.hiding(module))
    }

    /// Moves a module one position towards the start of the widget.
    func moveUp(_ module: MetricModule) {
        commit(settings.movingUp(module))
    }

    /// Moves a module one position towards the end of the widget.
    func moveDown(_ module: MetricModule) {
        commit(settings.movingDown(module))
    }

    /// Whether the module's visibility toggle may be switched off.
    func canHide(_ module: MetricModule) -> Bool {
        settings.canHide(module)
    }

    /// Accepts a normalised value, persists it and notifies the observers.
    ///
    /// An unchanged value is rejected before anything else, which is what makes
    /// every no-op transition (the last-module guard, an edge reorder, the same
    /// interval twice) free of a store write. Observers run after the save
    /// attempt so they always see the committed value, whether or not it
    /// reached the store.
    private func commit(_ updated: Settings) {
        guard updated != settings else { return }

        settings = updated

        do {
            try store.save(updated)
            lastSaveError = nil
        } catch {
            lastSaveError = error
        }

        for observer in observers {
            observer(updated)
        }
    }
}
