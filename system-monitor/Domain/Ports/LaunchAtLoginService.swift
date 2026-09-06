import Foundation

/// Port that registers the app as a login item (LAL-2).
///
/// `status` is a live read: implementations ask the system on every access and
/// never cache or persist the answer, so the menu always shows what System
/// Settings shows. `enable()` and `disable()` throw because registration is a
/// system operation that can legitimately fail; a failure leaves the status
/// untouched and the next read reports reality.
nonisolated protocol LaunchAtLoginService: Sendable {
    var status: LaunchAtLoginStatus { get }
    func enable() throws
    func disable() throws
    func openLoginItemsSettings()
}
