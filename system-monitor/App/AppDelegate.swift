import AppKit

/// Composition root of the app.
///
/// Builds the settings stack — store, observable state, settings window — and
/// the metrics stack — state, adapters, sampler, cadence controller — then the
/// menu bar item that ties them together, and starts sampling. Every
/// collaborator is retained here for the lifetime of the process; nothing else
/// owns them.
///
/// Two single-instance rules are the point of doing it in one place. There is
/// exactly one `SettingsState`, so the widget, the settings window and the
/// sampler always agree on the user's choices (ST-4, ST-7); and exactly one
/// `SettingsWindowController`, so the context-menu item and Cmd+, show the same
/// window instead of one each (ST-5). The About window follows the same
/// single-owner rule (MBW-15), and so does the updater: the context-menu command
/// and the settings form must observe one instance or they disagree about the
/// same machine (AU-7).
final class AppDelegate: NSObject, NSApplicationDelegate {

    // The graph. Internal rather than private so `AppDelegateCompositionTests`
    // can assert the wiring — a second settings object or a missing panel
    // observer is invisible to every suite that builds one collaborator over
    // fakes. Nothing outside the tests reads them.

    private(set) var state: MetricsState?
    private(set) var settingsState: SettingsState?
    private(set) var sampler: MetricsSampler?
    private(set) var cadence: SamplingCadenceController?
    private(set) var settingsWindow: SettingsWindowController?
    private(set) var aboutWindow: AboutWindowController?
    private(set) var statusItemController: StatusItemController?

    /// The one updater, held here because the context menu and the settings
    /// window must observe the *same* instance (AU-7). Typed as the port, never
    /// as the concrete checker.
    private(set) var updater: (any AppUpdating)?

    /// How the updater is built, substitutable before launch.
    ///
    /// The seam exists because `AppDelegateCompositionTests` launches this very
    /// delegate: constructing the real checker there would start the updater,
    /// reach the feed, write the developer's real automatic-check preference and
    /// let the framework open its own window from a test run. Every suite
    /// replaces this with an in-memory updater, which is what makes those
    /// failures structurally impossible rather than merely unlikely.
    ///
    /// The default is the real one, so the shipped app needs no configuration
    /// and a forgotten substitution fails a test loudly rather than silently
    /// disabling updates in the product.
    var updaterFactory: @MainActor () -> any AppUpdating = {
        SparkleUpdateChecker(automaticChecks: AutomaticUpdateChecks(defaults: .standard))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settingsStore = UserDefaultsSettingsStore()
        let settingsState = SettingsState(store: settingsStore)
        let state = MetricsState()

        // The panel is closed at launch, so the loop starts at the idle cadence
        // rather than at the configured interval (CM-1). The cadence controller
        // only reacts to transitions, so this seeding is what makes the first
        // closed period correct.
        let sampler = MetricsSampler(
            state: state,
            cpuProvider: MachCPUProvider(),
            memoryProvider: MachMemoryProvider(),
            diskProvider: IOKitDiskProvider(capacity: VolumeCapacityReader()),
            networkProvider: SysctlNetworkProvider(),
            topologyProvider: IORegistryCoreTopologyProvider(sysctl: SysctlReader()),
            interval: SamplingCadence.effective(
                configured: settingsState.samplingInterval,
                panelOpen: false
            )
        )

        let cadence = SamplingCadenceController(sampler: sampler, settings: settingsState)
        // One updater for both surfaces (AU-7). Building it applies the app's
        // own persisted preference to the updater before starting it, so neither
        // a bundled default nor a value the framework persisted on a previous
        // launch can decide whether the app reaches the network (AU-4).
        let updater = updaterFactory()
        let settingsWindow = SettingsWindowController(settings: settingsState, updater: updater)
        let aboutWindow = AboutWindowController(
            info: AboutModel.info(bundleInfo: Bundle.main.infoDictionary ?? [:])
        )
        let statusItemController = StatusItemController(
            state: state,
            settings: settingsState,
            launchAtLogin: SMAppServiceLaunchAtLogin(),
            panelObserver: cadence,
            updater: updater,
            openSettings: { [settingsWindow] in settingsWindow.show() },
            openAbout: { [aboutWindow] in aboutWindow.show() }
        )

        self.state = state
        self.updater = updater
        self.settingsState = settingsState
        self.sampler = sampler
        self.cadence = cadence
        self.settingsWindow = settingsWindow
        self.aboutWindow = aboutWindow
        self.statusItemController = statusItemController

        sampler.start()
    }

    /// Target of the Cmd+, command in `SystemMonitorApp` (ST-5).
    ///
    /// It shows the very window the context-menu item shows, because both go
    /// through the one `SettingsWindowController` built above.
    func showSettings() {
        settingsWindow?.show()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sampler?.stop()
    }
}
