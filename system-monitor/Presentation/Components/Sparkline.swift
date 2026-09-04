import SwiftUI

/// Layout of a sample series inside a fixed drawing area.
///
/// The x axis is pinned to `capacity`, not to the number of samples, so a
/// history that is still filling up grows from the right edge instead of
/// stretching. Kept pure and `nonisolated` so the geometry is unit tested
/// without rendering a view.
nonisolated enum SparklineGeometry {

    /// Points for `samples`, oldest first, right-aligned inside `size`.
    ///
    /// Only the newest `capacity` samples are used. Values are clamped to
    /// `0...1` and inverted, so `1` sits on the top edge. Returns an empty
    /// array when there is nothing to draw or the area is degenerate.
    static func points(samples: [Double], capacity: Int, size: CGSize) -> [CGPoint] {
        guard capacity > 0, size.width > 0, size.height > 0 else { return [] }

        let visible = Array(samples.suffix(capacity))
        guard !visible.isEmpty else { return [] }

        let step = capacity > 1 ? size.width / CGFloat(capacity - 1) : 0
        let newest = visible.count - 1

        return visible.enumerated().map { offset, value in
            let fromEnd = CGFloat(newest - offset)
            let clamped = value.isNaN ? 0 : min(max(value, 0), 1)
            return CGPoint(
                x: size.width - step * fromEnd,
                y: size.height * (1 - clamped)
            )
        }
    }

    /// Filled area under the sample line, closed along the bottom edge.
    static func areaPath(points: [CGPoint], in size: CGSize) -> Path {
        var path = Path()
        guard let first = points.first, let last = points.last else { return path }

        path.move(to: CGPoint(x: first.x, y: size.height))
        path.addLine(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: last.x, y: size.height))
        path.closeSubpath()
        return path
    }

    /// Open line through the samples.
    static func linePath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    /// Opacity of the filled area under the line.
    static let fillOpacity: Double = 0.35

    /// Stroke width of the sample line, in points.
    static let lineWidth: CGFloat = 1
}

/// Compact filled area chart used inside the menu bar item.
///
/// `Equatable` so identical sample arrays skip the redraw at the 1 Hz sampling
/// cadence (menu-bar-widget "Equal data compares equal").
struct Sparkline: View, Equatable {

    /// Samples oldest first; fewer than `capacity` values render right-aligned.
    let samples: [Double]

    /// Number of slots on the x axis, fixing the horizontal scale.
    let capacity: Int

    let color: Color

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
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

#Preview("Sparkline") {
    VStack(alignment: .leading, spacing: 8) {
        Sparkline(
            samples: (0..<60).map { Double($0) / 60 },
            capacity: 60,
            color: Palette.cpuAccent
        )
        .frame(width: 60, height: 14)

        Sparkline(samples: [0.2, 0.9, 0.4], capacity: 60, color: Palette.cpuAccent)
            .frame(width: 60, height: 14)

        Sparkline(samples: [], capacity: 60, color: Palette.cpuAccent)
            .frame(width: 60, height: 14)
    }
    .padding()
    .background(Palette.panelBackground)
}
