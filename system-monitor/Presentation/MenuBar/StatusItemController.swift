import AppKit
import SwiftUI

/// Owns the `NSStatusItem`, the popover with the detail panel and the context menu.
///
/// The widget updates once per second, so its geometry is fixed up front: the
/// hosting view never resizes itself from its content and the status item length
/// is measured once from the widest content the widget can render
/// (menu-bar-widget "Fixed-width, jitter-free layout").
final class StatusItemController {

    private let state: MetricsState
    private let statusItem: NSStatusItem
    private let hostingView: PassthroughHostingView<StatusItemRootView>
    private let popover = NSPopover()

    init(state: MetricsState) {
        self.state = state
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hostingView = PassthroughHostingView(rootView: StatusItemRootView(state: state))

        // 1 Hz content updates must not rewrite Auto Layout constraints (PRD 6.5).
        hostingView.sizingOptions = []

        configureButton()
        configurePopover()
    }

    // MARK: - Setup

    private func configureButton() {
        guard let button = statusItem.button else { return }

        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        // Sized once from the widest sample. Every sub-width is constant — the
        // label, the 60 pt sparkline and the value frame — so a live reading can
        // never need more room than this.
        statusItem.length = Self.measuredContentWidth()

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PanelView().environment(state)
        )
    }

    // MARK: - Measurement

    /// Width of the widget rendering its widest content.
    ///
    /// Measured on a throwaway hosting view with the default sizing options:
    /// `hostingView` reports no fitting size because its own options are empty.
    private static func measuredContentWidth() -> CGFloat {
        let measurementView = NSHostingView(
            rootView: StatusItemContent(readings: StatusItemMetrics.measurementReadings)
        )
        measurementView.layoutSubtreeIfNeeded()
        return measurementView.fittingSize.width
    }

    // MARK: - Layout contract (test-visible)

    /// Current status item width. Constant across published readings.
    var statusItemLength: CGFloat {
        statusItem.length
    }

    /// Sizing options of the live hosting view. Empty by contract.
    var hostingSizingOptions: NSHostingSizingOptions {
        hostingView.sizingOptions
    }

    /// Width of the widget at full scale, measured independently of the live
    /// hosting view.
    var contentFittingWidth: CGFloat {
        Self.measuredContentWidth()
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit System Monitor",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        menu.addItem(quitItem)

        // Standard pattern: attach the menu, trigger the button, then detach so
        // a subsequent left click reaches `handleClick` instead of opening the menu.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }
}

/// Hosting view that is transparent to mouse events so clicks reach the status bar button.
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
