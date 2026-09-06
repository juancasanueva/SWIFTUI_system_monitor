import Foundation

/// Port that persists and restores the user's `Settings` (ST-2).
///
/// `load()` deliberately does not throw: a missing, partial or corrupt store is
/// a normal first-launch condition, so it yields a value that already satisfies
/// the ST-1 invariants rather than an error the UI would have to handle.
/// `save(_:)` may throw because a real backing store can refuse a write; the
/// caller keeps the in-memory value and surfaces the failure.
///
/// The port is `nonisolated` and `Sendable` so an adapter can be handed to any
/// isolation domain; settings themselves are mutated on the main actor.
nonisolated protocol SettingsStore: Sendable {
    func load() -> Settings
    func save(_ settings: Settings) throws
}
