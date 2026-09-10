import Foundation
import Testing

/// The app target's own source, comment-stripped.
///
/// Every claim in this suite is an **absence** — "no other file names this
/// type", "nothing writes this key at run time" — and an absence cannot be
/// proved by importing the thing it is about. Comments are stripped so a
/// prohibition described in a doc comment is never mistaken for one violated in
/// code: this very file's neighbours explain in prose exactly what they must not
/// do.
nonisolated enum UpdateAppSources {

    nonisolated struct Source: Sendable, Hashable {
        /// File name, e.g. `SparkleUpdateChecker.swift`.
        let name: String
        /// Path relative to the repository root.
        let path: String
        /// The file's Swift code with every comment removed.
        let code: String
    }

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // system-monitorTests
            .deletingLastPathComponent()   // repository root
    }

    /// Only the shipped app target. The test bundle is deliberately outside the
    /// sweep: a test double naming a forbidden symbol is not a shipped surface.
    static var appSourceRoot: URL {
        repositoryRoot.appendingPathComponent("system-monitor", isDirectory: true)
    }

    static func load() throws -> [Source] {
        let rootPath = repositoryRoot.standardizedFileURL.path
        guard let enumerator = FileManager.default.enumerator(at: appSourceRoot, includingPropertiesForKeys: nil)
        else { return [] }

        var sources: [Source] = []
        while let candidate = enumerator.nextObject() as? URL {
            guard candidate.pathExtension == "swift" else { continue }
            let text = try String(contentsOf: candidate, encoding: .utf8)
            sources.append(
                Source(
                    name: candidate.lastPathComponent,
                    path: candidate.standardizedFileURL.path
                        .replacingOccurrences(of: rootPath + "/", with: ""),
                    code: strippingComments(text)
                )
            )
        }
        return sources.sorted { $0.path < $1.path }
    }

    /// Removes line and block comments, leaving string literals alone.
    ///
    /// String literals have to be tracked, not merely skipped over: the About
    /// view carries `"https://…"` URLs, and a stripper that treated the `//`
    /// inside them as a comment would silently delete the rest of those lines
    /// and weaken every absence asserted here into a vacuous pass.
    static func strippingComments(_ source: String) -> String {
        var output = ""
        var characters = Array(source)
        var index = 0
        var inString = false
        var inLineComment = false
        var blockDepth = 0

        while index < characters.count {
            let character = characters[index]
            let next = index + 1 < characters.count ? characters[index + 1] : nil

            if inLineComment {
                if character == "\n" {
                    inLineComment = false
                    output.append(character)
                }
                index += 1
                continue
            }

            if blockDepth > 0 {
                if character == "*", next == "/" {
                    blockDepth -= 1
                    index += 2
                    continue
                }
                if character == "/", next == "*" {
                    blockDepth += 1
                    index += 2
                    continue
                }
                if character == "\n" { output.append(character) }
                index += 1
                continue
            }

            if inString {
                if character == "\\", next != nil {
                    output.append(character)
                    output.append(characters[index + 1])
                    index += 2
                    continue
                }
                if character == "\"" { inString = false }
                output.append(character)
                index += 1
                continue
            }

            if character == "/", next == "/" {
                inLineComment = true
                index += 2
                continue
            }
            if character == "/", next == "*" {
                blockDepth = 1
                index += 2
                continue
            }
            if character == "\"" {
                inString = true
                output.append(character)
                index += 1
                continue
            }

            output.append(character)
            index += 1
        }

        characters = []
        return output
    }
}

// app-updates — AU-7 "The updater reaches nothing but the updater", and the
// structural halves of AU-3 and AU-4.
@Suite("Update composition", .timeLimit(.minutes(1)))
struct UpdateCompositionTests {

    private static let checkerFile = "SparkleUpdateChecker.swift"

    /// Files under `Presentation/`. Every update surface must speak to the port,
    /// so the real updater and an in-memory one stay interchangeable.
    private static func presentationSources(in sources: [UpdateAppSources.Source]) -> [UpdateAppSources.Source] {
        sources.filter { $0.path.contains("/Presentation/") }
    }

    // app-updates — AU-7 "Exactly one file imports the updater framework".
    //
    // The count is what matters. "SparkleUpdateChecker imports Sparkle" would
    // still be true on the day a second file did too, and the second file is the
    // one that would quietly spread framework types through the app.
    @Test func exactlyOneFileImportsTheUpdaterFramework() throws {
        let sources = try UpdateAppSources.load()
        let importers = sources.filter { $0.code.contains("import Sparkle") }

        #expect(importers.map(\.name) == [Self.checkerFile])
        // The sweep is only meaningful if it read the app target at all.
        #expect(sources.count > 40)
    }

    // app-updates — AU-7 "No user-interface file names the framework's types".
    @Test func onlyTheCheckerNamesTheFrameworksUpdaterTypes() throws {
        let sources = try UpdateAppSources.load()

        for type in ["SPUStandardUpdaterController", "SPUUpdater", "SUUpdater"] {
            let naming = sources.filter { $0.code.contains(type) }.map(\.name)
            #expect(naming.allSatisfy { $0 == Self.checkerFile }, "\(type) escaped the checker")
        }

        let checker = try #require(sources.first { $0.name == Self.checkerFile })
        #expect(checker.code.contains("SPUStandardUpdaterController"))
    }

    // app-updates — AU-7: no Presentation file names the concrete checker, so
    // every update surface renders identically over an in-memory updater and a
    // test can never construct something that reaches the network.
    @Test func noPresentationFileNamesTheConcreteChecker() throws {
        let sources = try UpdateAppSources.load()
        let presentation = Self.presentationSources(in: sources)

        let offenders = presentation
            .filter { $0.code.contains("SparkleUpdateChecker") }
            .map(\.name)

        #expect(offenders == [])
        // The filter is only meaningful if it found surfaces to filter.
        #expect(presentation.count > 20)
        #expect(presentation.contains { $0.name == "SettingsView.swift" })
        #expect(presentation.contains { $0.name == "StatusItemController.swift" })

        // The composition root is the one place allowed to name it: dependency
        // injection is exactly the job an app delegate is there to do.
        let namers = sources.filter { $0.code.contains("SparkleUpdateChecker") }.map(\.name)
        #expect(namers.sorted() == ["AppDelegate.swift", Self.checkerFile])
    }

    // app-updates — AU-3 "Nothing in the app can substitute a different feed or
    // key at run time".
    //
    // This is the other half of the key-material guard: that one proves no
    // second key is *committed*, this one proves no key or feed can be
    // *supplied* while the app runs. A key an attacker can supply is a key an
    // attacker can supply, which is the entire security argument for compiling
    // it in.
    @Test func nothingInTheAppCanSubstituteADifferentFeedOrKey() throws {
        let sources = try UpdateAppSources.load()

        for override in ["SPUUpdaterDelegate", "feedURLString(for:", "setFeedURL", "updater.feedURL"] {
            let offenders = sources.filter { $0.code.contains(override) }.map(\.name)
            #expect(offenders == [], "\(override) is a runtime feed override")
        }

        for key in ["SUFeedURL", "SUPublicEDKey"] {
            let offenders = sources.filter { $0.code.contains(key) }.map(\.name)
            #expect(offenders == [], "\(key) is named in app source rather than only in the bundle")
        }
    }

    // app-updates — AU-4 "No framework prompt can enable checking", structural
    // half: the preference is applied **before** the updater starts.
    //
    // Order, not presence. Left unset, the framework asks the user on second
    // launch whether to enable automatic checks — a system alert the app never
    // wanted and cannot style. Writing the preference first means the value is
    // already there when the updater starts, so the prompt has nothing to ask
    // about. Starting first and writing second would show it once, on exactly
    // the launch nobody tests.
    @Test func thePreferenceIsAppliedBeforeTheUpdaterStarts() throws {
        let sources = try UpdateAppSources.load()
        let checker = try #require(sources.first { $0.name == Self.checkerFile })

        let apply = try #require(checker.code.range(of: "AutomaticUpdateChecksPolicy.apply("))
        let start = try #require(checker.code.range(of: "startUpdater()"))

        #expect(apply.lowerBound < start.lowerBound)
        #expect(checker.code.contains("startingUpdater: false"))
    }

    // app-updates — AU-6 "The Updates section renders nothing inert": exactly
    // two controls, both with behaviour behind them.
    //
    // The count of accessibility identifiers is the assertion that actually
    // forbids a third row: naming the two that must exist would still pass on
    // the day an update-channel picker was added beside them. This app has no
    // channels — a prerelease never enters the feed at all — so such a picker
    // would be a control that changes nothing.
    @Test func theUpdatesSectionDeclaresExactlyTheToggleAndTheLastCheckedLabel() throws {
        let sources = try UpdateAppSources.load()
        let form = try #require(sources.first { $0.name == "SettingsView.swift" })

        let identifiers = ["updates-automatic-toggle", "updates-last-checked"]
        for identifier in identifiers {
            #expect(form.code.contains("accessibilityIdentifier(\"\(identifier)\")"))
        }
        let declared = form.code.components(separatedBy: "accessibilityIdentifier(").count - 1
        #expect(declared == identifiers.count)

        #expect(!form.code.lowercased().contains("channel"))
    }
}
