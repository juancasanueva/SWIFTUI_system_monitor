import SwiftUI

/// One line of a `HistoryGraph`.
///
/// Declared at the top level rather than nested inside the main-actor view so
/// it stays `nonisolated` and `Sendable`; `Color` is `Sendable` (`CPUCardRow`
/// precedent). The fill lives on the series, not on the graph, so a card can
/// stroke two bare lines whose crossing stays readable while the single-series
/// cards keep their filled area (network-card NC-9).
nonisolated struct HistoryGraphSeries: Sendable, Equatable {

    /// Samples oldest first, already normalised to `0...1` by the caller.
    let samples: [Double]

    let color: Color

    /// Opacity of the filled area under the line; `0` strokes the line only.
    let fillOpacity: Double

    init(samples: [Double], color: Color, fillOpacity: Double = SparklineGeometry.fillOpacity) {
        self.samples = samples
        self.color = color
        self.fillOpacity = fillOpacity
    }
}

/// Full-width area graph of the recent history shown inside a panel card.
///
/// Same geometry as `Sparkline` at panel scale, plus a baseline so the card
/// reads as a chart rather than a floating shape. Draws N series over that one
/// shared baseline in a single `Canvas`, in array order, so the x axes stay
/// aligned. `Equatable` so an unchanged history skips the redraw (cpu-card
/// R3.7).
struct HistoryGraph: View, Equatable {

    /// Lines to draw, first underneath. Each carries its own colour and fill.
    let series: [HistoryGraphSeries]

    /// Number of slots on the x axis, fixing the horizontal scale for every
    /// series; fewer than `capacity` samples render right-aligned.
    let capacity: Int

    init(series: [HistoryGraphSeries], capacity: Int) {
        self.series = series
        self.capacity = capacity
    }

    /// Single-series convenience, so the CPU and Memory call sites are unchanged.
    init(samples: [Double], capacity: Int, color: Color) {
        self.init(
            series: [HistoryGraphSeries(samples: samples, color: color)],
            capacity: capacity
        )
    }

    /// Pure geometry seam: one point array per series, in draw order.
    ///
    /// A series with no samples contributes an empty array rather than being
    /// dropped, so the result stays index-aligned with `series`.
    nonisolated static func points(
        series: [HistoryGraphSeries],
        capacity: Int,
        size: CGSize
    ) -> [[CGPoint]] {
        series.map {
            SparklineGeometry.points(samples: $0.samples, capacity: capacity, size: size)
        }
    }

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

            let geometry = Self.points(series: series, capacity: capacity, size: size)
            for (line, points) in zip(series, geometry) {
                guard !points.isEmpty else { continue }

                if line.fillOpacity > 0 {
                    context.fill(
                        SparklineGeometry.areaPath(points: points, in: size),
                        with: .color(line.color.opacity(line.fillOpacity))
                    )
                }
                context.stroke(
                    SparklineGeometry.linePath(points: points),
                    with: .color(line.color),
                    lineWidth: SparklineGeometry.lineWidth
                )
            }
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

        HistoryGraph(
            series: [
                HistoryGraphSeries(
                    samples: (0..<120).map { 0.5 + 0.4 * sin(Double($0) / 8) },
                    color: Palette.networkDownload,
                    fillOpacity: 0
                ),
                HistoryGraphSeries(
                    samples: (0..<120).map { 0.5 + 0.4 * cos(Double($0) / 11) },
                    color: Palette.networkUpload,
                    fillOpacity: 0
                )
            ],
            capacity: 120
        )
        .frame(height: 48)

        HistoryGraph(
            series: [
                HistoryGraphSeries(samples: [0.2, 0.6, 0.3], color: Palette.networkDownload, fillOpacity: 0),
                HistoryGraphSeries(samples: [], color: Palette.networkUpload, fillOpacity: 0)
            ],
            capacity: 120
        )
        .frame(height: 48)
    }
    .padding()
    .frame(width: 296)
    .background(Palette.cardBackground)
}
