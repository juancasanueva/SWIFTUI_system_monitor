import SwiftUI

/// The detail panel shown in the popover.
///
/// Container view: it reads `MetricsState` from the environment and hands plain
/// values to the presentational cards, so the CPU card keeps updating while the
/// popover is open. Memory stays a placeholder until M3.
struct PanelView: View {

    @Environment(MetricsState.self) private var state

    private static let width: CGFloat = 320
    private static let spacing: CGFloat = 12
    private static let padding: CGFloat = 12

    var body: some View {
        VStack(spacing: Self.spacing) {
            CPUCard(snapshot: state.cpu, history: state.cpuHistory)
            PlaceholderCard(title: "Memory")
        }
        .padding(Self.padding)
        .frame(width: Self.width)
        .background(Palette.panelBackground)
    }
}

/// A card skeleton with a title and a placeholder message.
private struct PlaceholderCard: View {

    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("No data yet")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            Palette.cardBackground,
            in: RoundedRectangle(cornerRadius: Palette.cardCornerRadius)
        )
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
    }

    return PanelView()
        .environment(state)
}
