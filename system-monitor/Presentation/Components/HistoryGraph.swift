import SwiftUI

/// Full-width area graph of the recent history shown inside a panel card.
///
/// Same geometry as `Sparkline` at panel scale, plus a baseline so the card
/// reads as a chart rather than a floating shape. `Equatable` so an unchanged
/// history skips the redraw (cpu-card R3.7).
struct HistoryGraph: View, Equatable {

    /// Samples oldest first; fewer than `capacity` values render right-aligned.
    let samples: [Double]

    /// Number of slots on the x axis, fixing the horizontal scale.
    let capacity: Int

    let color: Color

    private static let baselineOpacity: Double = 0.25
    private static let baselineWidth: CGFloat = 1

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: size.height))
            baseline.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(
                baseline,
                with: .color(Palette.textSecondary.opacity(Self.baselineOpacity)),
                lineWidth: Self.baselineWidth
            )

            let points = SparklineGeometry.points(samples: samples, capacity: capacity, size: size)
            guard !points.isEmpty else { return }

            context.fill(
                SparklineGeometry.areaPath(points: points, in: size),
                with: .color(color.opacity(SparklineGeometry.fillOpacity))
            )
            context.stroke(
                SparklineGeometry.linePath(points: points),
                with: .color(color),
                lineWidth: SparklineGeometry.lineWidth
            )
        }
        .accessibilityHidden(true)
    }
}

#Preview("History graph") {
    VStack(spacing: 12) {
        HistoryGraph(
            samples: (0..<120).map { 0.5 + 0.4 * sin(Double($0) / 8) },
            capacity: 120,
            color: Palette.cpuAccent
        )
        .frame(height: 48)

        HistoryGraph(samples: [0.2, 0.6, 0.3], capacity: 120, color: Palette.cpuAccent)
            .frame(height: 48)

        HistoryGraph(samples: [], capacity: 120, color: Palette.cpuAccent)
            .frame(height: 48)
    }
    .padding()
    .frame(width: 296)
    .background(Palette.cardBackground)
}
