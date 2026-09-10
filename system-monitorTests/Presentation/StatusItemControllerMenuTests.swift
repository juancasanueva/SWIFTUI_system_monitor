import AppKit
import Testing
@testable import system_monitor

/// Counts calls to the injected `openSettings` closure (MBW-10).
///
/// Main-actor bound because the closure the controller stores is, so the count
/// is read on the same actor that writes it.
@MainActor
private final class OpenSettingsCounter {

    private(set) var count = 0

    func increment() {
        count += 1
    }
}

// menu-bar-widget MBW-10 (context menu actions) and launch-at-login LAL-4
// (controller behaviour).
//
// `ContextMenuModelTests` already pins the pure table — titles, check state and
// the action each status maps to. This suite owns what the controller adds on
// top of it: that the values become real `NSMenuItem`s with working targets,
// that the status is read live on every build, and that a refused registration
// is surfaced instead of crashing.
//
// Every case builds a real `NSStatusItem` in the test host, as
// `StatusItemControllerTests` does, and releases its controller at the end of
// the scope so the item is removed with it (convention 14).
@Suite("Status item controller menu", .timeLimit(.minutes(1)))
struct StatusItemControllerMenuTests {

    /// Index of each action item in the built menu, matching
    /// `ContextMenuModel.items(launchAtLogin:canCheckForUpdates:)`.
    private enum Item {
        static let about = 0
        static let checkForUpdates = 1
        static let settings = 2
        static let launchAtLogin = 3
        static let quit = 4
    }

    /// Builds a controller over fakes, runs `body`, then drops it.
    ///
    /// Generic in the result so a case can carry AppKit readings back out as
    /// plain `Sendable` values instead of leaking a main-actor object into the
    /// non-isolated test body (convention 2).
    ///
    /// The updater defaults to `nil`, which is the shape every pre-update case
    /// runs under: no updater means the check item is inert and disabled, and
    /// nothing here can reach the network.
    @MainActor
    private static func withController<T>(
        launchAtLogin: FakeLaunchAtLoginService = FakeLaunchAtLoginService(),
        modules: [MetricModule] = MetricModule.menuBarOrder,
        updater: (any AppUpdating)? = nil,
        openSettings: @escaping @MainActor () -> Void = {},
        openAbout: @escaping @MainActor () -> Void = {},
        _ body: @MainActor (StatusItemController) -> T
    ) -> T {
        let settings = SettingsState(
            store: FakeSettingsStore(stored: Settings(menuBarModules: modules))
        )
        let controller = StatusItemController(
            state: MetricsState(),
            settings: settings,
            launchAtLogin: launchAtLogin,
            updater: updater,
            openSettings: openSettings,
            openAbout: openAbout
        )
        return body(controller)
    }

    /// The menu's action items. Separators are allowed by MBW-10 and are not
    /// part of the contract, so they are filtered out rather than counted.
    @MainActor
    private static func actionItems(of menu: NSMenu) -> [NSMenuItem] {
        menu.items.filter { !$0.isSeparatorItem }
    }

    /// Sends the item's action to its target, exactly as AppKit does when the
    /// user picks it. Returns `false` when the item carries no working wiring,
    /// so a missing target fails its case instead of passing silently.
    @MainActor
    @discardableResult
    private static func fire(_ item: NSMenuItem) -> Bool {
        guard let action = item.action, let target = item.target as? NSObject else {
            return false
        }
        _ = target.perform(action, with: item)
        return true
    }

    // MARK: - Menu shape (MBW-10)

    // menu-bar-widget — MBW-10 "Item titles and order"
    @Test func theContextMenuHasTheFiveActionItemsInOrder() async {
        let titles = await Self.withController(
            launchAtLogin: FakeLaunchAtLoginService(status: .notRegistered),
            updater: FakeAppUpdater()
        ) { controller in
            Self.actionItems(of: controller.makeContextMenu()).map(\.title)
        }

        #expect(
            titles == [
                "About System Monitor",
                "Check for Updates\u{2026}",
                "Settings\u{2026}",
                "Launch at Login",
                "Quit System Monitor",
            ]
        )
    }

    // menu-bar-widget — MBW-15 "About item opens the window", closure half.
    @Test func theAboutItemCallsTheInjectedOpenAboutClosureOnce() async {
        let opens = await MainActor.run { () -> Int in
            let counter = OpenSettingsCounter()

            Self.withController(openAbout: { counter.increment() }) { controller in
                let items = Self.actionItems(of: controller.makeContextMenu())
                #expect(Self.fire(items[Item.about]))
            }

            return counter.count
        }

        #expect(opens == 1)
    }

    // menu-bar-widget — MBW-15 "About item opens the window", against the real
    // window controller the composition root injects.
    @Test func theAboutItemOpensTheRealAboutWindow() async {
        let observed = await MainActor.run { () -> (isVisible: Bool, title: String?) in
            let window = AboutWindowController(info: AboutModel.info(bundleInfo: [:]))
            defer { window.close() }

            var result = (isVisible: false, title: String?.none)
            Self.withController(openAbout: { window.show() }) { controller in
                let items = Self.actionItems(of: controller.makeContextMenu())
                #expect(Self.fire(items[Item.about]))
                result = (window.isWindowVisible, window.windowTitle)
            }
            return result
        }

        #expect(observed.isVisible)
        #expect(observed.title == "About System Monitor")
    }

    // menu-bar-widget — MBW-10 "Settings item opens the window", closure half.
    @Test func theSettingsItemCallsTheInjectedOpenSettingsClosureOnce() async {
        let opens = await MainActor.run { () -> Int in
            let counter = OpenSettingsCounter()

            Self.withController(openSettings: { counter.increment() }) { controller in
                let items = Self.actionItems(of: controller.makeContextMenu())
                #expect(Self.fire(items[Item.settings]))
            }

            return counter.count
        }

        #expect(opens == 1)
    }

    // menu-bar-widget — MBW-10 "Settings item opens the window", against the
    // real window controller the composition root injects (ST-5).
    @Test func theSettingsItemOpensTheRealSettingsWindow() async {
        let observed = await MainActor.run { () -> (isVisible: Bool, title: String?) in
            let window = SettingsWindowController(
                settings: SettingsState(store: FakeSettingsStore())
            )
            defer { window.close() }

            var result = (isVisible: false, title: String?.none)
            Self.withController(openSettings: { window.show() }) { controller in
                let items = Self.actionItems(of: controller.makeContextMenu())
                #expect(Self.fire(items[Item.settings]))
                result = (window.isWindowVisible, window.windowTitle)
            }
            return result
        }

        #expect(observed.isVisible)
        #expect(observed.title == "Settings")
    }

    // menu-bar-widget — MBW-10 "Quit terminates". The item is inspected, never
    // fired: firing it would terminate the test host.
    @Test func theQuitItemIsWiredToTheApplicationTerminateAction() async {
        let wiring = await Self.withController { controller in
            let item = Self.actionItems(of: controller.makeContextMenu())[Item.quit]
            return (
                isTerminate: item.action == #selector(NSApplication.terminate(_:)),
                targetsTheApplication: item.target === NSApp
            )
        }

        #expect(wiring.isTerminate)
        #expect(wiring.targetsTheApplication)
    }

    // MARK: - Launch at login (LAL-4)

    // launch-at-login — LAL-4 "Status is re-read on every build". The status
    // changes underneath the controller, exactly as it does when the user edits
    // Login Items while the app runs.
    @Test func theLaunchAtLoginItemFollowsTheLiveStatusOnEveryBuild() async {
        let service = FakeLaunchAtLoginService(status: .notRegistered)

        let checkedStates = await Self.withController(launchAtLogin: service) { controller in
            let before = Self.actionItems(of: controller.makeContextMenu())
            let wasCheckedBefore = before[Item.launchAtLogin].state == .on

            service.setStatus(.enabled)

            let after = Self.actionItems(of: controller.makeContextMenu())
            return [wasCheckedBefore, after[Item.launchAtLogin].state == .on]
        }

        #expect(checkedStates == [false, true])
        #expect(service.statusReads == 2, "the menu cached the status instead of re-reading it")
    }

    // launch-at-login — LAL-4 "Toggle on calls enable once"
    @Test func togglingFromNotRegisteredCallsEnableExactlyOnce() async {
        let service = FakeLaunchAtLoginService(status: .notRegistered)

        await Self.withController(launchAtLogin: service) { controller in
            let items = Self.actionItems(of: controller.makeContextMenu())
            #expect(Self.fire(items[Item.launchAtLogin]))
        }

        #expect(service.enableCalls == 1)
        #expect(service.disableCalls == 0)
    }

    // launch-at-login — LAL-4 "Toggle off calls disable once"
    @Test func togglingFromEnabledCallsDisableExactlyOnce() async {
        let service = FakeLaunchAtLoginService(status: .enabled)

        await Self.withController(launchAtLogin: service) { controller in
            let items = Self.actionItems(of: controller.makeContextMenu())
            #expect(Self.fire(items[Item.launchAtLogin]))
        }

        #expect(service.disableCalls == 1)
        #expect(service.enableCalls == 0)
    }

    // launch-at-login — LAL-4 "Approval pending routes to Login Items"
    @Test func approvalPendingOpensLoginItemsInsteadOfToggling() async {
        let service = FakeLaunchAtLoginService(status: .requiresApproval)

        let item = await Self.withController(launchAtLogin: service) { controller in
            let menuItem = Self.actionItems(of: controller.makeContextMenu())[Item.launchAtLogin]
            #expect(Self.fire(menuItem))
            return (title: menuItem.title, isChecked: menuItem.state == .on)
        }

        #expect(item.title == "Launch at Login (Requires Approval)\u{2026}")
        #expect(item.isChecked == false)
        #expect(service.openLoginItemsCalls == 1)
        #expect(service.enableCalls == 0)
        #expect(service.disableCalls == 0)
    }

    // launch-at-login — LAL-4 "Enable failure does not crash". The error reaches
    // the presenter once instead of propagating, and the next build still
    // reflects the live (unchanged) status.
    @Test func aRefusedEnableIsSurfacedOnceAndLeavesTheItemUnchecked() async {
        let service = FakeLaunchAtLoginService(status: .notRegistered, throwOnEnable: [0])

        let observed = await MainActor.run { () -> (errorCount: Int, isCheckedAfter: Bool) in
            let recorder = ErrorRecorder()
            var result = (errorCount: -1, isCheckedAfter: true)

            Self.withController(launchAtLogin: service) { controller in
                controller.errorPresenter = { recorder.record($0) }

                let items = Self.actionItems(of: controller.makeContextMenu())
                #expect(Self.fire(items[Item.launchAtLogin]))

                let rebuilt = Self.actionItems(of: controller.makeContextMenu())
                result = (recorder.errors.count, rebuilt[Item.launchAtLogin].state == .on)
            }

            return result
        }

        #expect(observed.errorCount == 1)
        #expect(observed.isCheckedAfter == false)
        #expect(service.enableCalls == 1)
    }
}

// MARK: - Check for Updates (AU-5)
//
// `ContextMenuModelTests` pins the pure enablement table. This extension owns
// what the controller adds on top of it: that the value becomes a real
// `NSMenuItem` whose enabled state AppKit actually honours, that firing it
// starts exactly one check, and that the readiness is re-read on every build
// rather than frozen at construction.
extension StatusItemControllerMenuTests {

    // app-updates — AU-5 "Invoking the command starts exactly one check".
    @Test func theUpdateItemStartsExactlyOneCheck() async {
        let checks = await MainActor.run { () -> Int in
            let updater = FakeAppUpdater(canCheckForUpdates: true)

            Self.withController(updater: updater) { controller in
                let items = Self.actionItems(of: controller.makeContextMenu())
                #expect(Self.fire(items[Item.checkForUpdates]))
            }

            return updater.checkCount
        }

        #expect(checks == 1)
    }

    // app-updates — AU-5 "The command is disabled only while a check is in
    // flight". The menu must not auto-enable its items, or AppKit would decide
    // enablement from the target's `validateMenuItem` and quietly override the
    // rule the Domain owns.
    @Test func theUpdateItemIsDisabledWhileTheUpdaterCannotCheck() async {
        let states = await Self.withController(
            updater: FakeAppUpdater(canCheckForUpdates: false)
        ) { controller in
            let menu = controller.makeContextMenu()
            let items = Self.actionItems(of: menu)
            return (
                autoenables: menu.autoenablesItems,
                update: items[Item.checkForUpdates].isEnabled,
                settings: items[Item.settings].isEnabled,
                quit: items[Item.quit].isEnabled
            )
        }

        #expect(states.autoenables == false, "AppKit would override the Domain's enablement rule")
        #expect(states.update == false)
        #expect(states.settings, "a check in flight must not take the rest of the menu with it")
        #expect(states.quit)
    }

    // app-updates — AU-5: the readiness is read live on every build, exactly as
    // the launch-at-login status is. A check that finishes while the menu is
    // closed must leave the item live the next time it opens.
    @Test func theUpdateItemsEnablementIsReReadOnEveryBuild() async {
        let enabledStates = await MainActor.run { () -> [Bool] in
            let updater = FakeAppUpdater(canCheckForUpdates: false)

            return Self.withController(updater: updater) { controller in
                let before = Self.actionItems(of: controller.makeContextMenu())
                let wasEnabledBefore = before[Item.checkForUpdates].isEnabled

                updater.canCheckForUpdates = true

                let after = Self.actionItems(of: controller.makeContextMenu())
                return [wasEnabledBefore, after[Item.checkForUpdates].isEnabled]
            }
        }

        #expect(enabledStates == [false, true], "the menu cached the readiness instead of re-reading it")
    }

    // app-updates — AU-5: with no updater injected the item is present but
    // inert, which is what keeps a test host — and any surface built without an
    // updater — structurally unable to reach the feed.
    @Test func withoutAnUpdaterTheItemIsPresentAndDisabled() async {
        let observed = await Self.withController { controller in
            let items = Self.actionItems(of: controller.makeContextMenu())
            let item = items[Item.checkForUpdates]
            let fired = Self.fire(item)
            return (title: item.title, isEnabled: item.isEnabled, fired: fired, count: items.count)
        }

        #expect(observed.count == 5)
        #expect(observed.title == "Check for Updates\u{2026}")
        #expect(observed.isEnabled == false)
        #expect(observed.fired, "the item must still carry a target, so a nil updater is a no-op not a crash")
    }
}
