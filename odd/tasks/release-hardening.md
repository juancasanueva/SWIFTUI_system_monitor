# Feature: release-hardening

## Objective
Port the release-pipeline hardening already shipped in Burnbar (juancasanueva/SWIFTUI_burnbar, PR #19) back to System Monitor, so a transient failure can no longer wipe the appcast's history or strand a published release without a feed entry.

## Problem / Why
Reviews of the Burnbar port found these weaknesses, all inherited from System Monitor:
1. `scripts/appcast.sh` treats any feed fetch failure (DNS, timeout, 5xx) as the first-release 404 and starts an empty channel, so the deploy can replace the live feed with a one-item feed.
2. The feed fetch and the Sparkle tools download run after `gh release create`, with no timeouts or retries, so a transient error strands a published release.
3. `RELEASING.md` says "a failure publishes nothing" and suggests re-tagging, which is false for the post-publish steps.
4. GitHub Actions are referenced by movable major tags while the signing keychain is unlocked.

## Reference (Burnbar, /Users/juancasanueva/programming/swiftUI/burnbar, read-only)
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

## Next step
Review, then open the PR (single-pr).
