import CryptoKit
import Foundation
import Testing

@testable import system_monitor

/// Reads `scripts/appcast.sh` off disk.
///
/// Self-contained rather than importing `ReleasePipelineSources`, on the same
/// reasoning that helper itself records: the publication half of this slice is
/// independently revertible, and rollback should be the deletion of one script
/// and one test file.
nonisolated enum AppcastScriptSources {

    static let scriptPath = "scripts/appcast.sh"

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // system-monitorTests
            .deletingLastPathComponent()   // repository root
    }

    static var scriptURL: URL { repositoryRoot.appendingPathComponent(scriptPath) }

    static func script() throws -> String {
        try String(contentsOf: scriptURL, encoding: .utf8)
    }

    /// Every invocation of `command` as a **command token**.
    ///
    /// A bare substring search is not good enough. `gh` occurs inside
    /// "github.com", which this script names in every enclosure URL, and `git`
    /// occurs inside "gitignored". A prohibition that fires on prose, or on a
    /// hostname, is a prohibition someone eventually weakens to shut it up — so
    /// it fires only on an actual invocation: start of line, or after whitespace,
    /// `;`, `|`, `&` or `(`, and followed by whitespace or the end of the line.
    static func commandInvocations(of command: String, in text: String) -> [String] {
        let pattern = "(?:^|[\\s;|&(])\(NSRegularExpression.escapedPattern(for: command))(?=\\s|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        return text.split(separator: "\n", omittingEmptySubsequences: false).flatMap { line -> [String] in
            let text = String(line)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.matches(in: text, range: range).compactMap { match in
                guard let matched = Range(match.range, in: text) else { return nil }
                let start = text[matched].hasPrefix(command) ? matched.lowerBound
                    : text.index(after: matched.lowerBound)
                return String(text[start...])
            }
        }
    }

    static func lines(naming needle: String, in text: String) -> [String] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.contains(needle) }
    }
}

// release-distribution — what the appcast script is allowed to do, and what it
// must never do.
//
// Structural assertions over text, because the properties that matter here are
// absences — "it cannot publish", "it cannot trace itself", "the key is never
// written anywhere" — and an absence in a shell script is only provable by
// reading it.
@Suite("Appcast script contract", .timeLimit(.minutes(1)))
struct AppcastScriptContractTests {

    static let signPipeline = "printf '%s' \"$SPARKLE_PRIVATE_KEY\" |"

    // MARK: - The script's own posture

    /// It exists, it runs, and it fails loudly.
    @Test("The appcast script is executable and fails on the first error")
    func theScriptIsExecutableAndFailsLoudly() throws {
        let path = AppcastScriptSources.scriptURL.path

        #expect(FileManager.default.fileExists(atPath: path))
        #expect(FileManager.default.isExecutableFile(atPath: path))
        #expect(try AppcastScriptSources.script().contains("set -euo pipefail"))
    }

    /// It cannot publish, tag, retract, or pick a different repository.
    ///
    /// The release workflow's own guarantee is that it can only ever *create* a
    /// release: exactly one `gh release create`, zero `git`. A script invoked
    /// from that workflow with a `git` or a second `gh` in it would move the
    /// guarantee without touching the test that guards it, which is precisely why
    /// the script is asserted separately.
    @Test("The appcast script contains no git and no gh invocation")
    func theScriptCannotPublishOrSelectARepository() throws {
        let script = try AppcastScriptSources.script()

        #expect(AppcastScriptSources.commandInvocations(of: "git", in: script) == [])
        #expect(AppcastScriptSources.commandInvocations(of: "gh", in: script) == [])
        // The reader is only meaningful if it can find an invocation at all.
        #expect(!AppcastScriptSources.commandInvocations(of: "curl", in: script).isEmpty)
    }

    /// It never traces its own commands.
    ///
    /// `set -x` would echo the signing pipeline into the job log, and the signing
    /// pipeline is where the private key is.
    ///
    /// Matched as a command token rather than as a substring: the script explains
    /// in a comment *why* it must never trace itself, and a prohibition that
    /// fires on prose about itself is a prohibition someone eventually deletes to
    /// shut it up.
    @Test("The appcast script never traces itself")
    func theScriptNeverTracesItself() throws {
        let script = try AppcastScriptSources.script()

        #expect(AppcastScriptSources.commandInvocations(of: "set -x", in: script) == [])
        // The reader is only meaningful if it can see a `set` that is really there.
        #expect(!AppcastScriptSources.commandInvocations(of: "set", in: script).isEmpty)
    }

    /// The signing tool is pinned by version **and** by digest.
    ///
    /// A tampered `sign_update` would sign the release with an attacker's key and
    /// every installed copy would accept the result, because the client only
    /// checks the signature against the key in its own bundle. The version alone
    /// does not prevent that; the digest does, and the verification aborts before
    /// anything is signed.
    @Test("The signing tool is pinned to 2.9.6 by a sha256 literal")
    func theSigningToolIsPinnedByDigest() throws {
        let script = try AppcastScriptSources.script()
        let digest = try NSRegularExpression(pattern: "\\b[0-9a-f]{64}\\b")
        let range = NSRange(script.startIndex..<script.endIndex, in: script)

        #expect(script.contains("2.9.6"))
        #expect(digest.numberOfMatches(in: script, range: range) == 1)
        #expect(script.contains("shasum -a 256"))
    }

    /// The private key reaches the tool on **stdin** and touches nothing else.
    ///
    /// Never a file, never a command argument, never a redirection target. The
    /// signing tool reads `--ed-key-file -` from standard input precisely so the
    /// key can come from a secret environment binding without ever being written
    /// down, which satisfies the invariant by construction rather than by
    /// remembering to clean up afterwards.
    @Test("The private key is only ever piped on stdin")
    func thePrivateKeyIsOnlyEverPipedOnStdin() throws {
        let script = try AppcastScriptSources.script()
        let naming = AppcastScriptSources.lines(naming: "SPARKLE_PRIVATE_KEY", in: script)

        #expect(!naming.isEmpty)
        for line in naming {
            let isComment = line.trimmingCharacters(in: .whitespaces).hasPrefix("#")
            #expect(isComment || line.contains(Self.signPipeline), "unsafe use: \(line)")
            #expect(!line.contains(">"), "the key must never be a redirection target: \(line)")
        }
        #expect(script.contains("--ed-key-file -"))
        #expect(!script.contains("--ed-key-file \""))
    }

    // MARK: - The emitter and the validator agree on names

    /// Every name the offline validator requires appears in the emitter.
    ///
    /// **Honest about being textual.** The fixtures the validator is tested
    /// against are hand-authored, because running this script inside
    /// `xcodebuild test` would need the signing tool, a private key and network
    /// egress — three things this project forbids. So this proves the emitter and
    /// the validator agree on **names**, not on bytes. That limitation is stated
    /// rather than smoothed over.
    @Test("The emitter names every field the offline validator requires")
    func theEmitterNamesEveryFieldTheValidatorRequires() throws {
        let script = try AppcastScriptSources.script()
        let required = [
            "sparkle:edSignature",
            "length=",
            "sparkle:version",
            "sparkle:shortVersionString",
            "sparkle:minimumSystemVersion",
            "<enclosure"
        ]

        for name in required {
            #expect(script.contains(name), "the emitter never writes \(name)")
        }
    }

    /// The emitter's floor and the validator's floor are the same string.
    ///
    /// Asserted against `AppcastDocument.expectedMinimumSystemVersion` rather
    /// than against a literal repeated in this file: two constants that must
    /// agree are only kept in step by a test that reads both. A feed emitted with
    /// a floor the validator rejects is a feed every installed copy refuses, and
    /// it would only be discovered after publication.
    @Test("The emitter's minimum system version is the one the validator requires")
    func theEmitterAndTheValidatorAgreeOnTheMinimumSystemVersion() throws {
        let script = try AppcastScriptSources.script()
        let expected = AppcastDocument.expectedMinimumSystemVersion

        #expect(expected == "15.0")
        #expect(
            script.contains("MINIMUM_SYSTEM_VERSION=\"\(expected)\""),
            "the emitter must declare MINIMUM_SYSTEM_VERSION=\"\(expected)\""
        )
    }


    // MARK: - Fetching the live feed

    /// The script's `# --- fetch` section, up to the next section marker.
    static func fetchSection(of script: String) throws -> String {
        let start = try #require(script.range(of: "# --- fetch"))
        let rest = script[start.upperBound...]
        let end = try #require(rest.range(of: "# --- tool"))
        return String(rest[rest.startIndex..<end.lowerBound])
    }

    /// Every download goes through one `curl` call site, in the fetch section.
    ///
    /// The live feed and the Sparkle tarball share one bounded, retrying
    /// download helper. The behavioural tests below run the real script against
    /// a stubbed `curl`, so they only prove something about production if every
    /// download goes through the one call site they exercise.
    @Test("The script has exactly one curl call site, in the fetch section")
    func theScriptHasExactlyOneCurlCallSite() throws {
        let script = try AppcastScriptSources.script()
        let fetch = try Self.fetchSection(of: script)
        // An invocation passes options; prose and log lines say "curl exit".
        let calls = { (text: String) in
            AppcastScriptSources.commandInvocations(of: "curl", in: text).filter { $0.hasPrefix("curl -") }
        }

        #expect(calls(script).count == 1)
        #expect(calls(fetch).count == 1)
    }

    /// Only a 404 means "no feed yet", and it is never retried.
    ///
    /// The merged feed replaces the live one wholesale, so a fetch failure read
    /// as "first release" would publish a one-item feed and strand every
    /// installed copy on a version it skipped.
    @Test("A 404 starts an empty channel after one attempt")
    func a404StartsAnEmptyChannelAfterOneAttempt() throws {
        let run = try FeedFetchHarness.run(responses: ["404"])

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.count == 1)
        let feed = try #require(run.feed.flatMap { String(data: $0, encoding: .utf8) })
        #expect(feed.contains("<channel>"))
        #expect(feed.contains("</channel>"))
        #expect(!feed.contains("<item>"))
        // The heredoc is tab-indented and `<<-` strips the tabs: an unstripped
        // tab before the declaration would make the document malformed XML.
        #expect(feed.hasPrefix("<?xml"))
    }

    /// A usable 200 is kept byte for byte.
    @Test("A valid 200 is kept as served")
    func aValid200IsKeptAsServed() throws {
        let run = try FeedFetchHarness.run(responses: ["200"], body: FeedFetchHarness.liveFeed)

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.count == 1)
        #expect(run.feed == Data(FeedFetchHarness.liveFeed.utf8))
    }

    /// Every other outcome exits non-zero and leaves no feed file behind, not
    /// even a stale one from an earlier run.
    ///
    /// curl failing (DNS, connection refused, timeout), a 5xx that never
    /// recovers, another 4xx, and a 200 whose body is empty or is not a feed.
    /// Each run starts with a valid feed already at `CURRENT_FEED_FILE`: a
    /// refused fetch that left it there would hand the build a feed this run
    /// never read.
    @Test("Any other fetch outcome exits non-zero and leaves no feed file", arguments: FeedFetchFailure.all)
    func anyOtherFetchOutcomeExitsNonZero(_ failure: FeedFetchFailure) throws {
        let run = try FeedFetchHarness.run(
            responses: failure.responses,
            body: failure.body,
            preexistingFeed: FeedFetchHarness.liveFeed
        )

        #expect(run.exitStatus != 0, "\(run.log)")
        #expect(run.feed == nil, "a refused fetch must not leave a feed file, stale or new")
        #expect(run.curlCalls.count == failure.expectedAttempts)
    }

    /// A transient failure is retried, and a later success is kept.
    @Test("A transient 5xx or timeout is retried until the feed answers")
    func aTransientFailureIsRetried() throws {
        let run = try FeedFetchHarness.run(responses: ["503", "exit28", "200"], body: FeedFetchHarness.liveFeed)

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.count == 3)
        #expect(run.feed == Data(FeedFetchHarness.liveFeed.utf8))
    }

    /// Every feed attempt is bounded in time and reads the status code itself.
    ///
    /// `-f` is refused because it folds a 404 and a 503 into one exit status, and
    /// curl's own `--retry-all-errors` because it would retry a 404.
    @Test("Every feed attempt carries connect and total timeouts and no -f")
    func everyAttemptIsBounded() throws {
        let run = try FeedFetchHarness.run(responses: ["503", "200"], body: FeedFetchHarness.liveFeed)

        #expect(run.curlCalls.count == 2)
        FeedFetchHarness.expectBounded(run.curlCalls)
    }

    /// The build reads the pre-fetched feed and never fetches it again.
    ///
    /// In CI the feed is fetched before the release is published; the build step
    /// runs after. A missing pre-fetched file must stop the build, saying why,
    /// rather than quietly fetch a second time after the release is public.
    @Test("The build refuses a missing pre-fetched feed without fetching")
    func theBuildRefusesAMissingPreFetchedFeed() throws {
        let run = try FeedFetchHarness.run(mode: nil, responses: ["200"], body: FeedFetchHarness.liveFeed)

        #expect(run.exitStatus != 0, "\(run.log)")
        #expect(run.curlCalls.isEmpty)
        #expect(run.log.contains("the pre-fetched feed"), "\(run.log)")
        #expect(run.log.contains("is missing or empty"), "\(run.log)")
        #expect(run.appcast == nil)
    }

    /// A prerelease tag downloads nothing and writes nothing, in every mode.
    @Test("A prerelease tag fetches and writes nothing", arguments: ["fetch", "tools", "build"])
    func aPrereleaseTagFetchesNothing(_ mode: String) throws {
        let run = try FeedFetchHarness.run(
            mode: mode == "build" ? nil : mode,
            responses: ["200"],
            body: FeedFetchHarness.liveFeed,
            tag: "v1.0.0-beta.1"
        )

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.isEmpty)
        #expect(run.feed == nil)
        #expect(!run.toolsInstalled)
        #expect(run.appcast == nil)
    }

    /// The prerelease guard is the same literal the workflow uses.
    ///
    /// Restated in the script so running it by hand behaves identically to
    /// running it in CI. A prerelease that reached the feed would be offered to
    /// every stable user, which the version comparison alone would not prevent.
    /// The behaviour itself is covered by `aPrereleaseTagFetchesNothing`.
    @Test("The prerelease guard matches a hyphen in the tag and exits 0")
    func thePrereleaseGuardIsTheWorkflowsLiteral() throws {
        let script = try AppcastScriptSources.script()

        #expect(script.contains("case \"$GITHUB_REF_NAME\" in"))
        #expect(script.contains("*-*)"))
        #expect(script.contains("exit 0"))
    }

    // MARK: - Fetching the Sparkle tools

    /// The pinned tarball is downloaded, digest-checked and extracted, and
    /// nothing else is needed for the build to sign.
    @Test("The tools download installs sign_update when the digest matches")
    func theToolsDownloadInstallsSignUpdate() throws {
        let tarball = try FeedFetchHarness.fakeSparkleTarball()
        let run = try FeedFetchHarness.run(
            mode: "tools",
            responses: ["200"],
            bodyData: tarball,
            pinnedDigest: FeedFetchHarness.sha256(tarball)
        )

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.count == 1)
        #expect(run.curlCalls.first?.last == FeedFetchHarness.sparkleTarballURL)
        #expect(run.toolsInstalled)
        FeedFetchHarness.expectBounded(run.curlCalls)
    }

    /// A tarball whose digest is not the pinned one is refused, and nothing is
    /// installed.
    ///
    /// Run against the **unmodified** production script and its real digest: a
    /// fake tarball can never match it, which is the whole point.
    @Test("A digest mismatch fails and installs nothing")
    func aDigestMismatchFails() throws {
        let run = try FeedFetchHarness.run(
            mode: "tools",
            responses: ["200"],
            bodyData: try FeedFetchHarness.fakeSparkleTarball()
        )

        #expect(run.exitStatus != 0, "\(run.log)")
        #expect(run.curlCalls.count == 1)
        #expect(!run.toolsInstalled)
        #expect(run.log.contains("digest"), "\(run.log)")
    }

    /// The tools download retries what the feed fetch retries.
    @Test("A transient failure of the tools download is retried")
    func aTransientToolsFailureIsRetried() throws {
        let tarball = try FeedFetchHarness.fakeSparkleTarball()
        let run = try FeedFetchHarness.run(
            mode: "tools",
            responses: ["503", "exit28", "200"],
            bodyData: tarball,
            pinnedDigest: FeedFetchHarness.sha256(tarball)
        )

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.count == 3)
        #expect(run.toolsInstalled)
    }

    /// A tools download that never succeeds stops the run and removes a tools
    /// directory an earlier run installed.
    @Test("A failed tools download exits non-zero and leaves no tools", arguments: [
        (["exit7"], 4),
        (["503"], 4),
        (["404", "200"], 1)
    ])
    func aFailedToolsDownloadLeavesNoTools(_ responses: [String], _ attempts: Int) throws {
        let tarball = try FeedFetchHarness.fakeSparkleTarball()
        let run = try FeedFetchHarness.run(
            mode: "tools",
            responses: responses,
            bodyData: tarball,
            pinnedDigest: FeedFetchHarness.sha256(tarball),
            seedTools: true
        )

        #expect(run.exitStatus != 0, "\(run.log)")
        #expect(run.curlCalls.count == attempts)
        #expect(!run.toolsInstalled, "a failed download must not leave stale tools behind")
    }

    /// A directory the script did not install is never deleted.
    ///
    /// `SPARKLE_TOOLS_DIR` comes from the environment, so clearing it blindly
    /// would turn a mistyped path into `rm -rf` of whatever it named.
    @Test("The tools download refuses to replace a directory it did not write")
    func theToolsDownloadRefusesAForeignDirectory() throws {
        let tarball = try FeedFetchHarness.fakeSparkleTarball()
        let run = try FeedFetchHarness.run(
            mode: "tools",
            responses: ["200"],
            bodyData: tarball,
            pinnedDigest: FeedFetchHarness.sha256(tarball),
            foreignToolsDirectory: true
        )

        #expect(run.exitStatus != 0, "\(run.log)")
        #expect(run.curlCalls.isEmpty)
        #expect(run.foreignFileSurvived)
    }

    /// The build signs with the pre-fetched tools and touches no network.
    @Test("The build signs with the pre-fetched tools without downloading")
    func theBuildUsesThePreFetchedTools() throws {
        let run = try FeedFetchHarness.run(
            mode: nil,
            responses: ["200"],
            preexistingFeed: FeedFetchHarness.liveFeed,
            seedTools: true
        )

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.isEmpty)
        let appcast = try #require(run.appcast)
        #expect(appcast.contains("sparkle:edSignature=\"c3R1Yg==\""))
        #expect(appcast.contains("<title>Version 1.0.0</title>"))
    }

    /// A missing pre-fetched tools directory stops the build without a download.
    ///
    /// The tools are fetched before the release is published; downloading them
    /// again after Publish would reopen the failure that step exists to close.
    @Test("The build refuses a missing pre-fetched tools directory without downloading")
    func theBuildRefusesMissingPreFetchedTools() throws {
        let run = try FeedFetchHarness.run(
            mode: nil,
            responses: ["200"],
            bodyData: try FeedFetchHarness.fakeSparkleTarball(),
            preexistingFeed: FeedFetchHarness.liveFeed
        )

        #expect(run.exitStatus != 0, "\(run.log)")
        #expect(run.curlCalls.isEmpty)
        #expect(run.log.contains("the pre-fetched Sparkle tools"), "\(run.log)")
        #expect(run.appcast == nil)
    }

    /// Without `SPARKLE_TOOLS_DIR` (a local run) the build downloads the tools
    /// itself, through the same bounded, digest-checked path.
    @Test("A local build downloads and verifies the tools itself")
    func aLocalBuildDownloadsTheToolsItself() throws {
        let tarball = try FeedFetchHarness.fakeSparkleTarball()
        let run = try FeedFetchHarness.run(
            mode: nil,
            responses: ["503", "200"],
            bodyData: tarball,
            preexistingFeed: FeedFetchHarness.liveFeed,
            pinnedDigest: FeedFetchHarness.sha256(tarball),
            setToolsDirectory: false
        )

        #expect(run.exitStatus == 0, "\(run.log)")
        #expect(run.curlCalls.count == 2)
        #expect(run.curlCalls.allSatisfy { $0.last == FeedFetchHarness.sparkleTarballURL })
        #expect(run.appcast?.contains("sparkle:edSignature=\"c3R1Yg==\"") == true)
        FeedFetchHarness.expectBounded(run.curlCalls)
    }
}

// MARK: - Running the real script against controlled responses

/// One refused fetch outcome, and how many attempts it is allowed.
nonisolated struct FeedFetchFailure: Sendable, CustomTestStringConvertible {
    let name: String
    let responses: [String]
    let body: String?
    let expectedAttempts: Int

    var testDescription: String { name }

    static let all: [FeedFetchFailure] = [
        FeedFetchFailure(name: "503 on every attempt", responses: ["503"], body: nil, expectedAttempts: 4),
        FeedFetchFailure(name: "connection refused", responses: ["exit7"], body: nil, expectedAttempts: 4),
        FeedFetchFailure(name: "DNS failure", responses: ["exit6"], body: nil, expectedAttempts: 4),
        FeedFetchFailure(name: "timeout", responses: ["exit28"], body: nil, expectedAttempts: 4),
        FeedFetchFailure(name: "403, never retried", responses: ["403", "200"], body: FeedFetchHarness.liveFeed,
                         expectedAttempts: 1),
        FeedFetchFailure(name: "empty 200", responses: ["200"], body: "", expectedAttempts: 1),
        FeedFetchFailure(name: "200 without </channel>", responses: ["200"], body: "<html>maintenance</html>",
                         expectedAttempts: 1)
    ]
}

/// Runs `scripts/appcast.sh` with a stubbed `curl` first on `PATH`.
///
/// A stub rather than a local HTTP server: it needs no port, no network and no
/// timing, so every outcome — including DNS failures and timeouts, which a
/// server cannot produce on demand — is deterministic inside `xcodebuild test`.
/// The stub answers the n-th call with the n-th response (the last one repeats),
/// and records each call's arguments one per line. A response is an HTTP status
/// or `exit<N>`, a curl failure with exit status N.
///
/// **The pinned digest.** A fake tarball can never match the real Sparkle
/// digest, and the production script must not read its digest from anywhere a
/// caller controls. So a test that needs a *matching* digest passes
/// `pinnedDigest`, and the harness runs a **copy** of the script, written into
/// the test's own temporary directory, with the one pinned literal replaced by
/// the fake tarball's digest computed here. The script in the repository is
/// never changed and has no override; `theSigningToolIsPinnedByDigest` keeps
/// the literal unique, and the mismatch test runs the unmodified script.
nonisolated enum FeedFetchHarness {

    struct Run {
        let exitStatus: Int32
        let feed: Data?
        let toolsInstalled: Bool
        let appcast: String?
        let foreignFileSurvived: Bool
        let curlCalls: [[String]]
        let log: String
    }

    static let sparkleTarballURL =
        "https://github.com/sparkle-project/Sparkle/releases/download/2.9.6/Sparkle-2.9.6.tar.xz"

    static let liveFeed = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
            <channel>
                <title>System Monitor</title>
                <item><title>Version 0.9.0</title></item>
            </channel>
        </rss>

        """

    static let stubCurl = #"""
        #!/bin/bash
        set -eu
        printf '%s\x1f' "$@" >> "$STUB_DIR/calls"
        printf '\n' >> "$STUB_DIR/calls"
        n="$(wc -l < "$STUB_DIR/calls")"
        read -r -a responses <<< "$STUB_RESPONSES"
        i=$(( n <= ${#responses[@]} ? n - 1 : ${#responses[@]} - 1 ))
        response="${responses[$i]}"
        out=""
        while [ $# -gt 0 ]; do
            case "$1" in -o) out="$2"; shift 2 ;; *) shift ;; esac
        done
        case "$response" in
            exit*) echo "curl: (${response#exit}) stubbed failure" >&2; printf '000'; exit "${response#exit}" ;;
            200) if [ -f "$STUB_DIR/body" ]; then cp "$STUB_DIR/body" "$out"; fi ;;
            *) printf '<html>%s</html>' "$response" > "$out" ;;
        esac
        printf '%s' "$response"
        """#

    /// A stand-in `sign_update`: it swallows the key on stdin and prints the two
    /// attributes the script checks for.
    static let stubSignUpdate = """
        #!/bin/bash
        cat > /dev/null
        printf '%s\\n' 'sparkle:edSignature="c3R1Yg==" length="42"'
        """

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The digest pinned in the production script.
    static func productionDigest() throws -> String {
        let script = try AppcastScriptSources.script()
        let regex = try NSRegularExpression(pattern: "SPARKLE_TARBALL_SHA256=\"([0-9a-f]{64})\"")
        let range = NSRange(script.startIndex..<script.endIndex, in: script)
        let match = try #require(regex.firstMatch(in: script, range: range))
        return try String(script[#require(Range(match.range(at: 1), in: script))])
    }

    /// A `.tar.xz` laid out like the Sparkle distribution: `bin/sign_update`.
    static func fakeSparkleTarball() throws -> Data {
        let fileManager = FileManager.default
        let dir = fileManager.temporaryDirectory.appendingPathComponent("fake-sparkle-\(UUID().uuidString)")
        defer { try? fileManager.removeItem(at: dir) }
        try installStubTools(in: dir.appendingPathComponent("payload"), marker: nil)

        let tarball = dir.appendingPathComponent("Sparkle.tar.xz")
        let tar = Process()
        tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        tar.arguments = ["-cJf", tarball.path, "-C", dir.appendingPathComponent("payload").path, "bin"]
        try tar.run()
        tar.waitUntilExit()
        #expect(tar.terminationStatus == 0)
        return try Data(contentsOf: tarball)
    }

    /// `bin/sign_update` under `dir`, plus the marker the tools step writes.
    static func installStubTools(in dir: URL, marker: String?) throws {
        let fileManager = FileManager.default
        let bin = dir.appendingPathComponent("bin")
        try fileManager.createDirectory(at: bin, withIntermediateDirectories: true)
        let tool = bin.appendingPathComponent("sign_update")
        try Data(stubSignUpdate.utf8).write(to: tool)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        if let marker {
            try Data("\(marker)\n".utf8).write(to: dir.appendingPathComponent(".pinned-sha256"))
        }
    }

    /// Every attempt is bounded in time and reads the status code itself.
    static func expectBounded(_ calls: [[String]]) {
        for call in calls {
            #expect(call.contains("--connect-timeout"), "\(call)")
            #expect(call.contains("--max-time"), "\(call)")
            #expect(call.contains("%{http_code}"), "\(call)")
            #expect(!call.contains("--retry-all-errors"), "\(call)")
            let clusters = call.filter { $0.hasPrefix("-") && !$0.hasPrefix("--") }
            #expect(!clusters.contains { $0.contains("f") }, "curl -f hides which failure it was: \(call)")
        }
    }

    /// `mode` is the script's first argument; `nil` runs the build.
    static func run(
        mode: String? = "fetch",
        responses: [String],
        body: String? = nil,
        bodyData: Data? = nil,
        tag: String = "v1.0.0",
        preexistingFeed: String? = nil,
        pinnedDigest: String? = nil,
        setToolsDirectory: Bool = true,
        seedTools: Bool = false,
        foreignToolsDirectory: Bool = false
    ) throws -> Run {
        let fileManager = FileManager.default
        let dir = fileManager.temporaryDirectory.appendingPathComponent("feed-fetch-\(UUID().uuidString)")
        let stubs = dir.appendingPathComponent("bin")
        try fileManager.createDirectory(at: stubs, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: dir) }

        let curl = stubs.appendingPathComponent("curl")
        try Data(stubCurl.utf8).write(to: curl)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: curl.path)
        if let served = bodyData ?? body.map({ Data($0.utf8) }) {
            try served.write(to: dir.appendingPathComponent("body"))
        }

        let feedFile = dir.appendingPathComponent("prefetched/current.xml")
        if let preexistingFeed {
            try fileManager.createDirectory(at: feedFile.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(preexistingFeed.utf8).write(to: feedFile)
        }

        let digest = try pinnedDigest ?? productionDigest()
        let toolsDir = dir.appendingPathComponent("prefetched/sparkle-tools")
        if seedTools { try installStubTools(in: toolsDir, marker: digest) }
        let foreignFile = toolsDir.appendingPathComponent("keep-me")
        if foreignToolsDirectory {
            try fileManager.createDirectory(at: toolsDir, withIntermediateDirectories: true)
            try Data("not the script's".utf8).write(to: foreignFile)
        }

        var script = AppcastScriptSources.scriptURL
        if let pinnedDigest {
            let source = try AppcastScriptSources.script()
            let production = try productionDigest()
            #expect(source.components(separatedBy: production).count == 2, "the pinned digest must be unique")
            script = dir.appendingPathComponent("appcast.sh")
            try Data(source.replacingOccurrences(of: production, with: pinnedDigest).utf8).write(to: script)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + (mode.map { [$0] } ?? [])
        process.currentDirectoryURL = dir
        var environment = [
            "PATH": "\(stubs.path):/usr/bin:/bin",
            "HOME": dir.path,
            "TMPDIR": dir.path,
            "STUB_DIR": dir.path,
            "STUB_RESPONSES": responses.joined(separator: " "),
            "GITHUB_REF_NAME": tag,
            "FEED_URL": "https://feed.invalid/appcast.xml",
            "CURRENT_FEED_FILE": feedFile.path,
            "FETCH_RETRY_DELAY": "0",
            "VERSION": "1.0.0",
            "BUILD_NUMBER": "1",
            "ASSET_URL": "https://example.invalid/System-Monitor-1.0.0.zip",
            "ZIP_PATH": dir.appendingPathComponent("System-Monitor-1.0.0.zip").path,
            "OUTPUT_DIR": dir.appendingPathComponent("site").path,
            "SPARKLE_PRIVATE_KEY": "not-a-key"
        ]
        if setToolsDirectory { environment["SPARKLE_TOOLS_DIR"] = toolsDir.path }
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let calls = (try? String(contentsOf: dir.appendingPathComponent("calls"), encoding: .utf8)) ?? ""
        let signUpdate = toolsDir.appendingPathComponent("bin/sign_update").path
        return Run(
            exitStatus: process.terminationStatus,
            feed: mode == "fetch" ? try? Data(contentsOf: feedFile) : nil,
            toolsInstalled: fileManager.isExecutableFile(atPath: signUpdate),
            appcast: try? String(contentsOf: dir.appendingPathComponent("site/appcast.xml"), encoding: .utf8),
            foreignFileSurvived: fileManager.fileExists(atPath: foreignFile.path),
            curlCalls: calls.split(separator: "\n").map { line in
                line.split(separator: "\u{1F}", omittingEmptySubsequences: false).dropLast().map(String.init)
            },
            log: String(decoding: output, as: UTF8.self)
        )
    }
}
