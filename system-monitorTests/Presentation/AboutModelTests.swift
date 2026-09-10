import Foundation
import Testing
@testable import system_monitor

// menu-bar-widget — MBW-15 "About window".
//
// The window's content is a pure table derived from the bundle's info
// dictionary, so the version wording, the credits and the links are pinned
// here without a window, a bundle or AppKit.
@Suite("About model", .timeLimit(.minutes(1)))
struct AboutModelTests {

    private static var bundleInfo: [String: Any] { [
        "CFBundleShortVersionString": "1.0.0",
        "CFBundleVersion": "7",
    ] }

    // MBW-15 "Version reads the bundle": marketing version, then the build in
    // parentheses, which is what the Finder's Get Info shows.
    @Test func theVersionTextJoinsTheMarketingVersionAndTheBuild() {
        #expect(AboutModel.versionText(shortVersion: "1.0.0", build: "7") == "1.0.0 (7)")
    }

    // A bundle with no build number still shows its version, and a bundle
    // with neither never renders an empty string.
    @Test func theVersionTextDegradesWithoutABuildOrAVersion() {
        #expect(AboutModel.versionText(shortVersion: "1.0.0", build: nil) == "1.0.0")
        #expect(AboutModel.versionText(shortVersion: nil, build: "7") == "Unknown")
        #expect(AboutModel.versionText(shortVersion: nil, build: nil) == "Unknown")
    }

    // MBW-15 "Version reads the bundle": the keys are the standard Info.plist
    // ones, read from the dictionary the caller passes.
    @Test func theInfoReadsTheVersionFromTheBundleDictionary() {
        let info = AboutModel.info(bundleInfo: Self.bundleInfo)

        #expect(info.versionText == "1.0.0 (7)")
    }

    // MBW-15 "Identity": the name and tagline are constants, never read from
    // the bundle, so a renamed target cannot change what the window says.
    @Test func theInfoCarriesTheAppIdentity() {
        let info = AboutModel.info(bundleInfo: [:])

        #expect(info.appName == "System Monitor")
        #expect(info.tagline.isEmpty == false)
        #expect(info.license == "MIT license")
        #expect(info.footer == "Made with care using SwiftUI")
    }

    // MBW-15 "Credits and links": the developer credit and the three links, in
    // the order the window lists them. Every link is an absolute URL, and only
    // the email one uses the mailto scheme.
    @Test func theInfoListsTheCreditsAndLinksInOrder() throws {
        let info = AboutModel.info(bundleInfo: [:])

        #expect(info.credits.map(\.role) == ["Developer", "Tester", "Tester"])
        #expect(info.credits.map(\.name) == ["Juan Casanueva", "Sebasti\u{00E1}n Casanueva", "Rodrigo Casanueva"])

        #expect(info.links.map(\.label) == ["Website", "Developer", "Email"])
        #expect(info.links.allSatisfy { $0.url.scheme != nil })
        #expect(info.links.map { $0.url.scheme } == ["https", "https", "mailto"])
        #expect(info.links.allSatisfy { $0.text.isEmpty == false })
    }

    // MBW-15: plain values, so two builds from the same dictionary are
    // interchangeable and the view can compare them.
    @Test func twoBuildsFromTheSameDictionaryAreEqual() {
        #expect(AboutModel.info(bundleInfo: Self.bundleInfo) == AboutModel.info(bundleInfo: Self.bundleInfo))
        #expect(AboutModel.info(bundleInfo: Self.bundleInfo) != AboutModel.info(bundleInfo: [:]))
    }
}
