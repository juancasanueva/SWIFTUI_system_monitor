import Foundation
import Observation
import Sparkle

/// The **only** file in the repository that imports the updater framework (AU-7).
///
/// Everything else — the settings form, the context-menu item, the composition
/// root — speaks to `AppUpdating`, so the framework's vocabulary stops here.
/// That containment is asserted by `UpdateCompositionTests` rather than left to
/// convention, because a second import is exactly the kind of change that looks
/// harmless in review.
///
/// The feed and the verification key are **not** set here. They are build-time
/// facts merged into the bundle's information dictionary from the partial
/// property list, and this type deliberately offers no way to override either:
/// no updater delegate, no per-call feed URL, no runtime write. A key supplied
/// at run time is a key an attacker can supply (AU-3).
@MainActor
@Observable
final class SparkleUpdateChecker: AppUpdating {

    private(set) var canCheckForUpdates: Bool

    private(set) var lastUpdateCheckDate: Date?

    @ObservationIgnored private let controller: SPUStandardUpdaterController
    @ObservationIgnored private let automaticChecks: AutomaticUpdateChecks
    @ObservationIgnored private var canCheckObservation: NSKeyValueObservation?
    @ObservationIgnored private var lastCheckObservation: NSKeyValueObservation?

    /// The app's own preference is the authority, and it is applied **before**
    /// the updater starts.
    ///
    /// That order is the whole reason the controller is created with
    /// `startingUpdater: false`. Left unset, the framework asks the user on
    /// second launch whether to enable automatic checks — a system alert System
    /// Monitor never wanted, on a machine where the user may already have said
    /// no. Writing the preference first means the value is already there when
    /// the updater starts, so the prompt has nothing to ask about (AU-4).
    init(automaticChecks: AutomaticUpdateChecks) {
        self.automaticChecks = automaticChecks
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller = controller
        self.canCheckForUpdates = controller.updater.canCheckForUpdates
        self.lastUpdateCheckDate = controller.updater.lastUpdateCheckDate

        AutomaticUpdateChecksPolicy.apply(preference: automaticChecks.isEnabled, to: self)
        controller.startUpdater()

        observeUpdater()
    }

    var automaticallyChecksForUpdates: Bool {
        get {
            access(keyPath: \.automaticallyChecksForUpdates)
            return automaticChecks.isEnabled
        }
        set {
            withMutation(keyPath: \.automaticallyChecksForUpdates) {
                // The framework's property first, the app's key second. A crash
                // between the two leaves the app's key — the authority — holding
                // the old answer, which the next launch re-applies. The reverse
                // order would leave the framework checking on a machine whose
                // recorded answer says it must not.
                controller.updater.automaticallyChecksForUpdates = newValue
                automaticChecks.isEnabled = newValue
            }
        }
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    /// Mirrors the two values the surfaces read into Observation.
    ///
    /// **Invariant, written down because it is an assumption:** the framework
    /// mutates both of these on the main thread, so `assumeIsolated` is true
    /// rather than convenient. A `Task { @MainActor in … }` hop instead would
    /// leave the menu item briefly enabled while a check is already running,
    /// which is the one state the command must not be offered in. The whole type
    /// is `@MainActor`, so nothing else can observe the gap either way.
    private func observeUpdater() {
        canCheckObservation = controller.updater.observe(
            \.canCheckForUpdates,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.canCheckForUpdates = self.controller.updater.canCheckForUpdates
            }
        }
        lastCheckObservation = controller.updater.observe(
            \.lastUpdateCheckDate,
            options: [.initial, .new]
        ) { [weak self] _, _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.lastUpdateCheckDate = self.controller.updater.lastUpdateCheckDate
            }
        }
    }
}
