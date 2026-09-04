import AppKit
import SwiftUI
import Testing
@testable import system_monitor

// cpu-card — "Presentational contract"
@Suite("PanelView reads the live metrics state")
struct PanelViewTests {

    private static let english = Locale(identifier: "en_US")

    private static func snapshot(total: Double, coreCount: Int) -> CPUSnapshot {
        let performance = (0..<coreCount).prefix(8).map {
            CoreUsage(index: $0, usage: 0.7, level: .performance)
        }
        let efficiency = (8..<coreCount).map {
            CoreUsage(index: $0, usage: 0.1, level: .efficiency)
        }
        return CPUSnapshot(
            total: total,
            user: total * 0.75,
            system: total * 0.25,
            performanceAverage: performance.isEmpty ? nil : 0.7,
            efficiencyAverage: efficiency.isEmpty ? nil : 0.1,
            cores: Array(performance) + efficiency
        )
    }

    @MainActor
    private static func fittingSize(for state: MetricsState) -> CGSize {
        let hostingView = NSHostingView(rootView: PanelView().environment(state))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    @Test func thePanelKeepsItsFixedWidth() async {
        let size = await Self.fittingSize(for: MetricsState())

        #expect(size.width == 320)
    }

    // cpu-card — "Card renders from fixed inputs"
    @Test func thePanelRendersTheCPUCardRatherThanAPlaceholder() async {
        let size = await Self.fittingSize(for: MetricsState())

        #expect(size.height > 260, "the CPU card gauge and history graph are missing")
    }

    // cpu-card — "Live update while open"
    @Test func applyingASnapshotWithCoresGrowsThePanelWithBarGroups() async {
        let empty = await Self.fittingSize(for: MetricsState())

        let populated = await MetricsState()
        await populated.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        let populatedSize = await Self.fittingSize(for: populated)

        #expect(populatedSize.height > empty.height, "the panel ignored the published snapshot")
    }

    // cpu-card — "Live update while open"
    @Test func theGaugeTextFollowsTheStateTotal() async {
        let state = await MetricsState()
        let before = await CPUCardModel.gaugeText(for: state.cpu, locale: Self.english)

        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        let after = await CPUCardModel.gaugeText(for: state.cpu, locale: Self.english)
        let history = await state.cpuHistory.ordered

        #expect(before == "0.0%")
        #expect(after == "42.0%")
        #expect(history == [0.42])
    }
}
