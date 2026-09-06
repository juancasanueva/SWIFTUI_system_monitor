import Foundation

/// A metric shown in the menu bar widget and the detail panel.
///
/// The module list is data-driven so a new module (for example GPU in v2)
/// can be added by appending a case and registering it in `menuBarOrder`.
nonisolated enum MetricModule: String, CaseIterable, Sendable, Identifiable {
    case cpu
    case memory

    var id: String { rawValue }

    /// Short label rendered in the menu bar next to the value.
    var label: String {
        switch self {
        case .cpu: "CPU"
        case .memory: "MEM"
        }
    }

    /// Default left-to-right order of the modules in the menu bar widget; the
    /// effective order is `Settings.menuBarModules`, which the user edits.
    static var menuBarOrder: [MetricModule] {
        [.cpu, .memory]
    }
}
