import AppKit
import SwiftUI
import Testing
@testable import system_monitor

// menu-bar-widget — MBW-15 "About window".
//
// Same shape as `SettingsWindowControllerTests`: every case drives a real
// `NSWindow` in the test host because reuse, visibility and appearance are
// AppKit behaviour. No case asserts key status, and every case closes its
// window in a `defer` so none survives the suite (convention 14).
@Suite("About window controller", .timeLimit(.minutes(1)))
struct AboutWindowControllerTests {

    private static let info = AboutModel.info(bundleInfo: [
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "1",
    ])

    @MainActor
    private static func withAboutWindow(
        _ body: @MainActor (AboutWindowController) -> Void
    ) {
        let controller = AboutWindowController(info: info)
        defer { controller.close() }
        body(controller)
    }

    // MBW-15: lazy, so an app that never opens About never pays for a window.
    @Test func noWindowExistsBeforeTheFirstShow() async {
        await Self.withAboutWindow { controller in
            #expect(controller.isWindowVisible == false)
            #expect(controller.windowTitle == nil)
            #expect(controller.windowNumber == nil)
        }
    }

    // MBW-15 "About item opens the window"
    @Test func theFirstShowCreatesAVisibleWindowTitledAboutSystemMonitor() async {
        await Self.withAboutWindow { controller in
            controller.show()

            #expect(controller.isWindowVisible)
            #expect(controller.windowTitle == "About System Monitor")
        }
    }

    // MBW-15 "One About window": a second show and a show after a close both
    // find the same window instead of building another.
    @Test func showingAgainAndAfterAClosReusesTheSameWindow() async {
        await Self.withAboutWindow { controller in
            controller.show()
            let created = controller.windowNumber

            controller.show()
            let afterSecondShow = controller.windowNumber

            controller.close()
            let visibleAfterClose = controller.isWindowVisible

            controller.show()

            #expect(created != nil)
            #expect(afterSecondShow == created)
            #expect(visibleAfterClose == false)
            #expect(controller.isWindowVisible)
            #expect(controller.windowNumber == created)
        }
    }

    // MBW-15 "Hosts the About view": the window's content is the SwiftUI About
    // view, sized to it, closable but not resizable.
    @Test func theWindowHostsTheAboutViewAtItsFittingSize() async {
        await Self.withAboutWindow { controller in
            controller.show()

            let size = controller.windowContentSize ?? .zero
            let mask = controller.windowStyleMask ?? []

            #expect(controller.hostedRootViewType == AboutRootView.self)
            #expect(size.width == AboutView.width)
            #expect(size.height > 300, "the About content collapsed to \(size.height) pt")
            #expect(mask.contains(.closable))
            #expect(mask.contains(.resizable) == false)
        }
    }

    // MBW-15 "Dark like the panel": the window is pinned to `darkAqua`, as the
    // popover is (MBW-11), because the About view paints the panel palette.
    @Test func theWindowIsPinnedToTheDarkAppearance() async {
        await Self.withAboutWindow { controller in
            controller.show()

            #expect(controller.windowAppearanceName == .darkAqua)
        }
    }
}
