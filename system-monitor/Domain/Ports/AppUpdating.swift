import Foundation
import Observation

/// Port for everything System Monitor's own surfaces ask of an updater (AU-1).
///
/// Four members and nothing else: the third-party updater framework is confined
/// to exactly one adapter in Infrastructure, and this is the only vocabulary
/// that crosses out of it. The settings form, the context-menu item and the
/// composition root all speak to this; none of them can name a framework type.
///
/// It is `@MainActor` because the module compiles under
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and the concrete updater is
/// main-actor by construction, so a `nonisolated` requirement could not be
/// satisfied by the only conformer that matters. It is `AnyObject` because both
/// surfaces must observe the *same* instance rather than copies of a value.
///
/// It refines `Observable` so a view holding `any AppUpdating` still re-renders:
/// Observation registers at the **accessor**, so tracking survives the
/// existential. The existential is deliberate — the composition root picks the
/// concrete type at run time, real or in-memory.
@MainActor
protocol AppUpdating: AnyObject, Observable {

    /// Whether a check can run right now. In practice this is false only while a
    /// check is already in flight — never because automatic checking is off,
    /// never because the last check found nothing.
    var canCheckForUpdates: Bool { get }

    /// Whether the updater checks on its own. The app's persisted preference is
    /// the authority for this value and writes it at every launch (AU-4).
    var automaticallyChecksForUpdates: Bool { get set }

    /// When the updater last completed a check, or `nil` if it never has.
    var lastUpdateCheckDate: Date? { get }

    /// Starts exactly one check.
    func checkForUpdates()
}
