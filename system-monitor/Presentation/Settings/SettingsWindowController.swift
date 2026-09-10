import AppKit
import SwiftUI

/// Owner of the single "Settings" window (ST-5).
///
/// Both entry points — the status-item context menu and Cmd+, — call `show()`
/// on the one controller the composition root builds, which is what makes a
/// second settings window impossible. The window is created lazily on the first
/// `show()` and kept afterwards (`isReleasedWhenClosed = false`), so closing it
/// hides it and the next `show()` brings back the same window with the form's
/// scroll position and the user's edits intact.
///
/// Sizing: the window's content size is set explicitly in `makeWindow()`
/// rather than inherited from the hosting controller's defaults — see that
/// method for why a grouped `Form` otherwise opens as a bare title bar.
///
/// Activation: every `show()` calls `NSApp.activate()` before ordering the
/// window front, because an `LSUIElement` app is not active when the user picks
/// "Settings…" from the menu bar. The design's S3 fallback — toggling the
/// activation policy to `.regular` around the window's lifetime — is
/// deliberately not implemented: it is only warranted if the manual checklist
/// finds that the window does not become key on first show.
@MainActor
final class SettingsWindowController {

    private let settings: SettingsState

    /// The updater the hosted form shows, or `nil` when the host has none
    /// (AU-6). Typed as the port and never as the concrete checker, and optional
    /// so a window built without one renders the same form with the Updates
    /// section absent rather than inert.
    private let updater: (any AppUpdating)?

    /// The one window, or `nil` until the first `show()`.
    private var window: NSWindow?

    init(settings: SettingsState, updater: (any AppUpdating)? = nil) {
        self.settings = settings
        self.updater = updater
    }

    /// Creates the window on first use, then brings the app forward and the
    /// window to the front. Later calls reuse the same window.
    func show() {
        let window = self.window ?? makeWindow()
        self.window = window

        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    /// Hides the window. The window and this controller both survive, so the
    /// next `show()` is a reuse rather than a rebuild.
    func close() {
        window?.orderOut(nil)
    }

    /// The settings object the hosted form edits. Test-visible so the
    /// composition-root suite can prove the window and the widget share one
    /// `SettingsState` (ST-5): two objects loaded from the same store look
    /// identical until the user changes something.
    var boundSettings: SettingsState {
        settings
    }

    /// The updater the hosted form shows. Test-visible for the same reason as
    /// `boundSettings`: the composition root must hand the *same* updater to
    /// this window and to the context menu, and two instances behave identically
    /// until one of them checks (AU-7).
    var boundUpdater: (any AppUpdating)? {
        updater
    }

    /// Height the hosted form measures for itself, or `nil` before the first
    /// `show()`.
    ///
    /// Test-visible because "the Updates section is rendered" has no other
    /// observable at this level: the section is inside a SwiftUI tree the window
    /// only ever sees as a size (AU-6).
    var hostedFormFittingHeight: CGFloat? {
        window?.contentViewController?.view.fittingSize.height
    }

    /// Whether the window is on screen. `false` before the first `show()`.
    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    /// The window's title, or `nil` before the first `show()`.
    var windowTitle: String? {
        window?.title
    }

    /// Identity of the owned window: equal across repeated `show()` calls and
    /// across a close/show cycle, which is how ST-5 reuse is observed.
    var windowNumber: Int? {
        window?.windowNumber
    }

    /// The size of the window's content area, or `nil` before the first
    /// `show()`. Test-visible because ST-5's "first show" is only satisfied if
    /// the form is actually on screen: a window whose content resolved to zero
    /// height still reports `isVisible` and the right title.
    var windowContentSize: CGSize? {
        window?.contentView?.frame.size
    }

    /// The window's style mask, or `nil` before the first `show()`.
    var windowStyleMask: NSWindow.StyleMask? {
        window?.styleMask
    }

    /// The SwiftUI root view type the window hosts, or `nil` when the window
    /// does not host the settings form.
    var hostedRootViewType: Any.Type? {
        guard let hosting = window?.contentViewController as? NSHostingController<SettingsRootView> else {
            return nil
        }
        return type(of: hosting.rootView)
    }

    /// Creates the window and sizes its content explicitly from the hosted
    /// form.
    ///
    /// The explicit sizing is required, not defensive. `NSHostingController`'s
    /// default `sizingOptions` is `.standardBounds`, which publishes the
    /// SwiftUI content's minimum, intrinsic and maximum sizes on the hosted
    /// *view* but never sets the controller's `preferredContentSize` — so a
    /// window built with `contentRect: .zero` keeps a zero-sized content area.
    /// `SettingsView` is a grouped `Form`, a scrolling container that accepts
    /// any proposed height instead of pushing back, so the window opened as a
    /// bare title bar with nothing under it. Measuring the hosted view and
    /// applying `SettingsView.formHeight` as the floor is what puts the whole
    /// form on screen on the first `show()`.
    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false

        let hosting = NSHostingController(
            rootView: SettingsRootView(settings: settings, updater: updater)
        )
        window.contentViewController = hosting
        hosting.view.layoutSubtreeIfNeeded()
        window.setContentSize(
            CGSize(
                width: SettingsView.formWidth,
                height: max(hosting.view.fittingSize.height, SettingsView.formHeight)
            )
        )

        window.center()
        return window
    }
}
