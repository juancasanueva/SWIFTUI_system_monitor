import AppKit
import Testing
@testable import system_monitor

/// Builds the real composition root, records weak references to the status item
/// controller and its status item, then drops the delegate.
///
/// A holder object rather than two `weak var` locals for the reason
/// `StatusItemReleaseProbe` gives: the test body is not `@MainActor`
/// (convention 2), and a main-actor class is the only place a weak reference to
/// a main-actor object can be written and read on the same actor.
@MainActor
private final class LaunchReleaseProbe {

    private(set) weak var controller: StatusItemController?
    private(set) weak var statusItem: NSStatusItem?

    /// Returns whether both references were live immediately after launching,
    /// so a probe that never saw a graph fails its case instead of reporting a
    /// vacuous release.
    @discardableResult
    func launchAndRelease() -> Bool {
        var live = false

        do {
            let delegate = AppDelegate()
            delegate.applicationDidFinishLaunching(
                Notification(name: NSApplication.didFinishLaunchingNotification)
            )
            defer {
                delegate.applicationWillTerminate(
                    Notification(name: NSApplication.willTerminateNotification)
                )
                delegate.settingsWindow?.close()
            }

            controller = delegate.statusItemController
            statusItem = delegate.statusItemController?.installedStatusItem
            live = controller != nil && statusItem != nil
        }

        return live
    }

    var isFullyReleased: Bool {
        controller == nil && statusItem == nil
    }
}

// settings ST-5 "Both entry points share the window" (the composition-root
// half) and ST-7 wiring, plus cpu-metrics CM-1 as the app really assembles it.
//
// Every other suite builds one collaborator over fakes. This one builds the
// graph `AppDelegate` builds — real store, real adapters, real status item, real
// window — because the failures it rules out are wiring failures that every
// isolated suite passes: a second `SettingsState` so the widget and the settings
// window disagree, a second `SettingsWindowController` so Cmd+, opens its own
// window, a sampler seeded at the configured rate instead of the closed cadence,
// or a panel observer that was never passed to the status item controller.
//
// Cmd+, itself is not here: the key equivalent lives on a SwiftUI `CommandGroup`
// that only exists inside a running `App` scene, so it is manual check 8.3. What
// this suite pins is that the command's target, `showSettings()`, opens the same
// window the context menu opens.
//
// Tagged `.integration` because launching reads the real `UserDefaults` suite,
// the live `SMAppService` status and real Mach counters. It never writes a
// setting, so it cannot disturb the installed app's stored preferences.
@Suite("App delegate composition root", .tags(.integration), .timeLimit(.minutes(1)))
struct AppDelegateCompositionTests {

    /// Launches a real graph, runs `body`, then terminates it and closes the
    /// settings window.
    ///
    /// Generic in the result so a case carries plain `Sendable` readings back
    /// out instead of leaking a main-actor object into the non-isolated test
    /// body (convention 2).
    @MainActor
    private static func withLaunchedApp<T>(_ body: @MainActor (AppDelegate) -> T) -> T {
        let delegate = AppDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            delegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
            delegate.settingsWindow?.close()
        }
        return body(delegate)
    }

    /// The menu's action items, as `StatusItemControllerMenuTests` reads them.
    @MainActor
    private static func actionItems(of menu: NSMenu) -> [NSMenuItem] {
        menu.items.filter { !$0.isSeparatorItem }
    }

    /// Sends the item's action to its target exactly as AppKit does. Returns
    /// `false` when the item carries no working wiring, so missing plumbing
    /// fails its case instead of passing silently.
    @MainActor
    @discardableResult
    private static func fire(_ item: NSMenuItem) -> Bool {
        guard let action = item.action, let target = item.target as? NSObject else {
            return false
        }
        _ = target.perform(action, with: item)
        return true
    }

    // MARK: - The graph exists and is wired to one settings object

    // settings — ST-5/ST-7 wiring: one `SettingsState` for the widget and the
    // window, one `SettingsWindowController`, one cadence controller.
    @Test func launchingBuildsOneSettingsObjectSharedByEveryCollaborator() async throws {
        let identities = await MainActor.run { () -> (widget: Bool, window: Bool, observer: Bool, built: Bool) in
            Self.withLaunchedApp { delegate in
                guard
                    let settings = delegate.settingsState,
                    let controller = delegate.statusItemController,
                    let window = delegate.settingsWindow,
                    let cadence = delegate.cadence
                else {
                    return (false, false, false, false)
                }

                return (
                    widget: controller.observedSettings === settings,
                    window: window.boundSettings === settings,
                    observer: (controller.panelVisibilityObserver as? SamplingCadenceController) === cadence,
                    built: true
                )
            }
        }

        #expect(identities.built, "the composition root must retain every collaborator")
        #expect(identities.widget, "the widget must observe the delegate's SettingsState")
        #expect(identities.window, "the settings window must edit the delegate's SettingsState")
        #expect(identities.observer, "panel transitions must reach the cadence controller")
    }

    // MARK: - Cadence seeding (CM-1)

    // cpu-metrics — CM-1 "Cadence truth table": the panel is closed at launch, so
    // the sampler starts at the idle cadence whatever the stored interval is.
    @Test func launchingSeedsTheSamplerAtTheClosedCadenceAndStartsIt() async throws {
        let readings = await MainActor.run { () -> (interval: Duration?, configured: Duration?, running: Bool) in
            Self.withLaunchedApp { delegate in
                guard let sampler = delegate.sampler, let settings = delegate.settingsState else {
                    return (nil, nil, false)
                }
                return (sampler.interval, settings.samplingInterval, sampler.isRunning)
            }
        }

        let interval = try #require(readings.interval)
        let configured = try #require(readings.configured)

        #expect(interval == SamplingCadence.effective(configured: configured, panelOpen: false))
        #expect(interval == SamplingCadence.idleInterval)
        #expect(readings.running)
    }

    // cpu-metrics — CM-1 "Opening the panel restarts at the configured rate",
    // through the real delegate chain: popover delegate → panel observer →
    // cadence controller → sampler.
    @Test func aPanelTransitionOnTheStatusItemReachesTheSampler() async throws {
        let readings = await MainActor.run {
            () -> (closed: Duration?, opened: Duration?, reclosed: Duration?, configured: Duration?) in
            Self.withLaunchedApp { delegate in
                guard let sampler = delegate.sampler, let controller = delegate.statusItemController else {
                    return (nil, nil, nil, nil)
                }

                let closed = sampler.interval
                controller.popoverWillShow(Notification(name: NSPopover.willShowNotification))
                let opened = sampler.interval
                controller.popoverDidClose(Notification(name: NSPopover.didCloseNotification))

                return (closed, opened, sampler.interval, delegate.settingsState?.samplingInterval)
            }
        }

        let configured = try #require(readings.configured)

        #expect(readings.closed == SamplingCadence.effective(configured: configured, panelOpen: false))
        #expect(readings.opened == SamplingCadence.effective(configured: configured, panelOpen: true))
        #expect(readings.reclosed == SamplingCadence.effective(configured: configured, panelOpen: false))
    }

    // MARK: - Settings entry points (ST-5)

    // settings — ST-5 "Both entry points share the window": `showSettings()` is
    // what the Cmd+, command calls, and the context menu item is the other entry
    // point. Firing both must leave exactly one window, identified by its number.
    @Test func bothSettingsEntryPointsShowTheSameWindow() async throws {
        let readings = await MainActor.run {
            () -> (afterCommand: Int?, afterMenu: Int?, title: String?, visible: Bool, fired: Bool) in
            Self.withLaunchedApp { delegate in
                delegate.showSettings()

                guard let window = delegate.settingsWindow, let controller = delegate.statusItemController else {
                    return (nil, nil, nil, false, false)
                }

                let afterCommand = window.windowNumber
                let items = Self.actionItems(of: controller.makeContextMenu())
                let fired = items.indices.contains(0) ? Self.fire(items[0]) : false

                return (afterCommand, window.windowNumber, window.windowTitle, window.isWindowVisible, fired)
            }
        }

        #expect(readings.fired, "the context menu must carry a working Settings item")
        let afterCommand = try #require(readings.afterCommand)
        let afterMenu = try #require(readings.afterMenu)

        #expect(afterCommand == afterMenu, "the two entry points must reuse one window")
        #expect(readings.title == "Settings")
        #expect(readings.visible)
    }

    // settings — ST-5, the reverse order: the context menu opens the window
    // first, then the Cmd+, target re-shows it without creating a second one.
    @Test func theCommandTargetReusesTheWindowTheContextMenuOpened() async throws {
        let readings = await MainActor.run { () -> (afterMenu: Int?, afterCommand: Int?, visible: Bool) in
            Self.withLaunchedApp { delegate in
                guard let window = delegate.settingsWindow, let controller = delegate.statusItemController else {
                    return (nil, nil, false)
                }

                let items = Self.actionItems(of: controller.makeContextMenu())
                if items.indices.contains(0) {
                    Self.fire(items[0])
                }
                let afterMenu = window.windowNumber

                delegate.showSettings()

                return (afterMenu, window.windowNumber, window.isWindowVisible)
            }
        }

        let afterMenu = try #require(readings.afterMenu)
        let afterCommand = try #require(readings.afterCommand)

        #expect(afterMenu == afterCommand)
        #expect(readings.visible)
    }

    // MARK: - Lifetime

    // cpu-metrics — the loop must not outlive the app: `applicationWillTerminate`
    // stops the sampler it started.
    @Test func terminatingStopsTheSampler() async throws {
        let readings = await MainActor.run { () -> (beforeTerminate: Bool, afterTerminate: Bool?) in
            let delegate = AppDelegate()
            delegate.applicationDidFinishLaunching(
                Notification(name: NSApplication.didFinishLaunchingNotification)
            )
            defer { delegate.settingsWindow?.close() }

            let before = delegate.sampler?.isRunning ?? false
            delegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )

            return (before, delegate.sampler?.isRunning)
        }

        #expect(readings.beforeTerminate)
        #expect(readings.afterTerminate == false)
    }

    // menu-bar-widget — MBW-12 at the composition level: dropping the delegate
    // drops the status item with it, so a launched-and-released graph leaves no
    // item behind (convention 14).
    @Test func releasingTheDelegateRemovesTheStatusItem() async {
        let probe = await LaunchReleaseProbe()
        let live = await probe.launchAndRelease()

        await MainActor.run {}

        #expect(live, "the probe must have held a live controller and status item")
        #expect(await probe.isFullyReleased)
    }
}
