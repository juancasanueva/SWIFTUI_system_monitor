import AppKit
import SwiftUI
import Testing
@testable import system_monitor

// menu-bar-widget — "Fixed-width, jitter-free layout"
//
// Every case builds a real `NSStatusItem` inside the test host: the layout
// contract is about AppKit sizing, so a stub would not prove anything.
@Suite("Status item controller layout")
struct StatusItemControllerTests {

    /// Budget for the whole widget, in points (menu-bar-widget R1.7).
    private static let widthBudget: CGFloat = 230

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

    // menu-bar-widget — "Length stable across updates"
    @Test func theStatusItemLengthDoesNotChangeWhenTheValueChanges() async {
        let state = await MetricsState()
        let controller = await StatusItemController(state: state)

        let initial = await controller.statusItemLength
        await state.apply(cpu: Self.snapshot(total: 0.05))
        let afterLowReading = await controller.statusItemLength
        await state.apply(cpu: Self.snapshot(total: 1.0))
        let afterFullReading = await controller.statusItemLength

        #expect(initial > 0)
        #expect(afterLowReading == initial)
        #expect(afterFullReading == initial)
    }

    // menu-bar-widget — "Sizing options disabled"
    @Test func theHostingViewDoesNotResizeItselfFromItsContent() async {
        let controller = await StatusItemController(state: MetricsState())

        let options = await controller.hostingSizingOptions

        #expect(options == [])
    }

    // menu-bar-widget — "Width budget"
    @Test func theWidgetStaysUnderTheWidthBudgetAtFullScale() async {
        let controller = await StatusItemController(state: MetricsState())

        let width = await controller.contentFittingWidth

        #expect(width > 0, "the widget measured as empty")
        #expect(width < Self.widthBudget)
    }

    // menu-bar-widget — "Fixed-width, jitter-free layout"
    @Test func theStatusItemIsSizedFromTheWidestContent() async {
        let controller = await StatusItemController(state: MetricsState())

        let length = await controller.statusItemLength
        let width = await controller.contentFittingWidth

        #expect(length == width)
    }
}
