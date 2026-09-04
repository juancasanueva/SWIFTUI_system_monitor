import SwiftUI

/// A titled group of per-core bars, wrapped so no row holds more than eight.
///
/// Wrapping is a static pure function so the layout rule is unit tested without
/// rendering (cpu-card "16 P-cores wrap").
struct CoreBarGrid: View {

    /// Group heading, for example `"P-Cores"`, `"E-Cores"`, or `"Cores"`.
    let title: String

    /// Cores in snapshot order; the order is preserved across rows.
    let cores: [CoreUsage]

    let color: Color

    /// Maximum number of bars on one row.
    nonisolated static let maxPerRow = 8

    private static let titleFontSize: CGFloat = 10
    private static let barSpacing: CGFloat = 4
    private static let rowSpacing: CGFloat = 6

    /// Splits `cores` into consecutive rows of at most `maxPerRow` bars.
    nonisolated static func rows(for cores: [CoreUsage]) -> [[CoreUsage]] {
        guard !cores.isEmpty else { return [] }
        return stride(from: 0, to: cores.count, by: maxPerRow).map { start in
            Array(cores[start..<min(start + maxPerRow, cores.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Self.rowSpacing) {
            Text(title)
                .font(.system(size: Self.titleFontSize, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)

            ForEach(Array(Self.rows(for: cores).enumerated()), id: \.offset) { _, row in
                HStack(spacing: Self.barSpacing) {
                    ForEach(row) { core in
                        CoreBar(
                            usage: core.usage,
                            color: color,
                            label: PercentFormatter.integer(core.usage)
                        )
                        .equatable()
                        .frame(maxWidth: .infinity)
                    }
                    // Invisible fillers keep a short last row's bars the same
                    // width as the bars of a full row.
                    ForEach(row.count..<Self.maxPerRow, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Core bar grid") {
    VStack(alignment: .leading, spacing: 12) {
        CoreBarGrid(
            title: "P-Cores",
            cores: (0..<8).map { CoreUsage(index: $0, usage: Double($0) / 8, level: .performance) },
            color: Palette.cpuAccent
        )
        CoreBarGrid(
            title: "E-Cores",
            cores: (8..<12).map { CoreUsage(index: $0, usage: 0.1, level: .efficiency) },
            color: Palette.cpuEfficiency
        )
    }
    .padding()
    .frame(width: 296)
    .background(Palette.cardBackground)
}
