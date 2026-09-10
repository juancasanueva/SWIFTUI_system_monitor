import AppKit
import SwiftUI
import Testing
@testable import system_monitor

/// Builds a controller, records weak references to it and to its status item,
/// then drops its only strong reference (MBW-12).
///
/// A holder object rather than two `weak var` locals: the test body is not
/// `@MainActor` (convention 2), and a main-actor class is the only place a weak
/// reference to a main-actor object can be written and read on the same actor.
@MainActor
private final class StatusItemReleaseProbe {

    private(set) weak var controller: StatusItemController?
    private(set) weak var statusItem: NSStatusItem?

    /// Returns whether both references were live immediately after
    /// construction, so a probe that never saw a controller fails its case
    /// instead of reporting a vacuous release.
    @discardableResult
    func buildAndRelease() -> Bool {
        let controller = StatusItemController(
            state: MetricsState(),
            settings: SettingsState(store: FakeSettingsStore()),
            launchAtLogin: FakeLaunchAtLoginService()
        )
        self.controller = controller
        self.statusItem = controller.installedStatusItem

        return self.controller != nil && self.statusItem != nil
    }

    var isFullyReleased: Bool {
        controller == nil && statusItem == nil
    }
}

// menu-bar-widget — "Fixed-width, jitter-free layout" (MBW-9), the dark popover
// appearance (MBW-11), status item release (MBW-12) and the panel transitions
// that drive the sampling cadence (MBW-13).
//
// Every case builds a real `NSStatusItem` inside the test host: the layout
// contract is about AppKit sizing, so a stub would not prove anything. Every
// controller is released before its case ends, which is what removes the item
// (convention 14).
@Suite("Status item controller layout", .timeLimit(.minutes(1)))
struct StatusItemControllerTests {

    /// Budget for the whole widget, in points (menu-bar-widget R1.7).
    private static let widthBudget: CGFloat = 230

    /// Budget for a single module (MBW-9 "One-module width").
    private static let oneModuleBudget: CGFloat = 130

    /// Builds a controller over fakes, runs `body`, then drops it.
    ///
    /// Generic in the result so a case carries plain `Sendable` readings back
    /// out instead of leaking a main-actor object into the non-isolated test
    /// body.
    @MainActor
    private static func withController<T>(
        state: MetricsState = MetricsState(),
        settings: SettingsState = SettingsState(store: FakeSettingsStore()),
        panelObserver: (any PanelVisibilityObserver)? = nil,
        _ body: @MainActor (StatusItemController) -> T
    ) -> T {
        let controller = StatusItemController(
            state: state,
            settings: settings,
            launchAtLogin: FakeLaunchAtLoginService(),
            panelObserver: panelObserver
        )
        return body(controller)
    }

    private static func snapshot(total: Double) -> CPUSnapshot {
        CPUSnapshot(
            total: total,
            user: total * 0.75,
            system: total * 0.25,
            performanceAverage: nil,
            efficiencyAverage: nil,
            cores: []
        )
    }

    /// A state carrying all four readings, so the panel the controller
    /// measures is the full 1 049 pt four-card panel rather than a skeleton
    /// that might happen to fit any frame (NC-12).
    @MainActor
    private static func fourCardState() -> MetricsState {
        let state = MetricsState()
        state.apply(
            cpu: CPUSnapshot(
                total: 0.42,
                user: 0.315,
                system: 0.105,
                performanceAverage: 0.7,
                efficiencyAverage: 0.1,
                cores: (0..<8).map { CoreUsage(index: $0, usage: 0.7, level: .performance) }
                    + (8..<12).map { CoreUsage(index: $0, usage: 0.1, level: .efficiency) }
            )
        )
        state.apply(memory: MemoryFixtures.snapshot(from: MemoryFixtures.eightGiB))
        state.apply(disk: DiskFixtures.referenceSnapshot)
        state.apply(network: NetworkFixtures.referenceSnapshot)
        return state
    }

    /// Whether the recorder ever reported two opens in a row, which is the
    /// failure MBW-13 "No duplicate transitions" rules out.
    private static func hasConsecutiveOpens(_ events: [Bool]) -> Bool {
        zip(events, events.dropFirst()).contains { $0 && $1 }
    }

    /// The PRD section 7.1 colour for a hex literal, in the sRGB space.
    private static func sRGB(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    // MARK: - Layout (MBW-9)

    // menu-bar-widget — "Length stable across updates"
    @Test func theStatusItemLengthDoesNotChangeWhenTheValueChanges() async {
        let state = await MetricsState()

        let lengths = await Self.withController(state: state) { controller in
            var lengths = [controller.statusItemLength]
            state.apply(cpu: Self.snapshot(total: 0.05))
            lengths.append(controller.statusItemLength)
            state.apply(cpu: Self.snapshot(total: 1.0))
            lengths.append(controller.statusItemLength)
            return lengths
        }

        #expect(lengths[0] > 0)
        #expect(lengths.allSatisfy { $0 == lengths[0] })
    }

    // menu-bar-widget — "Sizing options disabled"
    @Test func theHostingViewDoesNotResizeItselfFromItsContent() async {
        let options = await Self.withController { $0.hostingSizingOptions }

        #expect(options == [])
    }

    // menu-bar-widget — "Width budget"
    @Test func theWidgetStaysUnderTheWidthBudgetAtFullScale() async {
        let width = await Self.withController {
            $0.contentFittingWidth(for: MetricModule.menuBarOrder)
        }

        #expect(width > 0, "the widget measured as empty")
        #expect(width < Self.widthBudget)
    }

    // menu-bar-widget — "Fixed-width, jitter-free layout": the item is sized on
    // init from the module set it actually renders.
    @Test func theStatusItemIsSizedFromTheCurrentModuleSet() async {
        let measured = await Self.withController { controller in
            (
                length: controller.statusItemLength,
                width: controller.contentFittingWidth(for: MetricModule.menuBarOrder)
            )
        }

        #expect(measured.length == measured.width)
    }

    // menu-bar-widget — MBW-9 "Length changes only when the module set changes",
    // shrink half: hiding MEM re-measures the item down to the one-module width.
    @Test func hidingAModuleReMeasuresTheItemToTheOneModuleWidth() async {
        let settings = await SettingsState(store: FakeSettingsStore())

        let measured = await Self.withController(settings: settings) { controller in
            let before = controller.statusItemLength
            settings.setModule(.memory, visible: false)
            return (
                before: before,
                after: controller.statusItemLength,
                oneModuleWidth: controller.contentFittingWidth(for: [.cpu])
            )
        }

        #expect(measured.after == measured.oneModuleWidth)
        #expect(measured.after < measured.before, "hiding a module did not shrink the item")
        #expect(measured.after < Self.oneModuleBudget)
    }

    // menu-bar-widget — MBW-9 "Length changes only when the module set changes":
    // once re-measured, neither further readings nor an interval change touch
    // the length. A re-measure per value tick is exactly the jitter MBW-9 bans.
    @Test func neitherNewReadingsNorAnIntervalChangeReMeasureTheItem() async {
        let state = await MetricsState()
        let settings = await SettingsState(store: FakeSettingsStore())

        let lengths = await Self.withController(state: state, settings: settings) { controller in
            let initial = controller.statusItemLength
            settings.setModule(.memory, visible: false)

            var afterModuleChange = [controller.statusItemLength]
            state.apply(cpu: Self.snapshot(total: 0.42))
            afterModuleChange.append(controller.statusItemLength)
            state.apply(cpu: Self.snapshot(total: 1.0))
            afterModuleChange.append(controller.statusItemLength)
            settings.setInterval(.seconds(3))
            afterModuleChange.append(controller.statusItemLength)

            return (initial: initial, afterModuleChange: afterModuleChange)
        }

        #expect(lengths.afterModuleChange[0] < lengths.initial, "the module change was ignored")
        #expect(lengths.afterModuleChange.allSatisfy { $0 == lengths.afterModuleChange[0] })
    }

    // menu-bar-widget — MBW-9 "Length changes only when the module set changes",
    // restore half: showing the module again brings the two-module width back.
    @Test func showingAModuleAgainRestoresTheTwoModuleWidth() async {
        let settings = await SettingsState(store: FakeSettingsStore())

        let measured = await Self.withController(settings: settings) { controller in
            let initial = controller.statusItemLength
            settings.setModule(.memory, visible: false)
            let hidden = controller.statusItemLength
            settings.setModule(.memory, visible: true)
            return (initial: initial, hidden: hidden, restored: controller.statusItemLength)
        }

        #expect(measured.restored == measured.initial)
        #expect(measured.restored > measured.hidden)
        #expect(measured.restored < Self.widthBudget)
    }

    // MARK: - Appearance (MBW-11)

    // menu-bar-widget — MBW-11 "Popover appearance"
    @Test func thePopoverIsPinnedToTheDarkAppearance() async {
        let name = await Self.withController { $0.popoverAppearanceName?.rawValue }

        #expect(name == NSAppearance.Name.darkAqua.rawValue)
    }

    // menu-bar-widget — MBW-11 "Palette untouched": pinning the popover chrome
    // is an appearance change, not a token change.
    @Test func thePaletteTokensAreUnchangedByTheDarkPopover() {
        #expect(Palette.cardBackground == Self.sRGB(0x1A2131))
        #expect(Palette.memAccent == Self.sRGB(0xF5A623))
    }

    // MARK: - Visible-frame cap (network-card NC-12)

    // network-card — "Taller than the visible frame".
    //
    // The controller's half of the rule: it measures the real four-card panel
    // and hands the figure to `PanelLayout`. Asserting it through a supplied
    // number rather than a real `NSScreen` keeps the case deterministic on any
    // display the suite happens to run on.
    @Test func theControllerCapsTheFourCardPanelToA14InchVisibleFrame() async throws {
        let state = await Self.fourCardState()

        let cap = try #require(
            await StatusItemController.panelMaxHeight(for: state, visibleFrameHeight: 945),
            "the four-card panel fits a 14\" visible frame, so nothing was capped"
        )

        #expect(cap == 921, "the cap is not 945 pt minus the 24 pt screen margin")
        #expect(cap < 945)
    }

    // network-card — "Shorter than the visible frame": on a frame the four-card
    // panel fits inside, the controller supplies no cap at all, so the popover
    // keeps today's unbounded tree.
    @Test func theControllerSuppliesNoCapWhenTheFourCardPanelFits() async {
        let state = await Self.fourCardState()

        let cap = await StatusItemController.panelMaxHeight(
            for: state,
            visibleFrameHeight: 2000
        )

        #expect(cap == nil)
    }

    // network-card — the measurement is of the panel, not of a constant: the
    // same state measured against a frame just above and just below its
    // fitting height flips the branch, which is what proves the controller
    // really measured 1 049 pt of cards.
    @Test func theControllerMeasuresThePanelRatherThanAFixedHeight() async {
        let state = await Self.fourCardState()

        let capped = await StatusItemController.panelMaxHeight(
            for: state,
            visibleFrameHeight: 1000
        )
        let uncapped = await StatusItemController.panelMaxHeight(
            for: state,
            visibleFrameHeight: 1200
        )

        #expect(capped == 976, "1 000 pt minus the 24 pt margin is below the 1 049 pt panel")
        #expect(uncapped == nil, "1 176 pt of room is more than the 1 049 pt panel needs")
    }

    // MARK: - Lifetime (MBW-12)

    // menu-bar-widget — MBW-12 "Deinit removes the item"
    @Test func releasingTheControllerRemovesItsStatusItem() async {
        let probe = await StatusItemReleaseProbe()

        let wasLive = await probe.buildAndRelease()
        // One main-actor turn so an `isolated deinit` scheduled from the
        // release has run before the references are read.
        await MainActor.run {}
        let released = await probe.isFullyReleased

        #expect(wasLive, "the probe never held a live controller and status item")
        #expect(released, "the controller or its status item outlived the last reference")
    }

    // MARK: - Panel transitions (MBW-13)

    // menu-bar-widget — MBW-13 "Open and close are reported"
    @Test func thePopoverDelegateReportsEachTransitionOnce() async {
        let spy = PanelVisibilitySpy()

        await Self.withController(panelObserver: spy) { controller in
            controller.popoverWillShow(Notification(name: NSPopover.willShowNotification))
            controller.popoverDidClose(Notification(name: NSPopover.didCloseNotification))
        }

        #expect(await spy.events == [true, false])
    }

    // menu-bar-widget — MBW-13 "No duplicate transitions".
    //
    // Design fallback (revision 2, "if the popover cannot display headless"):
    // a `.transient` popover does not display while its application is
    // inactive, and the test host never is — measured here as
    // `NSApp.isActive == false` with the status item button present and in a
    // window — so `togglePopover()` cannot open one in this suite.
    //
    // The case therefore asserts the mechanism the requirement rests on rather
    // than the display: the controller has no show-only reporting path, so an
    // open can only ever be reported by `popoverWillShow`. Reporting the open
    // from inside `togglePopover()` — the obvious wrong implementation, and the
    // one that would double-count — makes `events` non-empty and fails here. If
    // a host ever does display the popover, the same case asserts the full
    // `[open, closed]` sequence instead of quietly passing on an empty one.
    @Test func togglingTwiceNeverReportsASecondOpen() async {
        let spy = PanelVisibilitySpy()

        let panel = await Self.withController(panelObserver: spy) { controller in
            controller.togglePopover()
            let didDisplay = controller.isPanelOpen
            controller.togglePopover()
            return (didDisplay: didDisplay, isOpenAtEnd: controller.isPanelOpen)
        }

        let events = await spy.events

        #expect(panel.isOpenAtEnd == false)
        #expect(Self.hasConsecutiveOpens(events) == false, "an open transition was reported twice")

        if panel.didDisplay {
            #expect(events == [true, false])
        } else {
            #expect(
                events.isEmpty,
                "the popover never displayed, so an open was reported by something other than the delegate"
            )
        }
    }
}
