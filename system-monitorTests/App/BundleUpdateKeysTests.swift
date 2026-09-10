import Foundation
import Testing

/// Reads the partial property list off disk, anchored to this file.
///
/// Self-contained rather than shared: the update slice must roll back by
/// deleting its own files. The `#filePath` anchor is used because the test
/// runner promises nothing about the working directory.
nonisolated enum UpdateBundleSources {

    static let partialInfoPlist = "Resources/SystemMonitor-Info.plist"

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // system-monitorTests
            .deletingLastPathComponent()   // repository root
    }

    static func url(_ relativePath: String) -> URL {
        repositoryRoot.appendingPathComponent(relativePath)
    }

    /// The partial property list as a dictionary, parsed the way the build
    /// system parses it rather than read as text. A file that looks right and
    /// does not parse is a build failure nobody sees until an archive.
    static func partialInfoPlistContents() throws -> [String: Any] {
        let data = try Data(contentsOf: url(partialInfoPlist))
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try #require(parsed as? [String: Any])
    }
}

// app-updates — AU-3 "The feed the running app trusts is fixed inside the
// bundle" and AU-4 (the bundle half).
//
// Everything here reads `Bundle.main`, not the repository, because the claims
// are about the values a delivered copy of System Monitor actually carries. A
// test that only read the partial property list off disk would pass for a build
// that never merged it, which is the exact failure this suite exists to catch.
@Suite("Bundle update keys", .timeLimit(.minutes(1)))
struct BundleUpdateKeysTests {

    private static let applicationCategory = "public.app-category.utilities"
    private static let feedURL = "https://juancasanueva.github.io/SWIFTUI_system_monitor/appcast.xml"

    /// The three keys the updater framework reads to decide, on its own, whether
    /// to check for updates and whether to ask the user to let it. None of them
    /// may exist anywhere in the bundle: the app's own persisted preference is
    /// the authority, written to the updater at launch.
    private static let frameworkAutomaticCheckKeys = [
        "SUEnableAutomaticChecks",
        "SUAutomaticallyUpdate",
        "SUScheduledCheckInterval",
    ]

    // app-updates — AU-3: the category the Finder inspector reads. The exact
    // value rather than mere presence, because a category of the wrong kind is
    // as wrong as no category at all.
    @Test func theBundleReportsTheUtilitiesApplicationCategory() throws {
        let info = try #require(Bundle.main.infoDictionary)
        let value = try #require(info["LSApplicationCategoryType"] as? String)

        #expect(value == Self.applicationCategory)
    }

    // app-updates — AU-3 "The bundle carries the exact feed URL and a
    // well-formed verification key".
    //
    // The feed is asserted as the exact string and then again for its scheme,
    // because "starts with the right host" would pass for an `http` downgrade,
    // and the whole point of compiling the key in is that the transport is not
    // the thing being trusted.
    //
    // The key is asserted by *decoded length*, not character count. A
    // 44-character base64 string is what an Ed25519 public key looks like, but so
    // is any 32 bytes of noise with the right padding, and `Data(base64Encoded:)`
    // silently returns `nil` for a string that only looks right. Decoding to
    // exactly 32 bytes is the narrowest claim a placeholder cannot satisfy.
    @Test func theBundleCarriesTheFeedAndA32ByteVerificationKey() throws {
        let info = try #require(Bundle.main.infoDictionary)

        let feed = try #require(info["SUFeedURL"] as? String)
        #expect(feed == Self.feedURL)
        let url = try #require(URL(string: feed))
        #expect(url.scheme == "https")

        let key = try #require(info["SUPublicEDKey"] as? String)
        #expect(!key.isEmpty)
        let decoded = try #require(Data(base64Encoded: key))
        #expect(decoded.count == 32)
    }

    // app-updates — AU-4 "No bundled default can enable checking".
    //
    // An exact key set rather than an absence list. An absence list only forbids
    // the three keys someone thought of; the framework reads more than three,
    // and the next one it learns to read would arrive unnoticed. Two keys,
    // named, is the only form of this assertion that stays true as the framework
    // grows.
    //
    // The bundle half matters separately from the file half: the generator
    // merges this file into the generated `Info.plist`, and a key could in
    // principle reach the bundle from the generator rather than from here.
    @Test func thePartialPropertyListCarriesOnlyTheFeedAndTheKey() throws {
        let contents = try UpdateBundleSources.partialInfoPlistContents()

        #expect(contents.keys.sorted() == ["SUFeedURL", "SUPublicEDKey"])
        #expect(contents["SUFeedURL"] as? String == Self.feedURL)

        for key in Self.frameworkAutomaticCheckKeys {
            #expect(contents[key] == nil, "\(key) may never be bundled")
        }

        let info = try #require(Bundle.main.infoDictionary)
        for key in Self.frameworkAutomaticCheckKeys {
            #expect(info[key] == nil, "\(key) reached the merged bundle")
        }
        // The sweep over the bundle is only meaningful if it read a real bundle.
        #expect(info["CFBundleIdentifier"] as? String == "com.juancasanueva.system-monitor")
    }
}
