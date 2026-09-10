import Foundation
import Testing

/// Reads `system-monitor.xcodeproj/project.pbxproj` off disk.
///
/// Deliberately self-contained: the update slice is a net-new, independently
/// revertible change, and rollback should be the deletion of its own files
/// rather than the unpicking of a shared helper. The `#filePath` anchor is used
/// because the test runner promises nothing about the working directory.
nonisolated enum UpdateProjectSources {

    static let projectFile = "system-monitor.xcodeproj/project.pbxproj"

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // system-monitorTests
            .deletingLastPathComponent()   // repository root
    }

    static func projectText() throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent(projectFile), encoding: .utf8)
    }

    /// Every `XCBuildConfiguration` body in the project file, as text.
    ///
    /// A build setting is only meaningful inside the configuration that owns it:
    /// "the file contains `INFOPLIST_FILE = …;`" would be satisfied by a single
    /// occurrence in a single configuration, and this change must land its
    /// settings in **both** app-target blocks or the Debug and Release bundles
    /// stop agreeing about which feed they trust. So the file is cut into blocks
    /// first and every assertion is made per block. A block runs from its `isa`
    /// line to the two-tab `};` that closes it; the three-tab `};` closing the
    /// inner `buildSettings` dictionary cannot be mistaken for it.
    static func buildConfigurationBlocks() throws -> [String] {
        let marker = "isa = XCBuildConfiguration;"
        let terminator = "\n\t\t};"
        return try projectText()
            .components(separatedBy: marker)
            .dropFirst()
            .map { chunk in
                guard let end = chunk.range(of: terminator) else { return chunk }
                return String(chunk[chunk.startIndex..<end.lowerBound])
            }
    }

    /// The two configurations that build the shipped app.
    ///
    /// The closing quote is load-bearing: `"com.juancasanueva.system-monitorTests"`
    /// also starts with `com.juancasanueva.system-monitor`, and a test target
    /// must never be mistaken for an app target.
    static func appTargetBuildConfigurationBlocks() throws -> [String] {
        try buildConfigurationBlocks()
            .filter { $0.contains("PRODUCT_BUNDLE_IDENTIFIER = \"com.juancasanueva.system-monitor\";") }
    }

    /// How many app-target configuration blocks declare `setting`.
    static func appTargetBlocksDeclaring(_ setting: String) throws -> Int {
        try appTargetBuildConfigurationBlocks().filter { $0.contains(setting) }.count
    }

    /// The two configurations that build the unit-test bundle.
    static func unitTestBuildConfigurationBlocks() throws -> [String] {
        try buildConfigurationBlocks()
            .filter { $0.contains("PRODUCT_BUNDLE_IDENTIFIER = \"com.juancasanueva.system-monitorTests\";") }
    }

    /// The body of one `/* Begin … section */ … /* End … section */` pair.
    ///
    /// An empty string when the section does not exist, which is a real answer
    /// rather than a missing one: the project had no `XCRemoteSwiftPackageReference`
    /// section at all before this change, so "the section is absent" and "the
    /// section is present but empty" must both read as zero entries.
    static func section(_ name: String, in project: String) -> String {
        guard let start = project.range(of: "/* Begin \(name) section */"),
              let end = project.range(of: "/* End \(name) section */"),
              start.upperBound <= end.lowerBound
        else { return "" }
        return String(project[start.upperBound..<end.lowerBound])
    }

    /// Every multi-line object in a section, cut at the two-tab `};` that closes it.
    static func objectBlocks(inSection name: String, of project: String) -> [String] {
        let body = section(name, in: project)
        guard !body.isEmpty else { return [] }
        return Array(body.components(separatedBy: "\n\t\t};").dropLast())
    }

    static func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return haystack.components(separatedBy: needle).count - 1
    }

    /// The app target's frameworks phase, told apart from the two empty
    /// test-target phases by the only product the app links.
    static func appTargetFrameworksBuildPhase(in project: String) throws -> String {
        let phases = objectBlocks(inSection: "PBXFrameworksBuildPhase", of: project)
        return try #require(phases.first { $0.contains("Sparkle in Frameworks */,") })
    }

    /// The `packageReferences` list on the project object.
    static func packageReferences(in project: String) throws -> String {
        let opening = "\t\t\tpackageReferences = (\n"
        let start = try #require(project.range(of: opening))
        let rest = project[start.upperBound...]
        let end = try #require(rest.range(of: "\n\t\t\t);"))
        return String(rest[rest.startIndex..<end.lowerBound])
    }
}

// app-updates — AU-2 "The update dependency is declared once, pinned, and
// nothing else in the project can substitute it", plus the build-setting half of
// AU-3.
//
// Structural, over text, because these are claims about what the repository
// declares rather than about what a test-host binary happens to contain.
@Suite("Update project file", .timeLimit(.minutes(1)))
struct UpdateProjectFileTests {

    private static let partialInfoPlist = "INFOPLIST_FILE = \"Resources/SystemMonitor-Info.plist\";"
    private static let applicationCategory =
        "INFOPLIST_KEY_LSApplicationCategoryType = \"public.app-category.utilities\";"

    // app-updates — AU-3: the partial property list is merged by **both**
    // configurations, and the generator is still running.
    //
    // The two are asserted together on purpose: this is a *merge*, not a
    // replacement, and every key the generator contributes — `LSUIElement`
    // included, which is what keeps the app out of the Dock — only survives
    // while the generator stays on. Setting the file and turning the generator
    // off would still ship `SUFeedURL` and would silently strip the rest.
    @Test func bothAppConfigurationsMergeThePartialPropertyList() throws {
        let blocks = try UpdateProjectSources.appTargetBuildConfigurationBlocks()

        #expect(blocks.count == 2)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring(Self.partialInfoPlist) == 2)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("GENERATE_INFOPLIST_FILE = YES;") == 2)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring(Self.applicationCategory) == 2)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("INFOPLIST_KEY_LSUIElement = YES;") == 2)
    }

    // app-updates — AU-2 "The updater replaces the bundle in place": an app that
    // rewrites its own bundle cannot be sandboxed, and the two configurations
    // must agree or a Debug build would prove nothing about a Release one. The
    // hardened runtime stays on, because it is what notarisation requires and it
    // does not stand in the updater's way.
    @Test func bothAppConfigurationsShipUnsandboxedOnAppleSilicon() throws {
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("ENABLE_APP_SANDBOX = NO;") == 2)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("ENABLE_APP_SANDBOX = YES;") == 0)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("ENABLE_HARDENED_RUNTIME = YES;") == 2)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("ARCHS = arm64;") == 2)
    }

    // app-updates — AU-2: the shipped bundle is named once, in both
    // configurations, and the module keeps the name the tests import. Renaming
    // the product without pinning `PRODUCT_MODULE_NAME` would silently rename
    // the Swift module and break every `@testable import`.
    @Test func bothAppConfigurationsNameTheProductAndKeepTheModuleName() throws {
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("PRODUCT_NAME = \"System-Monitor\";") == 2)
        #expect(try UpdateProjectSources.appTargetBlocksDeclaring("PRODUCT_MODULE_NAME = system_monitor;") == 2)
        #expect(
            try UpdateProjectSources
                .appTargetBlocksDeclaring("INFOPLIST_KEY_CFBundleDisplayName = \"System-Monitor\";") == 2
        )
    }

    // app-updates — AU-2: the unit-test bundle is loaded into the renamed host.
    // A stale `TEST_HOST` does not fail the build; it fails every test at launch
    // with a missing bundle, which is exactly the failure a renamed product
    // introduces silently.
    @Test func theUnitTestBundleLoadsTheRenamedHost() throws {
        let blocks = try UpdateProjectSources.unitTestBuildConfigurationBlocks()
        let host = "TEST_HOST = \"$(BUILT_PRODUCTS_DIR)/System-Monitor.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/System-Monitor\";"

        #expect(blocks.count == 2)
        #expect(blocks.filter { $0.contains(host) }.count == 2)
        #expect(blocks.filter { $0.contains("BUNDLE_LOADER = \"$(TEST_HOST)\";") }.count == 2)
    }

    // app-updates — AU-2 "exactly one pinned updater package, and no embed phase".
    //
    // Counts rather than presences, because a package dependency that appears
    // twice is as broken as one that points at the wrong version: Xcode will
    // happily resolve two references to the same repository with different
    // requirements. `exactVersion 2.9.6` is pinned because the update channel's
    // whole trust story rests on a known signing tool and a known framework, and
    // a range would let either drift on a clean resolve.
    //
    // The `PBXCopyFilesBuildPhase` count of **0** is the load-bearing one:
    // Sparkle auto-embeds into `Contents/Frameworks`, so an Embed Frameworks
    // phase arriving later from an Xcode UI edit would silently double-sign the
    // framework.
    @Test func theProjectLinksExactlyOnePinnedSparklePackageWithNoEmbedPhase() throws {
        let project = try UpdateProjectSources.projectText()

        let remote = UpdateProjectSources.objectBlocks(
            inSection: "XCRemoteSwiftPackageReference",
            of: project
        )
        let sparkle = try #require(
            remote.first { $0.contains("repositoryURL = \"https://github.com/sparkle-project/Sparkle\";") }
        )
        #expect(remote.count == 1)
        #expect(sparkle.contains("kind = exactVersion;"))
        #expect(sparkle.contains("version = 2.9.6;"))

        let references = try UpdateProjectSources.packageReferences(in: project)
        #expect(
            UpdateProjectSources.occurrences(
                of: "XCRemoteSwiftPackageReference \"Sparkle\"",
                in: references
            ) == 1
        )

        let buildFiles = UpdateProjectSources.section("PBXBuildFile", in: project)
        #expect(
            UpdateProjectSources.occurrences(
                of: "/* Sparkle in Frameworks */ = {isa = PBXBuildFile;",
                in: buildFiles
            ) == 1
        )

        let phase = try UpdateProjectSources.appTargetFrameworksBuildPhase(in: project)
        #expect(UpdateProjectSources.occurrences(of: "/* Sparkle in Frameworks */,", in: phase) == 1)

        let products = UpdateProjectSources.objectBlocks(
            inSection: "XCSwiftPackageProductDependency",
            of: project
        )
        #expect(products.filter { $0.contains("productName = Sparkle;") }.count == 1)

        #expect(UpdateProjectSources.occurrences(of: "PBXCopyFilesBuildPhase", in: project) == 0)
    }
}
