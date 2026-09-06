import Foundation

/// The user-editable settings of the app (ST-1).
///
/// Every instance satisfies the invariants because the initialiser normalises:
/// the interval is clamped to `minimumInterval...maximumInterval` and the module
/// list is de-duplicated, order preserving and never empty. No other layer can
/// therefore build an invalid value, and the transition helpers below all route
/// back through the initialiser.
nonisolated struct Settings: Sendable, Equatable {

    /// Fastest cadence the UI offers; also the lower clamp bound.
    static let minimumInterval: Duration = .milliseconds(500)

    /// Slowest cadence the UI offers; also the upper clamp bound.
    static let maximumInterval: Duration = .seconds(5)

    /// Step used by the Settings stepper. A UI concern, not an invariant: any
    /// in-range value is a valid `samplingInterval`.
    static let intervalStep: Duration = .milliseconds(500)

    /// Cadence used until the user changes it.
    static let defaultInterval: Duration = .seconds(1)

    /// The value a fresh install starts from.
    static let `default` = Settings()

    /// Clamped to `minimumInterval...maximumInterval`.
    let samplingInterval: Duration

    /// Non-empty, first-occurrence order, no duplicates.
    let menuBarModules: [MetricModule]

    /// Clamps `samplingInterval`; de-duplicates `menuBarModules` keeping the
    /// first occurrence; an empty list normalises to `MetricModule.menuBarOrder`.
    init(
        samplingInterval: Duration = Settings.defaultInterval,
        menuBarModules: [MetricModule] = MetricModule.menuBarOrder
    ) {
        self.samplingInterval = Settings.clamped(samplingInterval)
        self.menuBarModules = Settings.normalised(menuBarModules)
    }

    /// Same value with a different cadence, clamped through the initialiser.
    func withSamplingInterval(_ interval: Duration) -> Settings {
        Settings(samplingInterval: interval, menuBarModules: menuBarModules)
    }

    /// The last-module guard: the widget always shows at least one module, so
    /// the only visible one can never be hidden. An absent module is already
    /// hidden and cannot be hidden either.
    func canHide(_ module: MetricModule) -> Bool {
        menuBarModules.contains(module) && menuBarModules.count > 1
    }

    /// Appends the module at the end when it is absent; idempotent otherwise.
    func showing(_ module: MetricModule) -> Settings {
        guard !menuBarModules.contains(module) else { return self }
        return Settings(
            samplingInterval: samplingInterval,
            menuBarModules: menuBarModules + [module]
        )
    }

    /// Removes the module when `canHide` allows it; returns `self` otherwise.
    func hiding(_ module: MetricModule) -> Settings {
        guard canHide(module) else { return self }
        return Settings(
            samplingInterval: samplingInterval,
            menuBarModules: menuBarModules.filter { $0 != module }
        )
    }

    /// Swaps the module with its predecessor; `self` at index 0 or when absent.
    func movingUp(_ module: MetricModule) -> Settings {
        moving(module, by: -1)
    }

    /// Swaps the module with its successor; `self` at the end or when absent.
    func movingDown(_ module: MetricModule) -> Settings {
        moving(module, by: 1)
    }

    private func moving(_ module: MetricModule, by offset: Int) -> Settings {
        guard let index = menuBarModules.firstIndex(of: module) else { return self }

        let target = index + offset
        guard menuBarModules.indices.contains(target) else { return self }

        var reordered = menuBarModules
        reordered.swapAt(index, target)
        return Settings(samplingInterval: samplingInterval, menuBarModules: reordered)
    }

    private static func clamped(_ interval: Duration) -> Duration {
        min(max(interval, minimumInterval), maximumInterval)
    }

    private static func normalised(_ modules: [MetricModule]) -> [MetricModule] {
        var seen: Set<MetricModule> = []
        let unique = modules.filter { seen.insert($0).inserted }
        return unique.isEmpty ? MetricModule.menuBarOrder : unique
    }
}
