import Foundation

/// One credit line of the About window: a role and the person holding it.
nonisolated struct AboutCredit: Sendable, Equatable, Identifiable {

    let role: String
    let name: String

    var id: String { role + name }
}

/// One link row of the About window.
nonisolated struct AboutLink: Sendable, Equatable, Identifiable {

    /// Row label, for example `"Website"`.
    let label: String

    /// The visible link text, for example the host without its scheme.
    let text: String

    let url: URL

    var id: String { label + text }
}

/// Everything the About window renders (MBW-15).
///
/// A plain value so the version wording, the credits and the links are unit
/// tested without a window, and so the view can compare two builds.
nonisolated struct AboutInfo: Sendable, Equatable {

    let appName: String
    let tagline: String

    /// Marketing version and build, for example `"1.0.0 (7)"`.
    let versionText: String

    let credits: [AboutCredit]
    let links: [AboutLink]

    /// License line under the cards.
    let license: String

    /// Closing line under the license.
    let footer: String
}

/// Pure content of the About window (MBW-15).
///
/// Identity, credits and links are constants: they describe the project, not
/// the build, so a renamed target cannot change them. Only the version is read
/// from the bundle, through the info dictionary the caller passes, which is
/// what keeps this testable without `Bundle.main`.
nonisolated enum AboutModel {

    static let appName = "System Monitor"
    static let tagline = "CPU, memory, disk and network at a glance, from your menu bar."
    static let license = "MIT license"
    static let footer = "Made with care using SwiftUI"

    private static let unknownVersion = "Unknown"

    private static let credits = [
        AboutCredit(role: "Developer", name: "Juan Casanueva"),
        AboutCredit(role: "Tester", name: "Sebasti\u{00E1}n Casanueva"),
        AboutCredit(role: "Tester", name: "Rodrigo Casanueva"),
    ]

    private static let links = [
        AboutLink(
            label: "Website",
            text: "github.com/juancasanueva/SWIFTUI_system_monitor",
            url: URL(string: "https://github.com/juancasanueva/SWIFTUI_system_monitor")!
        ),
        AboutLink(
            label: "Developer",
            text: "juancasanueva.vercel.app",
            url: URL(string: "https://juancasanueva.vercel.app")!
        ),
        AboutLink(
            label: "Email",
            text: "juancasanueva@gmail.com",
            url: URL(string: "mailto:juancasanueva@gmail.com")!
        ),
    ]

    /// Builds the window content from an Info.plist dictionary, normally
    /// `Bundle.main.infoDictionary`.
    static func info(bundleInfo: [String: Any]) -> AboutInfo {
        AboutInfo(
            appName: appName,
            tagline: tagline,
            versionText: versionText(
                shortVersion: bundleInfo["CFBundleShortVersionString"] as? String,
                build: bundleInfo["CFBundleVersion"] as? String
            ),
            credits: credits,
            links: links,
            license: license,
            footer: footer
        )
    }

    /// `"<version> (<build>)"`, the wording Finder's Get Info uses.
    ///
    /// A missing build leaves the bare version; a missing version reads
    /// `"Unknown"` rather than an empty row, whatever the build says.
    static func versionText(shortVersion: String?, build: String?) -> String {
        guard let shortVersion, !shortVersion.isEmpty else { return unknownVersion }
        guard let build, !build.isEmpty else { return shortVersion }
        return "\(shortVersion) (\(build))"
    }
}
