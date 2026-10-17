import Foundation
import Testing

/// Reads `.github/workflows/release.yml` off disk.
///
/// Self-contained for the same reason the rest of this slice's suites are: the
/// publication half must roll back by deleting its own files and reverting one
/// workflow hunk.
nonisolated enum AppcastWorkflowSources {

    static let workflowPath = ".github/workflows/release.yml"

    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // App
            .deletingLastPathComponent()   // system-monitorTests
            .deletingLastPathComponent()   // repository root
    }

    static func workflow() throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent(workflowPath), encoding: .utf8)
    }

    /// The workflow cut into steps at its `- name:` boundaries.
    ///
    /// The properties worth asserting about a workflow are per-step — "the
    /// appcast is built after the release exists", "every publishing step carries
    /// the prerelease guard". Asserting that two substrings both appear somewhere
    /// in the file would pass for a workflow where they sit in different steps,
    /// which is exactly the failure being guarded against.
    static func steps(in workflow: String) -> [String] {
        var steps: [String] = []
        var current: [String]?

        for line in workflow.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- name:") {
                if let started = current { steps.append(started.joined(separator: "\n")) }
                current = [String(line)]
            } else {
                current?.append(String(line))
            }
        }
        if let last = current { steps.append(last.joined(separator: "\n")) }
        return steps
    }

    /// Whether `text` shells out to `command` as a command word.
    ///
    /// Substring matching would find `gh` inside `github.repository`, so the
    /// token boundary is what makes "this step shells out to `gh`" a claim worth
    /// asserting at all.
    static func invokes(_ command: String, in text: String) -> Bool {
        let pattern = "(?:^|[\\s;|&(])\(NSRegularExpression.escapedPattern(for: command))(?=\\s|$)"
        return text.split(separator: "\n", omittingEmptySubsequences: false).contains {
            String($0).range(of: pattern, options: [.regularExpression]) != nil
        }
    }

    /// The `release` job's header: everything it declares before its steps.
    ///
    /// Scoped deliberately. `permissions:` also exists at workflow level, and a
    /// job-level block **replaces** the workflow-level one rather than extending
    /// it — so "the file contains `contents: write`" would be satisfied by the
    /// workflow-level line while the job silently ran without it.
    static func releaseJobHeader(in workflow: String) throws -> String {
        let start = try #require(workflow.range(of: "\n  release:\n"))
        let rest = workflow[start.upperBound...]
        let end = try #require(rest.range(of: "\n    steps:"))
        return String(rest[rest.startIndex..<end.lowerBound])
    }

    /// The step whose `run:` line is exactly `line`.
    ///
    /// `appcast.sh` runs three times — `tools` and `fetch` before the release is
    /// published, the build after — so "the step containing appcast.sh" no
    /// longer names one step.
    static func step(running line: String, in workflow: String) -> String? {
        steps(in: workflow).first { step in
            step.split(separator: "\n").contains { $0.trimmingCharacters(in: .whitespaces) == "run: \(line)" }
        }
    }

    static func feedFetchStep(in workflow: String) throws -> String {
        try #require(step(running: "scripts/appcast.sh fetch", in: workflow), "no step runs scripts/appcast.sh fetch")
    }

    static func toolsFetchStep(in workflow: String) throws -> String {
        try #require(step(running: "scripts/appcast.sh tools", in: workflow), "no step runs scripts/appcast.sh tools")
    }

    static func appcastBuildStep(in workflow: String) throws -> String {
        try #require(step(running: "scripts/appcast.sh", in: workflow), "no step runs scripts/appcast.sh")
    }
}

// release-distribution — "A stable tag also publishes the update feed, without a
// push and without a second release call", and "A prerelease tag publishes a
// release and no feed entry": what the release workflow must say to publish the
// update feed.
@Suite("Appcast workflow", .timeLimit(.minutes(1)))
struct AppcastWorkflowTests {

    static let prereleaseGuard = "if: ${{ !contains(github.ref_name, '-') }}"

    /// The seven publication steps, identified by their names or what they run.
    ///
    /// The guard is one of them: it is the step that decides whether this commit
    /// may publish a feed at all, so a prerelease must skip it for the same
    /// reason a prerelease skips the deploy.
    static let publicationMarkers = [
        "Refuse a second feed deployment from this commit",
        "- name: Fetch the Sparkle tools",
        "- name: Fetch the live feed",
        "- name: Build the appcast",
        "actions/configure-pages",
        "actions/upload-pages-artifact",
        "actions/deploy-pages"
    ]

    static let deployStepMarker = "- name: Deploy to Pages"
    static let guardStepMarker = "- name: Refuse a second feed deployment from this commit"

    // MARK: - Ordering and the prerelease guard

    /// The feed is built **after** the release exists.
    ///
    /// The item's enclosure points at the published asset's download URL, so an
    /// appcast built before `gh release create` would advertise a URL that
    /// 404s — and the feed, once served, is what every installed copy trusts.
    @Test("The appcast step runs after the release is published")
    func theAppcastStepRunsAfterTheReleaseIsPublished() throws {
        let workflow = try AppcastWorkflowSources.workflow()
        let steps = AppcastWorkflowSources.steps(in: workflow)
        let build = try AppcastWorkflowSources.appcastBuildStep(in: workflow)

        let publish = try #require(steps.firstIndex { $0.contains("gh release create") })
        let appcast = try #require(steps.firstIndex(of: build))

        #expect(publish < appcast)
        // The split is only meaningful if it found the whole job.
        #expect(steps.count > 10)
    }

    /// The live feed is fetched and validated **before** the release exists, and
    /// the build step reads the same file.
    ///
    /// A fetch failure after `gh release create` would strand a published
    /// release with no feed item. Fetched first, a Pages or CDN error stops the
    /// run while nothing is public yet. Asserted here: the fetch step sits after
    /// Notarize and before Publish, both steps name the same `CURRENT_FEED_FILE`,
    /// the fetch reads the bundle's feed URL, and it holds no secret. That the
    /// build never re-fetches is the script's behaviour, covered by
    /// `AppcastScriptContractTests.theBuildRefusesAMissingPreFetchedFeed`.
    @Test("The live feed is fetched before the release is published")
    func theLiveFeedIsFetchedBeforeTheReleaseIsPublished() throws {
        let workflow = try AppcastWorkflowSources.workflow()
        let steps = AppcastWorkflowSources.steps(in: workflow)
        let fetch = try AppcastWorkflowSources.feedFetchStep(in: workflow)
        let build = try AppcastWorkflowSources.appcastBuildStep(in: workflow)

        let fetchIndex = try #require(steps.firstIndex(of: fetch))
        let publish = try #require(steps.firstIndex { $0.contains("gh release create") })
        let notarize = try #require(steps.firstIndex { $0.contains("scripts/release.sh notarize") })
        #expect(notarize < fetchIndex)
        #expect(fetchIndex < publish)

        let file = "CURRENT_FEED_FILE: ${{ runner.temp }}/current-appcast.xml"
        #expect(fetch.contains(file))
        #expect(build.contains(file))
        let feed = "FEED_URL: https://juancasanueva.github.io/SWIFTUI_system_monitor/appcast.xml"
        #expect(fetch.contains(feed))
        // The fetch holds no secret: it runs before anything needs signing.
        #expect(!fetch.contains("secrets."))
    }

    /// The Sparkle tools are downloaded and verified **before** the release
    /// exists, and the build step signs with them.
    ///
    /// A download failure after `gh release create` would strand a published
    /// release with no feed item, exactly like a feed fetch failure. Asserted
    /// here: the tools step sits after Notarize and before Publish, both it and
    /// the build name the same `SPARKLE_TOOLS_DIR`, and the download holds no
    /// secret. That the build never downloads when the directory is set is the
    /// script's behaviour, covered by
    /// `AppcastScriptContractTests.theBuildRefusesMissingPreFetchedTools`.
    @Test("The Sparkle tools are fetched before the release is published")
    func theSparkleToolsAreFetchedBeforeTheReleaseIsPublished() throws {
        let workflow = try AppcastWorkflowSources.workflow()
        let steps = AppcastWorkflowSources.steps(in: workflow)
        let tools = try AppcastWorkflowSources.toolsFetchStep(in: workflow)
        let build = try AppcastWorkflowSources.appcastBuildStep(in: workflow)

        let toolsIndex = try #require(steps.firstIndex(of: tools))
        let buildIndex = try #require(steps.firstIndex(of: build))
        let publish = try #require(steps.firstIndex { $0.contains("gh release create") })
        let notarize = try #require(steps.firstIndex { $0.contains("scripts/release.sh notarize") })
        #expect(notarize < toolsIndex)
        #expect(toolsIndex < publish)
        #expect(publish < buildIndex)

        let directory = "SPARKLE_TOOLS_DIR: ${{ runner.temp }}/sparkle-tools"
        #expect(tools.contains(directory))
        #expect(build.contains(directory))
        #expect(tools.contains(Self.prereleaseGuard))
        #expect(!tools.contains("secrets."))
    }

    /// Every publishing step is skipped on a prerelease tag.
    ///
    /// All seven, not just the first. The deploy step is the dangerous one: a
    /// prerelease that reached it with an empty artifact would replace the live
    /// site — Pages deploys are a full-site replacement — and blank the feed for
    /// every installed copy.
    @Test("All seven publication steps carry the prerelease guard")
    func allSevenPublicationStepsCarryThePrereleaseGuard() throws {
        let steps = AppcastWorkflowSources.steps(in: try AppcastWorkflowSources.workflow())

        var guarded = 0
        for marker in Self.publicationMarkers {
            let step = try #require(steps.first { $0.contains(marker) }, "no step runs \(marker)")
            #expect(step.contains(Self.prereleaseGuard), "\(marker) is not guarded")
            guarded += 1
        }
        #expect(guarded == 7)
    }

    // MARK: - The job header

    /// The three permissions and the deployment environment, on the job.
    ///
    /// `contents: write` is restated deliberately. A job-level `permissions:`
    /// block replaces the workflow-level one rather than extending it, so
    /// omitting it here would silently strip `gh release create` of its token —
    /// a failure that appears only on a real tag, after Apple has already been
    /// asked for a notarization round trip.
    @Test("The release job declares the Pages permissions and environment")
    func theReleaseJobDeclaresThePagesPermissionsAndEnvironment() throws {
        let header = try AppcastWorkflowSources.releaseJobHeader(in: try AppcastWorkflowSources.workflow())

        #expect(header.contains("permissions:"))
        #expect(header.contains("contents: write"))
        #expect(header.contains("pages: write"))
        #expect(header.contains("id-token: write"))
        #expect(header.contains("environment: github-pages"))
    }

    /// The secret is bound as an environment variable on the appcast step, and
    /// nowhere else.
    ///
    /// A `run:` line that interpolated the secret would put it in the command the
    /// runner logs. An `env:` binding is masked, and the script reads it from the
    /// environment onto the signing tool's standard input.
    @Test("The signing key is bound only as an environment variable")
    func theSigningKeyIsBoundOnlyAsAnEnvironmentVariable() throws {
        let workflow = try AppcastWorkflowSources.workflow()
        let naming = workflow.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { $0.contains("SPARKLE_PRIVATE_KEY") }

        #expect(naming.count == 1)
        let binding = try #require(naming.first)
        #expect(binding.trimmingCharacters(in: .whitespaces) == "SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}")

        let step = try AppcastWorkflowSources.appcastBuildStep(in: workflow)
        #expect(step.contains("SPARKLE_PRIVATE_KEY"))
    }

    // MARK: - One stable release per commit

    /// `actions/deploy-pages` is what deploys the feed.
    ///
    /// The action sends the commit SHA as the build version, and the Pages
    /// deployments API accepts **only** a build version that is a commit in the
    /// repository: a `<sha>-<run>` string and a synthetic forty-hex string both
    /// answer 404. The action already sends the one value the API takes, so there
    /// is nothing left for a hand-rolled request to improve on.
    @Test("The appcast is deployed by actions/deploy-pages")
    func theAppcastIsDeployedByTheDeployPagesAction() throws {
        let workflow = try AppcastWorkflowSources.workflow()

        #expect(workflow.contains("actions/deploy-pages"))
        #expect(workflow.contains("actions/configure-pages"))
        #expect(workflow.contains("actions/upload-pages-artifact"))

        let deploy = try #require(
            AppcastWorkflowSources.steps(in: workflow).first { $0.contains(Self.deployStepMarker) }
        )
        #expect(deploy.contains("actions/deploy-pages"))
    }

    /// Nothing in the workflow names the build version.
    ///
    /// The only value the API accepts is the commit SHA, which is what the action
    /// sends unprompted. Every override is rejected with a 404, and the rejection
    /// lands *after* the release was published.
    @Test("The workflow never overrides the Pages build version")
    func theWorkflowNeverOverridesThePagesBuildVersion() throws {
        let workflow = try AppcastWorkflowSources.workflow()

        #expect(!workflow.contains("pages_build_version"))
        #expect(!workflow.contains("BUILD_VERSION"))
    }

    /// The commit may not have deployed the feed already.
    ///
    /// Pages keys a deployment by its build version, and the build version is the
    /// commit SHA. Asking it to deploy a commit it has already deployed is
    /// accepted, reports `succeed`, and leaves the previously published site in
    /// place — so a second stable tag on one commit would publish a release the
    /// feed never learns about.
    @Test("A guard refuses a second feed deployment from one commit")
    func aGuardRefusesASecondFeedDeploymentFromOneCommit() throws {
        let steps = AppcastWorkflowSources.steps(in: try AppcastWorkflowSources.workflow())
        let step = try #require(steps.first { $0.contains(Self.guardStepMarker) })

        #expect(step.contains(Self.prereleaseGuard))
        #expect(step.contains("pages/deployments/${GITHUB_SHA}"))
        // The API answers 200 for every SHA it is asked about; what separates a
        // deployed commit from an undeployed one is the `status` in the body —
        // `succeed` against an empty string. A guard that read the HTTP code
        // would refuse every release.
        #expect(step.contains("succeed"))
        #expect(step.contains("exit 1"))
    }

    /// The guard runs before anything Apple is asked for.
    ///
    /// A commit that cannot publish a feed cannot publish a release either, and
    /// finding that out after notarization means the release is already on the
    /// tag with no feed behind it. So the guard sits with the other refusals at
    /// the top of the job.
    @Test("The guard runs before notarization and before the release is published")
    func theGuardRunsBeforeNotarizationAndBeforeTheReleaseIsPublished() throws {
        let steps = AppcastWorkflowSources.steps(in: try AppcastWorkflowSources.workflow())

        let refuseGuard = try #require(steps.firstIndex { $0.contains(Self.guardStepMarker) })
        let privateRepo = try #require(steps.firstIndex { $0.contains("Refuse to publish from a private repository") })
        let notarize = try #require(steps.firstIndex { $0.contains("release.sh notarize") })
        let publish = try #require(steps.firstIndex { $0.contains("gh release create") })

        #expect(privateRepo < refuseGuard)
        #expect(refuseGuard < notarize)
        #expect(refuseGuard < publish)
    }

    /// The guard reaches the API with `curl`, and with nothing that could touch a
    /// release.
    ///
    /// The workflow's blast radius is pinned at exactly one `gh` invocation —
    /// `gh release create` — and no `git` invocation, by
    /// `theWorkflowInvokesGhOnceAndGitNever`. Reading the deployments API through
    /// `gh` here would quietly widen it.
    @Test("The guard reaches the API with curl and not gh")
    func theGuardReachesTheAPIWithCurlAndNotGh() throws {
        let steps = AppcastWorkflowSources.steps(in: try AppcastWorkflowSources.workflow())
        let step = try #require(steps.first { $0.contains(Self.guardStepMarker) })

        #expect(AppcastWorkflowSources.invokes("curl", in: step))
        #expect(!AppcastWorkflowSources.invokes("gh", in: step))
        #expect(!AppcastWorkflowSources.invokes("git", in: step))
    }

    /// The deploy step keeps its place in the job.
    ///
    /// It must come after the upload, whose artifact it deploys, and before the
    /// `if: always()` cleanup that destroys the keychain and the API key — so a
    /// deployment that takes its full ten minutes never races the teardown.
    @Test("The deploy step runs after the upload and before the keychain cleanup")
    func theDeployStepRunsAfterTheUploadAndBeforeTheKeychainCleanup() throws {
        let steps = AppcastWorkflowSources.steps(in: try AppcastWorkflowSources.workflow())

        let upload = try #require(steps.firstIndex { $0.contains("actions/upload-pages-artifact") })
        let deploy = try #require(steps.firstIndex { $0.contains(Self.deployStepMarker) })
        let cleanup = try #require(steps.firstIndex { $0.contains("security delete-keychain") })

        #expect(upload < deploy)
        #expect(deploy < cleanup)
    }

    // MARK: - Blast radius

    /// The workflow can only ever *create* a release.
    ///
    /// Exactly one `gh` invocation, and it is `gh release create`; no `git`
    /// invocation at all. Comment lines are skipped, because the workflow
    /// explains in prose what it never does.
    @Test("The workflow invokes gh once, to create the release, and git never")
    func theWorkflowInvokesGhOnceAndGitNever() throws {
        let code = try AppcastWorkflowSources.workflow()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }

        let gh = code.filter { AppcastWorkflowSources.invokes("gh", in: $0) }
        let git = code.filter { AppcastWorkflowSources.invokes("git", in: $0) }

        #expect(gh.count == 1)
        #expect(gh.first?.contains("gh release create") == true)
        #expect(git == [])
        // The reader is only meaningful if it can find an invocation at all.
        #expect(code.contains { AppcastWorkflowSources.invokes("curl", in: $0) })
    }

    // MARK: - Supply chain

    /// Every action is pinned to a full commit SHA, with its tag as a comment.
    ///
    /// A tag is mutable: whoever controls the action's repository can move it,
    /// and this job holds the signing certificate, the notarization key and the
    /// Sparkle private key. A forty-hex commit is the only reference that cannot
    /// be repointed.
    @Test("Every action is pinned to a 40-hex commit SHA")
    func everyActionIsPinnedToACommitSHA() throws {
        let uses = try AppcastWorkflowSources.workflow()
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("uses:") || $0.hasPrefix("- uses:") }
        let pinned = "uses: [A-Za-z0-9_.-]+/[A-Za-z0-9_./-]+@[0-9a-f]{40} # v[0-9]+(\\.[0-9]+)*$"

        #expect(uses.count == 4)
        for line in uses {
            #expect(line.range(of: pinned, options: .regularExpression) != nil, "not pinned to a SHA: \(line)")
        }
    }
}
