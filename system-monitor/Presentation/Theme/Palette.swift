import SwiftUI

/// Colour tokens from PRD section 7.1.
///
/// The palette is kept as Swift constants rather than an asset catalog: the
/// app is dark-only in v1, and the light variants are a later milestone.
nonisolated enum Palette {

    /// Popover background.
    static let panelBackground = sRGB(0x0F1522)

    /// Card surface inside the panel.
    static let cardBackground = sRGB(0x1A2131)

    /// Corner radius of a card surface, in points. Cards carry no border.
    static let cardCornerRadius: CGFloat = 12

    /// Values and headline text.
    static let textPrimary = sRGB(0xF2F4F8)

    /// Labels and secondary captions.
    static let textSecondary = sRGB(0x8A93A6)

    /// CPU gauge, history graph, and performance-core values.
    static let cpuAccent = sRGB(0x4D8DFF)

    /// Efficiency-core values and bars.
    static let cpuEfficiency = sRGB(0x3FC1C9)

    /// Memory gauge and graph.
    static let memAccent = sRGB(0xF5A623)

    /// Builds an opaque sRGB colour from a `0xRRGGBB` literal.
    private static func sRGB(_ hex: UInt32) -> Color {
        Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// Presentation-layer accent for each metric module.
///
/// The mapping lives here, not in the Domain enum, so `MetricModule` stays free
/// of SwiftUI. Memory keeps its palette accent as a placeholder until M3.
nonisolated extension MetricModule {
    var accent: Color {
        switch self {
        case .cpu: Palette.cpuAccent
        case .memory: Palette.memAccent
        }
    }
}
