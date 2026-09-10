import Foundation

/// One action item of the status item context menu (MBW-10).
///
/// A plain value rather than an `NSMenuItem`: titles, check state, enablement
/// and the action each item carries are the menu's behaviour, so they are unit
/// tested without AppKit, without `SMAppService` and without an updater. The
/// controller maps these onto `NSMenuItem`s and owns the AppKit side alone.
nonisolated struct ContextMenuItem: Sendable, Equatable {

    /// What the controller must do when the item is chosen.
    ///
    /// Nested types need explicit `nonisolated` because the module defaults to
    /// main-actor isolation.
    nonisolated enum Action: Sendable, Equatable {
        case openAbout
        case checkForUpdates
        case openSettings
        case toggleLaunchAtLogin
        case openLoginItems
        case quit
    }

    let title: String

    /// Whether the item renders a checkmark. Only the launch-at-login item is
    /// ever checked, and only while the app really is registered.
    let isChecked: Bool

    /// Whether the item can be chosen. Only the update item is ever disabled,
    /// and only while a check genuinely cannot run (AU-5).
    let isEnabled: Bool

    let action: Action

    /// Written out rather than left to the memberwise initialiser so `isEnabled`
    /// can stay a `let` and still default: a `let` with an inline value drops
    /// out of the memberwise initialiser entirely, and a `var` would let a
    /// caller mutate an item the model already decided.
    init(title: String, isChecked: Bool, isEnabled: Bool = true, action: Action) {
        self.title = title
        self.isChecked = isChecked
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Pure content of the status item context menu (MBW-10, LAL-4, AU-5).
nonisolated enum ContextMenuModel {

    private static let aboutTitle = "About System Monitor"
    private static let checkForUpdatesTitle = "Check for Updates\u{2026}"
    private static let settingsTitle = "Settings\u{2026}"
    private static let launchAtLoginTitle = "Launch at Login"
    private static let approvalPendingTitle = "Launch at Login (Requires Approval)\u{2026}"
    private static let quitTitle = "Quit System Monitor"

    /// Always five items, in this order: "About System Monitor", "Check for
    /// Updates…", "Settings…", the launch-at-login item, "Quit System Monitor".
    /// About comes first, as it does in every macOS application menu (MBW-15),
    /// and the update command sits directly behind it, where the standard
    /// application menu puts it.
    ///
    /// The launch-at-login item follows the live status (LAL-4), which the
    /// caller reads when the menu is built rather than caching it, because the
    /// user can change the registration in System Settings at any time:
    ///
    /// - `.enabled` — "Launch at Login", checked; the action toggles, so it
    ///   unregisters.
    /// - `.notRegistered` — "Launch at Login", unchecked; the action registers.
    /// - `.notFound` — the same plain, unchecked item: a stale registration
    ///   (typically a moved development build) is recovered by registering the
    ///   current bundle path again, so it needs no separate wording.
    /// - `.requiresApproval` — annotated title, unchecked, and the action opens
    ///   Login Items instead of toggling, because only the user can grant the
    ///   approval. The ellipsis follows the HIG for an action that opens
    ///   another window.
    ///
    /// `canCheckForUpdates` is read the same way, live per build, and decides
    /// **only** the update item's enablement, through the Domain rule that owns
    /// that decision. An explicit user action is its own consent, so the item is
    /// never dimmed because automatic checking is off (AU-5).
    static func items(
        launchAtLogin status: LaunchAtLoginStatus,
        canCheckForUpdates: Bool
    ) -> [ContextMenuItem] {
        [
            ContextMenuItem(title: aboutTitle, isChecked: false, action: .openAbout),
            ContextMenuItem(
                title: checkForUpdatesTitle,
                isChecked: false,
                isEnabled: UpdateCommandEnablement.isEnabled(canCheckForUpdates: canCheckForUpdates),
                action: .checkForUpdates
            ),
            ContextMenuItem(title: settingsTitle, isChecked: false, action: .openSettings),
            launchAtLoginItem(for: status),
            ContextMenuItem(title: quitTitle, isChecked: false, action: .quit),
        ]
    }

    private static func launchAtLoginItem(for status: LaunchAtLoginStatus) -> ContextMenuItem {
        guard !status.needsApproval else {
            return ContextMenuItem(
                title: approvalPendingTitle,
                isChecked: false,
                action: .openLoginItems
            )
        }

        return ContextMenuItem(
            title: launchAtLoginTitle,
            isChecked: status.isEnabled,
            action: .toggleLaunchAtLogin
        )
    }
}
