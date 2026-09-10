import AppKit
import SwiftUI
import Testing
@testable import system_monitor

// menu-bar-widget — "Legibility"
@Suite("Menu bar module accents")
struct StatusItemReadingsTests {

    // menu-bar-widget — "Accent from module"
    @Test func cpuUsesTheCPUAccent() {
        #expect(MetricModule.cpu.accent == Palette.cpuAccent)
    }

    @Test func memoryUsesTheMemoryAccent() {
        #expect(MetricModule.memory.accent == Palette.memAccent)
    }

    @Test func everyModuleResolvesToADistinctAccent() {
        let accents = MetricModule.allCases.map(\.accent)

        #expect(accents.count == MetricModule.allCases.count)
        #expect(MetricModule.cpu.accent != MetricModule.memory.accent)
    }
}

// cpu-card — "Palette and card surface"
@Suite("Palette tokens")
struct PaletteTests {

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

    // cpu-card — "Token values"
    @Test func accentTokensMatchTheProductPalette() {
        #expect(Palette.cpuAccent == Self.sRGB(0x4D8DFF))
        #expect(Palette.cpuEfficiency == Self.sRGB(0x3FC1C9))
        #expect(Palette.memAccent == Self.sRGB(0xF5A623))
    }

    // memory-card — "Token values"
    //
    // Values only: `memCached` is deliberately the same colour as `cpuAccent`,
    // so asserting pairwise distinctness here would pin a coincidence rather
    // than the palette.
    @Test func memorySegmentTokensMatchTheProductPalette() {
        #expect(Palette.memAccent == Self.sRGB(0xF5A623))
        #expect(Palette.memWired == Self.sRGB(0xE5484D))
        #expect(Palette.memCompressed == Self.sRGB(0xF5D90A))
        #expect(Palette.memCached == Self.sRGB(0x4D8DFF))
        #expect(Palette.memFree == Self.sRGB(0x3DD68C))
    }

    // disk-card — "Token value"
    //
    // Values only, for the same reason as the memory segments: `diskAccent` is
    // deliberately the same colour as `memFree` — two tokens, one colour —
    // because the disk ring and the memory bar are never adjacent.
    @Test func theDiskAccentMatchesTheProductPalette() {
        #expect(Palette.diskAccent == Self.sRGB(0x3DD68C))
        #expect(Palette.diskAccent == Palette.memFree)
    }

    // network-card — NC-10 "Token values"
    //
    // Values and the two deliberate sharings: `networkDownload` is the same
    // colour as `memFree`/`diskAccent` and `networkUpload` the same as
    // `cpuAccent`/`memCached` — two tokens, one colour, because the network
    // lines are never adjacent to the memory bar, the disk ring or the CPU
    // graph. `networkDownload != networkUpload` is the only distinctness
    // assertion: the two badges must be told apart, and any other pairwise
    // check would forbid the sharings above.
    //
    // `networkAccent` is sampled from the densest globe pixel of
    // `docs/reference/06-panel-network.png` (0xC659E4).
    @Test func networkTokensMatchTheProductPalette() {
        #expect(Palette.networkAccent == Self.sRGB(0xC659E4))

        #expect(Palette.networkDownload == Self.sRGB(0x3DD68C))
        #expect(Palette.networkDownload == Palette.memFree)
        #expect(Palette.networkDownload == Palette.diskAccent)

        #expect(Palette.networkUpload == Self.sRGB(0x4D8DFF))
        #expect(Palette.networkUpload == Palette.cpuAccent)

        #expect(Palette.networkDownload != Palette.networkUpload)
    }

    @Test func surfaceTokensMatchTheProductPalette() {
        #expect(Palette.panelBackground == Self.sRGB(0x0F1522))
        #expect(Palette.cardBackground == Self.sRGB(0x1A2131))
    }

    @Test func textTokensMatchTheProductPalette() {
        #expect(Palette.textPrimary == Self.sRGB(0xF2F4F8))
        #expect(Palette.textSecondary == Self.sRGB(0x8A93A6))
    }

    @Test func cardSurfaceUsesTheDocumentedCornerRadius() {
        #expect(Palette.cardCornerRadius == 12)
    }
}

// menu-bar-widget — "Data-driven module list", "Integer percentage value",
// "Sixty-sample sparkline", "Live updates"
@Suite("Menu bar readings")
struct MenuBarReadingsTests {

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

    /// A memory snapshot whose `fraction` is exactly `fraction`.
    ///
    /// Only `total` and `used` drive the widget, so the component fields stay
    /// zero: the widget must read the fraction, not re-derive it.
    private static func memorySnapshot(fraction: Double) -> MemorySnapshot {
        let total: UInt64 = 1_000_000_000

        return MemorySnapshot(
            total: total,
            app: 0,
            wired: 0,
            compressed: 0,
            cached: 0,
            free: 0,
            used: UInt64((Double(total) * fraction).rounded())
        )
    }

    private static func history(_ values: [Double], capacity: Int = 120) -> MetricHistory {
        var history = MetricHistory(capacity: capacity)
        for value in values {
            history.append(value)
        }
        return history
    }

    /// The reading for `module`, built from the user's ordered module subset.
    ///
    /// `modules` defaults to `MetricModule.menuBarOrder` because that is the
    /// default `Settings.menuBarModules`, not because the builder still has a
    /// fixed list of its own (MBW-1).
    private static func reading(
        _ module: MetricModule,
        modules: [MetricModule] = MetricModule.menuBarOrder,
        cpu: CPUSnapshot? = nil,
        cpuHistory: MetricHistory = MetricHistory(capacity: 120),
        memory: MemorySnapshot? = nil,
        memoryHistory: MetricHistory = MetricHistory(capacity: 120)
    ) -> ModuleReading? {
        StatusItemReadings.build(
            modules: modules,
            cpu: cpu,
            cpuHistory: cpuHistory,
            memory: memory,
            memoryHistory: memoryHistory
        )
        .first { $0.module == module }
    }

    // menu-bar-widget — "Order preserved"
    @Test func readingsFollowTheMenuBarOrder() {
        let readings = StatusItemReadings.build(
            modules: MetricModule.menuBarOrder,
            cpu: nil,
            cpuHistory: MetricHistory(capacity: 120),
            memory: nil,
            memoryHistory: MetricHistory(capacity: 120)
        )

        #expect(readings.map(\.module) == [.cpu, .memory])
        #expect(readings.map(\.module) == MetricModule.menuBarOrder)
    }

    // menu-bar-widget — "Hidden module omitted": the builder renders the user's
    // subset, so a hidden module produces no reading at all rather than a
    // reading the view then has to filter.
    @Test func aHiddenModuleProducesNoReading() {
        let readings = StatusItemReadings.build(
            modules: [.memory],
            cpu: Self.snapshot(total: 0.42),
            cpuHistory: Self.history([0.4, 0.42]),
            memory: Self.memorySnapshot(fraction: 0.59),
            memoryHistory: Self.history([0.58, 0.59])
        )

        #expect(readings.count == 1)
        #expect(readings.map(\.module) == [.memory])
        #expect(readings[0].valueText == "59%")
    }

    // menu-bar-widget — "Reversed order": the order comes from the argument,
    // not from `menuBarOrder`, so reversing the subset reverses the widget.
    @Test func theReadingsFollowTheRequestedOrder() {
        let readings = StatusItemReadings.build(
            modules: [.memory, .cpu],
            cpu: Self.snapshot(total: 0.42),
            cpuHistory: MetricHistory(capacity: 120),
            memory: Self.memorySnapshot(fraction: 0.59),
            memoryHistory: MetricHistory(capacity: 120)
        )

        #expect(readings.map(\.module) == [.memory, .cpu])
        #expect(readings.map(\.valueText) == ["59%", "42%"])
    }

    // menu-bar-widget — "Data-driven module list": an empty subset renders
    // nothing. `Settings` never produces one, but the builder is pure and must
    // not fall back to a default list of its own.
    @Test func anEmptyModuleListProducesNoReadings() {
        let readings = StatusItemReadings.build(
            modules: [],
            cpu: Self.snapshot(total: 0.42),
            cpuHistory: Self.history([0.1, 0.2]),
            memory: Self.memorySnapshot(fraction: 0.59),
            memoryHistory: Self.history([0.3, 0.4])
        )

        #expect(readings.isEmpty)
    }

    // menu-bar-widget — "No snapshot yet"
    @Test func theCPUValueReadsZeroPercentBeforeTheFirstSnapshot() throws {
        let cpu = try #require(Self.reading(.cpu))

        #expect(cpu.valueText == "0%")
    }

    // menu-bar-widget — "Value follows state"
    @Test func theCPUValueFollowsTheSnapshotTotal() throws {
        let cpu = try #require(Self.reading(.cpu, cpu: Self.snapshot(total: 0.42)))

        #expect(cpu.valueText == "42%")
    }

    // menu-bar-widget — "Integer formatting"
    @Test(arguments: zip([0.264, 0.266, 0.0, 1.0], ["26%", "27%", "0%", "100%"]))
    func theCPUValueIsAWholePercentage(total: Double, expected: String) throws {
        let cpu = try #require(Self.reading(.cpu, cpu: Self.snapshot(total: total)))

        #expect(cpu.valueText == expected)
    }

    // menu-bar-widget — "Last 60 of 120"
    @Test func theSparklineUsesTheNewestSixtySamples() throws {
        let values = (0..<120).map { Double($0) / 120 }
        let cpu = try #require(Self.reading(.cpu, cpuHistory: Self.history(values)))

        #expect(cpu.samples.count == 60)
        #expect(cpu.samples == Array(values.suffix(60)))
    }

    // menu-bar-widget — "Partial history"
    @Test func aPartialHistoryKeepsEveryStoredSample() throws {
        let values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]
        let cpu = try #require(Self.reading(.cpu, cpuHistory: Self.history(values)))

        #expect(cpu.samples == values)
    }

    // menu-bar-widget — "Empty history"
    @Test func anEmptyHistoryProducesNoSamples() throws {
        let cpu = try #require(Self.reading(.cpu))

        #expect(cpu.samples.isEmpty)
    }

    // menu-bar-widget — "MEM value from fraction"
    @Test func theMemoryValueFollowsTheSnapshotFraction() throws {
        let memory = try #require(
            Self.reading(.memory, memory: Self.memorySnapshot(fraction: 0.59))
        )

        #expect(memory.valueText == "59%")
    }

    // menu-bar-widget — "MEM before first snapshot"
    @Test func theMemoryValueReadsZeroPercentBeforeTheFirstSnapshot() throws {
        let memory = try #require(Self.reading(.memory))

        #expect(memory.valueText == "0%")
        #expect(memory.samples.isEmpty)
    }

    // menu-bar-widget — "MEM newest 60 samples"
    @Test func theMemorySparklineUsesTheNewestSixtySamples() throws {
        let values = (0..<120).map { Double($0) / 120 }
        let memory = try #require(
            Self.reading(.memory, memoryHistory: Self.history(values))
        )

        #expect(memory.samples.count == 60)
        #expect(memory.samples == Array(values.suffix(60)))
    }

    // menu-bar-widget — "MEM accent"
    @Test func theMemoryModuleCarriesTheMemoryAccent() throws {
        let memory = try #require(Self.reading(.memory))

        #expect(memory.module.accent == Palette.memAccent)
    }

    // menu-bar-widget — "Both modules follow state"
    //
    // The two modules read two independent pairs: swapping the histories or the
    // snapshots would break exactly one of these four expectations.
    @Test func bothModulesFollowTheirOwnState() throws {
        let cpuValues = [0.10, 0.20, 0.30]
        let memoryValues = [0.55, 0.57, 0.59]

        let readings = StatusItemReadings.build(
            modules: [.cpu, .memory],
            cpu: Self.snapshot(total: 0.42),
            cpuHistory: Self.history(cpuValues),
            memory: Self.memorySnapshot(fraction: 0.59),
            memoryHistory: Self.history(memoryValues)
        )
        let cpu = try #require(readings.first { $0.module == .cpu })
        let memory = try #require(readings.first { $0.module == .memory })

        #expect(readings.map(\.module) == [.cpu, .memory])
        #expect(cpu.valueText == "42%")
        #expect(memory.valueText == "59%")
        #expect(cpu.samples == cpuValues)
        #expect(memory.samples == memoryValues)
    }

    // menu-bar-widget — "Equal data compares equal"
    @Test func readingsBuiltFromTheSameStateCompareEqual() {
        let history = Self.history([0.1, 0.2, 0.3])
        let snapshot = Self.snapshot(total: 0.3)
        let memoryHistory = Self.history([0.4, 0.5])
        let memory = Self.memorySnapshot(fraction: 0.5)

        let first = StatusItemReadings.build(
            modules: MetricModule.menuBarOrder,
            cpu: snapshot,
            cpuHistory: history,
            memory: memory,
            memoryHistory: memoryHistory
        )
        let second = StatusItemReadings.build(
            modules: MetricModule.menuBarOrder,
            cpu: snapshot,
            cpuHistory: history,
            memory: memory,
            memoryHistory: memoryHistory
        )

        #expect(first == second)
    }
}

// menu-bar-widget — MBW-14 "Redraw gating on unchanged readings".
//
// `StatusItemContent` and `ModuleLabel` are `Equatable` so SwiftUI can skip
// their bodies while the readings stand still. Views are main-actor isolated
// under the module's default isolation, so the comparison runs inside
// `MainActor.run` (precedent: `CanvasComponentEqualityTests`).
@Suite("Status item content equality", .timeLimit(.minutes(1)))
struct StatusItemContentEqualityTests {

    private static func readings(cpuValue: String) -> [ModuleReading] {
        [
            ModuleReading(module: .cpu, samples: [0.1, 0.2], valueText: cpuValue),
            ModuleReading(module: .memory, samples: [0.5, 0.6], valueText: "59%"),
        ]
    }

    // menu-bar-widget — "Identical readings compare equal"
    @Test func contentsBuiltFromIdenticalReadingsCompareEqual() async {
        await MainActor.run {
            let base = StatusItemContent(readings: Self.readings(cpuValue: "42%"))
            let same = StatusItemContent(readings: Self.readings(cpuValue: "42%"))

            #expect(base == same)
        }
    }

    // menu-bar-widget — "Changed value compares unequal"
    @Test func contentsDifferingOnlyInTheCPUValueCompareUnequal() async {
        await MainActor.run {
            let base = StatusItemContent(readings: Self.readings(cpuValue: "42%"))
            let changed = StatusItemContent(readings: Self.readings(cpuValue: "43%"))

            #expect(base != changed)
        }
    }

    // menu-bar-widget — MBW-14: the module label is the unit SwiftUI skips, so
    // it carries the same equality contract as the content around it. Samples
    // are compared too, otherwise a moving sparkline would be gated away.
    @Test func moduleLabelsCompareOnTheirWholeReading() async {
        await MainActor.run {
            let reading = ModuleReading(module: .cpu, samples: [0.1, 0.2], valueText: "42%")
            let base = ModuleLabel(reading: reading)
            let same = ModuleLabel(reading: reading)
            let differentValue = ModuleLabel(
                reading: ModuleReading(module: .cpu, samples: [0.1, 0.2], valueText: "43%")
            )
            let differentSamples = ModuleLabel(
                reading: ModuleReading(module: .cpu, samples: [0.1, 0.3], valueText: "42%")
            )

            #expect(base == same)
            #expect(base != differentValue)
            #expect(base != differentSamples)
        }
    }

    // menu-bar-widget — MBW-14: a different module set is a different content,
    // so hiding a module can never be gated away as "unchanged".
    @Test func contentsWithDifferentModuleSetsCompareUnequal() async {
        await MainActor.run {
            let both = StatusItemContent(readings: Self.readings(cpuValue: "42%"))
            let memoryOnly = StatusItemContent(
                readings: [ModuleReading(module: .memory, samples: [0.5, 0.6], valueText: "59%")]
            )

            #expect(both != memoryOnly)
        }
    }
}

// menu-bar-widget — "Fixed-width, jitter-free layout", "Sixty-sample sparkline"
@Suite("Status item metrics")
struct StatusItemMetricsTests {

    /// Width of `text` at the widget value font, measured outside SwiftUI.
    private static func measuredWidth(_ text: String) -> CGFloat {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    /// Width of `StatusItemContent` rendering a single reading.
    @MainActor
    private static func contentWidth(for reading: ModuleReading) -> CGFloat {
        Self.contentWidth(for: [reading])
    }

    /// Width of `StatusItemContent` rendering the whole widget.
    @MainActor
    private static func contentWidth(for readings: [ModuleReading]) -> CGFloat {
        let view = NSHostingView(rootView: StatusItemContent(readings: readings))
        view.layoutSubtreeIfNeeded()
        return view.fittingSize.width
    }

    private static func history(_ values: [Double], capacity: Int = 120) -> MetricHistory {
        var history = MetricHistory(capacity: capacity)
        for value in values {
            history.append(value)
        }
        return history
    }

    private static func memorySnapshot(fraction: Double) -> MemorySnapshot {
        let total: UInt64 = 1_000_000_000

        return MemorySnapshot(
            total: total,
            app: 0,
            wired: 0,
            compressed: 0,
            cached: 0,
            free: 0,
            used: UInt64((Double(total) * fraction).rounded())
        )
    }

    // menu-bar-widget — "Sixty-sample sparkline"
    @Test func theSparklineKeepsItsFortyPointWidth() async {
        let width = await StatusItemMetrics.sparklineWidth

        #expect(width == 40)
    }

    // menu-bar-widget — "Every module renders a sparkline"
    @Test func theSparklineStillHoldsSixtySamples() {
        #expect(StatusItemReadings.sampleCount == 60)
    }

    // menu-bar-widget — "Fixed-width, jitter-free layout"
    //
    // The 250 pt budget exists so the widget can breathe. Pinning the spacing
    // keeps a future width squeeze from collapsing the gaps instead of raising
    // the budget again.
    @Test func theLayoutKeepsItsReadableSpacing() async {
        let element = await StatusItemMetrics.elementSpacing
        let module = await StatusItemMetrics.moduleSpacing
        let padding = await StatusItemMetrics.horizontalPadding
        let separator = await StatusItemMetrics.separatorWidth
        let corner = await StatusItemMetrics.cardCornerRadius

        #expect(element == 4)
        #expect(module == 6)
        #expect(padding == 6)
        #expect(separator == 1)
        #expect(corner == 6)
    }

    // menu-bar-widget — "Module separator": the two-module widget is exactly
    // one hairline and one extra module gap wider than its modules laid side
    // by side, which is what proves a separator sits between them and that a
    // single module never draws one.
    @Test func theModulesAreSeparatedByAHairline() async {
        let both = await StatusItemMetrics.measurementReadings(for: MetricModule.menuBarOrder)
        let cpu = await StatusItemMetrics.measurementReadings(for: [.cpu])
        let memory = await StatusItemMetrics.measurementReadings(for: [.memory])

        let bothWidth = await Self.contentWidth(for: both)
        let cpuWidth = await Self.contentWidth(for: cpu)
        let memoryWidth = await Self.contentWidth(for: memory)
        let padding = await StatusItemMetrics.horizontalPadding
        let module = await StatusItemMetrics.moduleSpacing
        let separator = await StatusItemMetrics.separatorWidth

        let modulesOnly = cpuWidth + memoryWidth - 2 * padding
        let expected = modulesOnly + 2 * module + separator

        #expect(abs(bothWidth - expected) < 0.5)
    }

    // menu-bar-widget — "Fixed-width, jitter-free layout"
    @Test func theValueFrameFitsTheWidestPercentage() async {
        let width = await StatusItemMetrics.valueWidth

        #expect(width >= Self.measuredWidth("100%"))
        #expect(width < 40)
    }

    // menu-bar-widget — "Width budget"
    @Test func theMeasurementReadingsRenderFullScaleForEveryModule() async {
        let readings = await StatusItemMetrics.measurementReadings(for: MetricModule.menuBarOrder)

        #expect(readings.map(\.module) == MetricModule.menuBarOrder)
        #expect(readings.allSatisfy { $0.valueText == "100%" })
        #expect(readings.allSatisfy { $0.samples.count == StatusItemReadings.sampleCount })
    }

    // menu-bar-widget — MBW-9: the measurement follows the module set it is
    // asked about, in that order, which is what lets the controller re-measure
    // when the user hides or reorders a module.
    @Test func theMeasurementReadingsFollowTheRequestedModuleSet() async {
        let single = await StatusItemMetrics.measurementReadings(for: [.memory])
        let reversed = await StatusItemMetrics.measurementReadings(for: [.memory, .cpu])

        #expect(single.map(\.module) == [.memory])
        #expect(single.allSatisfy { $0.valueText == "100%" })
        #expect(reversed.map(\.module) == [.memory, .cpu])
    }

    // menu-bar-widget — "One-module width": a single module at full scale must
    // stay under 130 pt, so hiding a module visibly frees menu bar space.
    @Test func oneModuleAtFullScaleStaysUnderTheOneModuleBudget() async {
        let readings = await StatusItemMetrics.measurementReadings(for: [.memory])
        let width = await Self.contentWidth(for: readings)

        #expect(width > 0, "the widget measured as empty")
        #expect(width < 130)
    }

    // menu-bar-widget — "Width budget": both modules at full scale stay under
    // the 250 pt budget, and one module is strictly narrower than two.
    @Test func twoModulesAtFullScaleStayUnderTheWidgetBudget() async {
        let both = await StatusItemMetrics.measurementReadings(for: MetricModule.menuBarOrder)
        let single = await StatusItemMetrics.measurementReadings(for: [.memory])

        let bothWidth = await Self.contentWidth(for: both)
        let singleWidth = await Self.contentWidth(for: single)

        #expect(bothWidth > 0, "the widget measured as empty")
        #expect(bothWidth < 250)
        #expect(singleWidth < bothWidth)
    }

    // menu-bar-widget — "Every module renders a sparkline"
    //
    // The sparkline area is structural: a module reserves it even with no
    // samples, so a module that skipped it could not reach this width.
    @Test(arguments: MetricModule.menuBarOrder)
    func everyModuleReservesItsSparklineArea(module: MetricModule) async {
        let reading = ModuleReading(module: module, samples: [], valueText: "0%")

        let width = await Self.contentWidth(for: reading)
        let sparkline = await StatusItemMetrics.sparklineWidth
        let value = await StatusItemMetrics.valueWidth
        let insets = await 2 * StatusItemMetrics.horizontalPadding

        #expect(width >= sparkline + value + insets)
        #expect(width < sparkline + value + insets + 40, "the module reserved more than one label and one sparkline")
    }

    // menu-bar-widget — "MEM live sparkline"
    @Test func theMemoryModuleRendersItsLiveSparkline() async throws {
        let values = (0..<30).map { 0.5 + Double($0) / 300 }

        let readings = StatusItemReadings.build(
            modules: MetricModule.menuBarOrder,
            cpu: nil,
            cpuHistory: MetricHistory(capacity: 120),
            memory: Self.memorySnapshot(fraction: 0.59),
            memoryHistory: Self.history(values)
        )
        let memory = try #require(readings.first { $0.module == .memory })
        let width = await Self.contentWidth(for: memory)
        let sparkline = await StatusItemMetrics.sparklineWidth
        let value = await StatusItemMetrics.valueWidth

        #expect(memory.samples == values)
        #expect(memory.valueText == "59%")
        #expect(memory.module.label == "MEM")
        #expect(memory.module.accent == Palette.memAccent)
        #expect(width >= sparkline + value)
    }

    // menu-bar-widget — "MEM empty history still has a sparkline"
    @Test func theMemoryModuleKeepsItsSparklineWithoutHistory() async throws {
        let readings = StatusItemReadings.build(
            modules: MetricModule.menuBarOrder,
            cpu: nil,
            cpuHistory: MetricHistory(capacity: 120),
            memory: nil,
            memoryHistory: MetricHistory(capacity: 120)
        )
        let memory = try #require(readings.first { $0.module == .memory })
        let width = await Self.contentWidth(for: memory)
        let sparkline = await StatusItemMetrics.sparklineWidth
        let value = await StatusItemMetrics.valueWidth

        #expect(memory.samples.isEmpty)
        #expect(memory.valueText == "0%")
        #expect(memory.module.label == "MEM")
        #expect(width >= sparkline + value)

        // menu-bar-widget — "Width budget": both modules at "100%" with a full
        // sparkline, which is the widest content the widget can ever render.
        let fullScale = await StatusItemMetrics.measurementReadings(for: MetricModule.menuBarOrder)
        let fullWidth = await Self.contentWidth(for: fullScale)

        #expect(fullWidth > 0, "the widget measured as empty")
        #expect(fullWidth < 250)
    }
}
