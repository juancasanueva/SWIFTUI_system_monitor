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

    private static let networkSnapshot = NetworkFixtures.referenceSnapshot

    /// Card width inside the panel: the fixed 320 pt minus its 12 pt padding.
    private static let cardWidth: CGFloat = 296

    /// One panel spacing plus its top and bottom padding: what the two-card
    /// panel added to its cards.
    private static let panelChrome: CGFloat = 12 + 12 + 12

    /// Two panel spacings plus its top and bottom padding, the chrome of the
    /// three-card panel (DC-11).
    private static let threeCardChrome: CGFloat = 12 + 12 + 12 + 12

    /// Three panel spacings plus its top and bottom padding, the chrome of the
    /// four-card panel (NC-11).
    private static let fourCardChrome: CGFloat = 12 + 12 + 12 + 12 + 12

    @MainActor
    private static func fittingSize(for state: MetricsState) -> CGSize {
        let hostingView = NSHostingView(rootView: PanelView().environment(state))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    @MainActor
    private static func fittingSize(for state: MetricsState, maxHeight: CGFloat) -> CGSize {
        let hostingView = NSHostingView(
            rootView: PanelView(maxHeight: maxHeight).environment(state)
        )
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
    private static func networkCardHeight(for state: MetricsState) -> CGFloat {
        cardHeight(
            NetworkCard(
                snapshot: state.network,
                downloadHistory: state.networkDownloadHistory,
                uploadHistory: state.networkUploadHistory
            )
        )
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

    // disk-card DC-1 / network-card NC-1 — "Card order"
    @Test func thePanelStacksCPUThenMemoryThenDiskThenNetwork() {
        #expect(PanelView.cards == [.cpu, .memory, .disk, .network])
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
    // The panel is exactly its cards plus its own chrome. Three cards measured
    // 871 pt = 370 (CPU) + 278 (memory) + 175 (disk) + 48, up from the 678 pt
    // the two-card panel occupied; with the network card the panel now measures
    // 1049 pt = 370 + 278 + 175 + 166 (network) + 60, which no longer fits a
    // 14" display and is what NC-12's visible-frame cap exists for.
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

    // MARK: - network-card NC-1, NC-7, NC-11 (DC-1, DC-11 delta)

    // network-card — "Card renders from fixed inputs"
    @Test func theNetworkCardRendersFromItsSnapshotAndHistoriesAlone() async {
        let state = await MetricsState()
        await state.apply(network: Self.networkSnapshot)

        let height = await Self.networkCardHeight(for: state)

        #expect(height > 120, "the network card lost its readings, rows or history graph")
    }

    // network-card — "Height is stable"
    //
    // The network card renders its full skeleton before the first reading, so
    // the first snapshot fills the card instead of resizing the popover.
    @Test func theFirstNetworkSnapshotFillsTheCardWithoutResizingThePanel() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        await state.apply(memory: Self.memorySnapshot)
        await state.apply(disk: Self.diskSnapshot)
        let before = await Self.fittingSize(for: state)

        await state.apply(network: Self.networkSnapshot)
        let after = await Self.fittingSize(for: state)

        #expect(after == before, "the network card changed size when its first reading landed")
    }

    // network-card — "Four-card height"
    //
    // Measured 1049 pt = 370 (CPU) + 278 (memory) + 175 (disk) + 166 (network)
    // + 60 chrome.
    //
    // The three-card height is the sum of the three cards plus the chrome the
    // panel carried while they were the whole panel, exactly as
    // `thePanelGrowsByTheFullDiskCard` builds its two-card figure: a panel
    // rendered with `network == nil` is not a three-card panel, because the
    // network skeleton is already occupying its slot (NC-7).
    @Test func thePanelGrowsByTheFullNetworkCard() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        await state.apply(memory: Self.memorySnapshot)
        await state.apply(disk: Self.diskSnapshot)
        await state.apply(network: Self.networkSnapshot)

        let panel = await Self.fittingSize(for: state)
        let cards = await Self.cardHeights(for: state)
        let disk = await Self.diskCardHeight(state.disk)
        let network = await Self.networkCardHeight(for: state)
        let threeCardHeight = cards.cpu + cards.memory + disk + Self.threeCardChrome

        #expect(network > 120, "the network card lost its readings, rows or history graph")
        #expect(panel.height >= cards.cpu + cards.memory + disk + network + Self.fourCardChrome)
        #expect(panel.height > threeCardHeight, "the panel did not grow with the fourth card")
    }

    // network-card — "Live update while open"
    @Test func theNetworkReadingsFollowTheAppliedSnapshot() async {
        let state = await MetricsState()
        let before = await NetworkCardModel.rateReadings(for: state.network, locale: Self.english)

        await state.apply(network: Self.networkSnapshot)
        let after = await NetworkCardModel.rateReadings(for: state.network, locale: Self.english)
        let download = await state.networkDownloadHistory.ordered
        let upload = await state.networkUploadHistory.ordered

        #expect(before.map(\.text) == ["\u{2014}", "\u{2014}"], "the empty panel invented a rate")
        #expect(
            after.map { $0.text.replacingOccurrences(of: "\u{00A0}", with: " ") }
                == ["5.0 kB/s", "78.0 kB/s"]
        )
        #expect(download == [5_000])
        #expect(upload == [78_000])
    }

    // MARK: - network-card NC-12 (visible-frame scroll cap)

    // network-card — "Taller than the visible frame"
    //
    // A supplied cap is the panel's height, not a ceiling it may ignore: the
    // four cards are 1 049 pt of content, so a 600 pt cap can only be honoured
    // by scrolling them. The uncapped panel is measured in the same case, so
    // the assertion cannot pass by the panel having shrunk on its own.
    @Test func aSuppliedMaxHeightPinsThePanelAndScrollsItsCards() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        await state.apply(memory: Self.memorySnapshot)
        await state.apply(disk: Self.diskSnapshot)
        await state.apply(network: Self.networkSnapshot)

        let capped = await Self.fittingSize(for: state, maxHeight: 600)
        let uncapped = await Self.fittingSize(for: state)

        #expect(capped.height == 600)
        #expect(uncapped.height > 600, "the uncapped panel is not tall enough to prove the cap")
        #expect(capped.width == 320, "the capped panel lost the fixed panel width")
    }

    // network-card — "Shorter than the visible frame": a cap above the content
    // still pins the frame, which is why `StatusItemController` passes `nil`
    // rather than the fitting height when the panel fits.
    @Test func aMaxHeightAboveTheContentStillPinsTheFrame() async {
        let state = await MetricsState()
        await state.apply(cpu: Self.snapshot(total: 0.42, coreCount: 12))
        await state.apply(memory: Self.memorySnapshot)
        await state.apply(disk: Self.diskSnapshot)
        await state.apply(network: Self.networkSnapshot)

        let capped = await Self.fittingSize(for: state, maxHeight: 1500)
        let uncapped = await Self.fittingSize(for: state)

        #expect(capped.height == 1500)
        #expect(uncapped.height < 1500)
        #expect(
            PanelLayout.maxHeight(fitting: uncapped.height, visibleFrameHeight: 1500) == nil,
            "the rule would have capped a panel that fits"
        )
    }
}
