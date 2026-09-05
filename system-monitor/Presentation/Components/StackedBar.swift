import SwiftUI

/// Layout of proportional segments inside a fixed drawing area.
///
/// Segments are laid out left to right at their share of the full width. The
/// cumulative offset is clamped to the width, so a set of fractions that sums
/// above 1 fills the bar instead of drawing past its edge. Kept pure and
/// `nonisolated` so the geometry is unit tested without rendering a view.
nonisolated enum StackedBarGeometry {

    /// Rects for `fractions`, in order, spanning `size` from the left edge.
    ///
    /// A zero, negative or NaN fraction yields a zero-width rect at the current
    /// offset rather than being dropped, so a rect keeps its index and the
    /// following segments stay in place. Returns an empty array when the
    /// drawing area is degenerate.
    static func rects(fractions: [Double], in size: CGSize) -> [CGRect] {
        guard size.width > 0, size.height > 0 else { return [] }

        var x: CGFloat = 0
        return fractions.map { fraction in
            let clamped = fraction.isNaN ? 0 : max(fraction, 0)
            let available = size.width - x
            let width = min(CGFloat(clamped) * size.width, available)
            let rect = CGRect(x: x, y: 0, width: width, height: size.height)
            x += width
            return rect
        }
    }
}

/// Horizontal bar splitting one total into coloured proportional segments.
///
/// Drawn with `Canvas` and clipped to a capsule so the whole bar stays in one
/// layer at the 1 Hz refresh rate. `Equatable` so unchanged segments skip the
/// redraw, matching the other canvas components.
struct StackedBar: View, Equatable {

    /// One coloured slice of the bar.
    nonisolated struct Segment: Sendable, Equatable {

        /// Share of the whole bar, `0...1`.
        let fraction: Double

        let color: Color
    }

    /// Segments in drawing order, left to right. Empty renders the track only.
    let segments: [Segment]

    private static let trackOpacity: Double = 0.18

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: false) { context, size in
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Palette.textSecondary.opacity(Self.trackOpacity))
            )

            let rects = StackedBarGeometry.rects(fractions: segments.map(\.fraction), in: size)
            for (segment, rect) in zip(segments, rects) where rect.width > 0 {
                context.fill(Path(rect), with: .color(segment.color))
            }
        }
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

#Preview("Stacked bar") {
    VStack(spacing: 12) {
        StackedBar(segments: [
            StackedBar.Segment(fraction: 0.17, color: Palette.memAccent),
            StackedBar.Segment(fraction: 0.06, color: Palette.memAccent),
            StackedBar.Segment(fraction: 0.23, color: Palette.memWired),
            StackedBar.Segment(fraction: 0.23, color: Palette.memCompressed),
            StackedBar.Segment(fraction: 0.11, color: Palette.memCached),
            StackedBar.Segment(fraction: 0.20, color: Palette.memFree)
        ])
        .frame(height: 8)

        StackedBar(segments: [])
            .frame(height: 8)
    }
    .padding()
    .frame(width: 296)
    .background(Palette.cardBackground)
}
