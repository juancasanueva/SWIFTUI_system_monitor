# release-distribution Specification

## Purpose

What must be true of a build System Monitor delivers to a stranger: how a tag becomes a downloadable asset, what that asset is named and where it lives, what the app inside it is stamped with, what it is signed and hardened with, what Gatekeeper does with it on a machine that has never seen it, what update feed the same run publishes and what that feed must contain, what the repository is allowed to contain while producing it, and what a release run is never allowed to do to the releases that came before it. Serves PRD milestone "Ship". This capability owns **what must be true of a delivered build, never how the build is produced**: the runner image, the Xcode pin, the export/notarize/staple command ordering, the ephemeral-keychain mechanics and the release body are design-owned and live in `RELEASING.md`. The app-side update surface — which feed the running bundle trusts, when it may reach the network, what the update UI may say — belongs to `app-updates` and is deliberately absent here.

## Verification classes

Every scenario in this file declares exactly one verification class, and no requirement is written that no test or gate could ever check:

| Class | Meaning |
|---|---|
| `unit` | RED-first assertion in `system-monitorTests`, anchored to `#filePath` so it reads the repository off disk, run by `xcodebuild test … -only-testing:system-monitorTests` |
| `ci-gate` | a hard gate whose failure fails its job and publishes nothing — the release run in `.github/workflows/release.yml` here, or `ci.yml` / `bump.yml` in `juancasanueva/homebrew-system-monitor` for the cask channel |
| `manual-evidence` | no harness can exist — no runner may install into a real `/Applications` or observe a self-updated app — so the maintainer's observed output is recorded verbatim in `RELEASING.md` |

## Requirements

### Requirement: RD-1 A pushed tag is the only thing that produces a downloadable release (Layer: App) — PRD "Ship"

Publication MUST be reachable only from a pushed tag matching `v*`, with **no manual step between the push and the published asset**. A published release for tag `vX.Y.Z` MUST carry exactly one downloadable asset, named **`System-Monitor-<version>.zip`**, where `<version>` is the tag with its leading `v` removed. The asset MUST be reachable at `https://github.com/<owner>/<repo>/releases/download/v<version>/System-Monitor-<version>.zip`, and the bundle inside it MUST be **`System-Monitor.app`** with display name **`System-Monitor`** and main executable **`Contents/MacOS/System-Monitor`**. The delivered bundle's identifier MUST remain **`com.juancasanueva.system-monitor`**: every preference domain, cache root and update host-match derives from that identifier and from no product name.

An asset nobody can download is not a release: a run against a repository that is not anonymously readable MUST fail fast, with an explicit message, **before** any signing or notarization work, and MUST publish nothing.

A run for a **stable** tag — one whose version carries no hyphen — MUST additionally publish an update feed describing that release, served over `https` from the project's GitHub Pages site. The feed is a **site artifact, not a release asset**, so the one-asset rule above is unaffected. Publishing the feed MUST NOT require a version-control push and MUST NOT require a second release-management invocation beyond the single one that creates the release; it MUST reuse the run's already-published asset URL. A run for a **prerelease** tag — one whose version contains a hyphen — MUST publish the release and MUST NOT publish any feed entry for it, so that an installed copy is never offered a prerelease.

Because GitHub Pages keys a deployment by the commit it was cut from and silently ignores a second deployment of the same commit, a stable run whose commit has already deployed the feed MUST fail **before** anything is signed, notarized or published, rather than publishing a release the feed never learns about.

#### Scenario: A tag produces one correctly named, anonymously reachable asset

- GIVEN a pushed tag `v1.0.0` on a publicly readable repository
- WHEN the release run completes
- THEN a GitHub Release for `v1.0.0` exists carrying exactly one asset named `System-Monitor-1.0.0.zip`
- AND that asset is downloadable from the documented URL without authentication
- Verification: `ci-gate`

#### Scenario: The bundle inside the zip is the one both channels bind against

- GIVEN the published `System-Monitor-<version>.zip`
- WHEN it is extracted
- THEN it contains exactly one application bundle, named `System-Monitor.app`
- AND that bundle's display name is `System-Monitor` and its main executable is `Contents/MacOS/System-Monitor`
- AND its bundle identifier is `com.juancasanueva.system-monitor`
- Verification: `ci-gate`

#### Scenario: Nothing but a version tag can trigger a release

- GIVEN the repository's workflow definitions
- WHEN their triggers are inspected structurally
- THEN the release workflow is triggered only by a pushed tag matching `v*`
- AND no pull-request, schedule, or branch-push trigger and no test action is declared on it
- Verification: `unit`

#### Scenario: A private repository fails fast instead of publishing an unreachable asset

- GIVEN a release run on a repository that is not publicly readable
- WHEN the run starts
- THEN it fails with an explicit message before any signing or notarization step executes
- AND no release, tag asset, or partial artifact is published
- Verification: `ci-gate`

#### Scenario: Every publication step is skipped on a prerelease tag

- GIVEN the release workflow
- WHEN its steps are inspected structurally
- THEN the distinct-commit gate, the feed build, the Pages configuration, the artifact upload and the deployment all carry the same prerelease guard
- AND the feed step runs after the release exists, because the item's enclosure is the published asset's URL
- Verification: `unit`

#### Scenario: A stable tag also publishes the update feed, without a push and without a second release call

- GIVEN a pushed stable tag `v1.0.0` whose release and asset have been published
- WHEN the run completes
- THEN the feed served from the project's GitHub Pages site carries an entry for `1.0.0` whose enclosure is the run's published `https` asset URL
- AND the run performed no version-control push and no release-management invocation beyond the single one that created the release
- AND every entry published by an earlier stable tag is still present in the feed
- Verification: `ci-gate`

#### Scenario: A second stable tag on one commit is refused before Apple is asked for anything

- GIVEN a commit whose Pages deployment already reports `succeed`
- WHEN a stable tag on that same commit starts a release run
- THEN the run fails at the distinct-commit gate, before notarization and before the release is published
- Verification: `ci-gate`

### Requirement: RD-2 The tag is the version, and a mislabelled build never ships (Layer: App) — PRD "Ship"

The delivered bundle's `CFBundleShortVersionString` MUST equal the tag with its leading `v` removed, and this MUST be asserted **before notarization** — a mismatch MUST fail the run rather than ship a mislabelled release. `CFBundleVersion` MUST equal the release run number, and MUST strictly increase across successive published releases, including re-cut tags for the same marketing version, because that monotonicity is what the update comparison rests on.

The checked-in project MUST NOT be bumped per release: version values MUST be supplied at build time, and `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` MUST remain at `1.0.0` / `1` in the project file. The consequence — a locally archived build reports `1.0.0 (1)` regardless of the current tag — MUST be recorded in the repository as a documented fact together with the exact one-line override that produces a correctly stamped local build. It MUST NOT be left as an undocumented trap for manual testing.

Two versions MUST order by marketing version first, then by prerelease **below** its own release, then by build number, and an unreadable version MUST produce a named failure rather than a fabricated value: a version that compares is a version that can offer or refuse an update for the wrong reason.

#### Scenario: A version mismatch stops the run before Apple ever sees the build

- GIVEN an exported build whose `CFBundleShortVersionString` does not equal the tag minus `v`
- WHEN the version assertion runs
- THEN the run fails
- AND no notarization submission and no publication occurred
- Verification: `ci-gate`

#### Scenario: The tag and run number reach the delivered bundle

- GIVEN a run for tag `v1.0.0` with run number `N`
- WHEN the delivered bundle's information is read
- THEN `CFBundleShortVersionString` is `1.0.0` and `CFBundleVersion` is `N`
- Verification: `ci-gate`

#### Scenario: Releasing does not edit the project file, and the cost is documented

- GIVEN the repository after this change
- WHEN the project file and the release documentation are inspected
- THEN `MARKETING_VERSION` is `1.0.0` and `CURRENT_PROJECT_VERSION` is `1`, unchanged by any release
- AND the documentation states that a local archive reports `1.0.0 (1)` and carries the exact override command that corrects it
- Verification: `unit`

#### Scenario: Versions order by marketing version, then prerelease, then build

- GIVEN pairs of versions that differ only in marketing version, only in prerelease suffix, and only in build number
- WHEN each pair is compared in both directions
- THEN the later one is greater, the earlier one is lesser, and the two are distinct
- AND a prerelease sorts below its own release
- Verification: `unit`

#### Scenario: An unreadable version names its own failure

- GIVEN an empty string, a two-component version, a non-numeric component, a leading `v`, and a non-numeric build number
- WHEN each is parsed
- THEN each throws its own named failure and no fabricated version is produced
- AND the failable form used by a bundle read answers with no version at all
- Verification: `unit`

### Requirement: RD-3 arm64 only, hardened, unsandboxed, and no entitlement added to get there (Layer: App) — PRD "Ship"

The delivered **application executable** MUST contain the `arm64` slice and no other. A prebuilt third-party framework vendored into the bundle MAY carry additional architecture slices, because thinning it would require either a sandboxed build phase or a post-export re-sign that takes signing ownership away from the export step. The delivered bundle MUST have the hardened runtime enabled and the app sandbox disabled — the sandbox prevents an app from replacing its own bundle, and an in-app update is exactly that.

Both app-target build configurations MUST declare the same values, because a Debug build whose posture differs from Release proves nothing about the delivered one. The two configurations MUST remain identical apart from their name; if a signing flip is ever applied in the project file, the assertion that pins this MUST be **explicitly relaxed with the reason recorded**, never deleted.

**No `.entitlements` file MUST exist in the repository**, and no entitlement MUST be added to make the delivered build work. Specifically, `allow-jit`, `allow-unsigned-executable-memory` and `disable-library-validation` MUST NOT be present. The repository MUST carry a written rationale for this posture, and that rationale MUST also explain what `ENABLE_USER_SELECTED_FILES` and `REGISTER_APP_GROUPS` mean while the sandbox is disabled.

#### Scenario: The delivered application executable is single-architecture

- GIVEN the exported application executable
- WHEN its architectures are enumerated
- THEN `arm64` is the only one reported
- AND the run fails if any other slice is present in the application executable
- AND a vendored prebuilt framework carrying additional slices does not fail the run
- Verification: `ci-gate`

#### Scenario: The delivered bundle is hardened and unsandboxed

- GIVEN the app extracted from the published zip
- WHEN its code signature attributes are read
- THEN the hardened runtime flag is set
- AND no app-sandbox entitlement is present
- Verification: `ci-gate`

#### Scenario: Both app configurations declare one posture

- GIVEN the two app-target build configurations
- WHEN their build settings are compared line by line
- THEN they are identical apart from their name
- AND both declare `ARCHS = arm64`, `ENABLE_APP_SANDBOX = NO`, `ENABLE_HARDENED_RUNTIME = YES` and `MACOSX_DEPLOYMENT_TARGET = 26.5`
- Verification: `unit`

#### Scenario: No entitlements file exists anywhere in the repository

- GIVEN the repository tree after this change
- WHEN it is inspected structurally
- THEN no `.entitlements` file exists
- AND no build configuration references an entitlements file
- Verification: `unit`

#### Scenario: The rationale names what is absent and why

- GIVEN the release documentation in the repository
- WHEN it is read
- THEN it names `allow-jit`, `allow-unsigned-executable-memory` and `disable-library-validation` as deliberately absent, with the reason
- AND it explains `ENABLE_USER_SELECTED_FILES` and `REGISTER_APP_GROUPS` under a disabled sandbox
- Verification: `unit`

### Requirement: RD-4 Gatekeeper accepts the artifact users actually download, offline (Layer: App) — PRD "Ship"

The app **extracted from the published zip** — not an intermediate build product — MUST be Developer ID Application-signed under team `Z3S5JK8E38`, notarized, and **stapled**, such that Gatekeeper assessment for installation and staple validation both accept it **with networking disabled**. These checks MUST run as a hard gate before publication.

The stapled ticket MUST travel inside the published archive: an archive assembled before stapling MUST NOT be the published asset, because first launch would then require network access to succeed. The pre-notarization archive MUST therefore be deleted before the stapled bundle is packaged again.

#### Scenario: The published artifact passes assessment offline

- GIVEN the app extracted from the published zip into a temporary location, with networking disabled
- WHEN Gatekeeper install assessment and staple validation are run against it
- THEN both accept it
- AND the run fails, publishing nothing, if either does not
- Verification: `ci-gate`

#### Scenario: The signature is the expected Developer ID identity

- GIVEN the extracted app
- WHEN its signing information is read
- THEN it reports a Developer ID Application authority for team `Z3S5JK8E38`
- Verification: `ci-gate`

#### Scenario: The published archive can only be the post-staple one

- GIVEN the release script
- WHEN the staple phase is inspected structurally
- THEN the pre-notarization archive is deleted after stapling and before repackaging
- Verification: `unit`

#### Scenario: A stranger's first launch is a single "Open"

- GIVEN the published zip downloaded through a browser onto a machine that has never seen the bundle, carrying the quarantine attribute
- WHEN it is unzipped, moved to `/Applications` and opened for the first time
- THEN the app launches after a single ordinary confirmation, with no Gatekeeper refusal and no right-click workaround
- Verification: `manual-evidence`

### Requirement: RD-5 A release is all-or-nothing, and release history is never rewritten (Layer: App) — PRD "Ship"

If any gate fails — version assertion, architecture, notarization, assessment, or staple validation — the run MUST fail **before publishing**, leaving no release, no asset, and no partially published state. A rejected or delayed notarization MUST be surfaced with its diagnostic log rather than silently retried past the gate.

Publication MUST occur only from the automated release run. A local execution of the release logic MUST be a rehearsal that produces the same artifact and publishes nothing: neither the build script nor the feed script MUST contain a version-control or release-management invocation of any kind, so neither can select a repository, commit, push, or publish, whatever directory it is run from.

A release run MUST NOT delete, unpublish, retract, or change the flags of **any previously published release or tag**. Withdrawing a bad release is a deliberate maintainer action, never an automatic side effect of publishing the next one.

#### Scenario: A failed gate publishes nothing at all

- GIVEN a run in which notarization is rejected
- WHEN the run terminates
- THEN it failed, the notarization diagnostic log is present in the run output
- AND no release, asset, or draft exists for that tag
- Verification: `ci-gate`

#### Scenario: Nothing in the repository can retract a release

- GIVEN the release workflow and both scripts
- WHEN they are inspected structurally
- THEN the only release-management invocation anywhere is a single `gh release create`
- AND no version-control invocation appears in the workflow or in either script
- Verification: `unit`

#### Scenario: The local path rehearses but cannot publish

- GIVEN the release script in the repository
- WHEN it is inspected structurally
- THEN it carries the build, sign, notarize, staple and verify sequence
- AND it contains no release-publishing command; publication exists only in the automated workflow
- Verification: `unit`

#### Scenario: Prior releases survive the next one untouched

- GIVEN one or more previously published releases
- WHEN a new tag is published
- THEN every prior release and tag is still present, still published, and its prerelease/latest flags are unchanged
- Verification: `ci-gate`

### Requirement: RD-6 Release infrastructure lives outside the shipped app sources (Layer: App) — PRD "Ship"

`system-monitor/` is a synchronized root group: any file placed inside it joins the app target and ships inside the bundle. Release infrastructure MUST therefore live **outside** it — export options and release scripts under `scripts/`, workflow definitions under `.github/` — and this placement MUST be enforced by a test, not by a comment. Both shell scripts MUST be executable, because a release script that is not is a documentation-like path that fails at the worst possible moment.

No release script, export options file, workflow definition, or signing configuration MUST appear inside the delivered bundle. The export configuration MUST declare the `developer-id` distribution method, manual signing with the `Developer ID Application` certificate, team `Z3S5JK8E38`, and MUST NOT let the export step manage version or build number.

#### Scenario: The infrastructure is where it belongs, and nowhere else

- GIVEN the repository tree after this change
- WHEN it is inspected structurally
- THEN `scripts/ExportOptions.plist`, `scripts/release.sh`, `scripts/appcast.sh` and the release workflow under `.github/` all exist, and both scripts are executable
- AND no export options file, release script, or workflow definition exists anywhere under `system-monitor/`
- Verification: `unit`

#### Scenario: The export configuration declares Developer ID distribution

- GIVEN `scripts/ExportOptions.plist`
- WHEN it is parsed as a property list
- THEN its method is `developer-id`, its signing style is `manual`, its certificate is `Developer ID Application`, its team identifier is `Z3S5JK8E38`, and it does not manage the app version and build number
- Verification: `unit`

#### Scenario: None of it ships to the user

- GIVEN the app extracted from the published zip
- WHEN its `Contents` directory is enumerated
- THEN no release script, export options file, workflow definition, or signing configuration is present among them
- Verification: `ci-gate`

### Requirement: RD-7 No credential material in the repository, and injected credentials die with the run (Layer: App) — PRD "Ship"

No signing certificate, private key, password, or API key MUST exist in the repository in any form — not in source, scripts, configuration, build settings, generated property lists, or documentation. A committed key header or archived certificate blob MUST fail a test.

Credentials MUST be injected at run time from the platform's secret storage into storage created for that run alone, and that storage MUST be destroyed **unconditionally at the end of the run, including when the run fails**. No step handling a credential MUST enable shell command tracing, and no credential value MUST ever be written to the run's log; every secret reference MUST be the plain right-hand side of an environment binding, never interpolated into a command line the runner echoes.

The set of repository secrets the release run may reference MUST be **closed and enumerated**: exactly the **seven** named `BUILD_CERTIFICATE_BASE64`, `P12_PASSWORD`, `KEYCHAIN_PASSWORD`, `APPLE_API_KEY_P8`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER_ID`, and `SPARKLE_PRIVATE_KEY`. Referencing a secret outside that set MUST fail a test. Adding one is allowed; adding one without updating the enumerated set is not.

The update-signing private key MUST be piped to the signing tool on **standard input**, never written to disk, never passed as a command argument, and never used as a redirection target. Its **public** counterpart is public by construction, ships inside every copy of the app, and MUST NOT be handled as a secret.

Adding a second delivery channel MUST NOT widen what the release run reaches: the release workflow MUST NOT declare a cross-repository dispatch and MUST NOT name any repository other than the one it runs in.

#### Scenario: The repository carries no secret material

- GIVEN every file in the repository outside version-control internals and build output
- WHEN they are inspected for key headers and archived certificate blobs
- THEN none is present
- Verification: `unit`

#### Scenario: The referenced secret set is exactly the seven named ones

- GIVEN the release workflow
- WHEN every repository secret it references is collected
- THEN the collected set is exactly the seven named in this requirement
- AND every reference is a plain `NAME: ${{ secrets.NAME }}` environment binding
- Verification: `unit`

#### Scenario: Credential cleanup cannot be skipped by a failure

- GIVEN the release workflow
- WHEN its steps are inspected structurally
- THEN exactly one step deletes the ephemeral keychain and the API key, and it is declared to run unconditionally
- Verification: `unit`

#### Scenario: No step traces its own commands around a credential

- GIVEN the release workflow and both scripts
- WHEN their executable lines are inspected
- THEN no line enables shell command tracing
- Verification: `unit`

#### Scenario: The update-signing key only ever reaches the tool on stdin

- GIVEN `scripts/appcast.sh` and the workflow step that invokes it
- WHEN every line naming the key is inspected
- THEN the key is bound exactly once, as an environment binding on that step
- AND every non-comment use in the script is the standard-input pipe into the signing tool, and none is a redirection target
- Verification: `unit`

#### Scenario: The release run gains no cross-repository reach

- GIVEN the release workflow
- WHEN it is inspected structurally
- THEN it declares no cross-repository dispatch
- AND every GitHub API call it makes names the repository it runs in
- AND it names neither the tap repository nor the tap
- Verification: `unit`

### Requirement: RD-8 The published feed is verifiable offline before an installed copy ever fetches it (Layer: Domain) — PRD "Ship"

The feed the release run publishes is what every installed copy trusts, so its contract MUST be checkable in this repository without network access and without the updater framework.

A valid appcast document MUST have a `<channel>`, and every item in it MUST carry a `sparkle:version`, a non-empty `sparkle:shortVersionString` that parses as a version, a `sparkle:minimumSystemVersion` equal to the app's deployment floor, an enclosure whose `sparkle:edSignature` is present, whose `length` is a number, and whose `url` is **`https`** on **`github.com`**. Items MUST be ordered strictly newest first, because the publication step prepends one item to the feed it fetched and an out-of-order document means the merge lost history.

No item MUST carry a hyphenated version: a prerelease reaching the feed would be offered to every stable user, and the version comparison alone would not prevent that.

Every rejection MUST be a **named failure carrying the offending item's index**, and a document with one bad item MUST NOT validate with that item dropped: a feed that half-validates is a feed that offers whatever survived the filter.

The emitter and the validator MUST agree on the minimum system version. The emitter's `MINIMUM_SYSTEM_VERSION` and the validator's `expectedMinimumSystemVersion` MUST be the same string, and a test MUST read **both** — two constants that must agree are only kept in step by something that reads both. The emitter MUST additionally pin its signing tool by version **and** by a `sha256` digest verified before anything is signed, and MUST write every element and attribute name the validator requires.

#### Scenario: A complete item validates and carries every field an update depends on

- GIVEN an appcast document with one well-formed item
- WHEN it is validated offline
- THEN the item's version, short version string, signature, length, minimum system version and enclosure URL are all read back with their exact values
- Verification: `unit`

#### Scenario: Every malformed shape is rejected with its own named failure

- GIVEN one document per defect: no channel, missing signature, missing length, non-numeric length, missing version, missing or unreadable short version string, `http` enclosure, foreign host, wrong or missing minimum system version, hyphenated version, and items out of order
- WHEN each is validated
- THEN each throws its own named failure, carrying the offending item's index where the defect is item-scoped
- AND no document validates with a bad item dropped
- Verification: `unit`

#### Scenario: A merge keeps every previously published item, newest first

- GIVEN a document carrying three published versions
- WHEN it is validated
- THEN all three items are present, in strictly descending version order, with three distinct enclosure URLs
- Verification: `unit`

#### Scenario: The emitter and the validator agree on the floor and on the names

- GIVEN `scripts/appcast.sh` and the offline validator
- WHEN both are read
- THEN the emitter's `MINIMUM_SYSTEM_VERSION` equals the validator's `expectedMinimumSystemVersion`
- AND the emitter writes every element and attribute name the validator requires
- Verification: `unit`

#### Scenario: The signing tool is pinned by version and by digest

- GIVEN `scripts/appcast.sh`
- WHEN it is inspected structurally
- THEN it names Sparkle 2.9.6 and exactly one `sha256` literal, and verifies that digest before signing anything
- AND a prerelease tag exits before writing anything at all
- Verification: `unit`

### Requirement: RD-9 The delivered build is installable through the project's Homebrew tap (Layer: App) — PRD "Ship"

The delivered build MUST be installable through Homebrew and not only by dragging a downloaded zip. The project MUST publish a Homebrew tap whose cask installs **the same published asset this capability already specifies** — no second artifact, no separately built binary, and no mirrored copy.

Adding the tap and installing the cask MUST place the delivered bundle at **`/Applications/System-Monitor.app`**, whose `CFBundleShortVersionString` equals the released version and whose bundle identifier is `com.juancasanueva.system-monitor`. The cask MUST NOT rename what it installs and MUST NOT declare a `target:`, because that would make the cask channel and the direct-download channel install different paths.

The cask MUST declare that the app **updates itself**, because Sparkle replaces the bundle in place: a self-updated copy MUST NOT cause `brew` to report a mismatch or to reinstall over the newer app. The declared checksum MUST equal the digest of the **published** asset, established by downloading that asset rather than by trusting a value computed while building it. The cask MUST NOT offer a prerelease version.

Keeping the cask current MUST NOT require a manual step and MUST be **idempotent on the declared version** — an update attempt against a release the cask already declares MUST change nothing. The channel therefore cannot manufacture a second commit, or a second release, from one published release, which is what keeps it compatible with "one stable release per commit". The bump MUST **pull** from this repository rather than being pushed to, so the release run holds no credential for the tap.

The install and uninstall instructions MUST be documented **in this repository** as whole, copy-pasteable lines rather than as fragments a reader must assemble, MUST state that the installed bundle is `System-Monitor.app`, and MUST state that a full uninstall removes no Keychain item because the app creates none.

#### Scenario: A tap and an install put the released build in `/Applications`

- GIVEN a Mac with Homebrew that has never had System Monitor installed
- WHEN the project's tap is added and its cask is installed
- THEN `/Applications/System-Monitor.app` exists and reports the released version
- AND the app launches without a Gatekeeper refusal
- Verification: `manual-evidence`

#### Scenario: The cask is style-clean, audit-clean, and survives a real install/uninstall round trip

- GIVEN a cask commit against a release that is already published
- WHEN the tap's CI runs style, offline audit, and online strict audit, then installs the cask and uninstalls it with a zap
- THEN every gate passes, the online audit confirms the declared checksum against the downloaded published asset, and the round trip completes
- AND a failing gate leaves nothing committed and nothing published
- Verification: `ci-gate` — `ci.yml` in `juancasanueva/homebrew-system-monitor`

#### Scenario: Keeping the cask current is idempotent on the declared version

- GIVEN a cask that already declares the latest published stable version
- WHEN the update mechanism runs again against that unchanged release
- THEN it exits successfully and produces no commit and no version change
- Verification: `ci-gate` — `bump.yml` in `juancasanueva/homebrew-system-monitor`

#### Scenario: A self-updated app does not fight `brew upgrade`

- GIVEN a cask-installed copy that has since updated itself in place to a newer version
- WHEN an upgrade is requested through Homebrew
- THEN Homebrew does not report the installed copy as outdated or reinstall over it
- AND the self-update replaced the bundle at its existing path rather than creating a second bundle
- Verification: `manual-evidence`

#### Scenario: The install commands are documented as whole lines

- GIVEN the repository's README
- WHEN its install section is read
- THEN it carries each brew command as a complete line a reader can copy and run
- AND it states that the installed bundle is `System-Monitor.app` and gives the fully-qualified form
- Verification: `unit`

## Verification notes

- `ReleasePipelineCompositionTests` (App): the project-file, placement, credential and workflow-contract halves of RD-1 through RD-7, each read off disk and anchored to `#filePath` because the test runner promises nothing about the working directory.
- `AppcastWorkflowTests` (App): the publication half of RD-1 — step ordering, the Pages permissions and environment, the distinct-commit gate, and the prerelease guard on all five publication steps.
- `AppcastScriptContractTests` (App): the emitter half of RD-8 and the stdin clause of RD-7. It reads `AppcastDocument.expectedMinimumSystemVersion` rather than repeating the literal, so the emitter and the validator cannot drift apart silently.
- `AppVersionTests` (Domain): RD-2's ordering and parsing clauses, driven entirely by literal strings.
- `AppcastDocumentTests` (Domain): RD-8's validator, driven by hand-authored fixtures under `system-monitorTests/Fixtures/Appcast`. The fixtures are hand-authored rather than emitted by `scripts/appcast.sh`, because running that script inside a test would need the signing tool, a private key and network egress. The consequence is stated rather than smoothed over: the emitter and the validator are proven to agree on **names and on the floor**, not on bytes.
- `ci-gate` scenarios are structurally verified in this repository and execute for real only on a tagged release run; none has executed yet. `manual-evidence` scenarios are documented in `RELEASING.md` with the exact output to record and have not been observed. That is a deferred release checklist, not an open defect.
- The app-side update surface — which feed the running bundle trusts, when it may check, and what the update UI may say — is `app-updates`, and is deliberately not restated here.
