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

    private static func history(_ values: [Double], capacity: Int = 120) -> MetricHistory {
        var history = MetricHistory(capacity: capacity)
        for value in values {
            history.append(value)
        }
        return history
    }

    private static func reading(
        _ module: MetricModule,
        snapshot: CPUSnapshot? = nil,
        history: MetricHistory = MetricHistory(capacity: 120)
    ) -> ModuleReading? {
        StatusItemReadings.build(snapshot: snapshot, history: history)
            .first { $0.module == module }
    }

    // menu-bar-widget — "Order preserved"
    @Test func readingsFollowTheMenuBarOrder() {
        let readings = StatusItemReadings.build(
            snapshot: nil,
            history: MetricHistory(capacity: 120)
        )

        #expect(readings.map(\.module) == [.cpu, .memory])
        #expect(readings.map(\.module) == MetricModule.menuBarOrder)
    }

    // menu-bar-widget — "No snapshot yet"
    @Test func theCPUValueReadsZeroPercentBeforeTheFirstSnapshot() throws {
        let cpu = try #require(Self.reading(.cpu))

        #expect(cpu.valueText == "0%")
    }

    // menu-bar-widget — "Value follows state"
    @Test func theCPUValueFollowsTheSnapshotTotal() throws {
        let cpu = try #require(Self.reading(.cpu, snapshot: Self.snapshot(total: 0.42)))

        #expect(cpu.valueText == "42%")
    }

    // menu-bar-widget — "Integer formatting"
    @Test(arguments: zip([0.264, 0.266, 0.0, 1.0], ["26%", "27%", "0%", "100%"]))
    func theCPUValueIsAWholePercentage(total: Double, expected: String) throws {
        let cpu = try #require(Self.reading(.cpu, snapshot: Self.snapshot(total: total)))

        #expect(cpu.valueText == expected)
    }

    // menu-bar-widget — "Last 60 of 120"
    @Test func theSparklineUsesTheNewestSixtySamples() throws {
        let values = (0..<120).map { Double($0) / 120 }
        let cpu = try #require(Self.reading(.cpu, history: Self.history(values)))

        #expect(cpu.samples.count == 60)
        #expect(cpu.samples == Array(values.suffix(60)))
    }

    // menu-bar-widget — "Partial history"
    @Test func aPartialHistoryKeepsEveryStoredSample() throws {
        let values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7]
        let cpu = try #require(Self.reading(.cpu, history: Self.history(values)))

        #expect(cpu.samples == values)
    }

    // menu-bar-widget — "Empty history"
    @Test func anEmptyHistoryProducesNoSamples() throws {
        let cpu = try #require(Self.reading(.cpu))

        #expect(cpu.samples.isEmpty)
    }

    // menu-bar-widget — "MEM placeholder still has a sparkline": the MEM reading
    // carries no samples until M3, so its sparkline area renders empty.
    @Test func theMemoryModuleStaysAPlaceholder() throws {
        let values = (0..<120).map { Double($0) / 120 }
        let memory = try #require(
            Self.reading(.memory, snapshot: Self.snapshot(total: 0.9), history: Self.history(values))
        )

        #expect(memory.samples.isEmpty)
        #expect(memory.valueText == "0%")
    }

    // menu-bar-widget — "Equal data compares equal"
    @Test func readingsBuiltFromTheSameStateCompareEqual() {
        let history = Self.history([0.1, 0.2, 0.3])
        let snapshot = Self.snapshot(total: 0.3)

        let first = StatusItemReadings.build(snapshot: snapshot, history: history)
        let second = StatusItemReadings.build(snapshot: snapshot, history: history)

        #expect(first == second)
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
        let view = NSHostingView(rootView: StatusItemContent(readings: [reading]))
        view.layoutSubtreeIfNeeded()
        return view.fittingSize.width
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
    // The 230 pt budget exists so the widget can breathe. Pinning the spacing
    // keeps a future width squeeze from collapsing the gaps instead of raising
    // the budget again.
    @Test func theLayoutKeepsItsReadableSpacing() async {
        let element = await StatusItemMetrics.elementSpacing
        let module = await StatusItemMetrics.moduleSpacing
        let padding = await StatusItemMetrics.horizontalPadding

        #expect(element == 4)
        #expect(module == 6)
        #expect(padding == 2)
    }

    // menu-bar-widget — "Fixed-width, jitter-free layout"
    @Test func theValueFrameFitsTheWidestPercentage() async {
        let width = await StatusItemMetrics.valueWidth

        #expect(width >= Self.measuredWidth("100%"))
        #expect(width < 40)
    }

    // menu-bar-widget — "Width budget"
    @Test func theMeasurementReadingsRenderFullScaleForEveryModule() async {
        let readings = await StatusItemMetrics.measurementReadings

        #expect(readings.map(\.module) == MetricModule.menuBarOrder)
        #expect(readings.allSatisfy { $0.valueText == "100%" })
        #expect(readings.allSatisfy { $0.samples.count == StatusItemReadings.sampleCount })
    }

    // menu-bar-widget — "Every module renders a sparkline",
    // "MEM placeholder still has a sparkline"
    //
    // The sparkline area is structural: a module reserves it even with no
    // samples, so a module that skipped it could not reach this width.
    @Test(arguments: MetricModule.menuBarOrder)
    func everyModuleReservesItsSparklineArea(module: MetricModule) async {
        let reading = ModuleReading(module: module, samples: [], valueText: "0%")

        let width = await Self.contentWidth(for: reading)
        let sparkline = await StatusItemMetrics.sparklineWidth
        let value = await StatusItemMetrics.valueWidth

        #expect(width >= sparkline + value)
        #expect(width < sparkline + value + 40, "the module reserved more than one label and one sparkline")
    }
}
