# Feature: release-hardening

## Objective
Port the release-pipeline hardening already shipped in Burnbar (juancasanueva/SWIFTUI_burnbar, PR #19) back to System Monitor, so a transient failure can no longer wipe the appcast's history or strand a published release without a feed entry.

## Problem / Why
Reviews of the Burnbar port found these weaknesses, all inherited from System Monitor:
1. `scripts/appcast.sh` treats any feed fetch failure (DNS, timeout, 5xx) as the first-release 404 and starts an empty channel, so the deploy can replace the live feed with a one-item feed.
2. The feed fetch and the Sparkle tools download run after `gh release create`, with no timeouts or retries, so a transient error strands a published release.
3. `RELEASING.md` says "a failure publishes nothing" and suggests re-tagging, which is false for the post-publish steps.
4. GitHub Actions are referenced by movable major tags while the signing keychain is unlocked.

## Reference (Burnbar, https://github.com/juancasanueva/SWIFTUI_burnbar, read-only)
PR #19, squash-merged to main as `834d9df`; its branch commits:
- `7555e16` fix: appcast only starts empty on a 404 and actions are pinned
- `cb8eab3` docs: accurate release failure recovery
- `de69f97` fix: fetch the live feed before publishing, with timeouts and retries
- `58442cd` fix: fetch the Sparkle tools before publishing
- Files: `scripts/appcast.sh`, `.github/workflows/release.yml`, `RELEASING.md`, `burnbarTests/AppcastScriptContractTests.swift`, `burnbarTests/AppcastWorkflowTests.swift`.

## Scope (authorized)
`scripts/appcast.sh`, `.github/workflows/release.yml`, `RELEASING.md`, and the release contract tests in `system-monitorTests/App/`. No app code changes.

## Constraints
- Keep System Monitor's names (System-Monitor.app, asset `System-Monitor-<v>.zip`, feed URL, minimum 15.0) and its extra guards and tests (ReleasePipelineCompositionTests); adapt them rather than delete.
- Test-first where a deterministic test exists.

## Delivery strategy
single-pr with `size:exception` if over budget (user preference for these ports).

## Tasks
- [x] T1 Port the four Burnbar commits: 404-only empty channel, `fetch` and `tools` modes before Publish with timeouts and bounded retries, build consumes pre-fetched feed and tools, actions pinned to SHAs, RELEASING.md failure recovery, tests (fake-curl harness, workflow ordering, pins). Route: delegated (writer trigger: several non-trivial files).

- [x] T2 Review follow-ups: curl exits 16, 18 and 92 are transient; FETCH_RETRY_DELAY validated as a non-negative integer at start; usage names every mode; the prerelease test checks each mode's destination; the duplicated blast-radius test is removed in favour of `ReleaseWorkflowContractTests.theWorkflowCanOnlyEverCreateARelease`; the Xcode 26.6 pin is explained truthfully (deployment target is 15.0). Route: inline in a delegated writer.

## Acceptance criteria
- `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' test` passes (unit tests).
- `bash -n`, `shellcheck scripts/*.sh`, `actionlint .github/workflows/release.yml` clean.

## Progress / Evidence
- T1 done (route: delegated writer).
  - `6b0315f` fix(release): fetch the feed and Sparkle tools before publishing. Covers the script, the workflow and the ported tests.
  - `79875df` docs(release): accurate failure recovery before and after Publish.
  - The ported script and workflow are identical to Burnbar except for System Monitor's names and `MINIMUM_SYSTEM_VERSION="15.0"`; this was checked with `diff` after name substitution.
  - RED: with only the ported tests, `xcodebuild ... -only-testing:system-monitorTests test` gave TEST FAILED. 17 tests failed in AppcastScriptContractTests (fake-curl harness, tools, one curl site) and AppcastWorkflowTests (fetch and tools ordering, 7 guarded steps, SHA pins), plus the parameterized cases.
  - GREEN: TEST SUCCEEDED (955 passing test-case lines); `bash -n scripts/*.sh` ok, `shellcheck scripts/*.sh` clean, `actionlint .github/workflows/release.yml` clean.
  - ReleasePipelineCompositionTests needed no change: it still sees exactly one `gh release create`, no `git`, seven secrets, and one keychain cleanup step.

- T2 done (commits `e68f55d` fix(release): retry partial and HTTP/2 transfer errors, `ed64e79` test(release): drop the duplicated blast-radius test, `410609e` docs(release): explain the Xcode 26.6 pin accurately, `568f155` docs(release): list the HTTP/2 and partial-transfer retries).
  - RED: with only the new tests, `xcodebuild ... -only-testing:system-monitorTests/AppcastScriptContractTests test` gave TEST FAILED: 3 cases of `everyTransientClassIsRetried` (curl exits 16, 18, 92), every case of `aMalformedRetryDelayFailsImmediately`, and `anUnknownModePrintsTheFullUsage`. The other transient cases (6, 7, 28, 35, 52, 55, 56, 408, 429, 5xx) and the non-transient cases (3, 60) already passed.
  - GREEN: `xcodebuild ... -only-testing:system-monitorTests test` TEST SUCCEEDED; `bash -n`, `shellcheck scripts/*.sh`, `actionlint .github/workflows/release.yml` clean.
  - Xcode 26.6: the project was created and last upgraded with Xcode 26.6 (`LastUpgradeCheck = 2660`, `CreatedOnToolsVersion = 26.6`) and sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES` (Swift 6.2, Xcode 26). No `#available(macOS 26…)` gates exist. `MACOSX_DEPLOYMENT_TARGET = 15.0`.

## Next step
Review, then open the PR (single-pr).
