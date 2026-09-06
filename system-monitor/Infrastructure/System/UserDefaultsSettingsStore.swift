import Foundation

/// `SettingsStore` over `UserDefaults`, one plain key per field (ST-3).
///
/// Two independent keys rather than one encoded blob: each field is separately
/// recoverable when the other is missing or corrupt, both are readable and
/// editable with `defaults read`/`defaults write`, and adding a field later
/// costs a key rather than a `Codable` migration. Nothing else is written — in
/// particular the launch-at-login registration is never persisted here, because
/// its truth is `SMAppService.mainApp.status`, read live (LAL-3).
///
/// `UserDefaults` is not `Sendable` on MacOSX26.5.sdk: the compiler rejects it
/// as a stored property of a `Sendable` struct. Apple documents the class as
/// thread-safe ("The UserDefaults class is thread-safe", `UserDefaults`
/// reference, Overview), so the conformance is `@unchecked` and the property
/// `nonisolated(unsafe)`. In practice every call arrives on the main actor
/// through `SettingsState`.
nonisolated struct UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {

    /// The two keys this adapter owns. Nested types need explicit
    /// `nonisolated` because the module defaults to main-actor isolation.
    nonisolated enum Key {
        /// The sampling interval in seconds, as a `Double`.
        static let samplingIntervalSeconds = "settings.samplingIntervalSeconds"

        /// The ordered menu bar modules, as `MetricModule.rawValue` strings.
        static let menuBarModules = "settings.menuBarModules"
    }

    nonisolated(unsafe) private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Reads both keys independently and lets `Settings` normalise the result.
    ///
    /// A missing or wrongly typed interval yields `Settings.defaultInterval`;
    /// an out-of-range one is clamped by the initialiser. Module raw values
    /// that no longer name a case — a module removed since, or one a newer
    /// build wrote — are dropped, and a list left empty becomes
    /// `MetricModule.menuBarOrder`. Nothing here can fail, so nothing throws.
    func load() -> Settings {
        Settings(
            samplingInterval: loadInterval(),
            menuBarModules: loadModules()
        )
    }

    /// Writes the two keys and nothing else (LAL-3 "Nothing persisted").
    ///
    /// `UserDefaults` writes cannot fail, so this never throws in practice; the
    /// port declares `throws` for stores that can refuse a write.
    func save(_ settings: Settings) throws {
        defaults.set(Self.seconds(settings.samplingInterval), forKey: Key.samplingIntervalSeconds)
        defaults.set(settings.menuBarModules.map(\.rawValue), forKey: Key.menuBarModules)
    }

    /// A `Duration` as whole seconds plus its fractional remainder, exact for
    /// every 0.5 s step the Settings stepper produces.
    static func seconds(_ interval: Duration) -> Double {
        let components = interval.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    private func loadInterval() -> Duration {
        guard let value = defaults.object(forKey: Key.samplingIntervalSeconds) as? Double,
              value.isFinite
        else { return Settings.defaultInterval }

        return .seconds(value)
    }

    private func loadModules() -> [MetricModule] {
        guard let raw = defaults.stringArray(forKey: Key.menuBarModules) else { return [] }

        return raw.compactMap(MetricModule.init(rawValue:))
    }
}
