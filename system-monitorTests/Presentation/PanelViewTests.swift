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

    private static let memorySnapshot = MemoryFixtures.snapshot(from: MemoryFixtures.eightGiB)

    private static let diskSnapshot = DiskFixtures.referenceSnapshot

    /// Card width inside the panel: the fixed 320 pt minus its 12 pt padding.
    private static let cardWidth: CGFloat = 296

    /// One panel spacing plus its top and bottom padding: what the two-card
    /// panel added to its cards.
    private static let panelChrome: CGFloat = 12 + 12 + 12

    /// Two panel spacings plus its top and bottom padding, the chrome of the
    /// three-card panel (DC-11).
    private static let threeCardChrome: CGFloat = 12 + 12 + 12 + 12

    @MainActor
    private static func fittingSize(for state: MetricsState) -> CGSize {
        let hostingView = NSHostingView(rootView: PanelView().environment(state))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    @MainActor
    private static func cardHeight(_ card: some View) -> CGFloat {
        let hostingView = NSHostingView(rootView: card.frame(width: Self.cardWidth))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize.height
    }

    @MainActor
    private static func diskCardHeight(_ snapshot: DiskSnapshot?) -> CGFloat {
        cardHeight(DiskCard(snapshot: snapshot))
    }

    @MainActor
    private static func cardHeights(for state: MetricsState) -> (cpu: CGFloat, memory: CGFloat) {
        (
            cardHeight(CPUCard(snapshot: state.cpu, history: state.cpuHistory)),
            cardHeight(MemoryCard(snapshot: state.memory, history: state.memoryHistory))
        )
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

    // memory-card — "Panel grows with the memory card"
    //
    // The CPU and memory cards plus one spacing and the panel padding measured
    // 678 pt while the panel held two cards; the disk card now sits under
    // them, so the panel is taller than that sum (the measured three-card
    // figure is pinned in `thePanelGrowsByTheFullDiskCard`).
    // A placeholder in the memory slot is far shorter than the real card, so
    // it cannot reach the pinned lower bound.
    @Test func thePanelStacksTheFullMemoryCardUnderTheCPUCard() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        await state.apply(memory: Self.memorySnapshot)

        let panel = await Self.fittingSize(for: state)
        let cards = await Self.cardHeights(for: state)

        #expect(cards.memory > 200, "the memory card lost its gauge, bar or graph")
        #expect(panel.height >= cards.cpu + cards.memory + Self.panelChrome)
        #expect(panel.height > 620, "the memory slot is still a placeholder")
    }

    // memory-card — "Nil snapshot"
    //
    // The memory card renders its full skeleton before the first reading, so
    // the first snapshot fills the card instead of resizing the popover.
    @Test func theFirstMemorySnapshotFillsTheCardWithoutResizingThePanel() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        let before = await Self.fittingSize(for: state)

        await state.apply(memory: Self.memorySnapshot)
        let after = await Self.fittingSize(for: state)
        let gauge = await MemoryCardModel.gaugeText(for: state.memory, locale: Self.english)

        #expect(after == before, "the memory card changed size when its first reading landed")
        #expect(gauge == "69.0%", "the card is still showing its placeholder reading")
    }

    // memory-card — "Live update while open"
    @Test func theMemoryGaugeTextFollowsTheAppliedSnapshot() async {
        let state = await MetricsState()
        let before = await MemoryCardModel.gaugeText(for: state.memory, locale: Self.english)

        await state.apply(memory: Self.memorySnapshot)
        let after = await MemoryCardModel.gaugeText(for: state.memory, locale: Self.english)
        let history = await state.memoryHistory.ordered

        #expect(before == "0.0%")
        #expect(after == "69.0%")
        #expect(history.count == 1)
    }

    // MARK: - disk-card DC-1, DC-8, DC-11

    // disk-card — "Card order"
    @Test func thePanelStacksCPUThenMemoryThenDisk() {
        #expect(PanelView.cards == [.cpu, .memory, .disk])
        #expect(Set(PanelView.cards) == Set(PanelCard.allCases))
    }

    // disk-card — "Card renders from a fixed input"
    @Test func theDiskCardRendersFromItsSnapshotAlone() async {
        let height = await Self.diskCardHeight(Self.diskSnapshot)

        #expect(height > 120, "the disk card lost its gauge, rows or throughput footer")
    }

    // disk-card — "Height is stable"
    //
    // The disk card renders its full skeleton before the first reading, so the
    // first snapshot fills the card instead of resizing the popover.
    @Test func theFirstDiskSnapshotFillsTheCardWithoutResizingThePanel() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        await state.apply(memory: Self.memorySnapshot)
        let before = await Self.fittingSize(for: state)

        await state.apply(disk: Self.diskSnapshot)
        let after = await Self.fittingSize(for: state)

        #expect(after == before, "the disk card changed size when its first reading landed")
    }

    // disk-card — "Three-card height"
    //
    // The panel is exactly its three cards plus its own chrome: measured
    // 871 pt = 370 (CPU) + 278 (memory) + 175 (disk) + 48, up from the 678 pt
    // the two-card panel occupied. It still fits a 14" display.
    @Test func thePanelGrowsByTheFullDiskCard() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        await state.apply(memory: Self.memorySnapshot)
        await state.apply(disk: Self.diskSnapshot)

        let panel = await Self.fittingSize(for: state)
        let cards = await Self.cardHeights(for: state)
        let disk = await Self.diskCardHeight(state.disk)
        let twoCardHeight = cards.cpu + cards.memory + Self.panelChrome

        #expect(disk > 120, "the disk card lost its gauge, rows or throughput footer")
        #expect(panel.height >= cards.cpu + cards.memory + disk + Self.threeCardChrome)
        #expect(panel.height > 620, "the disk slot is still a placeholder")
        #expect(panel.height > twoCardHeight, "the panel did not grow with the third card")
    }

    // disk-card — "Live update while open"
    @Test func theDiskGaugeTextFollowsTheAppliedSnapshot() async {
        let state = await MetricsState()
        let before = await DiskCardModel.gaugeText(for: state.disk, locale: Self.english)

        await state.apply(disk: Self.diskSnapshot)
        let after = await DiskCardModel.gaugeText(for: state.disk, locale: Self.english)

        #expect(before == "\u{2014}", "the empty panel invented a reading")
        #expect(after == "87.4%")
    }
}
