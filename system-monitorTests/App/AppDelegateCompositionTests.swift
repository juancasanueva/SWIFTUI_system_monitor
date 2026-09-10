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
            // No suite may start the real updater (AU-7): it would reach the
            // feed, write the developer's real preference and open the
            // framework's own window from a test run.
            delegate.updaterFactory = { FakeAppUpdater() }
            delegate.applicationDidFinishLaunching(
                Notification(name: NSApplication.didFinishLaunchingNotification)
            )
            defer {
                delegate.applicationWillTerminate(
                    Notification(name: NSApplication.willTerminateNotification)
                )
                delegate.settingsWindow?.close()
                delegate.aboutWindow?.close()
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

    /// Index of each action item in the built context menu (MBW-10).
    private enum Item {
        static let about = 0
        static let checkForUpdates = 1
        static let settings = 2
        static let launchAtLogin = 3
        static let quit = 4
    }

    /// Builds the real delegate with the updater seam already substituted.
    ///
    /// **No suite may start the real updater** (AU-7). Constructing it would
    /// reach the feed, write the developer's real automatic-check preference and
    /// let the framework open its own window from a test run, which is exactly
    /// what the seam exists to make impossible.
    @MainActor
    private static func makeDelegate() -> AppDelegate {
        let delegate = AppDelegate()
        delegate.updaterFactory = { FakeAppUpdater() }
        return delegate
    }

    /// Launches a real graph, runs `body`, then terminates it and closes the
    /// settings window.
    ///
    /// Generic in the result so a case carries plain `Sendable` readings back
    /// out instead of leaking a main-actor object into the non-isolated test
    /// body (convention 2).
    @MainActor
    private static func withLaunchedApp<T>(_ body: @MainActor (AppDelegate) -> T) -> T {
        let delegate = makeDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            delegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
            delegate.settingsWindow?.close()
            delegate.aboutWindow?.close()
        }
        return body(delegate)
    }

    /// Launches a real graph, awaits `body` while its sampling loop keeps
    /// running, then terminates it and closes the settings window.
    ///
    /// The synchronous sibling above cannot serve here: the loop is a detached
    /// task that publishes back onto the main actor, so a case that waits for a
    /// published reading has to suspend, and a synchronous body would hold the
    /// very actor the publish needs.
    @MainActor
    private static func withRunningApp<T: Sendable>(_ body: @MainActor (AppDelegate) async -> T) async -> T {
        let delegate = makeDelegate()
        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        defer {
            delegate.applicationWillTerminate(
                Notification(name: NSApplication.willTerminateNotification)
            )
            delegate.settingsWindow?.close()
            delegate.aboutWindow?.close()
        }
        return await body(delegate)
    }

    /// Polls `read` on the main actor until it yields a value, or gives up at
    /// `timeout` and returns `nil`.
    ///
    /// A deadline rather than a fixed sleep: the loop publishes its first disk
    /// reading on its very first iteration, so a passing case costs
    /// milliseconds, while a graph that never publishes fails its case instead
    /// of hanging until the suite's time limit.
    @MainActor
    private static func awaitValue<T>(
        within timeout: Duration = .seconds(5),
        of read: @MainActor () -> T?
    ) async -> T? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while true {
            if let value = read() { return value }
            guard clock.now < deadline else { return nil }
            try? await clock.sleep(for: .milliseconds(20))
        }
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
                let fired = items.indices.contains(Item.settings) ? Self.fire(items[Item.settings]) : false

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
                if items.indices.contains(Item.settings) {
                    Self.fire(items[Item.settings])
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

    // MARK: - About window (MBW-15)

    // menu-bar-widget — MBW-15 "About item opens the window", the
    // composition-root half: the delegate builds one `AboutWindowController`
    // and the context menu's first item shows it.
    @Test func theAboutItemShowsTheDelegatesAboutWindow() async throws {
        let readings = await MainActor.run { () -> (fired: Bool, visible: Bool, title: String?) in
            Self.withLaunchedApp { delegate in
                guard let window = delegate.aboutWindow, let controller = delegate.statusItemController else {
                    return (false, false, nil)
                }

                let items = Self.actionItems(of: controller.makeContextMenu())
                let fired = items.indices.contains(Item.about) ? Self.fire(items[Item.about]) : false

                return (fired, window.isWindowVisible, window.windowTitle)
            }
        }

        #expect(readings.fired, "the context menu must carry a working About item")
        #expect(readings.visible)
        #expect(readings.title == "About System Monitor")
    }

    // MARK: - Lifetime

    // cpu-metrics — the loop must not outlive the app: `applicationWillTerminate`
    // stops the sampler it started.
    @Test func terminatingStopsTheSampler() async throws {
        let readings = await MainActor.run { () -> (beforeTerminate: Bool, afterTerminate: Bool?) in
            let delegate = Self.makeDelegate()
            delegate.applicationDidFinishLaunching(
                Notification(name: NSApplication.didFinishLaunchingNotification)
            )
            defer {
                delegate.settingsWindow?.close()
                delegate.aboutWindow?.close()
            }

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

    // MARK: - Disk provider (DM-14)

    // disk-metrics — DM-14 "Real graph runs with disk": the composition root
    // injects `IOKitDiskProvider(capacity: VolumeCapacityReader())`, so the
    // detached loop publishes the boot volume's real capacity on its first
    // iteration and real throughput rates on the next one.
    //
    // This is the only case that can tell the real adapter from a placeholder:
    // every other disk suite runs on `FakeDiskProvider`, and a provider whose
    // reads throw leaves `MetricsState.disk` at `nil` forever while all of them
    // stay green.
    @Test func theRealGraphPublishesRealDiskReadings() async throws {
        let readings = await Self.withRunningApp { delegate -> (first: DiskSnapshot?, withRates: DiskSnapshot?) in
            guard let state = delegate.state else { return (nil, nil) }

            let first = await Self.awaitValue { state.disk }
            let withRates = await Self.awaitValue { state.disk?.readBytesPerSecond == nil ? nil : state.disk }

            return (first, withRates)
        }

        let first = try #require(readings.first, "the real graph must publish a disk snapshot")

        #expect(first.total > 0, "the boot volume must report a capacity")
        #expect(first.free > 0)
        #expect(first.free <= first.total)
        #expect(first.used == first.total - first.free)
        #expect(first.fraction > 0 && first.fraction <= 1)

        let rated = try #require(readings.withRates, "the IOKit adapter must produce throughput rates")

        #expect(rated.readBytesPerSecond != nil)
        #expect(rated.writeBytesPerSecond != nil)
        #expect(rated.total == first.total, "the cached capacity must survive the next tick")
    }

    // disk-metrics — DM-14 "Modules untouched": the disk card is panel-only, so
    // the widget's module set is still exactly the two it has always rendered.
    @Test func theDiskModuleNeverEntersTheMenuBarModuleSet() {
        #expect(MetricModule.allCases == [.cpu, .memory])
        #expect(MetricModule.menuBarOrder == [.cpu, .memory])
    }

    // disk-metrics — DM-14 "Modules untouched", the width half (R10.11): the
    // item is measured from the settings' module set, and publishing disk
    // readings — the loop's own and a second, larger one — must never
    // re-measure it.
    @Test func publishingDiskReadingsLeavesTheStatusItemWidthUnchanged() async throws {
        let readings = await Self.withRunningApp {
            delegate -> (published: Bool, afterLoop: CGFloat, afterApply: CGFloat, fitting: CGFloat)? in
            guard
                let state = delegate.state,
                let settings = delegate.settingsState,
                let controller = delegate.statusItemController
            else {
                return nil
            }

            let published = await Self.awaitValue { state.disk } != nil
            let afterLoop = controller.statusItemLength
            state.apply(disk: DiskFixtures.referenceSnapshot)

            return (
                published: published,
                afterLoop: afterLoop,
                afterApply: controller.statusItemLength,
                fitting: controller.contentFittingWidth(for: settings.menuBarModules)
            )
        }

        let measured = try #require(readings, "the composition root must retain every collaborator")

        #expect(measured.published, "the real graph must publish a disk snapshot")
        #expect(measured.afterLoop > 0, "the widget measured as empty")
        #expect(measured.afterLoop == measured.fitting, "the item must stay sized from its module set")
        #expect(measured.afterApply == measured.afterLoop, "a disk reading must not resize the widget")
    }

    // MARK: - Network provider (NM-12)

    // network-metrics — NM-12 "Real graph publishes network": the composition
    // root injects `SysctlNetworkProvider()`, so the detached loop publishes the
    // machine's real since-boot totals on its first iteration and real
    // throughput rates on the next one.
    //
    // This is the only case that can tell the real adapter from a stand-in:
    // every other network suite runs on `FakeNetworkProvider`, and a provider
    // that reads no interface at all publishes zero totals forever while all of
    // them stay green. The totals are what pin it — a rate pair of `0 B/s` is
    // still a rate pair, so asserting only "rates are non-nil" would pass over a
    // provider that never reads a byte.
    @Test func theRealGraphPublishesRealNetworkReadings() async throws {
        let readings = await Self.withRunningApp { delegate -> (first: NetworkSnapshot?, withRates: NetworkSnapshot?) in
            guard let state = delegate.state else { return (nil, nil) }

            let first = await Self.awaitValue { state.network }
            let withRates = await Self.awaitValue { state.network?.downloadBytesPerSecond == nil ? nil : state.network }

            return (first, withRates)
        }

        let first = try #require(readings.first, "the real graph must publish a network snapshot")

        #expect(first.totalIn > 0, "the admitted interfaces must report received bytes since boot")
        #expect(first.totalOut > 0, "the admitted interfaces must report sent bytes since boot")

        let rated = try #require(readings.withRates, "the sysctl adapter must produce throughput rates")

        #expect(rated.downloadBytesPerSecond != nil)
        #expect(rated.uploadBytesPerSecond != nil)
        #expect(rated.totalIn >= first.totalIn, "since-boot totals must never go backwards between ticks")
        #expect(rated.totalOut >= first.totalOut)
    }

    // network-metrics — NM-12 "Modules and widget untouched": the network card
    // is panel-only, so the widget's module set is still exactly the two it has
    // always rendered, and publishing a network reading — the loop's own and a
    // second, hand-built one — must never re-measure the item.
    @Test func publishingNetworkReadingsLeavesTheModulesAndWidgetUnchanged() async throws {
        let readings = await Self.withRunningApp {
            delegate -> (published: Bool, afterLoop: CGFloat, afterApply: CGFloat, fitting: CGFloat)? in
            guard
                let state = delegate.state,
                let settings = delegate.settingsState,
                let controller = delegate.statusItemController
            else {
                return nil
            }

            let published = await Self.awaitValue { state.network } != nil
            let afterLoop = controller.statusItemLength
            state.apply(network: NetworkFixtures.referenceSnapshot)

            return (
                published: published,
                afterLoop: afterLoop,
                afterApply: controller.statusItemLength,
                fitting: controller.contentFittingWidth(for: settings.menuBarModules)
            )
        }

        let measured = try #require(readings, "the composition root must retain every collaborator")

        #expect(measured.published, "the real graph must publish a network snapshot")
        #expect(MetricModule.allCases == [.cpu, .memory])
        #expect(MetricModule.menuBarOrder == [.cpu, .memory])
        #expect(measured.afterLoop > 0, "the widget measured as empty")
        #expect(measured.afterLoop == measured.fitting, "the item must stay sized from its module set")
        #expect(measured.afterApply == measured.afterLoop, "a network reading must not resize the widget")
    }
}

// MARK: - The updater (AU-7)
//
// The composition-root half of the update slice: one updater, reaching both
// surfaces that speak to it. Every isolated suite passes with two — a menu item
// over one instance and a settings toggle over another would each behave
// correctly and would disagree about the same machine.
extension AppDelegateCompositionTests {

    // app-updates — AU-7 "The updater reaches nothing but the updater": the
    // delegate builds exactly one updater and hands that instance to the context
    // menu and to the settings window.
    @Test func launchingBuildsOneUpdaterSharedByTheMenuAndTheSettingsWindow() async throws {
        let identities = await MainActor.run { () -> (built: Bool, menu: Bool, window: Bool) in
            Self.withLaunchedApp { delegate in
                guard
                    let updater = delegate.updater,
                    let controller = delegate.statusItemController,
                    let window = delegate.settingsWindow
                else {
                    return (false, false, false)
                }

                return (
                    built: true,
                    menu: controller.injectedUpdater === updater,
                    window: window.boundUpdater === updater
                )
            }
        }

        #expect(identities.built, "the composition root must retain an updater")
        #expect(identities.menu, "the context menu must drive the delegate's updater")
        #expect(identities.window, "the settings window must show the delegate's updater")
    }

    // app-updates — AU-5 "An explicit update check is always reachable": the
    // menu item the delegate wires starts exactly one check on that updater.
    @Test func theContextMenuUpdateItemStartsOneCheckOnTheDelegatesUpdater() async throws {
        let readings = await MainActor.run { () -> (fired: Bool, checks: Int?, title: String?) in
            Self.withLaunchedApp { delegate in
                guard let controller = delegate.statusItemController else {
                    return (false, nil, nil)
                }

                let items = Self.actionItems(of: controller.makeContextMenu())
                guard items.indices.contains(Item.checkForUpdates) else {
                    return (false, nil, nil)
                }
                let item = items[Item.checkForUpdates]
                let fired = Self.fire(item)

                return (fired, (delegate.updater as? FakeAppUpdater)?.checkCount, item.title)
            }
        }

        #expect(readings.fired, "the context menu must carry a working Check for Updates item")
        #expect(readings.title == "Check for Updates\u{2026}")
        #expect(readings.checks == 1)
    }
}
