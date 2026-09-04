import SwiftUI

/// One vertical per-core usage bar with its integer percentage underneath.
struct CoreBar: View, Equatable {

    /// Core usage, clamped to `0...1`.
    let usage: Double

    let color: Color

    /// Pre-formatted percentage, for example `"73%"`.
    let label: String

    private static let barHeight: CGFloat = 34
    private static let cornerRadius: CGFloat = 2
    private static let trackOpacity: Double = 0.18
    private static let labelFontSize: CGFloat = 9

    private var clampedUsage: Double {
        usage.isNaN ? 0 : min(max(usage, 0), 1)
    }

    var body: some View {
        VStack(spacing: 3) {
            Canvas(opaque: false, rendersAsynchronously: false) { context, size in
                let track = Path(
                    roundedRect: CGRect(origin: .zero, size: size),
                    cornerRadius: Self.cornerRadius
                )
                context.fill(track, with: .color(color.opacity(Self.trackOpacity)))

                let filledHeight = size.height * clampedUsage
                guard filledHeight > 0 else { return }

                let filled = Path(
                    roundedRect: CGRect(
                        x: 0,
                        y: size.height - filledHeight,
                        width: size.width,
                        height: filledHeight
                    ),
                    cornerRadius: Self.cornerRadius
                )
                context.fill(filled, with: .color(color))
            }
            .frame(height: Self.barHeight)

            Text(label)
                .font(.system(size: Self.labelFontSize).monospacedDigit())
                .foregroundStyle(Palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(label)
    }
}

#Preview("Core bar") {
    HStack(spacing: 4) {
        CoreBar(usage: 0, color: Palette.cpuAccent, label: "0%")
        CoreBar(usage: 0.734, color: Palette.cpuAccent, label: "73%")
        CoreBar(usage: 1, color: Palette.cpuEfficiency, label: "100%")
    }
    .frame(width: 120)
    .padding()
    .background(Palette.cardBackground)
}
