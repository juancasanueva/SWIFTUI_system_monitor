import AppKit
import SwiftUI

/// One module's rendered data in the menu bar item.
///
/// A plain value so the presentational content is testable without a state
/// object and skips redraws when nothing changed.
nonisolated struct ModuleReading: Sendable, Equatable, Identifiable {

    let module: MetricModule

    /// Sparkline samples, oldest first. Empty for a module without live data.
    let samples: [Double]

    /// Whole-percent text such as `"42%"`.
    let valueText: String

    var id: String { module.id }
}

/// Builds the menu bar readings from the published metrics.
///
/// Pure and `nonisolated`: the mapping from state to rendered values is the
/// widget's behaviour, so it is unit tested without rendering a view.
nonisolated enum StatusItemReadings {

    /// Number of history samples the menu bar sparkline shows.
    static let sampleCount = 60

    /// One reading per module in `modules`, in that order (MBW-1).
    ///
    /// `modules` is the user's chosen subset (`SettingsState.menuBarModules`,
    /// default `MetricModule.menuBarOrder`), so a hidden module produces no
    /// reading and a reordered list reorders the widget. Each module binds to
    /// its own pair of published values: CPU to the CPU snapshot and history,
    /// MEM to the memory snapshot and history. Both read `0%` with an empty
    /// sparkline until their first snapshot arrives, so the widget never
    /// renders a static placeholder.
    static func build(
        modules: [MetricModule],
        cpu: CPUSnapshot?,
        cpuHistory: MetricHistory,
        memory: MemorySnapshot?,
        memoryHistory: MetricHistory
    ) -> [ModuleReading] {
        modules.map { module in
            switch module {
            case .cpu:
                ModuleReading(
                    module: .cpu,
                    samples: cpuHistory.suffix(sampleCount),
                    valueText: PercentFormatter.integer(cpu?.total ?? 0)
                )
            case .memory:
                ModuleReading(
                    module: .memory,
                    samples: memoryHistory.suffix(sampleCount),
                    valueText: PercentFormatter.integer(memory?.fraction ?? 0)
                )
            }
        }
    }
}

/// Fixed layout constants of the status item content.
///
/// Every width here is constant, so the rendered widget can never be wider than
/// the same content measured from `measurementReadings`
/// (menu-bar-widget "Fixed-width, jitter-free layout").
@MainActor
enum StatusItemMetrics {

    /// Width of a module sparkline, in points. Every module reserves it,
    /// whether or not it has samples to draw.
    static let sparklineWidth: CGFloat = 40

    /// Height of a module sparkline, in points.
    static let sparklineHeight: CGFloat = 14

    /// Spacing between the label, sparkline and value of one module.
    ///
    /// Two 40 pt sparklines, two labels and two `"100%"` value frames occupy
    /// 195 pt on their own, so readable gaps only fit inside the 230 pt budget
    /// (menu-bar-widget R1.7). The measured widget is 221 pt.
    static let elementSpacing: CGFloat = 4

    /// Spacing between two modules.
    static let moduleSpacing: CGFloat = 6

    /// Inset on each side of the widget.
    static let horizontalPadding: CGFloat = 2

    /// Font of the value text: 11 pt with monospaced digits.
    static let valueFont = Font.system(size: 11).monospacedDigit()

    /// Font of the module label: 11 pt semibold.
    static let labelFont = Font.system(size: 11, weight: .semibold)

    /// Width of the value frame, measured from `"100%"` so a changing value
    /// never resizes the widget.
    static let valueWidth: CGFloat = {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        let measured = ("100%" as NSString).size(withAttributes: [.font: font]).width
        return measured.rounded(.up)
    }()

    /// Widest content `modules` can render: every one of them at `"100%"` with
    /// a full sparkline, in the given order.
    ///
    /// A function rather than a constant because the module set is the user's
    /// (MBW-1): the status item is re-measured from this whenever that set
    /// changes, and never for a value tick (MBW-9).
    static func measurementReadings(for modules: [MetricModule]) -> [ModuleReading] {
        modules.map { module in
            ModuleReading(
                module: module,
                samples: Array(repeating: 1, count: StatusItemReadings.sampleCount),
                valueText: PercentFormatter.integer(1)
            )
        }
    }
}

/// Presentational status item content: one label per reading, no environment.
///
/// `Equatable` so SwiftUI skips the whole widget body while the readings stand
/// still, and each label is `.equatable()` so an unchanged module is skipped
/// even when its neighbour moved (MBW-14).
struct StatusItemContent: View, Equatable {

    let readings: [ModuleReading]

    var body: some View {
        HStack(spacing: StatusItemMetrics.moduleSpacing) {
            ForEach(readings) { reading in
                ModuleLabel(reading: reading)
                    .equatable()
            }
        }
        .padding(.horizontal, StatusItemMetrics.horizontalPadding)
        .fixedSize()
    }
}

/// Container reading the published metrics and the user's module list from the
/// environment.
///
/// It forwards the module list and both metric pairs to `StatusItemReadings`;
/// the mapping itself lives there so it stays testable without rendering this
/// view.
struct StatusItemView: View {

    @Environment(MetricsState.self) private var state

    /// The user's module list (MBW-1). Optional because the status item is
    /// hosted before the composition root exists in every preview and in the
    /// controller path that has no `SettingsState` yet; an absent settings
    /// object falls back to the ST-1 default order rather than trapping.
    @Environment(SettingsState.self) private var settings: SettingsState?

    private var modules: [MetricModule] {
        settings?.menuBarModules ?? MetricModule.menuBarOrder
    }

    var body: some View {
        StatusItemContent(
            readings: StatusItemReadings.build(
                modules: modules,
                cpu: state.cpu,
                cpuHistory: state.cpuHistory,
                memory: state.memory,
                memoryHistory: state.memoryHistory
            )
        )
        .equatable()
    }
}

/// Root of the status item hosting view, injecting the shared state.
struct StatusItemRootView: View {

    let state: MetricsState

    /// The settings object, when the composition root has one. `nil` keeps the
    /// default module order (see `StatusItemView.settings`).
    var settings: SettingsState? = nil

    var body: some View {
        StatusItemView()
            .environment(state)
            .environment(settings)
    }
}

/// A module abbreviation, its sparkline and its current value.
///
/// The label and sparkline carry the module accent; the value uses the system
/// label colour so it stays legible on dark and light menu bars
/// (menu-bar-widget "Legibility"). `Equatable` and internal rather than
/// private, so MBW-14 pins the redraw-gating contract directly on the unit
/// SwiftUI skips.
struct ModuleLabel: View, Equatable {

    let reading: ModuleReading

    var body: some View {
        HStack(spacing: StatusItemMetrics.elementSpacing) {
            Text(reading.module.label)
                .font(StatusItemMetrics.labelFont)
                .foregroundStyle(reading.module.accent)

            Sparkline(
                samples: reading.samples,
                capacity: StatusItemReadings.sampleCount,
                color: reading.module.accent
            )
            .equatable()
            .frame(
                width: StatusItemMetrics.sparklineWidth,
                height: StatusItemMetrics.sparklineHeight
            )

            Text(reading.valueText)
                .font(StatusItemMetrics.valueFont)
                .foregroundStyle(.primary)
                .frame(width: StatusItemMetrics.valueWidth, alignment: .trailing)
        }
    }
}

#Preview("Status item") {
    let state = MetricsState()

    return StatusItemRootView(state: state)
        .padding()
}

#Preview("Status item at full scale") {
    StatusItemContent(
        readings: StatusItemMetrics.measurementReadings(for: MetricModule.menuBarOrder)
    )
    .padding()
}

#Preview("Status item with MEM hidden") {
    StatusItemContent(readings: StatusItemMetrics.measurementReadings(for: [.cpu]))
        .padding()
}
