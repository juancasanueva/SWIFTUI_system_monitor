import SwiftUI

/// The detail panel shown in the popover.
///
/// Container view: it reads `MetricsState` from the environment and hands plain
/// values to the presentational cards, so both cards keep updating while the
/// popover is open.
struct PanelView: View {

    @Environment(MetricsState.self) private var state

    private static let width: CGFloat = 320
    private static let spacing: CGFloat = 12
    private static let padding: CGFloat = 12

    var body: some View {
        VStack(spacing: Self.spacing) {
            CPUCard(snapshot: state.cpu, history: state.cpuHistory)
            MemoryCard(snapshot: state.memory, history: state.memoryHistory)
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .background(Palette.panelBackground)
    }
}

#Preview("Panel — no snapshot") {
    PanelView()
        .environment(MetricsState())
}

#Preview("Panel — live snapshot") {
    let state = MetricsState()
    let cores = (0..<8).map { CoreUsage(index: $0, usage: 0.7, level: .performance) }
        + (8..<12).map { CoreUsage(index: $0, usage: 0.1, level: .efficiency) }

    for step in 0..<CPUCardModel.graphCapacity {
        state.apply(
            cpu: CPUSnapshot(
                total: 0.45 + 0.35 * sin(Double(step) / 9),
                user: 0.306,
                system: 0.096,
                performanceAverage: 0.706,
                efficiencyAverage: 0.098,
                cores: cores
            )
        )
        state.apply(
            memory: MemorySnapshot(
                total: 8_589_934_592,
                app: 1_460_961_280,
                wired: 1_986_560_000,
                compressed: 1_954_283_520,
                cached: 901_120_000,
                free: 1_762_721_792,
                used: 5_926_092_800
            )
        )
    }

    return PanelView()
        .environment(state)
}
