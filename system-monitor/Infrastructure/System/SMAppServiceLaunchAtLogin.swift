import Foundation
import ServiceManagement

/// `LaunchAtLoginService` over `SMAppService.mainApp` (LAL-3).
///
/// Stateless by design: `SMAppService.mainApp` is resolved inside every call
/// and the resulting status is never cached or persisted, so the menu always
/// shows what System Settings shows — including a registration the user
/// revoked while the app was running. The translation from the system enum is
/// the pure `map(_:)` below, which is where the unit tests live; the calls that
/// mutate the user's login items are never exercised by tests (convention 11).
nonisolated struct SMAppServiceLaunchAtLogin: LaunchAtLoginService {

    init() {}

    /// Read live from the system on every access; nothing is stored.
    var status: LaunchAtLoginStatus { Self.map(SMAppService.mainApp.status) }

    /// Registers the app as a login item. Throws when the system refuses.
    func enable() throws {
        try SMAppService.mainApp.register()
    }

    /// Removes the registration. Throws when the system refuses.
    func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    /// Opens the Login Items pane, used when registration is pending approval
    /// and only the user can complete it.
    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Translates the system status into the Domain case of the same name.
    ///
    /// `SMAppServiceStatus` is an `NS_ENUM`, so a later SDK may add a case that
    /// this build has never seen. An unrecognised status degrades to
    /// `.notRegistered`: the menu then offers to enable the login item, which
    /// is recoverable, instead of claiming an enabled state it cannot verify.
    static func map(_ status: SMAppService.Status) -> LaunchAtLoginStatus {
        switch status {
        case .notRegistered: .notRegistered
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notFound: .notFound
        @unknown default: .notRegistered
        }
    }
}
