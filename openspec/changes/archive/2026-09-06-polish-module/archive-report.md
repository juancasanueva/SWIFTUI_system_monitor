# Archive Report: polish-module (PRD M4 — "Polish — ship v1")

**Change**: `polish-module`
**Archived on**: 2026-09-06
**Archived to**: `openspec/changes/archive/2026-09-06-polish-module/`
**Artifact store**: hybrid (OpenSpec files under `openspec/` + Engram observations)
**Milestone**: PRD M4 "Polish — ship v1"; features F5 (launch at login) and F6 (settings: interval, module visibility, widget order); requirements R1.5, R5.1, R5.4, R6.2, R6.3; PRD 6.5 (reduce motion) and section 10 (redraw cost)
**Explicitly deferred**: F7 light mode and any appearance setting — out of scope for v1 by the confirmed product decision `light_mode_and_appearance: dark-only-v1`; F7 stays P2 for a later change. `Palette` is untouched and the popover is pinned to `darkAqua`.
**Status at close**: complete — verified PASS WITH WARNINGS (revision 2), 0 CRITICAL findings, 0 blockers; three destructive delta rewrites merged with explicit user confirmation; one PRD-goal miss accepted with a named follow-up.

This report is the terminal record of the cycle. It describes the state of the change **at close**.
Where it cites `apply-progress.md` or `verify-report.md`, those are intermediate snapshots and are
attributed to their moment in time, never restated as current fact.

---

## 1. Traceability

### Engram observation IDs (hybrid mirror)

| Artifact | Topic key | Observation ID |
|---|---|---|
| Exploration | `sdd/polish-module/explore` | 8237 |
| Research | — | not selected (user skipped research 2026-09-06; exploration had already verified the `SMAppService` and settings-window facts) |
| Proposal | `sdd/polish-module/proposal` | 8240 |
| Specs (6 deltas) | `sdd/polish-module/spec` | 8241 (upserted after the design validator, and again for the batch-H ST-5 scenario) |
| Design | `sdd/polish-module/design` | 8242 (revision 2, then revision 2.1 for the batch-H correction) |
| Tasks | `sdd/polish-module/tasks` | 8244 |
| Apply progress | `sdd/polish-module/apply-progress` | 8246, 8250, 8251, 8252, 8257 (batch series A–G plus correction batch H) |
| Verify report | `sdd/polish-module/verify-report` | 8254 (revision 2; supersedes revision 1) |
| Archive report | `sdd/polish-module/archive-report` | this document |
| State | `sdd/polish-module/state` | upserted to `ARCHIVED` at close |

### Archived filesystem artifacts

| File | Present |
|---|---|
| `exploration.md` | yes |
| `proposal.md` | yes |
| `design.md` (revision 2.1) | yes |
| `specs/` (6 delta specs: `settings`, `launch-at-login`, `menu-bar-widget`, `cpu-metrics`, `cpu-card`, `memory-card`) | yes |
| `tasks.md` (47/47 complete) | yes |
| `apply-progress.md` | yes |
| `verify-report.md` (revision 2) | yes |
| `state.yaml` (`status: ARCHIVED`) | yes |
| `archive-report.md` | this document (additive at archive time) |

`research.md` is absent by design: the research lane was unselected.

---

## 2. Specs synced to the source of truth

| Capability | Delta type | Destructive? | Merged |
|---|---|---|---|
| `settings` | New capability (full spec: ST-1..ST-7, 34 scenarios) | No | Created `openspec/specs/settings/spec.md` — mechanical `cp`, byte-identical to the delta |
| `launch-at-login` | New capability (full spec: LAL-1..LAL-4, 14 scenarios) | No | Created `openspec/specs/launch-at-login/spec.md` — mechanical `cp`, byte-identical to the delta |
| `menu-bar-widget` | Purpose amendment; MODIFIED MBW-1, MBW-9; ADDED MBW-10..MBW-14 | **Yes** (MBW-1, MBW-9) | Updated `openspec/specs/menu-bar-widget/spec.md` — 8 requirements → 13, 19 scenarios → 33 |
| `cpu-metrics` | Purpose amendment; MODIFIED "Loop resilience and cancellation" (now ID CM-1); ADDED CM-2, CM-3 | **Yes** (CM-1) | Updated `openspec/specs/cpu-metrics/spec.md` — 9 requirements → 11, 21 scenarios → 31 |
| `cpu-card` | MODIFIED "Palette and card surface" | No — the original "Token values" scenario is retained byte-identical and two scenarios are added | Updated `openspec/specs/cpu-card/spec.md` — 8 requirements, 14 scenarios → 16 |
| `memory-card` | MODIFIED MC-10 "Card surface and reduce motion" | No by the delta's own label — the "Reduce motion" scenario keeps its name but its Given/When/Then body is rewritten from an environment observation to a `MemoryCardModel.gaugeAnimation(reduceMotion:)` evaluation, and a "Motion allowed" scenario is added | Updated `openspec/specs/memory-card/spec.md` — 10 requirements, 20 scenarios → 21 |

Every requirement not named by a delta was preserved. The complete set of removed lines across the four
modified specs of record is: two Purpose paragraphs, four requirement prose sentences, three requirement
headings, and four scenario body lines — all inside the blocks the deltas rewrite. No untouched requirement
lost a byte.

Post-merge `rg` verification:

- Each delta requirement ID occurs **exactly once** in its spec of record: ST-1..ST-7 (1 each), LAL-1..LAL-4 (1 each), MBW-1, MBW-9, MBW-10..MBW-14 (1 each), CM-1, CM-2, CM-3 (1 each), MC-10 (1).
- `rg 'ADDED Requirements|MODIFIED Requirements|REMOVED Requirements|RENAMED Requirements|Destructive: archive must warn|Non-destructive:|\(Previously:|^# Delta for' openspec/specs/` → **no matches**. No delta scaffolding survived into the source of truth.

### Destructive-merge warning record (`rules.archive`: "warn before merging destructive deltas")

Three requirement rewrites lose prior normative text. They were presented to the user and **explicitly
confirmed on 2026-09-06 before this archive ran**. The exact confirmed rewrites:

1. **`menu-bar-widget` MBW-1 "Data-driven module list"**
   - Removed: *"The status item view MUST render modules from `MetricModule.menuBarOrder` (CPU then MEM)."*
   - Now: the view renders `SettingsState.menuBarModules`, read from the environment, in that order; the default is `MetricModule.menuBarOrder`; hidden modules MUST NOT render.
   - Also removed: the scenario line `- GIVEN \`menuBarOrder == [.cpu, .memory]\`` (now `menuBarModules`). Two scenarios added (hidden module omitted, reversed order).
   - Why destructive: the module list stops being a fixed constant and becomes a user-chosen ordered subset.

2. **`menu-bar-widget` MBW-9 "Fixed-width, jitter-free layout"**
   - Removed: *"`statusItem.length` MUST be set explicitly once and MUST NOT change as values change. … Total width for two modules MUST be under 230 pt."*
   - Now: the length is set on initialisation from a measurement of the *current* module set, re-measured **only when the module set changes**, and still never on a value tick; the budget is under 130 pt for one module and under 230 pt for two.
   - Why destructive: "set once" was a load-bearing invariant that the module-visibility feature necessarily breaks; the replacement narrows the permitted trigger instead of removing the guarantee.

3. **`cpu-metrics` "Loop resilience and cancellation" (assigned ID CM-1 by the delta)**
   - Removed: *"The loop MUST NOT depend on whether the panel is open."*
   - Now: *"The loop MUST keep running whether or not the panel is open; only its cadence changes"* — 2 s closed, the configured interval open, fast restart on open, with `SamplingCadence.effective(configured:panelOpen:)` as the pure rule. Three scenarios added (cadence truth table, loop keeps running while closed, opening restarts at the configured rate).
   - Why destructive: R5.4's idle cadence makes panel state a legitimate input to the loop's timing, which the old sentence forbade outright.

The user's confirmation covered all three by name. No other confirmation was requested and none was inferred.

### Mechanical readback evidence

New specs of record (`cp` → `diff -r` → `mv` → `diff -r`), verbatim:

```text
### diff -r openspec/changes/polish-module/specs/settings/spec.md openspec/specs/settings/.spec.md.zhI1ky
(exit 0)
### post-move diff -r openspec/changes/polish-module/specs/settings/spec.md openspec/specs/settings/spec.md
(exit 0)
### diff -r openspec/changes/polish-module/specs/launch-at-login/spec.md openspec/specs/launch-at-login/.spec.md.QmX5P1
(exit 0)
### post-move diff -r openspec/changes/polish-module/specs/launch-at-login/spec.md openspec/specs/launch-at-login/spec.md
(exit 0)
```

Archive folder move (recursive pre-move snapshot vs. destination), verbatim:

```text
MOVE: plain mv (source untracked; git mv refused; pre-move source verified byte-identical to snapshot)
### MANDATORY READBACK: diff -r $snapshot_root/source openspec/changes/archive/2026-09-06-polish-module
(diff -r exit status: 0)
READBACK PASSED — no differences
```

`git mv` was refused because the change folder was never tracked (`git ls-files openspec/changes/polish-module` → 0 files).
The skill's fallback path applied: the source was confirmed byte-identical to the snapshot and the
destination confirmed absent before `mv` ran. This also satisfies the standing constraint that the archive
must not touch the git index — the 27 intent-to-add entries are unchanged.

`state.yaml` and this `archive-report.md` were edited/added **after** the readback, so the empty diff above
is evidence of the artifacts as they left the active change folder.

---

## 3. Final state at close

These are the authoritative final numbers, per the Final-State Authority hierarchy. Where they differ from
`verify-report.md` or `apply-progress.md`, the difference is later work, not a correction of those snapshots.

| Fact | Value at close |
|---|---|
| Tests | **527 passing, 0 failing, 0 skipped** (baseline at `f41bc05` was 299) |
| Compiler warnings | **0**, under a forced full recompile of *both* targets (`fd -e swift . system-monitorTests system-monitor -x touch {}` then `xcodebuild … -quiet build-for-testing`) |
| Diff vs. `f41bc05` | 42 files changed, +5483 / −163, plus 27 new files staged intent-to-add |
| Commits | **none** — `HEAD` is still `f41bc0535c53279e93824622450f468fe8bc0272` |
| Tasks | **47/47 complete** (42 automated + 5 manual) |
| Requirements / scenarios | 23/23 requirements, 85/85 scenarios COMPLIANT |
| Verdict | `pass_with_warnings`; 0 blockers, 0 CRITICAL |

The zero-warning gate depends on the touch-all prerequisite: a plain `build` never compiles the test target,
which is how two `no 'async' operations occur within 'await' expression` warnings survived batch A undetected.
`build-for-testing` over a touched tree is the gate that catches them.

### Task Completion Gate

`tasks.md` in the archived folder contains 47 checkboxes, **47 marked `[x]` and 0 marked `[ ]`**. The gate
passed with no reconciliation: no stale checkbox was flipped by this phase.

Note the ranking this resolves. `verify-report.md` revision 2 records "46/47 tasks complete — 1 incomplete:
task 8.7 (MANUAL Instruments)". That was true *at verification time on 2026-09-06*. Task 8.7 was executed by
the user after that report was written, and the persisted tasks artifact — the highest-ranked source for
completion — now shows it complete with its result recorded. 47/47 is the state at close; the snapshot's
"1 incomplete" is valid history, not a current fact.

---

## 4. What was delivered

**Domain**
- `Settings` value: `nonisolated`/`Sendable`/`Equatable`, interval clamped to 0.5–5 s (default 1 s), `menuBarModules` order-preserving, duplicate-dropping, never empty (empty normalises to `MetricModule.menuBarOrder`), plus six pure transition helpers (`withSamplingInterval`, `canHide`, `showing`, `hiding`, `movingUp`, `movingDown`) carrying the last-module guard.
- `LaunchAtLoginStatus`: four-case enum (`notRegistered`, `enabled`, `requiresApproval`, `notFound`) with `isEnabled` and `needsApproval`.
- Ports defined before adapters: `SettingsStore` (`load()` never throws, `save(_:) throws`) and `LaunchAtLoginService` (`status`, `enable()`, `disable()`, `openLoginItemsSettings()`).
- `MetricModule.menuBarOrder` documented as the *default* order, not the rendered order.

**Application**
- `SettingsState`: the second `@MainActor @Observable` object; loads on init, persists every accepted mutation through the port, refuses to hide the last visible module, keeps the in-memory value on a save failure and records `lastSaveError`, and notifies synchronous main-actor observers after each commit.
- `SamplingCadence.effective(configured:panelOpen:)`: the pure R5.4 rule (2 s closed, configured open), plus `PanelVisibilityObserver` and `SamplingCadenceController` translating panel transitions and interval changes into sampler calls.
- `MetricsSampler.apply(interval:)`: idempotent for an unchanged value; while stopped it stores; while running it does exactly one `stop(); start()`, costing one publish-free CPU tick (memory still publishes on that tick).
- `ManualClock` and the W1/W5 loop rewrite: the five wall-clock loop tests and the `waitUntil` polling helper are gone; every loop scenario now runs on the injected `Clock` with an `awaitSleepCount` rendezvous. The M3 debt items W1 and W5 are retired.

**Infrastructure**
- `UserDefaultsSettingsStore(defaults:)`: two plain keys (`Double` seconds, `[String]` module raw values), field-by-field fallback on missing/corrupt/out-of-range values, unknown module raw values dropped, `@unchecked Sendable` with `nonisolated(unsafe) let defaults` and the documented-thread-safety citation.
- `SMAppServiceLaunchAtLogin`: stateless wrapper over `SMAppService.mainApp`, status read live on every access and never persisted, with a unit-testable static `map(_:)` (`@unknown default` → `.notRegistered`).

**Presentation**
- `ContextMenuModel`: pure three-item table (`"Settings…"`, `"Launch at Login"`, `"Quit System Monitor"`) with the check state and action derived per `LaunchAtLoginStatus`, including the `"Launch at Login (Requires Approval)…"` routing to Login Items.
- `SettingsFormModel` (pure derivations: stepper increments, saturation, locale-pinned label, module rows), `SettingsView` (grouped `Form`, 360 pt wide), and `SettingsWindowController` (one reusable `NSWindow` titled "Settings", `isReleasedWhenClosed = false`).
- `StatusItemController`: context menu and launch-at-login actions, `NSPopoverDelegate` transitions, re-measure only on a module-set difference, popover pinned to `.darkAqua`, and `isolated deinit` removing the `NSStatusItem` — retiring M3 debt item **W6**.
- `gaugeAnimation(reduceMotion:)` on `CPUCardModel` and `MemoryCardModel`, moving the reduce-motion decision out of the view bodies and turning **MC-10** from an inspection-only claim into a unit test.
- `StatusItemView`: `StatusItemReadings.build(modules:…)` and `StatusItemMetrics.measurementReadings(for:)` replacing the static maps; `Equatable` `StatusItemContent`/`ModuleLabel` for redraw gating.

**App and documentation**
- `AppDelegate` composition root: store → `SettingsState` → `MetricsState` → sampler seeded at the closed cadence → `SamplingCadenceController` → `SettingsWindowController` → `StatusItemController` → `sampler.start()`, all collaborators retained.
- `Cmd+,` via `CommandGroup(replacing: .appSettings)` calling the same `showSettings()`; the mandatory `SwiftUI.Settings { EmptyView() }` scene keeps its qualification because the Domain `Settings` type shadows it.
- `PRD.md` 6.1 and 6.4 amended (Application holds two `@Observable` objects), PRD section 10 points at the recorded Instruments numbers; `openspec/config.yaml` lines 24, 25 and 90 corrected against verified repository facts.

---

## 5. Test evidence

```text
xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests
exit 0 | rg -c "' passed on '" = 527 | rg -c "' failed on '" = 0

fd -e swift . system-monitorTests system-monitor -x touch {}
xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build-for-testing
exit 0 | rg -c "warning:" = 0 | rg -c "error:" = 0
```

Validator evidence revision recorded by `sdd-verify`: `sha256:0445c505d0f50607353d44f7b8beab6d9ea613f9eef2fa6933b13c3be7df852d`.
Test output hash `sha256:e45fa414…fbc1e`; build output hash `sha256:1997f6bc…f812`.

Layer distribution at close: roughly 330 pure unit cases, roughly 182 AppKit-host cases (real `NSStatusItem`,
`NSWindow`, `NSMenu`, `NSHostingView`), and 10+ `.integration` cases (live `SMAppService` status reads, real
`UserDefaults` suites, real Mach counters, the real composition graph). The `.integration` suites are not
excluded from the default command and did run.

TDD compliance: 6/6 checks passed, with the safety-net count recorded per batch
(299 → 359 → 389 → 426 → 483 → 497/501 → 518 → 525 → **527**).

---

## 6. Manual checks (user-executed, 2026-09-06)

| Check | Result |
|---|---|
| **8.3** Settings entry points | **PASSED** after correction batch H. The first run **FAILED**: the Settings window rendered as a bare title bar. Root cause, confirmed: `NSHostingController`'s default `sizingOptions` (`.standardBounds`) publish min/intrinsic/max on the hosted *view* but never set `preferredContentSize`, and a grouped `Form` is a scrolling container with no intrinsic height, so `contentRect: .zero` survived as a `(0, 0)` content area. Fixed by an explicit `setContentSize` from the hosted form's `fittingSize`, floored at `SettingsView.formHeight` (280 pt), applied before `center()`. Cost: two new tests, one new spec scenario (ST-5 "First show presents the whole form"), design revision 2.1. On re-run the window opened in front, key, with a normal title bar; Cmd+, brought back the same window, never a second and never an empty scene window. |
| **8.4** Interval and cadence | **PASSED** — 0.5 s and 5 s intervals observed with the panel open, 2 s idle cadence observed with it closed, and the popover open/close pair exercised including the `performClose` arm of `togglePopover()`. |
| **8.5** Module visibility and order | **PASSED** — hiding MEM shrank the bar to the one-module width and showing it restored the two-module width; the move chevrons reordered the widget in both directions ("up is up"). |
| **8.6** Launch at login and appearance | **PASSED** — real `SMAppService` registration and deregistration observed in System Settings › Login Items, the approval-pending path routed to Login Items instead of toggling, the popover chrome stayed dark under a light system appearance, and Reduce Motion made the ring gauge jump. |
| **8.7** Instruments (PRD 10) | **DONE with a MISS** — see below. |

### 8.7 in detail — the PRD section 10 miss

- Panel **closed**, run at 10:02, 10 minutes: **9.85 s of sampled CPU ≈ 1.6% of one core**. The PRD section 10 goal is **under 1%**, so this misses by roughly 0.6 points.
- Heaviest closed-panel stack: `NSStatusItem` → `NSView layoutSubtreeIfNeeded` → SwiftUI `ViewGraph`. **No `PanelView` bodies appear in the closed-panel samples.**
- Panel **open**, run at 10:03, 10 minutes: **40.77 s ≈ 6.8%**, dominated by `CA::Transaction` commits.
- Resident memory was **not captured**, so the "< 50 MB RSS" half of the check has no recorded number.

**User decision, recorded**: archive M4 now and ship v1; open a separate follow-up SDD change
(`redraw-optimization`) covering the status-item AppKit layout cost per tick, the panel's Core Animation
commit size, G3 (build the popover hosting controller on `popoverWillShow` and drop it on close) as a
candidate, and the idle cadence as a possible product knob. G3 was *not* triggered by its own stated
condition — that condition was closed-panel `PanelView` bodies evaluating, and none were observed — so it
enters the follow-up as a candidate, not as a diagnosed fix.

This archive therefore closes with one **PRD-goal miss accepted by explicit user decision**. It is not a
verification blocker: task 8.7 gates PRD-10 evidence and the two specs' non-scenario "Manual:" notes, never a
`#### Scenario:` heading, so all 85 scenarios were already covered by tests that passed at runtime.

---

## 7. Verification warnings — disposition at close

**Closed by the manual checks** (revision 1 warnings retired by runtime observation; listed for provenance,
not as open risk):

- **W-1** MBW-13 "No duplicate transitions": the `performClose` arm never executed headlessly — closed by 8.4.
- **W-2** ST-6 chevron-to-intent binding uncovered by construction — closed by 8.5.
- **W-3** Cmd+, unreachable from the unit target — closed by 8.3.
- **W-4** launch-at-login registration mutations proven only through the fake — closed by 8.6.
- **W-8** S3 activation fallback deliberately not implemented — closed by 8.3: the window is in front and key on first show, so the fallback's trigger condition never fired.

**Open at close** (all low severity, none blocking):

- **W-5** — `MachIntegrationTests.swift:64` retains a 120 ms `Task.sleep`. Pre-existing hardware-settle wait outside this change's scope; it is the only remaining `Task.sleep` in the whole test target, and the CM-3 grep gate over the sampler loop suites is clean.
- **W-6** — `AppDelegateCompositionTests` reads `.standard` `UserDefaults`. Read-only; it never mutates a stored preference. The unconditional identity assertion (`panelVisibilityObserver === cadence`) covers the case where a developer's stored 2 s interval would make two compared cadences coincidentally equal.
- **W-7** — `SettingsState.observers` is append-only and never pruned. Both current registrants capture `[weak self]` and `releasingTheControllerRemovesItsStatusItem` proves it, but any future registrant must do the same.
- **W-9** — the settings window is sized once, at creation, and never re-sized. Not a defect: a grouped `Form` scrolls rather than clips, and the 280 pt floor carries 36 pt of headroom over the 244 pt natural height. Recorded because the batch-H tests assert sizing only on a freshly created window.

---

## 8. Known debt and follow-ups

1. **PRD section 10 CPU goal missed** (1.6% closed vs. under 1%). Owner: the follow-up change `redraw-optimization`. Resident memory was never measured and should be captured there too.
2. **`seconds(_:)` is duplicated** in `SettingsFormModel` (Presentation) and `UserDefaultsSettingsStore` (Infrastructure) for layering reasons. Both are pinned by tests so a drift fails, but a shared Domain `Duration` extension would remove the duplication.
3. **`ClockProbe` lives in `MetricsSamplerTests.swift`** rather than under `system-monitorTests/Support`, unlike the other test doubles.
4. **Chevron-to-intent binding and the Cmd+, command remain manual-only by construction.** A SwiftUI `CommandGroup` only exists inside a running `App` scene, and swapping the two move `Button` bodies still passes all 527 cases. Both were runtime-confirmed by 8.3 and 8.5, but neither has an automated guard.
5. **S3 activation-policy fallback not implemented.** Its trigger condition did not fire on this machine; the design records the exact implementation if a future machine refuses activation.
6. **Suggestions carried forward from `verify-report.md` revision 2**: prune `SettingsState.observers` with a token-based `observe`/`cancel` pair (W-7); re-apply the content sizing on every `show()` or add a test that grows the hosted form after the first show (W-9).

---

## 9. Bookkeeping — attempt ledger

All work units are settled in the `gentle-ai sdd-attempt` ledger: batches A–G and correction batch H settled
`complete`; verify revisions 1 and 2 settled `passed`. One maintainer reset occurred after batch A, which
came in at 1259 lines against a 1200-line cap.

Review workload: `delivery_strategy: single-pr` with `review_budget_lines: unlimited` and a `size:exception`
accepted by the user up front (`state.yaml:7`). The tasks forecast recorded `400-line budget risk: High`,
`Chained PRs recommended: No`, `Decision needed before apply: No`. Batches A–H are apply/commit boundaries,
not separate PRs.

---

## 10. Repository state at close

| Check | Value |
|---|---|
| `HEAD` | `f41bc0535c53279e93824622450f468fe8bc0272` — unchanged |
| Working tree vs. `HEAD` | 42 files changed, +5483 / −163 |
| Intent-to-add entries | 27 — unchanged by this archive |
| `git status --short system-monitor.xcodeproj` | empty (test-run `INFOPLIST` key re-sort reverted per convention 16) |
| Active changes directory | `openspec/changes/` holds only `archive/`; `polish-module` is gone from it |

---

## 11. Delivery

**Delivery is user-owned. This archive committed nothing and staged nothing.**

- Use conventional commits, grouped by work unit (batches A–G plus correction H are natural boundaries).
- Add no attribution or co-author trailers.
- Before committing, revert the `project.pbxproj` noise an Xcode test run leaves behind:
  `git checkout -- system-monitor.xcodeproj/project.pbxproj`. Never commit it.
- The 27 intent-to-add entries are a ledger convenience so `git diff` shows new files; they are not a
  staging decision and carry no delivery intent.

---

## 12. Next

- **SDD cycle for `polish-module`: complete.** No further phase is pending.
- Recommended follow-up change: **`redraw-optimization`** — status-item AppKit layout cost per tick, panel Core Animation commit size, G3 (hosting controller built on `popoverWillShow`, dropped on close) as a candidate, and the idle cadence as a product knob. Capture resident memory alongside CPU.
- F7 (light mode / appearance setting) remains P2 and is unclaimed.

## SDD Cycle Complete

`polish-module` has been explored, proposed, specified, designed, broken into tasks, implemented under strict
TDD, corrected once after a manual check exposed a real defect, verified, and archived. PRD M4 is closed and
v1 is ready to ship, with one accepted performance miss tracked as a named follow-up.
