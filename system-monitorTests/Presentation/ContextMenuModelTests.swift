import Foundation
import Testing
@testable import system_monitor

// menu-bar-widget — MBW-10 "Context menu"; launch-at-login — LAL-4 "Launch at
// Login menu item".
//
// The menu content is a pure table: titles, check state and the action each
// item carries are derived from the launch-at-login status alone, so the whole
// LAL-4 matrix runs without an `NSMenu`, an `NSStatusItem` or `SMAppService`.
// The controller's job (batch F) is only to turn these values into
// `NSMenuItem`s and to call the service.
@Suite("Context menu model", .timeLimit(.minutes(1)))
struct ContextMenuModelTests {

    private static let settingsTitle = "Settings\u{2026}"
    private static let launchTitle = "Launch at Login"
    private static let quitTitle = "Quit System Monitor"

    /// The launch-at-login item, which is always the middle one.
    private static func launchItem(_ status: LaunchAtLoginStatus) throws -> ContextMenuItem {
        let items = ContextMenuModel.items(launchAtLogin: status)
        return try #require(items.dropFirst().first)
    }

    // menu-bar-widget — "Item titles and order": exactly three items, in that
    // order, for every status. Parameterised so no status can quietly add,
    // drop or reorder an item.
    @Test(arguments: LaunchAtLoginStatus.allCases)
    func everyStatusYieldsTheSameThreeItemsInOrder(status: LaunchAtLoginStatus) {
        let items = ContextMenuModel.items(launchAtLogin: status)

        #expect(items.count == 3)
        #expect(items.first?.title == Self.settingsTitle)
        #expect(items.last?.title == Self.quitTitle)
        #expect(items.map(\.action).first == .openSettings)
        #expect(items.map(\.action).last == .quit)
    }

    // menu-bar-widget — "Item titles and order": the exact title list for the
    // default status, which is what the controller renders.
    @Test func theDefaultStatusProducesTheDocumentedTitleList() {
        let titles = ContextMenuModel.items(launchAtLogin: .notRegistered).map(\.title)

        #expect(titles == [Self.settingsTitle, Self.launchTitle, Self.quitTitle])
    }

    // menu-bar-widget — MBW-10: the surrounding items never carry a checkmark,
    // so a check can only ever mean "the app launches at login".
    @Test(arguments: LaunchAtLoginStatus.allCases)
    func onlyTheLaunchItemCanBeChecked(status: LaunchAtLoginStatus) {
        let items = ContextMenuModel.items(launchAtLogin: status)

        #expect(items.first?.isChecked == false)
        #expect(items.last?.isChecked == false)
    }

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
    // annotated and its action opens System Settings instead of toggling, so
    // the user is never left with a switch that silently does nothing.
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
    // the same status are interchangeable and the controller can rebuild the
    // menu on every open without churn.
    @Test func twoBuildsFromTheSameStatusAreEqual() {
        #expect(
            ContextMenuModel.items(launchAtLogin: .enabled)
                == ContextMenuModel.items(launchAtLogin: .enabled)
        )
        #expect(
            ContextMenuModel.items(launchAtLogin: .enabled)
                != ContextMenuModel.items(launchAtLogin: .notRegistered)
        )
    }
}
