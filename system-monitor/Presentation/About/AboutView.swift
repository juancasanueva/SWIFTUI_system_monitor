import AppKit
import SwiftUI

/// The About window content (MBW-15): identity header, version, credits and
/// links, laid out as panel-style cards on the panel background.
///
/// Presentational and environment-free: everything it shows arrives as one
/// `AboutInfo` value, so the window controller can host it with nothing else.
struct AboutView: View {

    let info: AboutInfo

    /// Fixed content width; the window is sized from it and is not resizable.
    static let width: CGFloat = 340

    /// The app icon from the bundled asset catalog.
    ///
    /// Resolved by name rather than through `NSApp.applicationIconImage`: that
    /// accessor returns the generic application icon whenever Launch Services
    /// has not registered the running process, which is the case under the
    /// test runner and can be for other launch paths. The asset catalog is
    /// always in the main bundle. The generic icon remains the fallback only
    /// for a bundle that ships without an `AppIcon` set.
    static var icon: NSImage {
        NSImage(named: "AppIcon") ?? NSApp.applicationIconImage
    }

    private static let iconSize: CGFloat = 72
    private static let outerPadding: CGFloat = 20
    private static let cardSpacing: CGFloat = 16
    private static let rowPadding: CGFloat = 12

    var body: some View {
        VStack(spacing: Self.cardSpacing) {
            header

            card([
                .text(label: "Application", value: info.appName),
                .text(label: "Version", value: info.versionText),
            ])

            sectionTitle("Credits")

            card(info.credits.map { .text(label: $0.role, value: $0.name) })

            card(info.links.map { .link($0) })

            VStack(spacing: 4) {
                Text(info.license)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                Text(info.footer)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.cpuAccent)
            }
            .padding(.top, 4)
        }
        .padding(Self.outerPadding)
        .frame(width: Self.width)
        .background(Palette.panelBackground)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(nsImage: Self.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: Self.iconSize, height: Self.iconSize)

            VStack(alignment: .leading, spacing: 4) {
                Text(info.appName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(info.tagline)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Self.rowPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Palette.cardBackground,
            in: RoundedRectangle(cornerRadius: Palette.cardCornerRadius)
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(Palette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom, -8)
    }

    /// Rows stacked on one card with a hairline between each pair, never
    /// before the first or after the last.
    private func card(_ rows: [AboutCardRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle()
                        .fill(Palette.textSecondary.opacity(0.18))
                        .frame(height: 1)
                        .padding(.horizontal, Self.rowPadding)
                }
                switch row {
                case let .text(label, value):
                    AboutRow(label: label, value: value)
                case let .link(link):
                    AboutLinkRow(link: link)
                }
            }
        }
        .background(
            Palette.cardBackground,
            in: RoundedRectangle(cornerRadius: Palette.cardCornerRadius)
        )
    }
}

/// One row of an About card.
private enum AboutCardRow {
    case text(label: String, value: String)
    case link(AboutLink)
}

/// A bold label on the left and a plain value on the right.
private struct AboutRow: View {

    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

/// Like `AboutRow`, with the value as a link that opens in the default app.
private struct AboutLinkRow: View {

    let link: AboutLink

    var body: some View {
        HStack(spacing: 8) {
            Text(link.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 8)
            Link(destination: link.url) {
                HStack(spacing: 4) {
                    Text(link.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "arrow.up.forward.square")
                        .font(.system(size: 11))
                }
                .font(.system(size: 13))
                .foregroundStyle(Palette.cpuAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

/// Root the About window hosts.
struct AboutRootView: View {

    let info: AboutInfo

    var body: some View {
        AboutView(info: info)
    }
}

#Preview("About") {
    AboutRootView(
        info: AboutModel.info(bundleInfo: [
            "CFBundleShortVersionString": "1.0.0",
            "CFBundleVersion": "1",
        ])
    )
}
