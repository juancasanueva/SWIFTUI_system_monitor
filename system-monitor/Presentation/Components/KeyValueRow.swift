import SwiftUI

/// A label on the left and its value on the right, used by the panel cards.
struct KeyValueRow: View {

    let key: String
    let value: String
    var valueColor: Color = Palette.textPrimary

    private static let fontSize: CGFloat = 12

    var body: some View {
        HStack(spacing: 8) {
            Text(key)
                .font(.system(size: Self.fontSize))
                .foregroundStyle(Palette.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: Self.fontSize).monospacedDigit())
                .foregroundStyle(valueColor)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Key value rows") {
    VStack(spacing: 6) {
        KeyValueRow(key: "User", value: "30.6%")
        KeyValueRow(key: "System", value: "9.6%")
        KeyValueRow(key: "P-Cores", value: "70.6%", valueColor: Palette.cpuAccent)
        KeyValueRow(key: "E-Cores", value: "9.8%", valueColor: Palette.cpuEfficiency)
    }
    .frame(width: 160)
    .padding()
    .background(Palette.cardBackground)
}
