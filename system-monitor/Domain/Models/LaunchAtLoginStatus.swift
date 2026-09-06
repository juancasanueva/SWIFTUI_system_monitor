import Foundation

/// Registration state of the app as a login item (LAL-1).
///
/// It mirrors `SMAppService.Status` so the Domain never imports
/// ServiceManagement; the mapping lives in the Infrastructure adapter. The
/// value is always read live from the system and is never persisted by the app.
nonisolated enum LaunchAtLoginStatus: Sendable, Equatable, CaseIterable {
    /// The app is not registered as a login item.
    case notRegistered

    /// The app is registered and will launch at login.
    case enabled

    /// Registration succeeded but the user must approve it in System Settings.
    case requiresApproval

    /// A registration exists but its bundle can no longer be found, typically
    /// after the app moved on disk.
    case notFound

    /// `true` only for `.enabled`; drives the menu item checkmark (LAL-4).
    var isEnabled: Bool { self == .enabled }

    /// `true` only for `.requiresApproval`; routes the menu action to the
    /// Login Items pane instead of toggling (LAL-4).
    var needsApproval: Bool { self == .requiresApproval }
}
