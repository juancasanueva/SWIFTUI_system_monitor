import AppKit
import SwiftUI

/// Owns the `NSStatusItem`, the popover with the detail panel and the context menu.
///
/// The widget updates once per second, so its geometry is fixed up front: the
/// hosting view never resizes itself from its content and the status item length
/// is measured from the widest content the current module set can render
/// (menu-bar-widget "Fixed-width, jitter-free layout").
///
/// It is an `NSObject` subclass because AppKit needs one: the context menu items
/// use target-action, and the popover reports its transitions through
/// `NSPopoverDelegate` (MBW-13).
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let state: MetricsState
    private let settings: SettingsState
    private let launchAtLogin: any LaunchAtLoginService

    /// Told when the popover opens and closes, so the sampler can switch
    /// cadence (MBW-13). Optional because the widget works without a cadence
    /// consumer; the composition root always supplies one.
    private let panelObserver: (any PanelVisibilityObserver)?

    /// Runs the explicit update check and reports whether one can run at all
    /// (AU-5). Typed as the port and never as the concrete checker, so a test
    /// host substitutes an in-memory updater and can never reach the feed.
    ///
    /// Optional because the widget works without an updater: the composition
    /// root always supplies one, and with none the item is present but inert
    /// rather than absent, so the menu's shape never depends on the wiring.
    private let updater: (any AppUpdating)?

    /// Opens the settings window (MBW-10). Injected rather than owned so this
    /// controller and Cmd+, drive the same `SettingsWindowController` (ST-5).
    private let openSettings: @MainActor () -> Void

    /// Opens the About window (MBW-15). Injected for the same reason as
    /// `openSettings`: the composition root owns the one window controller.
    private let openAbout: @MainActor () -> Void

    private let statusItem: NSStatusItem
    private let hostingView: PassthroughHostingView<StatusItemRootView>
    private let popover = NSPopover()

    /// The panel's hosting controller, kept for the controller's whole life.
    ///
    /// Stored rather than built inline at configure time so `updatePanelCap()`
    /// can swap `rootView` before each show (NC-12). Rebuilding the hosting
    /// controller instead would replace the popover's content view controller
    /// while it is being presented; swapping one value leaves the popover's own
    /// lifecycle untouched, which is what keeps MBW-13's single `show` per
    /// transition true.
    private let hostingController: NSHostingController<PanelRootView>

    /// Module set the current `statusItem.length` was measured from.
    ///
    /// Keeping it here is what makes the re-measure conditional: a settings
    /// commit that leaves the list alone — an interval edit, a failed save —
    /// finds no difference and never touches the length (MBW-9).
    private var measuredModules: [MetricModule] = []

    /// Presents a failed registration change (LAL-4). Tests replace it with a
    /// recorder, which is what proves the failure is surfaced exactly once
    /// instead of propagating out of an AppKit action.
    ///
    /// An `LSUIElement` app is not active when the user picks the item from the
    /// menu bar, so the alert is only reliably in front after `NSApp.activate()`.
    /// If activation is refused the alert can still land behind another app's
    /// window; that is the design's S3 risk and is settled by the manual check,
    /// not by probing `NSApp.isActive`, which lags activation.
    var errorPresenter: @MainActor (any Error) -> Void = { error in
        NSApp.activate()
        NSAlert(error: error).runModal()
    }

    init(
        state: MetricsState,
        settings: SettingsState,
        launchAtLogin: any LaunchAtLoginService,
        panelObserver: (any PanelVisibilityObserver)? = nil,
        updater: (any AppUpdating)? = nil,
        openSettings: @escaping @MainActor () -> Void = {},
        openAbout: @escaping @MainActor () -> Void = {}
    ) {
        self.state = state
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        self.panelObserver = panelObserver
        self.updater = updater
        self.openSettings = openSettings
        self.openAbout = openAbout
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hostingView = PassthroughHostingView(
            rootView: StatusItemRootView(state: state, settings: settings)
        )
        // Uncapped until the first show measures the presenting screen.
        hostingController = NSHostingController(rootView: PanelRootView(state: state))

        // 1 Hz content updates must not rewrite Auto Layout constraints (PRD 6.5).
        hostingView.sizingOptions = []

        super.init()

        configureButton()
        configurePopover()

        // `SettingsState` holds its observers for its whole life, so this
        // closure must not retain the controller: MBW-12 requires the
        // controller to die with its last external reference.
        settings.observe { [weak self] updated in
            self?.settingsDidChange(updated)
        }
    }

    /// Removes the item from the status bar as the controller goes away, so no
    /// orphaned widget survives it (MBW-12, debt W6).
    ///
    /// `isolated deinit` (SE-0371) hops to the main actor when the last
    /// reference is dropped somewhere else, which is exactly what the tests do;
    /// `MainActor.assumeIsolated` would trap there instead.
    isolated deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        // Sized from the widest sample the user's current module set can
        // render. Every sub-width is constant — the label, the 60 pt sparkline
        // and the value frame — so a live reading can never need more room.
        remeasure(for: settings.menuBarModules)

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.delegate = self

        // `PanelView` paints `Palette.panelBackground` unconditionally, so the
        // popover chrome is pinned to match it under any system appearance
        // (MBW-11).
        popover.appearance = NSAppearance(named: .darkAqua)

        popover.contentViewController = hostingController
    }

    // MARK: - Measurement

    /// Width of the widget rendering its widest content.
    ///
    /// Measured on a throwaway hosting view with the default sizing options:
    /// `hostingView` reports no fitting size because its own options are empty.
    private static func measuredContentWidth(for modules: [MetricModule]) -> CGFloat {
        let measurementView = NSHostingView(
            rootView: StatusItemContent(
                readings: StatusItemMetrics.measurementReadings(for: modules)
            )
        )
        measurementView.layoutSubtreeIfNeeded()
        return measurementView.fittingSize.width
    }

    /// Height the four-card panel wants, measured on a throwaway hosting view.
    ///
    /// Same shape as `measuredContentWidth(for:)`: the live hosting controller
    /// is inside a popover and reports the size it was given, not the size its
    /// content wants, so the question is asked of a fresh view instead.
    private static func measuredPanelHeight(for state: MetricsState) -> CGFloat {
        let measurementView = NSHostingView(rootView: PanelRootView(state: state))
        measurementView.layoutSubtreeIfNeeded()
        return measurementView.fittingSize.height
    }

    /// The cap the panel must be pinned to on a screen that tall, or `nil` when
    /// it fits (NC-12).
    ///
    /// Internal, and taking the frame height as a plain number, so the whole
    /// decision — measure the real panel, then apply the rule — is assertable
    /// without a screen: a suite running on a 16" display can still ask what
    /// happens on a 14" one.
    static func panelMaxHeight(
        for state: MetricsState,
        visibleFrameHeight: CGFloat
    ) -> CGFloat? {
        PanelLayout.maxHeight(
            fitting: measuredPanelHeight(for: state),
            visibleFrameHeight: visibleFrameHeight
        )
    }

    /// Resolves the cap for the screen the panel is about to appear on and
    /// hands it to the hosting controller (NC-12).
    ///
    /// Called per show, not once at configure time, for two reasons: the CPU
    /// card grows after its first snapshot, and the user can move the window to
    /// another display or change scaling between opens. With no screen at all —
    /// which is what a headless test host reports — no cap is applied and the
    /// panel keeps its unbounded tree.
    private func updatePanelCap() {
        let visibleFrameHeight = (statusItem.button?.window?.screen ?? NSScreen.main)?
            .visibleFrame.height

        hostingController.rootView = PanelRootView(
            state: state,
            maxHeight: visibleFrameHeight.flatMap {
                Self.panelMaxHeight(for: state, visibleFrameHeight: $0)
            }
        )
    }

    /// Measures `modules` and records the set the length now stands for.
    private func remeasure(for modules: [MetricModule]) {
        measuredModules = modules
        statusItem.length = Self.measuredContentWidth(for: modules)
    }

    /// Re-measures the item when, and only when, the module set changed.
    ///
    /// Readings arrive once per second and must never reach this path: a
    /// re-measure per value tick is precisely the jitter MBW-9 rules out.
    private func settingsDidChange(_ settings: Settings) {
        guard settings.menuBarModules != measuredModules else { return }
        remeasure(for: settings.menuBarModules)
    }

    // MARK: - Layout contract (test-visible)

    /// Current status item width. Constant across published readings.
    var statusItemLength: CGFloat {
        statusItem.length
    }

    /// Sizing options of the live hosting view. Empty by contract.
    var hostingSizingOptions: NSHostingSizingOptions {
        hostingView.sizingOptions
    }

    /// Width of the widget rendering `modules` at full scale, measured
    /// independently of the live hosting view.
    func contentFittingWidth(for modules: [MetricModule]) -> CGFloat {
        Self.measuredContentWidth(for: modules)
    }

    /// The installed status item. Test-visible so MBW-12 can hold it weakly and
    /// watch it die with its controller.
    var installedStatusItem: NSStatusItem {
        statusItem
    }

    /// The settings object this controller observes. Test-visible so the
    /// composition-root suite can prove the app builds exactly one
    /// `SettingsState` (ST-4, ST-5): a second one would still render and still
    /// re-measure, only from a list nobody else edits.
    var observedSettings: SettingsState {
        settings
    }

    /// The panel observer, if one was injected. Test-visible for the same
    /// reason: a composition root that forgets it leaves the popover
    /// transitions reaching nothing, which no cadence assertion can see while
    /// the configured interval happens to equal the idle one (MBW-13, CM-1).
    var panelVisibilityObserver: (any PanelVisibilityObserver)? {
        panelObserver
    }

    /// The updater the menu drives, if one was injected. Test-visible for the
    /// same reason: a composition root that builds a second updater leaves the
    /// menu item and the settings toggle each behaving correctly over a
    /// different instance, which no isolated suite can see (AU-7).
    var injectedUpdater: (any AppUpdating)? {
        updater
    }

    /// Appearance pinned on the popover, or `nil` when it follows the system
    /// (MBW-11).
    var popoverAppearanceName: NSAppearance.Name? {
        popover.appearance?.name
    }

    /// Whether the detail panel is on screen (MBW-13).
    var isPanelOpen: Bool {
        popover.isShown
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    /// Internal rather than private so MBW-13 can drive the guard directly.
    /// There is deliberately no show-only entry point: while the popover is
    /// shown this closes it instead of re-issuing `show`, so one open can never
    /// be reported twice.
    func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Before the show, not during it: the cap is a `rootView` swap on a
            // hosting controller the popover already owns, so it costs no
            // second `show` and MBW-13 still sees one transition (NC-12).
            updatePanelCap()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    // MARK: - NSPopoverDelegate (MBW-13)

    /// Reported before the panel renders, so the sampler is already back at the
    /// configured cadence by the time the first frame is drawn.
    func popoverWillShow(_ notification: Notification) {
        panelObserver?.panelDidOpen()
    }

    /// Also fires when a transient popover closes from a click outside it,
    /// which `togglePopover()` never sees (design decision 17).
    func popoverDidClose(_ notification: Notification) {
        panelObserver?.panelDidClose()
    }

    // MARK: - Context menu presentation

    private func showContextMenu() {
        // Standard pattern: attach the menu, trigger the button, then detach so
        // a subsequent left click reaches `handleClick` instead of opening the menu.
        statusItem.menu = makeContextMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: - Context menu (MBW-10, LAL-4)

    /// Builds the menu from the pure `ContextMenuModel` (MBW-10).
    ///
    /// Both live inputs are read here, once per build, and never cached: the
    /// user can change the login-item registration in System Settings at any
    /// time (LAL-4 "Status is re-read on every build"), and a check that started
    /// or finished while the menu was closed must be reflected the next time it
    /// opens (AU-5).
    ///
    /// `autoenablesItems` is turned off because it is on by default and would
    /// hand enablement to AppKit's own validation, silently overriding the one
    /// Domain rule that owns the update item's answer — and dimming every other
    /// item whose target does not implement `validateMenuItem(_:)`.
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        let items = ContextMenuModel.items(
            launchAtLogin: launchAtLogin.status,
            canCheckForUpdates: updater?.canCheckForUpdates ?? false
        )
        for item in items {
            menu.addItem(menuItem(for: item))
        }
        return menu
    }

    private func menuItem(for item: ContextMenuItem) -> NSMenuItem {
        let menuItem = NSMenuItem(
            title: item.title,
            action: Self.selector(for: item.action),
            keyEquivalent: Self.keyEquivalent(for: item.action)
        )
        menuItem.state = item.isChecked ? .on : .off
        menuItem.isEnabled = item.isEnabled
        // Quit is the application's own action; everything else is ours.
        menuItem.target = item.action == .quit ? NSApp : self
        return menuItem
    }

    private static func selector(for action: ContextMenuItem.Action) -> Selector {
        switch action {
        case .openAbout: #selector(handleOpenAbout)
        case .checkForUpdates: #selector(handleCheckForUpdates)
        case .openSettings: #selector(handleOpenSettings)
        case .toggleLaunchAtLogin: #selector(toggleLaunchAtLogin)
        case .openLoginItems: #selector(openLoginItems)
        case .quit: #selector(NSApplication.terminate(_:))
        }
    }

    /// Key equivalents are hints only: the menu is transient, so these are what
    /// the user reads next to the item rather than working shortcuts. Cmd+,
    /// itself is served by the app's main menu (ST-5).
    private static func keyEquivalent(for action: ContextMenuItem.Action) -> String {
        switch action {
        case .openSettings: ","
        case .quit: "q"
        case .openAbout, .checkForUpdates, .toggleLaunchAtLogin, .openLoginItems: ""
        }
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }

    /// Starts exactly one check (AU-5).
    ///
    /// A no-op with no updater rather than a missing target: the item still
    /// carries working wiring, so a menu built without an updater behaves like a
    /// dimmed item the user cannot choose instead of one that reaches nothing.
    @objc private func handleCheckForUpdates() {
        updater?.checkForUpdates()
    }

    @objc private func handleOpenAbout() {
        openAbout()
    }

    /// Registers or unregisters the app, following the live status (LAL-4).
    ///
    /// A refusal from the system reaches `errorPresenter` and stops there: an
    /// AppKit action cannot throw, and the next menu build reads the status
    /// again, so a failed change simply leaves the item as it was.
    @objc func toggleLaunchAtLogin() {
        do {
            if launchAtLogin.status.isEnabled {
                try launchAtLogin.disable()
            } else {
                try launchAtLogin.enable()
            }
        } catch {
            errorPresenter(error)
        }
    }

    /// Opens System Settings › Login Items, the only place the user can grant a
    /// pending approval (LAL-4).
    @objc func openLoginItems() {
        launchAtLogin.openLoginItemsSettings()
    }
}

/// Hosting view that is transparent to mouse events so clicks reach the status bar button.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
