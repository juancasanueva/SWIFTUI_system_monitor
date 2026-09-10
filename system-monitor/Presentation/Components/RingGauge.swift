import SwiftUI

/// Circular gauge showing one fraction with its value and a caption.
///
/// The ring is drawn with `Canvas` rather than shapes so the track, the arc,
/// and the text stay in one layer at the 1 Hz refresh rate.
struct RingGauge: View, Equatable {

    /// Value to render, clamped to `0...1`.
    let fraction: Double

    let color: Color

    /// Pre-formatted value, for example `"40.2%"`.
    let valueText: String

    /// Caption under the value, for example `"CPU"`.
    let subtitle: String

    private static let diameter: CGFloat = 84
    private static let lineWidth: CGFloat = 8
    private static let trackOpacity: Double = 0.18
    private static let valueFontSize: CGFloat = 16
    private static let subtitleFontSize: CGFloat = 11

    private var clampedFraction: Double {
        fraction.isNaN ? 0 : min(max(fraction, 0), 1)
    }

    var body: some View {
        ZStack {
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                let inset = Self.lineWidth / 2
                let box = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)

                context.stroke(
                    Path(ellipseIn: box),
                    with: .color(color.opacity(Self.trackOpacity)),
                    style: StrokeStyle(lineWidth: Self.lineWidth)
                )

                guard clampedFraction > 0 else { return }

                var arc = Path()
                arc.addArc(
                    center: CGPoint(x: box.midX, y: box.midY),
                    radius: box.width / 2,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(-90 + 360 * clampedFraction),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round)
                )
            }

            VStack(spacing: 2) {
                Text(valueText)
                    .font(.system(size: Self.valueFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: Self.subtitleFontSize))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle)
        .accessibilityValue(valueText)
    }
}

#Preview("Ring gauge") {
    HStack(spacing: 16) {
        RingGauge(fraction: 0, color: Palette.cpuAccent, valueText: "0.0%", subtitle: "CPU")
        RingGauge(fraction: 0.402, color: Palette.cpuAccent, valueText: "40.2%", subtitle: "CPU")
        RingGauge(fraction: 1, color: Palette.cpuAccent, valueText: "100.0%", subtitle: "CPU")
    }
    .padding()
    .background(Palette.cardBackground)
}
