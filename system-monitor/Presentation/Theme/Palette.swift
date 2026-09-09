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

    /// Memory gauge, history graph, and the App part of the stacked bar.
    static let memAccent = sRGB(0xF5A623)

    /// Wired segment of the memory bar.
    static let memWired = sRGB(0xE5484D)

    /// Compressed segment of the memory bar.
    static let memCompressed = sRGB(0xF5D90A)

    /// Cached segment of the memory bar. Shares its value with `cpuAccent`:
    /// two tokens, one colour, because the two bars are never adjacent.
    static let memCached = sRGB(0x4D8DFF)

    /// Free segment of the memory bar.
    static let memFree = sRGB(0x3DD68C)

    /// Disk gauge, throughput icons, and the disk card header glyph. Shares its
    /// value with `memFree`: two tokens, one colour, because the disk ring and
    /// the memory bar are never adjacent.
    static let diskAccent = sRGB(0x3DD68C)

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
/// of SwiftUI.
nonisolated extension MetricModule {
    var accent: Color {
        switch self {
        case .cpu: Palette.cpuAccent
        case .memory: Palette.memAccent
        }
    }
}
