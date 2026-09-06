import AppKit
import SwiftUI
import Testing
@testable import system_monitor

// settings — ST-5 "Single reusable settings window".
//
// Every case drives a real `NSWindow` inside the test host: window reuse,
// visibility and lifetime are AppKit behaviour, so a stub would prove nothing.
// No case asserts key status — the test host is not guaranteed to be frontmost
// — and `withSettingsWindow` closes the window in a `defer` for every case, so
// no visible window survives the suite (convention 14).
@Suite("Settings window controller", .timeLimit(.minutes(1)))
struct SettingsWindowControllerTests {

    @MainActor
    private static func withSettingsWindow(
        _ body: @MainActor (SettingsWindowController) -> Void
    ) {
        let controller = SettingsWindowController(settings: SettingsState(store: FakeSettingsStore()))
        defer { controller.close() }
        body(controller)
    }

    // settings — ST-5: the window is lazy, so an app that never opens settings
    // never pays for one.
    @Test func noWindowExistsBeforeTheFirstShow() async {
        await Self.withSettingsWindow { controller in
            #expect(controller.isWindowVisible == false)
            #expect(controller.windowTitle == nil)
            #expect(controller.windowNumber == nil)
        }
    }

    // settings — ST-5 "First show creates the window"
    @Test func theFirstShowCreatesAVisibleWindowTitledSettings() async {
        await Self.withSettingsWindow { controller in
            controller.show()

            #expect(controller.isWindowVisible)
            #expect(controller.windowTitle == "Settings")
        }
    }

    // settings — ST-5 "Second show reuses the window"
    @Test func aSecondShowReusesTheSameWindow() async {
        await Self.withSettingsWindow { controller in
            controller.show()
            let firstNumber = controller.windowNumber
            controller.show()
            let secondNumber = controller.windowNumber

            #expect(firstNumber != nil)
            #expect(secondNumber == firstNumber)
            #expect(controller.isWindowVisible)
        }
    }

    // settings — ST-5 "Both entry points share the window": both entry points
    // call `show()` on this one controller, so a show after a close must find
    // the same window rather than build a second one.
    @Test func closingHidesTheWindowAndTheNextShowReusesIt() async {
        await Self.withSettingsWindow { controller in
            controller.show()
            let created = controller.windowNumber

            controller.close()
            let visibleAfterClose = controller.isWindowVisible

            controller.show()

            #expect(created != nil)
            #expect(visibleAfterClose == false)
            #expect(controller.isWindowVisible)
            #expect(controller.windowNumber == created)
        }
    }

    // settings — ST-5 "hosting `SettingsView` bound to `SettingsState`"
    @Test func theWindowHostsTheSettingsForm() async {
        await Self.withSettingsWindow { controller in
            controller.show()

            #expect(controller.hostedRootViewType == SettingsRootView.self)
        }
    }

    // settings — ST-5 "Closing the window MUST hide it": the user closes it
    // from the title bar, so the window needs one with a close button.
    @Test func theWindowIsTitledClosableAndMiniaturizable() async {
        await Self.withSettingsWindow { controller in
            controller.show()
            let mask = controller.windowStyleMask

            #expect(mask?.contains(.titled) == true)
            #expect(mask?.contains(.closable) == true)
            #expect(mask?.contains(.miniaturizable) == true)
        }
    }

    // settings — ST-5 "the controller owns exactly one window": uniqueness is
    // per controller, which is why the composition root builds exactly one.
    // Two controllers are two windows, and neither reuses the other's.
    @Test func eachControllerOwnsItsOwnWindow() async {
        await Self.withSettingsWindow { first in
            Self.withSettingsWindow { second in
                first.show()
                second.show()

                #expect(first.windowNumber != nil)
                #expect(second.windowNumber != nil)
                #expect(first.windowNumber != second.windowNumber)
            }
        }
    }

    // settings — ST-5 "First show presents the whole form": a grouped `Form` is
    // a scrolling container with no intrinsic height, so a window that trusts
    // the hosting controller's default sizing opens as a bare title bar. The
    // window must present the form at the width the design fixes and at least
    // the height both sections and the stepper need.
    @Test func theFirstShowPresentsTheWholeForm() async {
        await Self.withSettingsWindow { controller in
            controller.show()
            let size = controller.windowContentSize

            #expect(size?.width == SettingsView.formWidth)
            #expect(
                (size?.height ?? 0) >= SettingsView.formHeight,
                "window content size was \(String(describing: size))"
            )
        }
    }

    // settings — ST-5: the floor is a floor, not the whole answer. A window
    // sized by a constant smaller than the form would still cut the bottom
    // section off, so the content must also clear the height the hosted form
    // measures for itself.
    @Test func theWindowIsNeverShorterThanTheFormItHosts() async {
        await Self.withSettingsWindow { controller in
            controller.show()

            let hostingView = NSHostingView(rootView: SettingsRootView(settings: controller.boundSettings))
            hostingView.layoutSubtreeIfNeeded()
            let naturalHeight = hostingView.fittingSize.height

            #expect(naturalHeight > 0, "the form measured as empty")
            #expect((controller.windowContentSize?.height ?? 0) >= naturalHeight)
        }
    }
}
