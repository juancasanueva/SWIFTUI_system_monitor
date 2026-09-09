import SwiftUI

/// One card slot of the detail panel, top to bottom.
///
/// The order lives in `PanelView.cards` as a pure array, the panel analogue of
/// `DiskCardModel.sections`: "CPU, Memory, Disk" (DC-1) is an assertion on a
/// value rather than a rendering inspection, and the body is a switch, so the
/// two cannot drift apart.
nonisolated enum PanelCard: Sendable, Equatable, CaseIterable, Identifiable {
    case cpu
    case memory
    case disk

    var id: Self { self }
}

/// The detail panel shown in the popover.
///
/// Container view: it reads `MetricsState` from the environment and hands plain
/// values to the presentational cards, so every card keeps updating while the
/// popover is open. The panel has no fixed height: it grows with its cards, and
/// each card renders its full skeleton before its first reading, so the popover
/// does not resize when a snapshot lands.
struct PanelView: View {

    @Environment(MetricsState.self) private var state

    /// Card order, top to bottom (DC-1).
    nonisolated static let cards: [PanelCard] = [.cpu, .memory, .disk]

    private static let width: CGFloat = 320
    private static let spacing: CGFloat = 12
    private static let padding: CGFloat = 12

    var body: some View {
        VStack(spacing: Self.spacing) {
            ForEach(Self.cards) { card in
                self.card(card)
            }
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .background(Palette.panelBackground)
    }

    @ViewBuilder
    private func card(_ card: PanelCard) -> some View {
        switch card {
        case .cpu: CPUCard(snapshot: state.cpu, history: state.cpuHistory)
        case .memory: MemoryCard(snapshot: state.memory, history: state.memoryHistory)
        case .disk: DiskCard(snapshot: state.disk)
        }
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

    state.apply(
        disk: DiskSnapshot(
            total: 494_354_000_000,
            free: 62_286_000_000,
            readBytesPerSecond: 27_100_000,
            writeBytesPerSecond: 2_200_000
        )
    )

    return PanelView()
        .environment(state)
}
