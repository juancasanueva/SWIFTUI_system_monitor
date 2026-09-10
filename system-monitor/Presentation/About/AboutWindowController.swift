import AppKit
import SwiftUI

/// Owner of the single "About System Monitor" window (MBW-15).
///
/// Same lifecycle as `SettingsWindowController`: the window is created lazily
/// on the first `show()` and kept afterwards (`isReleasedWhenClosed = false`),
/// so closing it hides it and the next `show()` brings the same window back.
/// The composition root builds exactly one, which is what makes a second About
/// window impossible.
///
/// Activation: every `show()` calls `NSApp.activate()` first, because an
/// `LSUIElement` app is not active when the user picks the item from the menu
/// bar, and an inactive app cannot bring a window to the front.
///
/// Appearance: pinned to `darkAqua` like the popover (MBW-11), because
/// `AboutView` paints `Palette.panelBackground` unconditionally and the window
/// chrome must match it under any system appearance.
@MainActor
final class AboutWindowController {

    private let info: AboutInfo

    /// The one window, or `nil` until the first `show()`.
    private var window: NSWindow?

    init(info: AboutInfo) {
        self.info = info
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

    // MARK: - Test-visible window readings

    /// Whether the window is on screen. `false` before the first `show()`.
    var isWindowVisible: Bool {
        window?.isVisible ?? false
    }

    /// The window's title, or `nil` before the first `show()`.
    var windowTitle: String? {
        window?.title
    }

    /// Identity of the owned window: equal across repeated `show()` calls and
    /// across a close/show cycle, which is how reuse is observed.
    var windowNumber: Int? {
        window?.windowNumber
    }

    /// The size of the window's content area, or `nil` before the first
    /// `show()`.
    var windowContentSize: CGSize? {
        window?.contentView?.frame.size
    }

    /// The window's style mask, or `nil` before the first `show()`.
    var windowStyleMask: NSWindow.StyleMask? {
        window?.styleMask
    }

    /// Appearance pinned on the window, or `nil` before the first `show()` or
    /// when it follows the system.
    var windowAppearanceName: NSAppearance.Name? {
        window?.appearance?.name
    }

    /// The SwiftUI root view type the window hosts, or `nil` when the window
    /// does not host the About view.
    var hostedRootViewType: Any.Type? {
        guard let hosting = window?.contentViewController as? NSHostingController<AboutRootView> else {
            return nil
        }
        return type(of: hosting.rootView)
    }

    /// Creates the window and sizes its content from the hosted view.
    ///
    /// The explicit sizing follows `SettingsWindowController.makeWindow()`:
    /// a hosting controller never sets `preferredContentSize` on its own, so a
    /// window built with `contentRect: .zero` would keep a zero-sized content
    /// area. `AboutView` is a fixed-width stack, so its fitting size is the
    /// whole content and the window is not resizable.
    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About \(info.appName)"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(Palette.panelBackground)

        let hosting = NSHostingController(rootView: AboutRootView(info: info))
        window.contentViewController = hosting
        hosting.view.layoutSubtreeIfNeeded()
        window.setContentSize(
            CGSize(width: AboutView.width, height: hosting.view.fittingSize.height)
        )

        window.center()
        return window
    }
}
