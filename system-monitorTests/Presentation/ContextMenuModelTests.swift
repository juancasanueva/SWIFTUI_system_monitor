import Foundation
import Testing
@testable import system_monitor

// menu-bar-widget — MBW-10 "Context menu"; launch-at-login — LAL-4 "Launch at
// Login menu item"; app-updates — AU-5 "An explicit update check is always
// reachable".
//
// The menu content is a pure table: titles, check state, enablement and the
// action each item carries are derived from the launch-at-login status and the
// updater's readiness alone, so the whole matrix runs without an `NSMenu`, an
// `NSStatusItem`, `SMAppService` or an updater. The controller's job is only to
// turn these values into `NSMenuItem`s and to call the collaborators.
@Suite("Context menu model", .timeLimit(.minutes(1)))
struct ContextMenuModelTests {

    private static let aboutTitle = "About System Monitor"
    private static let updatesTitle = "Check for Updates\u{2026}"
    private static let settingsTitle = "Settings\u{2026}"
    private static let launchTitle = "Launch at Login"
    private static let quitTitle = "Quit System Monitor"

    /// Index of each item in the built menu.
    private enum Item {
        static let about = 0
        static let checkForUpdates = 1
        static let settings = 2
        static let launchAtLogin = 3
        static let quit = 4
    }

    private static func items(
        _ status: LaunchAtLoginStatus = .notRegistered,
        canCheckForUpdates: Bool = true
    ) -> [ContextMenuItem] {
        ContextMenuModel.items(launchAtLogin: status, canCheckForUpdates: canCheckForUpdates)
    }

    /// The launch-at-login item, which is always the fourth one.
    private static func launchItem(_ status: LaunchAtLoginStatus) throws -> ContextMenuItem {
        try #require(items(status).dropFirst(Item.launchAtLogin).first)
    }

    // menu-bar-widget — MBW-10 "Item titles and order": exactly five items, in
    // that order, for every status. Parameterised so no status can quietly add,
    // drop or reorder an item.
    @Test(arguments: LaunchAtLoginStatus.allCases)
    func everyStatusYieldsTheSameFiveItemsInOrder(status: LaunchAtLoginStatus) {
        let items = Self.items(status)

        #expect(items.count == 5)
        #expect(items[Item.about].title == Self.aboutTitle)
        #expect(items[Item.checkForUpdates].title == Self.updatesTitle)
        #expect(items[Item.settings].title == Self.settingsTitle)
        #expect(items[Item.quit].title == Self.quitTitle)
        #expect(
            items.map(\.action)
                == [.openAbout, .checkForUpdates, .openSettings, items[Item.launchAtLogin].action, .quit]
        )
    }

    // menu-bar-widget — MBW-10 "Item titles and order": the exact title list for
    // the default status, which is what the controller renders.
    @Test func theDefaultStatusProducesTheDocumentedTitleList() {
        let titles = Self.items().map(\.title)

        #expect(
            titles == [
                Self.aboutTitle, Self.updatesTitle, Self.settingsTitle, Self.launchTitle, Self.quitTitle,
            ]
        )
    }

    // menu-bar-widget — MBW-10: the surrounding items never carry a checkmark,
    // so a check can only ever mean "the app launches at login".
    @Test(arguments: LaunchAtLoginStatus.allCases)
    func onlyTheLaunchItemCanBeChecked(status: LaunchAtLoginStatus) {
        let items = Self.items(status)

        for index in [Item.about, Item.checkForUpdates, Item.settings, Item.quit] {
            #expect(items[index].isChecked == false)
        }
    }

    // MARK: - Update command enablement (AU-5)

    // app-updates — AU-5 "The command is enabled exactly while a check can run".
    // The whole domain of the input is two values, so the table is complete.
    @Test(arguments: [true, false])
    func theUpdateItemFollowsWhetherACheckCanRun(canCheck: Bool) {
        let item = Self.items(canCheckForUpdates: canCheck)[Item.checkForUpdates]

        #expect(item.title == Self.updatesTitle)
        #expect(item.action == .checkForUpdates)
        #expect(item.isEnabled == canCheck)
    }

    // app-updates — AU-5: every other item stays enabled whatever the updater
    // reports, so a check in flight can never take the rest of the menu with it.
    @Test(arguments: [true, false])
    func onlyTheUpdateItemCanBeDisabled(canCheck: Bool) {
        let items = Self.items(canCheckForUpdates: canCheck)

        for index in [Item.about, Item.settings, Item.launchAtLogin, Item.quit] {
            #expect(items[index].isEnabled, "item \(index) must never be disabled")
        }
    }

    // app-updates — AU-5: the update item's enablement is decided by
    // `UpdateCommandEnablement` and by nothing else — not by whether automatic
    // checking is on, not by the launch-at-login status beside it.
    @Test(arguments: LaunchAtLoginStatus.allCases)
    func theUpdateItemsEnablementIsTheDomainRule(status: LaunchAtLoginStatus) {
        for canCheck in [true, false] {
            let item = ContextMenuModel
                .items(launchAtLogin: status, canCheckForUpdates: canCheck)[Item.checkForUpdates]

            #expect(item.isEnabled == UpdateCommandEnablement.isEnabled(canCheckForUpdates: canCheck))
        }
    }

    // MARK: - Launch at login (LAL-4)

    // launch-at-login — "Enabled shows a checkmark"
    @Test func enabledIsCheckedAndTogglesOff() throws {
        let item = try Self.launchItem(.enabled)

        #expect(item.title == Self.launchTitle)
        #expect(item.isChecked)
        #expect(item.action == .toggleLaunchAtLogin)
    }

    // launch-at-login — "Not registered shows no checkmark". `.notFound` is a
    // stale registration, which LAL-4 and decision 12 treat exactly like
    // "not registered": plain title, unchecked, and the action re-registers.
    @Test(arguments: [LaunchAtLoginStatus.notRegistered, .notFound])
    func anUnregisteredStatusIsUncheckedWithThePlainTitle(status: LaunchAtLoginStatus) throws {
        let item = try Self.launchItem(status)

        #expect(item.title == Self.launchTitle)
        #expect(item.isChecked == false)
        #expect(item.action == .toggleLaunchAtLogin)
    }

    // launch-at-login — "Approval pending routes to Login Items": the item is
    // annotated and its action opens System Settings instead of toggling, so the
    // user is never left with a switch that silently does nothing.
    @Test func approvalPendingIsAnnotatedAndRoutesToLoginItems() throws {
        let item = try Self.launchItem(.requiresApproval)

        #expect(item.title == "Launch at Login (Requires Approval)\u{2026}")
        #expect(item.title != Self.launchTitle)
        #expect(item.title.hasPrefix(Self.launchTitle))
        #expect(item.isChecked == false)
        #expect(item.action == .openLoginItems)
    }

    // launch-at-login — LAL-4: only `.enabled` is checked, and only
    // `.requiresApproval` leaves the toggle action. Asserted across the whole
    // enum so the table cannot collapse into a constant.
    @Test func theCheckAndActionTableCoversEveryStatus() throws {
        var checked: [LaunchAtLoginStatus] = []
        var routed: [LaunchAtLoginStatus] = []

        for status in LaunchAtLoginStatus.allCases {
            let item = try Self.launchItem(status)
            if item.isChecked { checked.append(status) }
            if item.action == .openLoginItems { routed.append(status) }
        }

        #expect(checked == [.enabled])
        #expect(routed == [.requiresApproval])
    }

    // menu-bar-widget — MBW-10: the items are plain values, so two builds from
    // the same inputs are interchangeable and the controller can rebuild the
    // menu on every open without churn.
    @Test func twoBuildsFromTheSameInputsAreEqual() {
        #expect(Self.items(.enabled) == Self.items(.enabled))
        #expect(Self.items(.enabled) != Self.items(.notRegistered))
        #expect(Self.items(canCheckForUpdates: true) != Self.items(canCheckForUpdates: false))
    }
}
