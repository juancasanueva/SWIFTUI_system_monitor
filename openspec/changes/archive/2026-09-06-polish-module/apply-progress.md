# Apply Progress: Polish Module

Mode: Strict TDD. Delivery: single-pr with `size:exception` recorded (review budget unlimited); chain strategy `size-exception`.

## Batch A — Phase 1 (Domain foundation) + Phase 2 (test doubles)

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-a-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:a0ea323b5efebcf637a39f276ad007a90849a6e7b7e922b4153e039655bf061e"}` (parent token continued, zero ledger mutation; not settled by this actor)
- Work unit: `apply-batch-a-phases-1-2-domain-and-test-doubles`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`

### Tasks completed

- [x] 1.1 RED ST-1 invariants — `system-monitorTests/Domain/SettingsTests.swift`
- [x] 1.2 GREEN `system-monitor/Domain/Models/Settings.swift`
- [x] 1.3 RED LAL-1 — `system-monitorTests/Domain/LaunchAtLoginStatusTests.swift`
- [x] 1.4 GREEN `system-monitor/Domain/Models/LaunchAtLoginStatus.swift`
- [x] 1.5 GREEN ports before adapters — `SettingsStore.swift`, `LaunchAtLoginService.swift`, `MetricModule.menuBarOrder` doc comment
- [x] 1.6 RED CM-1 cadence truth table — `system-monitorTests/Application/SamplingCadenceTests.swift`
- [x] 1.7 GREEN `system-monitor/Application/SamplingCadence.swift`
- [x] 2.1 RED→GREEN `system-monitorTests/Support/FakeSettingsStore.swift` + ST-2 cases
- [x] 2.2 RED→GREEN `system-monitorTests/Support/FakeLaunchAtLoginService.swift` + LAL-2 cases
- [x] 2.3 RED→GREEN `system-monitorTests/Support/ManualClock.swift` + `ManualClockTests`
- [x] 2.4 RED→GREEN `system-monitorTests/Support/PanelVisibilitySpy.swift` + double self-checks

11 of 11 batch-A tasks complete. Phases 3–8 remain.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 1.1/1.2 | `Domain/SettingsTests.swift` | Unit | 299/299 baseline | Yes — `cannot find 'Settings' in scope` | Yes — 325 cases, 0 failures | Yes — 5-row clamp table, both list-normalisation paths, both guard paths, all four move edges | None needed |
| 1.3/1.4 | `Domain/LaunchAtLoginStatusTests.swift` | Unit | N/A (new) | Yes — `cannot find 'LaunchAtLoginStatus' in scope` | Yes — 334 cases, 0 failures | Yes — parameterised over all four cases, both predicates | None needed |
| 1.5 | `Domain/MetricModuleTests.swift` (untouched, still green) | Unit | 334/334 | N/A — structural port declaration | Yes — 334 cases, 0 failures | Triangulation skipped: protocol declaration with one possible shape; its scenarios land in 2.1/2.2 | None needed |
| 1.6/1.7 | `Application/SamplingCadenceTests.swift` | Unit | N/A (new) | Yes — `cannot find 'SamplingCadence' in scope` | Yes — 340 cases, 0 failures | Yes — 3 configured intervals x closed/open | None needed |
| 2.1 | `Domain/SettingsTests.swift` (ST-2 suite) | Unit | 340/340 | Yes — `cannot find 'FakeSettingsStore' in scope` | Yes — 344 cases, 0 failures | Yes — seeded vs unseeded load, throwing vs recording save, main vs detached thread | None needed |
| 2.2 | `Domain/LaunchAtLoginStatusTests.swift` (LAL-2 suite) | Unit | 344/344 | Yes — `cannot find 'FakeLaunchAtLoginService' in scope` | Yes — 350 cases, 0 failures | Yes — enable/disable success and scripted failure, openLoginItems, setStatus rescripting | None needed |
| 2.3 | `Application/MetricsSamplerTests.swift` (`ManualClockTests`) | Unit | 350/350 | Yes — `cannot find 'ManualClock' in scope` | Yes — 356 cases, 0 failures | Yes — advance order, large-advance no-replay, rendezvous idempotence, parked-sleeper cancellation, past deadline | Yes — extracted `ClockProbe` box after the non-copyable `Mutex` capture error; re-ran green |
| 2.4 | `Application/SamplingCadenceTests.swift` (doubles suite) | Unit | 356/356 | Yes — `cannot find 'PanelVisibilitySpy'/'ErrorRecorder' in scope` | Yes — 359 cases, 0 failures | Yes — ordered transitions, empty spy, recorded error identity | None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, 359 test cases, 0 failures |
| Runtime harness command/scenario and exact result | N/A — batch A is pure Domain values, a pure cadence rule and test doubles; no runtime boundary. The `.integration` adapter reads land in batch C (Phase 4) |
| Rollback boundary | Delete `Domain/Models/{Settings,LaunchAtLoginStatus}.swift`, `Domain/Ports/{SettingsStore,LaunchAtLoginService}.swift`, `Application/SamplingCadence.swift`, `Tests/Domain/{SettingsTests,LaunchAtLoginStatusTests}.swift`, `Tests/Application/SamplingCadenceTests.swift`, `Tests/Support/{ManualClock,FakeSettingsStore,FakeLaunchAtLoginService,PanelVisibilitySpy}.swift`; `git checkout --` on `App/system_monitorApp.swift`, `Domain/Models/MetricModule.swift`, `Tests/Application/MetricsSamplerTests.swift` |

### Files created

| File | Lines |
|---|---|
| `system-monitor/Domain/Models/Settings.swift` | 104 |
| `system-monitor/Domain/Models/LaunchAtLoginStatus.swift` | 28 |
| `system-monitor/Domain/Ports/SettingsStore.swift` | 16 |
| `system-monitor/Domain/Ports/LaunchAtLoginService.swift` | 15 |
| `system-monitor/Application/SamplingCadence.swift` | 19 |
| `system-monitorTests/Domain/SettingsTests.swift` | 216 |
| `system-monitorTests/Domain/LaunchAtLoginStatusTests.swift` | 102 |
| `system-monitorTests/Application/SamplingCadenceTests.swift` | 66 |
| `system-monitorTests/Support/FakeSettingsStore.swift` | 72 |
| `system-monitorTests/Support/FakeLaunchAtLoginService.swift` | 100 |
| `system-monitorTests/Support/ManualClock.swift` | 191 |
| `system-monitorTests/Support/PanelVisibilitySpy.swift` | 38 |
| Total new | 967 |

### Files modified (`git diff --stat`)

| File | Change |
|---|---|
| `system-monitor/App/system_monitorApp.swift` | +3 / -1 |
| `system-monitor/Domain/Models/MetricModule.swift` | +2 / -1 |
| `system-monitorTests/Application/MetricsSamplerTests.swift` | +161 / -0 |

Tracked diff total: 166 insertions, 2 deletions. Batch-A authored total including new files: about 1133 lines. `system-monitor.xcodeproj/project.pbxproj` is unmodified (convention 6 and 16 respected; reverted after every run).

### Test and warning counts

- Before batch A: 299 test cases, 0 failures.
- After batch A: 359 test cases, 0 failures (`TEST` exit 0). +60 cases.
- Warnings: `xcodebuild ... -quiet build` exit 0, `rg -c "warning:"` = 0.

### Deviations from the design

1. **`SwiftUI.Settings` qualification in `system-monitor/App/system_monitorApp.swift` (Phase 7 file, 1 token + 2 comment lines).** Mandatory for compilation, not scope creep. The design names the Domain value `Settings` verbatim, and a module-level `Settings` shadows the SwiftUI `Settings` scene inside the app module. Proven by reverting the file and building: `system_monitorApp.swift:10:9: error: static method 'buildExpression' requires that 'Settings' conform to 'Scene'` and `:10:18: error: extra trailing closure passed in call`. The `.commands`/`CommandGroup` work of task 7.2 was NOT done. Batch G must keep this qualification.
2. **`PanelVisibilitySpy` does not yet declare `: PanelVisibilityObserver`.** The protocol is created by task 3.6 (batch B), so the conformance cannot compile in batch A. The method signatures already match the design; batch B adds only the conformance clause. Recorded in the file's doc comment.
3. **`ClockProbe<Value>` added to `MetricsSamplerTests.swift` (not in the design).** A bare `Mutex` local cannot be captured by a detached task in Swift 6 (`sending value of non-Sendable type '@concurrent () async -> ()'`) because `Mutex` is non-copyable and is captured by borrow. The box mirrors the codebase's existing pattern of a `final class` owning a `let Mutex`. Batch B's loop rewrite can reuse it.
4. **Task 2.4 gained three self-check tests** (`Panel visibility doubles` suite in `SamplingCadenceTests.swift`). The task text lists no test, but strict TDD forbids adding code with no failing test first. The doubles are still consumed in 3.5 and 6.3/6.5 as planned.
5. **`ManualClock.sleep` increments `sleepCount` on both the parking and the already-past-deadline path.** The design does not state which. The counter covers every sleep that registers, including one whose deadline has already passed; a sleep cancelled before registration does not count (validator-corrected wording). Batch B must not build an `awaitSleepCount` expectation around a sleep cancelled after `stop()`.

### Open items for batch B (Phase 3)

- Add `: PanelVisibilityObserver` to `PanelVisibilitySpy` when task 3.6 creates the protocol (deviation 2).
- Task 3.7 rewrites `MetricsSamplerLoopTests` onto `ManualClock` and deletes the `waitUntil` poller at `MetricsSamplerTests.swift:294-306` (doc comment at :294, closing brace at :306; validator-corrected range). That helper and the five wall-clock loop tests are still present and green; batch A only appended `ClockProbe` and `ManualClockTests` after the existing suites.
- `ManualClock` semantics to rely on: advance one interval at a time, each followed by `awaitSleepCount(n)`; one large advance resumes only the sleeper parked at that moment (proved by `oneLargeAdvanceResumesOnlyTheSleeperParkedAtThatMoment`).
- `MetricsSampler.interval` is still `private let` (`:62`); task 3.4 makes it `private(set) var` and adds `apply(interval:)`.
- `SamplingCadence.swift` currently holds only the pure rule; task 3.6 appends `PanelVisibilityObserver` and `SamplingCadenceController`.
- A full `TEST` run leaves `system-monitor.xcodeproj/project.pbxproj` untouched in this environment, but keep reverting it per convention 16.
- The first clean build of the session took about 21 minutes; incremental runs take 3–20 seconds.

- Batch G (task 7.2): the `SwiftUI.Settings` qualification in `system-monitor/App/system_monitorApp.swift` is compilation-required; keep it when adding the `CommandGroup`.

## Batch B — Phase 3 (Application)

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-b-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:85aac7af171b11c6e39400b0962922ba142fda57238af0ba5ea0ff61f1f333b8"}` (parent token continued, zero ledger mutation; no untracked declaration demanded, not settled by this actor)
- Work unit: `apply-batch-b-phase-3-application-settings-state-sampler-restart-manual-clock`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`

### Tasks completed

- [x] 3.1 RED ST-4 — `system-monitorTests/Application/SettingsStateTests.swift`
- [x] 3.2 GREEN `system-monitor/Application/SettingsState.swift`
- [x] 3.3 RED CM-2 — `MetricsSamplerTests.swift`, `makeSampler` gains `clock:`
- [x] 3.4 GREEN `MetricsSampler.interval` becomes `private(set) var` + `apply(interval:)`
- [x] 3.5 RED CM-1 controller + ST-7 — `SamplingCadenceTests.swift` and `SettingsStateTests.swift`
- [x] 3.6 GREEN `PanelVisibilityObserver` + `SamplingCadenceController` in `SamplingCadence.swift`; `PanelVisibilitySpy` conformance
- [x] 3.7 REFACTOR W1/W5 retirement — `MetricsSamplerLoopTests` rewritten onto `ManualClock`

7 of 7 batch-B tasks complete. 18 of 18 tasks across phases 1–3. Phases 4–8 remain.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.1/3.2 | `Application/SettingsStateTests.swift` | Unit | 359/359 baseline | Yes — `cannot find 'SettingsState' in scope` (exit 65) | Yes — 375 cases, 0 failures | Yes — both clamp bounds, both `setModule` branches, hide accepted vs refused, `moveUp`/`moveDown` plus an edge no-op, save success vs scripted failure vs recovery, observer count across three commits | None needed |
| 3.3/3.4 | `Application/MetricsSamplerTests.swift` (`MetricsSamplerLoopTests`) | Unit | 375/375 | Yes — `'interval' is inaccessible due to 'private'`, `value of type 'MetricsSampler' has no member 'apply'` (exit 65) | Yes — 379 cases, 0 failures | Yes — all four CM-2 scenarios: stopped store, running restart, publish-free tick, unchanged no-op | None needed |
| 3.5/3.6 | `Application/SamplingCadenceTests.swift`, `Application/SettingsStateTests.swift` | Unit | 379/379 | Yes — `cannot find 'SamplingCadenceController' in scope`, `cannot find type 'PanelVisibilityObserver' in scope` (exit 65) | Yes — 386 cases, 0 failures | Yes — stopped open/close, interval change while open vs while closed, running restart-once, repeated open no-op, protocol existential over both implementors, ST-7 end to end | None needed |
| 3.7 | `Application/MetricsSamplerTests.swift` | Unit (approval rewrite) | 386/386 | Approval tests: the five wall-clock cases were rewritten one behaviour at a time onto `ManualClock`, each keeping its original assertion (`cpu != nil`, counts frozen, off-main flags) | Yes — 389 cases, 0 failures; two repeat runs also 389/0 | Yes — three added scenarios: CM-3 ten-advance loop, CM-1 idle cadence over five advances, CM-1 open-restarts through the controller | Yes — `waitUntil` poller deleted; `makeSampler`'s `clock` made required so the suite cannot build a wall-clock sampler again |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, 389 test cases, 0 failures; re-run twice, 389/0 both times |
| Runtime harness command/scenario and exact result | N/A — batch B is Application logic over `FakeSettingsStore`, `FakeCPUProvider`, `FakeMemoryProvider` and `ManualClock`; no OS boundary is crossed. The `.integration` adapter reads land in batch C (Phase 4) |
| Rollback boundary | Delete `Application/SettingsState.swift` and `Tests/Application/SettingsStateTests.swift`; `git checkout --` on `Application/MetricsSampler.swift` and `Tests/Application/MetricsSamplerTests.swift`; truncate `Application/SamplingCadence.swift` back to its 19-line pure rule and `Tests/Application/SamplingCadenceTests.swift` back to its 66-line batch-A form; restore the `PanelVisibilitySpy` doc comment and drop its conformance clause |

### Files created

| File | Lines |
|---|---|
| `system-monitor/Application/SettingsState.swift` | 103 |
| `system-monitorTests/Application/SettingsStateTests.swift` | 355 |
| Total new | 458 |

### Files modified

| File | Batch-B change | Size after |
|---|---|---|
| `system-monitor/Application/MetricsSampler.swift` | +29 / -1 (`private let interval` → documented `private(set) var`, `apply(interval:)`) | 207 (validator-corrected) |
| `system-monitorTests/Application/MetricsSamplerTests.swift` | about +407 / -68 (loop suite replaced; batch A had contributed +161 of the +568 tracked total) | 935 (validator-corrected) |
| `system-monitor/Application/SamplingCadence.swift` | +64 (protocol + controller appended) | 83 |
| `system-monitorTests/Application/SamplingCadenceTests.swift` | +218 / -2 (controller suite appended; two redundant `await`s removed) | 282 |
| `system-monitorTests/Support/PanelVisibilitySpy.swift` | +2 / -5 (conformance clause, doc comment updated) | 36 |

Batch-B authored total: about 1250 changed lines, inside the ledger's 2400-line work-unit cap and covered by the recorded `size:exception`. `system-monitor.xcodeproj/project.pbxproj` is unmodified (`git status` clean for it after every run; convention 16 applied 8 times).

### Test and warning counts

- Before batch B: 359 test cases, 0 failures.
- After 3.2: 375. After 3.4: 379. After 3.6: 386. After 3.7: 389.
- After batch B: 389 test cases, 0 failures (`TEST` exit 0). +30 cases; the 359 pre-existing ones all still pass, with five wall-clock loop cases replaced by eight deterministic ones.
- Warnings: 0. Verified by touching every `.swift` file in `system-monitor/` and `system-monitorTests/` and running `xcodebuild … -quiet build-for-testing` (exit 0, `rg -c "warning:"` = 0), so the **test** target was recompiled too. `xcodebuild … -quiet build` also exits 0 with 0 warnings.
- `rg -n "ContinuousClock|Task\.sleep|waitUntil" system-monitorTests/Application/MetricsSamplerTests.swift` → no matches (CM-3 grep gate).

### Deviations from the design

1. **Two pre-existing batch-A warnings fixed in `system-monitorTests/Application/SamplingCadenceTests.swift`.** `let spy = await PanelVisibilitySpy()` (`:42`) and `let recorder = await ErrorRecorder()` (`:58`) each emitted `warning: no 'async' operations occur within 'await' expression`: the implicit initialiser of a `@MainActor` class whose only stored property has a nonisolated default is itself nonisolated, so the `await` was redundant. Batch A missed them because its warning gate ran `xcodebuild … build`, which does not compile the test target. The redundant `await`s were removed; the assertions are untouched.
2. **`MetricsSamplerLoopTests.makeSampler` takes a required `clock: ManualClock`, not a defaulted `any Clock<Duration>`.** Task 3.3 added the parameter with a `ContinuousClock()` default so the not-yet-rewritten wall-clock cases still compiled; task 3.7 removed the default once they were gone, so the suite can no longer construct a wall-clock sampler by omission. `ContinuousClock` no longer appears anywhere in the file.
3. **CM-2 cases live inside `MetricsSamplerLoopTests` rather than a separate suite.** This follows the design's Testing Strategy row, which lists the CM-2 scenarios under that suite; task 3.3's wording ("extend `MetricsSamplerTests.swift`") does not name a suite.
4. **Triangulation cases beyond the literal task text.** Added: the upper clamp bound (9 s → 5 s), `setModule(_:visible: true)` append and idempotence, `canHide` before and after a hide, `moveDown` plus an edge no-op, observers still notified when the save failed, an interval change while the panel is closed absorbed by the idle cadence, and a `any PanelVisibilityObserver` existential exercised over both the controller and the spy. Strict TDD forbids adding a behaviour without a failing test and requires a second data path so a Fake It cannot survive.
5. **`SamplingCadenceController.init` does not refresh the sampler.** The design's init comment registers the observer only, and the composition root (task 7.1) seeds the sampler with `SamplingCadence.effective(configured:panelOpen: false)`. `aStoppedSamplerFollowsEveryPanelTransition` pins that: the sampler still reports the interval it was constructed with until the first transition arrives.
6. **`MetricsSampler.apply(interval:)` stores before the running check.** The design writes "stores the interval and, only while running, `stop(); start()`". The implementation is `guard newInterval != interval else { return }; interval = newInterval; guard isRunning else { return }; stop(); start()`, which is that order exactly; recorded because the guard-first shape is what makes CM-2 "Unchanged interval is a no-op" free of a store write.

### Open items for batch C (Phase 4: Infrastructure)

- Batch A deviation 2 is **closed**: `PanelVisibilitySpy` now declares `: PanelVisibilityObserver`.
- `SettingsState` is the only consumer of the `SettingsStore` port: it calls `load()` exactly once in `init` and `save(_:)` synchronously on the main actor. `UserDefaultsSettingsStore` (task 4.2) must therefore be safe to call from the main actor and must never throw from `load()`.
- Convention 12 and 14 apply to task 4.1: a unique `suiteName` per test plus `removePersistentDomain(forName:)` cleanup.
- **Warning gate**: `xcodebuild … -quiet build` does NOT compile the test target, so test-target warnings stay invisible. Use `fd -e swift . system-monitorTests system-monitor -x touch {}` followed by `xcodebuild … -quiet build-for-testing` before claiming zero warnings. This is exactly how batch A's two warnings survived.
- `ClockProbe<Value>` (`MetricsSamplerTests.swift`) remains the reusable `Mutex` box for asserting on values written from a detached task.
- `ManualClock` loop recipe now proven at scale: `start()` → `awaitSleepCount(1)` → `advance(by: gap)` → `awaitSleepCount(2)`, then one `advance(by: interval)` + `awaitSleepCount(n)` per iteration. Absolute deadlines are read from `pendingDeadlines`; a restart is counted as exactly one new sleep. Never advance by a multiple of the interval.
- `SamplingCadence.swift` is now 83 lines and holds the pure rule, `PanelVisibilityObserver` and `SamplingCadenceController`; phase 6 wires `StatusItemController` to the protocol, not to the controller type.
- Timing: each incremental `TEST` run took roughly 20–70 s; the forced full recompile took about 2 min. No clean build was needed in this batch.

- Batch E/F (Phase 6): `SettingsState.observers` is append-only and never pruned; the status-item re-measure registrant must capture `[weak self]` like `SamplingCadenceController` does, or it leaks.

## Batch C — Phase 4 (Infrastructure)

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-c-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:63936324737ca49a9397b914f037c95f0a002ce05076e325ebf50b839d03ca5b"}` (parent token continued, zero ledger mutation; no untracked declaration demanded, not settled by this actor)
- Work unit: `apply-batch-c-phase-4-infrastructure-userdefaults-store-smappservice-adapter`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`

### Tasks completed

- [x] 4.1 **RED** ST-3 + LAL-3 "Nothing persisted" — `system-monitorTests/Infrastructure/UserDefaultsSettingsStoreTests.swift`
- [x] 4.2 **GREEN** `system-monitor/Infrastructure/System/UserDefaultsSettingsStore.swift`
- [x] 4.3 **RED** LAL-3 mapping table + `.integration` status read — `system-monitorTests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift`
- [x] 4.4 **GREEN** `system-monitor/Infrastructure/System/SMAppServiceLaunchAtLogin.swift`

4 of 4 batch-C tasks complete. 22 of 22 tasks across phases 1–4. Phases 5–8 remain.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 4.1/4.2 | `Infrastructure/UserDefaultsSettingsStoreTests.swift` | Unit | 389/389 baseline (`TEST` exit 0) | Yes — `cannot find 'UserDefaultsSettingsStore' in scope` (exit 65) | Yes — 412 cases, 0 failures | Yes — two round trips with different data plus an overwrite, empty suite, corrupt interval with modules preserved, both clamp edges (9 s → 5 s, 0.1 s → 0.5 s), `["gpu","memory"]` → `[.memory]`, `["gpu"]` → `menuBarOrder`, wrong-typed modules key, the 0.5 s `seconds(_:)` grid asserted twice (pure conversion and the value actually under the key), raw values in order | Test helper `SettingsSuite` dropped its `Sendable` conformance |
| 4.2 addendum (non-finite guard) | same file | Unit | 422/422 | Yes — guard neutered on purpose; all four `aNonFiniteIntervalFallsBackToTheDefault` cases fail, run exits 65 with a `Duration.seconds` trap | Yes — guard restored, 426 cases, 0 failures | Yes — `.nan`, `.infinity`, `-.infinity`, `.signalingNaN` | None needed |
| 4.3/4.4 | `Infrastructure/SMAppServiceLaunchAtLoginTests.swift` | Unit + `.integration` | 412/412 | Yes — `cannot find 'SMAppServiceLaunchAtLogin' in scope` (exit 65) | Yes — 422 cases, 0 failures; all three `.integration` cases executed and passed | Yes — the four-row mapping table, a distinctness assertion over the whole table, the `@unknown default` arm through raw value 99, the port existential, and three live reads (two reads agree, two instances agree, reported status equals the mapped live system status) | None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, 426 test cases, 0 failures |
| Runtime harness command/scenario and exact result | Real runtime boundary exercised. `SMAppServiceLaunchAtLoginIntegrationTests` ran inside the sandboxed test host under the same `TEST` command: `readingTheStatusTwiceSucceedsAndReturnsOneOfTheFourCases`, `theReportedStatusIsTheMappedSystemStatus`, `twoAdaptersReportTheSameLiveStatus` all passed (~0.19 s each), proving `SMAppService.mainApp.status` is readable under App Sandbox (convention 8). `UserDefaults(suiteName:)` likewise worked in the container across 22 unique suites (validator-corrected: 13 plain call sites + 4 + 5 parameterised). No `enable()`, `disable()` or `openLoginItemsSettings()` was ever called on the real adapter (convention 11) |
| Rollback boundary | Delete `system-monitor/Infrastructure/System/UserDefaultsSettingsStore.swift`, `system-monitor/Infrastructure/System/SMAppServiceLaunchAtLogin.swift`, `system-monitorTests/Infrastructure/UserDefaultsSettingsStoreTests.swift` and `system-monitorTests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift`. Batch C touched no existing file, so no `git checkout --` is needed and phases 1–3 are unaffected |

### Files created

| File | Lines |
|---|---|
| `system-monitor/Infrastructure/System/UserDefaultsSettingsStore.swift` | 79 |
| `system-monitor/Infrastructure/System/SMAppServiceLaunchAtLogin.swift` | 50 |
| `system-monitorTests/Infrastructure/UserDefaultsSettingsStoreTests.swift` | 283 |
| `system-monitorTests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift` | 108 |
| Total new | 520 |

### Files modified

None. Batch C is additive only; `git diff --stat` is unchanged from batch B (4 files, 602 insertions, 71 deletions, all from batches A and B). `system-monitor.xcodeproj/project.pbxproj` is unmodified — convention 16 applied after each of the 6 `xcodebuild` runs.

Batch-C authored total: 520 lines, well inside the ledger's 2400-line work-unit cap and covered by the recorded `size:exception`.

### Test and warning counts

- Before batch C: 389 test cases, 0 failures.
- After 4.2: 412. After 4.4: 422. After the non-finite guard cycle: 426.
- After batch C: 426 test cases, 0 failures (`TEST` exit 0). +37 cases; the 389 pre-existing ones all still pass.
- Warnings: 0. Gate run exactly as batch B's open item requires — `fd -e swift . system-monitorTests system-monitor -x touch {}` then `xcodebuild … -quiet build-for-testing` (exit 0), `rg -c "warning:"` = 0 with no matches, so the **test** target was recompiled too.
- `git status --short system-monitor.xcodeproj` is empty after every run.

### Deviations from the design

1. **`load()` rejects non-finite `Double`s before converting.** The design's load rule reads "`object(forKey:) as? Double`, finite → `.seconds(value)`, else `Settings.defaultInterval`", so the guard is design-sanctioned; it is recorded here because no spec scenario names it and it was proven load-bearing rather than assumed. `Duration.seconds(_:)` traps on NaN and the infinities, and both are ordinary `Double`s that pass the type cast that catches `"fast"`. The guard was temporarily neutered to produce a real RED (four failing cases, exit 65) and then restored.
2. **A corrupt modules key falls back like an absent one.** `stringArray(forKey:)` returns `nil` for a non-array value (the test writes `42`), which flows through the same `[]` → `MetricModule.menuBarOrder` normalisation as a missing key. ST-3 names the wrong-type rule only for the interval; applying it symmetrically is the smaller surprise and is pinned by `aCorruptModuleListFallsBackToTheDefaultOrder`.
3. **The test helper `SettingsSuite` is deliberately not `Sendable`.** `UserDefaults` is not `Sendable` on MacOSX26.5.sdk, and the design sanctions exactly one `@unchecked Sendable` — the adapter. The helper never leaves the test body that built it, so a plain `nonisolated struct` is correct; the first RED run surfaced this as `stored property 'defaults' of 'Sendable'-conforming struct 'SettingsSuite' has non-Sendable type 'UserDefaults'`.
4. **LAL-3 "Nothing persisted" is asserted through `persistentDomain(forName:)`, not a filtered `dictionaryRepresentation()`.** The design describes filtering `dictionaryRepresentation().keys` to the suite; `persistentDomain(forName:)` returns exactly the suite's keys with no global-domain noise to filter, so the assertion is an exact set equality (`{samplingIntervalSeconds, menuBarModules}`) plus a substring scan for "login", "launch" and "smappservice". Strictly stronger than the described check.
5. **The `@unknown default` arm is genuinely reachable and is tested as such.** `SMAppServiceStatus` is an `NS_ENUM` (`SMAppService.h:30`), not `NS_CLOSED_ENUM`, and this SDK's imported `init(rawValue:)` accepts an undeclared value — verified empirically before writing the test. `aStatusTheSDKDoesNotDeclareDegradesToNotRegistered` therefore `#require`s raw value 99 and asserts the mapping instead of skipping. It degrades to `.notRegistered` rather than `.enabled` so an unrecognised future status offers a recoverable action instead of claiming an unverified enabled state.
6. **Triangulation cases beyond the literal task text.** Added: a second round trip (0.5 s / `[.cpu]`), a save-twice overwrite, the lower clamp edge, a wrong-typed modules key, the raw-value-order assertion, the four non-finite doubles, the mapping-distinctness assertion, the port existential, and two of the three integration assertions. Strict TDD requires a second data path so a hardcoded answer cannot survive; one of the ST-3 assertions (`load()` on an empty suite writes nothing) also pins that `load()` is read-only.

### Open items for batch D (Phase 5: Presentation models)

- `UserDefaultsSettingsStore.Key` raw strings are now pinned by tests (`"settings.samplingIntervalSeconds"`, `"settings.menuBarModules"`). Changing either breaks `theSavedIntervalKeyHoldsThatExactDouble` and `savingWritesExactlyTheTwoSettingsKeys` — that is deliberate, they are a persisted format.
- `SMAppServiceLaunchAtLogin.map(_:)` is `static` and pure, so batch F's `StatusItemControllerMenuTests` can build LAL-4 tables without any `SMAppService` call. The instance methods that mutate login items remain untested by contract (convention 11); only the manual checklist 8.6 exercises them.
- The composition root (task 7.1) should construct `UserDefaultsSettingsStore()` with the default `.standard`; every call arrives on the main actor through `SettingsState`, which is what makes the `@unchecked Sendable` safe in practice.
- `MetricModule.menuBarOrder` is `[.cpu, .memory]`, so ST-3's `["gpu"]` case expects `[.cpu, .memory]` — not `[.memory]`. Batch D's `SettingsFormModel.moduleRows` ordering assertions must use the same source.
- Batch D touches four existing test files (`StatusItemReadingsTests`, `CPUCardTests`, `MemoryCardModelTests`) and three existing production files. Unlike batch C it needs a real safety net and `git checkout --` in its rollback boundary.
- The `.integration` tag does not exclude tests from the default `TEST` run: all three new integration cases executed under the plain command, as `MachMemoryIntegrationTests` already did.
- Timing in this batch: each incremental `TEST` run took roughly 45–90 s; the forced full recompile for the warning gate took about 2 min. No clean build was needed.

- Batch D first item (batch C gate amendment): `theAdapterSatisfiesTheDomainPort` in `system-monitorTests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift:64-69` reads the live `SMAppService.mainApp.status` from the untagged mapping suite; make it pure (assert only the existential binding) or move it under `.tags(.integration)`.

## Batch D — Phase 5 (Presentation models)

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-d-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:01cd1721e8fae185199b10e2fe276dea5c2161800b338a9687fc04c313bff4e6"}` (parent token continued, zero ledger mutation; no untracked declaration demanded, not settled by this actor)
- Work unit: `apply-batch-d-phase-5-presentation-models-readings-menu-form-gauge-animation`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`
- Skills loaded: `swiftui-patterns`, `swift-testing`, `swift-concurrency-6-2`. `swift-formatstyle` was **not** loaded — `/Users/juancasanueva/.config/opencode/skills/swift-formatstyle/SKILL.md` does not exist.

### Carried amendment (batch C gate, executed before 5.1)

`system-monitorTests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift` — `theAdapterSatisfiesTheDomainPort` in the untagged `SMAppServiceLaunchAtLoginMappingTests` suite read the live `SMAppService.mainApp.status`, contradicting the suite header comment ("No test in this file calls … on the real adapter"). The assertion is now `#expect(type(of: service) == SMAppServiceLaunchAtLogin.self)` over the existential binding, so the suite never touches `SMAppService`. The live read stays in the `.integration` suite, which already covers it three ways. Verified in isolation: `TEST` exit 0, still 426 passing cases (no case added or removed).

### Tasks completed

- [x] 5.1 **RED** MBW-1 / MBW-9 / MBW-14 — `system-monitorTests/Presentation/StatusItemReadingsTests.swift`
- [x] 5.2 **GREEN** `system-monitor/Presentation/MenuBar/StatusItemView.swift`
- [x] 5.3 **RED** MBW-10 + LAL-4 table — `system-monitorTests/Presentation/ContextMenuModelTests.swift`
- [x] 5.4 **GREEN** `system-monitor/Presentation/MenuBar/ContextMenuModel.swift`
- [x] 5.5 **RED** ST-6 — `system-monitorTests/Presentation/SettingsFormModelTests.swift`
- [x] 5.6 **GREEN** model half of `system-monitor/Presentation/Settings/SettingsView.swift`
- [x] 5.7 **RED** reduce motion — `CPUCardTests.swift`, `MemoryCardModelTests.swift`
- [x] 5.8 **GREEN** `system-monitor/Presentation/Panel/CPUCard.swift`, `MemoryCard.swift`

8 of 8 batch-D tasks complete. 30 of 30 tasks across phases 1–5. Phases 6–8 remain.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| amendment | `Infrastructure/SMAppServiceLaunchAtLoginTests.swift` | Unit (approval) | 426/426 baseline (`TEST` exit 0) | Approval test: the case keeps asserting the port conformance, with the live `status` read removed — the behaviour under test is unchanged | Yes — 426 cases, 0 failures | N/A — the mapping table, the `@unknown default` arm and the three `.integration` reads already triangulate the adapter | Yes — the doc comment now states why `status` is not read here |
| 5.1/5.2 | `Presentation/StatusItemReadingsTests.swift` | Unit + `@MainActor` measurement | 426/426 | Yes — `extra argument 'modules' in call`, `cannot find 'ModuleLabel' in scope`, `'StatusItemContent' … requires conformance to 'Equatable'`, `cannot call value of non-function type '[ModuleReading]'` (exit 65) | Yes — 436 cases, 0 failures | Yes — `[.memory]` one reading, `[.memory, .cpu]` reversed with `["59%", "42%"]`, `[.cpu, .memory]` with 0.42/0.59, `[]` empty, `measurementReadings(for:)` over three module sets, one-module width < 130 pt, two-module width < 230 pt and strictly wider than one, content equality over identical/changed-value/different-module-set, `ModuleLabel` equality over value and samples | None needed |
| 5.3/5.4 | `Presentation/ContextMenuModelTests.swift` | Unit | 436/436 | Yes — `cannot find 'ContextMenuModel' in scope`, `cannot find type 'ContextMenuItem' in scope` (exit 65) | Yes — 451 cases, 0 failures | Yes — parameterised over all four statuses for count/order/actions and for "only the launch item can be checked", the exact title list, `.enabled` checked, `.notRegistered`/`.notFound` parameterised as the plain unchecked pair, `.requiresApproval` annotated + `.openLoginItems`, a whole-enum check/route table (`checked == [.enabled]`, `routed == [.requiresApproval]`), value equality across two builds | None needed |
| 5.5/5.6 | `Presentation/SettingsFormModelTests.swift` | Unit | 451/451 | Yes — `cannot find 'SettingsFormModel' in scope`, `cannot find type 'ModuleRow' in scope` (exit 65) | Yes — 477 cases, 0 failures | Yes — 4-row increment grid and 4-row decrement grid, both saturation bounds, out-of-range clamp both directions, `intervalRange`/`intervalStep` tied to the Domain bounds, `intervalSeconds` over three values, `en_US` "2.5 s" vs `de_DE` "2,5 s" plus a "no ICU unit name" assertion, one-fraction-digit over three grid values, last-visible-toggle disabled and the two-visible counter-case, row order + move edges, hidden rows after visible ones and immovable, row identity | Yes — `#expect(rows.allSatisfy(\.isVisible))` replaced with a trailing closure (see deviation 5); re-ran green |
| 5.7/5.8 | `Presentation/CPUCardTests.swift`, `Presentation/MemoryCardModelTests.swift` | Unit | 477/477 | Yes — `type 'CPUCardModel' has no member 'gaugeAnimation'` (exit 65) | Yes — 483 cases, 0 failures | Yes — per card: `true` → nil, `false` → `Animation.easeOut(duration: 0.25)`, and the two answers assert-differ so the flag cannot be ignored; the memory card additionally asserts equality with the CPU card's answer (MC-10) | Yes — both views dropped their private `gaugeAnimation` constant and now call the model |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, 483 test cases passing, 0 failures |
| Runtime harness command/scenario and exact result | Partly real: the MBW-9 width scenarios render `StatusItemContent` in a real `NSHostingView` inside the test host and read `fittingSize` (`@MainActor` helpers at `StatusItemReadingsTests.swift`), which is the only runtime boundary phase 5 has. The remaining models are pure. The `#Preview`s named in the tasks' work-unit table are an Xcode-only manual affordance and were not exercised headlessly. AppKit menu, window and status-item runtime paths belong to batches E and F |
| Rollback boundary | Delete `system-monitor/Presentation/MenuBar/ContextMenuModel.swift`, `system-monitor/Presentation/Settings/SettingsView.swift`, `system-monitorTests/Presentation/ContextMenuModelTests.swift`, `system-monitorTests/Presentation/SettingsFormModelTests.swift`; `git checkout --` on `Presentation/MenuBar/StatusItemView.swift`, `Presentation/MenuBar/StatusItemController.swift`, `Presentation/Panel/CPUCard.swift`, `Presentation/Panel/MemoryCard.swift`, `Tests/Presentation/StatusItemReadingsTests.swift`, `Tests/Presentation/CPUCardTests.swift`, `Tests/Presentation/MemoryCardModelTests.swift`; revert the amendment hunk in the untracked `Tests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift` by restoring `#expect(LaunchAtLoginStatus.allCases.contains(service.status))`. Phases 1–4 are unaffected |

### Files created

| File | Lines |
|---|---|
| `system-monitor/Presentation/MenuBar/ContextMenuModel.swift` | 79 |
| `system-monitor/Presentation/Settings/SettingsView.swift` | 121 |
| `system-monitorTests/Presentation/ContextMenuModelTests.swift` | 122 |
| `system-monitorTests/Presentation/SettingsFormModelTests.swift` | 196 |
| Total new | 518 |

### Files modified

| File | Batch-D change | Size after |
|---|---|---|
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | +66 / -19 (`build(modules:…)`, `measurementReadings(for:)`, `Equatable` content and internal `ModuleLabel`, optional `SettingsState` environment, third preview) | 248 |
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | +3 / -1 (one call site only — deviation 1) | 136 |
| `system-monitor/Presentation/Panel/CPUCard.swift` | +12 / -4 (`CPUCardModel.gaugeAnimation(reduceMotion:)`, private constant deleted, view calls the model) | 254 |
| `system-monitor/Presentation/Panel/MemoryCard.swift` | +11 / -4 (same shape, delegating to `CPUCardModel`) | 282 |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | +160 / -12 (`modules:` at every call site, MBW-1 subset cases, MBW-9 widths, new MBW-14 suite) | 598 |
| `system-monitorTests/Presentation/CPUCardTests.swift` | +27 / -0 (`import SwiftUI`, three reduce-motion cases) | 200 |
| `system-monitorTests/Presentation/MemoryCardModelTests.swift` | +27 / -0 (three MC-10 cases) | 272 |
| `system-monitorTests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift` (untracked, batch C) | +12 / -6 (carried amendment) | 114 |

Batch-D authored total: about 870 changed lines (518 new + 318 tracked insertions + 28 tracked deletions + 6 net in the untracked amendment), inside the ledger's 2400-line work-unit cap and covered by the recorded `size:exception`. `system-monitor.xcodeproj/project.pbxproj` is unmodified — convention 16 applied after each of the 8 `xcodebuild` runs, and `git status --short system-monitor.xcodeproj` is empty.

### Test and warning counts

- Before batch D: 426 test cases, 0 failures.
- After the carried amendment: 426. After 5.2: 436. After 5.4: 451. After 5.6: 477. After 5.8: 483.
- After batch D: 483 test cases, 0 failures (`TEST` exit 0). +57 cases; the 426 pre-existing ones all still pass.
- **Counting method**: `rg -c "' passed on '"` was used, not `rg -c "^Test case '"`. The `-quiet` log interleaves concurrent lines, so one `Test case '…'` line per run is truncated mid-string; the baseline run reported 426 by both methods while the amendment run reported 425 by `^Test case '` and 426 by `' passed on '` for the same suite. Diffing the extracted names across the two runs showed a *different* case mangled each time, confirming the artefact is the log, not the suite.
- Warnings: 0. Gate run exactly as the batch B/C open item requires — `fd -e swift . system-monitorTests system-monitor -x touch {}` then `xcodebuild … -quiet build-for-testing` (exit 0), `rg -c "warning:"` reporting no matches, so the **test** target was recompiled too.

### Deviations from the design

1. **One call site in `system-monitor/Presentation/MenuBar/StatusItemController.swift` was updated (a Phase-6 file).** Task 5.2 replaces the stored `StatusItemMetrics.measurementReadings` with `measurementReadings(for:)`, and `:66-72` was its only consumer. The line now reads `StatusItemMetrics.measurementReadings(for: MetricModule.menuBarOrder)` — the same value the constant held, so behaviour is identical. Compilation-required, not scope creep, exactly like batch A's `SwiftUI.Settings` qualification. Task 6.6 replaces this helper wholesale with `measuredContentWidth(for:)` and `contentFittingWidth(for:)`.
2. **`StatusItemRootView.settings` is `SettingsState?` defaulted to `nil`, and `StatusItemView` uses the optional `@Environment(SettingsState.self)` overload.** The design writes `StatusItemRootView(state:settings:)`; that initialiser exists and is what batch F will call. The default keeps `StatusItemController.swift:20` (`StatusItemRootView(state: state)`) compiling without restructuring `StatusItemController.init`, which is task 6.4's job, and it makes a missing settings object degrade to `MetricModule.menuBarOrder` instead of trapping in `#Preview`s and in the pre-wiring controller path. Batch F must pass the real object; the nil fallback then becomes preview-only.
3. **`system-monitor/Presentation/Settings/SettingsView.swift` currently holds only `ModuleRow` and `SettingsFormModel`** — no `SettingsView` or `SettingsRootView` struct yet, and it imports `Foundation` only. That is exactly task 5.6's scope ("model half"); task 6.2 appends the view half and will need `import SwiftUI`. The file name follows the design's File Changes table.
4. **`SettingsFormModel.seconds(_:)` is a private duplicate of `UserDefaultsSettingsStore.seconds(_:)`.** Presentation must not import Infrastructure, and the design names the conversion in the adapter without saying where the form's copy lives. Both are the same three-line `components.seconds + attoseconds / 1e18`, and both are pinned by tests (`theSavedIntervalKeyHoldsThatExactDouble` in batch C, `theIntervalIsExposedInSeconds` here), so a drift fails.
5. **`#expect(collection.allSatisfy(\.property))` does not compile.** The key-path-as-function form makes the `#expect` macro expansion throwing: `error: call can throw, but it is not marked with 'try' and the error is not handled`, reported against the generated `@__swiftmacro_…expectfMf0_.swift`. A trailing closure (`allSatisfy { $0.isVisible }`) expands cleanly, which is why the existing suites already use closures. Recorded so batches E–G do not rediscover it.
6. **The LAL-4 table is derived from the LAL-1 predicates, not from a four-arm switch.** `ContextMenuModel.launchAtLoginItem(for:)` is `guard !status.needsApproval` followed by `isChecked: status.isEnabled`, so `.notFound` shares the plain unchecked item with `.notRegistered` (design decision 12) as a consequence of the Domain predicates rather than as a repeated literal. `theCheckAndActionTableCoversEveryStatus` pins the whole enum against it.
7. **`measurementReadings` became a function, so the previews changed.** `#Preview("Status item at full scale")` now passes `MetricModule.menuBarOrder`, and a third preview `"Status item with MEM hidden"` renders `[.cpu]` so the one-module layout is visible in Xcode. The design lists "previews updated" for task 5.2 without naming them.
8. **Triangulation cases beyond the literal task text.** Added: the empty-module-list case, `measurementReadings(for:)` over three module sets, "one module is strictly narrower than two", `ModuleLabel` equality on value *and* samples, content inequality across different module sets, "only the launch item can be checked" over every status, the whole-enum check/route table, two-builds-are-equal, `intervalRange` tied to `Settings.minimumInterval`/`maximumInterval`, the full increment and decrement grids, the out-of-range clamp both ways, the "no ICU unit name" assertion, one-fraction-digit over three values, the two-visible-toggles counter-case, hidden-rows-cannot-move, row identity, and the "two reduce-motion answers differ" case on both cards. Strict TDD requires a second data path so a hardcoded answer cannot survive.
9. **`ModuleLabel` became internal.** The design says "was private; internal for the MBW-14 test". Recorded because it widens a Presentation type's visibility for testability; it stays inside the app module and has no other consumer.

### Open items for batch E (Phase 6.1–6.2: settings window and view)

- `system-monitor/Presentation/Settings/SettingsView.swift` already exists with the model half (121 lines). Task 6.2 **appends** to it — do not overwrite — and must add `import SwiftUI` at the top.
- `SettingsFormModel.intervalRange` and `intervalStep` are `Double` seconds, matching a `Stepper`'s `value:in:step:` shape, but the design's stepper wiring goes through `onIncrement`/`onDecrement` calling `incremented`/`decremented` so the clamp is the Domain's. Prefer that; do not bind a `Double` directly.
- `ModuleRow.isToggleEnabled` is the only enablement rule the toggle needs: `.disabled(!row.isToggleEnabled)`. Move buttons use `canMoveUp`/`canMoveDown`, which are already `false` for every hidden row.
- `SettingsState.lastSaveError` is `(any Error)?` and is cleared on the next successful save; the footer reads `localizedDescription`.
- The window controller is a plain `final class` (not `NSObject`) unless the S3 activation fallback is triggered, which makes it the window delegate.
- Locale: the form label must pass the environment locale into `intervalLabel(for:locale:)`; the default `.current` is for tests and previews only.

### Open items for batch F (Phase 6.3–6.6: status item controller)

- Deviation 1 above: `StatusItemController.swift:66-72` currently calls `StatusItemMetrics.measurementReadings(for: MetricModule.menuBarOrder)`. Task 6.6 replaces it with `measuredContentWidth(for:)` taking the live module set, and `contentFittingWidth` (currently the property at `:88-90`) becomes `contentFittingWidth(for:)`.
- Deviation 2 above: `StatusItemRootView(state: state)` at `:20` must become `StatusItemRootView(state: state, settings: settings)` once the new `init(state:settings:launchAtLogin:panelObserver:openSettings:)` exists, so the widget follows the user's module list at runtime rather than falling back to `menuBarOrder`.
- `ContextMenuModel.items(launchAtLogin:)` returns values only. The controller must read `launchAtLogin.status` **at build time** (LAL-4 "Status is re-read on every build"; `FakeLaunchAtLoginService.statusReads` proves it) and map `ContextMenuItem.Action` onto selectors: `.openSettings` → the injected closure, `.toggleLaunchAtLogin` → `toggleLaunchAtLogin()`, `.openLoginItems` → `openLoginItems()`, `.quit` → `#selector(NSApplication.terminate(_:))` with `target = NSApp`.
- Exact titles are `"Settings\u{2026}"`, `"Launch at Login"`, `"Launch at Login (Requires Approval)\u{2026}"`, `"Quit System Monitor"` — the ellipsis is U+2026, not three periods. `ContextMenuModelTests` pins all four.
- `StatusItemContent` and `ModuleLabel` are `Equatable` and main-actor isolated; comparisons from a non-`@MainActor` test must run inside `await MainActor.run { … }` (precedent: `CanvasComponentEqualityTests`, and now `StatusItemContentEqualityTests`).
- MBW-9 numbers measured in this batch: one module at full scale fits under 130 pt and two under 230 pt, with one strictly narrower than two, so `settingsDidChange` really can shrink the item.
- `SettingsState.observers` is append-only and never pruned (batch B open item still stands): the re-measure registrant must capture `[weak self]`.
- Timing in this batch: each incremental `TEST` run took roughly 40–90 s; the forced full recompile for the warning gate took about 2 min. No clean build was needed.

- Batch F (task 6.4): add one case rendering `StatusItemRootView(state:settings:)` with a non-default `menuBarModules` and asserting the rendered order; this closes the MBW-1 runtime gap left by `StatusItemController.swift:20` constructing the root view without a `SettingsState`.

## Batch E — Phase 6.1–6.2 (Settings window)

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-e-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:77e862361bffb5e1f0d5de569a4c75a66a2e0c12f99cf727b43b34d5d6d5f8e1"}` (parent token continued, zero ledger mutation; no untracked declaration demanded, not settled by this actor)
- Work unit: `apply-batch-e-phase-6-1-6-2-settings-view-and-window-controller`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`
- Engram mirror: this section only is saved under topic key `sdd/polish-module/apply-progress-batch-e`. The combined observation `sdd/polish-module/apply-progress` is at the 50,000-character cap and was **not** updated; batches A–D remain under that key.
- Skills loaded: `swiftui-patterns`, `swift-testing`, `swift-concurrency-6-2`, `swiftui-layout-components` (all four present).

### Tasks completed

- [x] 6.1 **RED** ST-5 — `system-monitorTests/Presentation/SettingsWindowControllerTests.swift`
- [x] 6.2 **GREEN** `system-monitor/Presentation/Settings/SettingsWindowController.swift` + the view half of `system-monitor/Presentation/Settings/SettingsView.swift` (`SettingsFormIntent`, `SettingsView`, `ModuleSettingsRow`, `SettingsRootView`, previews), with `system-monitorTests/Presentation/SettingsViewTests.swift` as its RED

2 of 2 batch-E tasks complete. 32 of 32 tasks across phases 1–5 plus 6.1–6.2. Tasks 6.3–6.6 (status item controller) and phases 7–8 remain.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 6.1/6.2 (window) | `Presentation/SettingsWindowControllerTests.swift` | Presentation AppKit host (real `NSWindow`) | 483/483 baseline (`TEST` exit 0) | Yes — `cannot find 'SettingsWindowController' in scope`, `cannot find type 'SettingsWindowController' in scope` (exit 65) | Yes — 497 cases, 0 failures | Yes — lazy pre-show state (all three accessors nil/false), first show visible + titled, two shows same `windowNumber`, close → hidden → show → same number, hosted root view type, the three style-mask flags, two controllers own distinct windows | None needed |
| 6.2 (view half) | `Presentation/SettingsViewTests.swift` | Unit (intent) + Presentation host (`NSHostingView.fittingSize`) | 483/483 | Yes — `cannot find 'SettingsRootView' in scope` (exit 65) | Yes — 497 cases, 0 failures | Yes — increment and decrement each asserted on both the state and the store, both saturation bounds asserted with `saveCount == 0`, fixed 360 pt width, hidden module keeps its row (equal heights), failed save makes the form strictly taller than the identical successful one | None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, 497 test cases, 0 failures |
| Runtime harness command/scenario and exact result | Real runtime boundary exercised. `SettingsWindowControllerTests` creates real `NSWindow`s in the test host, calls `NSApp.activate()` + `makeKeyAndOrderFront(nil)` through `show()`, and reads back `isVisible`, `title`, `windowNumber`, `styleMask` and the `NSHostingController<SettingsRootView>` content; `SettingsViewTests` renders `SettingsRootView` in a real `NSHostingView` and reads `fittingSize`. Every window is closed by the helper's `defer`, and no case asserts key status, so the suite does not require the test host to be frontmost |
| Rollback boundary | Delete `system-monitor/Presentation/Settings/SettingsWindowController.swift`, `system-monitorTests/Presentation/SettingsWindowControllerTests.swift` and `system-monitorTests/Presentation/SettingsViewTests.swift`; truncate `system-monitor/Presentation/Settings/SettingsView.swift` back to its 121-line batch-D model half and drop the added `import SwiftUI`. Batch E touched no other file, so phases 1–5 are unaffected |

### Files created

| File | Lines |
|---|---|
| `system-monitor/Presentation/Settings/SettingsWindowController.swift` | 94 |
| `system-monitorTests/Presentation/SettingsWindowControllerTests.swift` | 116 |
| `system-monitorTests/Presentation/SettingsViewTests.swift` | 133 |
| Total new | 343 |

### Files modified

| File | Batch-E change | Size after |
|---|---|---|
| `system-monitor/Presentation/Settings/SettingsView.swift` | +159 / -0 (`import SwiftUI`, `SettingsFormIntent`, `SettingsView`, `ModuleSettingsRow`, `SettingsRootView`, two previews); appended, nothing overwritten | 280 |
| `openspec/changes/polish-module/tasks.md` | 6.1 and 6.2 marked `[x]` | unchanged otherwise |

Batch-E authored total: 502 lines, well inside the ledger's 2400-line work-unit cap and covered by the recorded `size:exception`. All three new Swift files were registered with `git add -N`. `system-monitor.xcodeproj/project.pbxproj` is unmodified — convention 16 applied after each of the 4 `xcodebuild` runs and `git status --short system-monitor.xcodeproj` is empty.

### Test and warning counts

- Before batch E: 483 test cases, 0 failures.
- After 6.2: 497 test cases, 0 failures (`TEST` exit 0). +14 cases (7 window, 7 view); the 483 pre-existing ones all still pass.
- Counting method: `rg -c "' passed on '"` (batch D's counting note still applies).
- Warnings: 0. Gate run as the standing open item requires — `fd -e swift . system-monitorTests system-monitor -x touch {}` then `xcodebuild … -quiet build-for-testing` (exit 0), `rg -c "warning:"` reporting no matches, so the **test** target was recompiled too.

### Deviations from the design

1. **No launch-at-login control in `SettingsView`.** The batch prompt described a launch-at-login toggle in the settings form reading a live `LaunchAtLoginService`, with a `.requiresApproval` → "Open Login Items…" button and `errorPresenter` surfacing. Design rev 2 and the specs place that surface only in the context menu: `SettingsView`'s declaration (`design.md:264`) has one dependency (`@Environment(SettingsState.self)`), its layout paragraph (`:279`) names exactly two sections plus the save-error footer, `errorPresenter` is a `StatusItemController` member (`:226`), and LAL-4 requires the item in "The context menu (MBW-10)". No spec scenario asks for a settings-window launch control, and no such string exists (`ContextMenuModel` pins `"Launch at Login"` and `"Launch at Login (Requires Approval)\u{2026}"`; there is no "Open Login Items…" title anywhere). The design won, per the prompt's own "Design rev 2 (authoritative)". Batch F delivers the whole LAL-4 surface. If the product actually wants a settings-window duplicate, it needs a spec delta first.
2. **`SettingsFormIntent` (a `@MainActor` enum) was added to `SettingsView.swift`.** The design writes the stepper action inline as `settings.setInterval(SettingsFormModel.incremented(settings.samplingInterval))`. That expression is a *composition* — the only place where a wiring mistake (swapping the two directions, or deriving a value and never committing it) survives every pure `SettingsFormModelTests` case — and inside a `Stepper` closure no test can reach it. Strict TDD cannot add unreachable behaviour, so the two compositions moved into a named main-actor seam the view calls and `SettingsViewTests` drives. The toggle and the move buttons stayed inline because each is a single `SettingsState` call with nothing to compose.
3. **`system-monitorTests/Presentation/SettingsViewTests.swift` is not in the design's File Changes table.** The table's `SettingsWindowControllerTests.swift` row is scoped to ST-5, and task 6.2 delivers a view half that needs its own RED. Rather than mix ST-6 view wiring into the ST-5 window file, the view half got a file named after its subject. No table row was renamed or ignored.
4. **Section titles are "Sampling interval" and "Menu bar modules".** The design's prose names them "Sampling" and "Menu Bar" (`:279`); the batch prompt's UI-copy list names the longer forms. No spec scenario or test pins either, and the longer titles say what the section does. Recorded because it is a visible string difference from the design text.
5. **Move buttons are chevron images with "Move Up"/"Move Down" as accessibility label and tooltip.** The design names the buttons by those strings without naming a presentation. Two text buttons per row would dominate a two-row form, so the strings became the accessible names of `chevron.up`/`chevron.down` buttons.
6. **Test accessors beyond the design's list.** The design lists `isWindowVisible`, `windowTitle`, `windowNumber`; `windowStyleMask` and `hostedRootViewType` were added so ST-5's "titled window the user can close" and "hosting `SettingsView` bound to `SettingsState`" are asserted rather than assumed. Both are read-only computed properties over the same optional window.
7. **One preview seeds its state through an immediately-applied closure.** `#Preview("Settings with MEM hidden")` builds a `SettingsState` and calls `setModule(.memory, visible: false)` inside a closure applied in place, because a preview-only in-memory store would be new untested production code (the double lives in the test target) and a `#Preview` body cannot hold loose statements. Both previews use a `UserDefaults(suiteName:)` store, so previewing never touches `.standard`.
8. **Triangulation cases beyond the literal task text.** Task 6.1 lists three window scenarios; added: the pre-show lazy state, the hosted root view type, the style mask, and two controllers owning distinct windows. The whole `SettingsViewTests` suite is additional: both stepper directions asserted on state *and* store, both saturation bounds asserted with `saveCount == 0`, the fixed 360 pt width, "a hidden module keeps its row", and the save-error footer proved by a height difference against an otherwise identical form.

### Open items for batch F (Phase 6.3–6.6: status item controller)

- **`showSettings()` entry point.** `SettingsWindowController.show()` is `@MainActor`, takes no arguments and returns `Void`, so it matches `StatusItemController`'s `openSettings: @escaping @MainActor () -> Void` exactly. Batch F passes `openSettings: { [settingsWindow] in settingsWindow.show() }`; `AppDelegate.showSettings()` (task 7.1) is the same one-liner for Cmd+,. Both entry points must call the **same** controller instance — `eachControllerOwnsItsOwnWindow` proves that two controllers mean two windows, which is exactly what ST-5 forbids.
- **The window controller's dependencies.** `SettingsWindowController(settings:)` takes only `SettingsState`. It does **not** take a `LaunchAtLoginService` and does not own an `errorPresenter` (deviation 1) — that pair belongs to `StatusItemController.init(state:settings:launchAtLogin:panelObserver:openSettings:)`.
- Task 6.3's "Settings…" case can assert against a real `SettingsWindowController`: build one, pass `openSettings: { controller.show() }`, fire the menu item's action, then assert `controller.isWindowVisible` and `controller.windowTitle == "Settings"`. Close it in a `defer` and do **not** assert `isKeyWindow` — the test host is not guaranteed frontmost.
- The window-test helper pattern to reuse: a `@MainActor private static func withSettingsWindow(_ body: @MainActor (SettingsWindowController) -> Void)` with `defer { controller.close() }`. A non-`@MainActor` async test cannot `defer` an `await`, so the cleanup has to live inside a synchronous main-actor helper (convention 2 stays satisfied — the test itself is not `@MainActor`).
- `SettingsView.formWidth` (360 pt) is `static` and internal. `SettingsViewTests` asserts against its own literal 360, deliberately, so a change to the constant fails the test instead of silently agreeing with it.
- Standing from batches B/D: `SettingsState.observers` is append-only and never pruned, so the status-item re-measure registrant must capture `[weak self]`.
- Standing from batch D: `StatusItemController.swift:20` still builds `StatusItemRootView(state: state)` without settings, and `:66-72` still calls `measurementReadings(for: MetricModule.menuBarOrder)`; tasks 6.4 and 6.6 replace both.
- Timing in this batch: the baseline `TEST` run took about 2 min, each incremental run about 1–2 min, and the forced full recompile for the warning gate about 2 min. No clean build was needed.

### Batch E gate amendments (orchestrator, 2026-09-06)
- Undeclared deviation recorded: `SettingsView` reads a second environment value, `@Environment(\.locale)`, and passes it to `SettingsFormModel.intervalLabel(for:locale:)` (design.md:264 declares only `SettingsState`). Kept: ST-6 requires the label to follow the injected locale.
- Coverage gap recorded: no test fires the settings-form move buttons or asserts `.disabled(!row.isToggleEnabled)`; swapping the two chevrons would pass all 497 cases. Carried into batch F as its first item: extend `SettingsFormIntent` with `moveUp`/`moveDown` compositions plus cases asserting the pairing and the toggle-disabled wiring.
- `SettingsViewTests.swift` deviates from specs/settings/spec.md:237 (test file names follow the design table), not only from the table itself.

## Batch F — Phase 6.3–6.6 (Status item controller)

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-f-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:004b55dfe0b7a5d4ca7bd3e95c028d27889dda81561f071138f2b69d9b8956e6"}` (parent token continued, zero ledger mutation; no untracked declaration demanded, not settled by this actor)
- Work unit: `apply-batch-f-phase-6-3-6-6-status-item-controller-menu-delegate-remeasure-deinit`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`
- Engram mirror: this section only is saved under topic key `sdd/polish-module/apply-progress-batch-f`. The combined observation `sdd/polish-module/apply-progress` is at the 50,000-character cap and was **not** updated; batches A–D remain under that key and batch E under `…-batch-e`.
- Skills loaded: `swift-concurrency-6-2`, `swiftui-patterns`, `swift-testing`, `swiftui-uikit-interop` (all four present; `swiftui-uikit-interop` is iOS-facing and contributed only its Coordinator/delegate discipline, which the `NSPopoverDelegate` work mirrors on AppKit).

### Carried amendment (batch E gate, done before 6.3)

The batch E gate recorded that no test fired the settings-form move buttons or observed `.disabled(!row.isToggleEnabled)`, so swapping the two chevrons would have passed all 497 cases. Closed here:

- `SettingsFormIntent` gained `moveUp(_:in:)`, `moveDown(_:in:)` and `setVisibility(_:visible:in:)`; `ModuleSettingsRow` now drives all three controls through it instead of calling `SettingsState` inline.
- `SettingsViewTests` gained four cases. Each move case asserts the direction **and** its edge no-op (`moveUp` on the already-first module, `moveDown` on the last), which is what makes a swap fail rather than agree: on a two-module list both directions otherwise produce the same array.
- The toggle case reads the `ModuleRow` the view applies as `.disabled(!row.isToggleEnabled)` and asserts it is off for exactly the last visible module, hidden rows stay enabled, and `SettingsState` refuses the hide anyway (`saveCount == 0`). A second case commits both directions so an inverted binding cannot hide.

RED: `type 'SettingsFormIntent' has no member 'moveUp' / 'moveDown' / 'setVisibility'` (exit 65). GREEN: 501 cases, 0 failures.

### Tasks completed

- [x] 6.3 **RED** MBW-10 actions + LAL-4 controller — `system-monitorTests/Presentation/StatusItemControllerMenuTests.swift`
- [x] 6.4 **GREEN** `system-monitor/Presentation/MenuBar/StatusItemController.swift` — `NSObject` subclass, new `init(state:settings:launchAtLogin:panelObserver:openSettings:)`, `errorPresenter`, `makeContextMenu()`, `toggleLaunchAtLogin()`, `openLoginItems()`
- [x] 6.5 **RED** MBW-9/11/12/13 — `system-monitorTests/Presentation/StatusItemControllerTests.swift`
- [x] 6.6 **GREEN** `StatusItemController` — `settingsDidChange` re-measure, `contentFittingWidth(for:)`, `.darkAqua` popover, `NSPopoverDelegate`, `installedStatusItem`, `isPanelOpen`, internal `togglePopover()`, `isolated deinit`

4 of 4 batch-F tasks complete, plus the carried amendment. 36 of 36 tasks across phases 1–6. Phases 7 and 8 remain.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Carried amendment | `Presentation/SettingsViewTests.swift` | Unit (intent) over a real `SettingsState` + `FakeSettingsStore` | 497/497 baseline (`TEST` exit 0) | Yes — `type 'SettingsFormIntent' has no member 'moveUp'`, `'moveDown'`, `'setVisibility'` (exit 65) | Yes — 501 cases, 0 failures | Yes — 4 cases: each direction asserted with its edge no-op, the last-visible toggle flag with the state's refusal, both visibility directions committed | None needed |
| 6.3 / 6.4 (menu) | `Presentation/StatusItemControllerMenuTests.swift` | Presentation AppKit host (real `NSStatusItem`, real `NSMenu`, real `SettingsWindowController`) | 501/501 | Yes — `extra arguments at positions #2, #3, #4 in call`, `has no member 'makeContextMenu'` (exit 65) | Yes — 509 cases, 0 failures | Yes — 9 cases: titles/order, `openSettings` closure count, the real window's visibility and title, the Quit selector and `NSApp` target, live re-read across two builds (`statusReads == 2`), enable-once, disable-once, approval routing with no enable/disable, refused enable surfaced once with the rebuilt item off | None needed |
| 6.5 / 6.6 (layout, appearance, lifetime, transitions) | `Presentation/StatusItemControllerTests.swift` | Presentation AppKit host (real `NSStatusItem`, real `NSPopover`) | 509/509 | Yes — `has no member 'installedStatusItem'`, `cannot call value of non-function type 'CGFloat'`, `has no member 'popoverAppearanceName'`, `has no member 'popoverWillShow'`, `'togglePopover' is inaccessible due to 'private' protection level` (exit 65) | Yes — 518 cases, 0 failures | Yes — 12 cases: value ticks keep the length, hiding MEM re-measures to `contentFittingWidth(for: [.cpu])` under 130 pt, further CPU/memory readings and `setInterval` keep it, showing MEM again restores the two-module width under 230 pt, `sizingOptions == []`, `.darkAqua`, the two palette tokens, weak controller **and** weak status item both released, delegate transitions `[true, false]`, no duplicate open through `togglePopover()` | None needed |

One intermediate RED was genuine and is recorded rather than hidden: the first 6.6 GREEN run left `togglingTwiceClosesThePopoverWithoutRepeatingTheOpen` failing with `(events → []) == [true, false]` (516 passed / 1 failed). A diagnostic run showed `afterFirst=false hasButton=true inWindow=true active=false` — the button exists and is in a window, but a `.transient` popover does not display while its application is inactive, and the test host never is. That is the design's named MBW-13 fallback condition; the case was rewritten under it (deviation 2) and the suite went green.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, 518 test cases, 0 failures. Suite-scoped runs used during the cycle: `-only-testing:system-monitorTests/StatusItemControllerTests` |
| Runtime harness command/scenario and exact result | Real runtime boundary exercised throughout. Every case builds a real `NSStatusItem` in the test host and measures real `NSHostingView.fittingSize`; `StatusItemControllerMenuTests` builds real `NSMenu`s and dispatches each item through `target.perform(action:with:)` exactly as AppKit does, including against a real `SettingsWindowController` whose window is read back (`isWindowVisible`, `windowTitle == "Settings"`) and closed in a `defer`; `releasingTheControllerRemovesItsStatusItem` proves the `isolated deinit` really runs by watching two weak references go `nil`. The one boundary the host cannot provide is popover display (`NSApp.isActive == false`), handled by the design's named fallback |
| Rollback boundary | Delete `system-monitorTests/Presentation/StatusItemControllerMenuTests.swift`; revert `system-monitor/Presentation/MenuBar/StatusItemController.swift`, `system-monitorTests/Presentation/StatusItemControllerTests.swift` and `system-monitor/App/AppDelegate.swift` to their pre-batch-F state; drop the `SettingsFormIntent` move/visibility members plus their four `SettingsViewTests` cases and restore the three inline calls in `ModuleSettingsRow`. Batches A–E are untouched |

### Files created

| File | Lines |
|---|---|
| `system-monitorTests/Presentation/StatusItemControllerMenuTests.swift` | 244 |

Registered with `git add -N` immediately after creation; earlier batches' intent-to-add staging was left alone.

### Files modified

| File | Batch-F change | Size after |
|---|---|---|
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | +220 / −25 — `NSObject, NSPopoverDelegate`; new five-parameter init; `errorPresenter`; `makeContextMenu()` + item mapping, selectors and key equivalents; `toggleLaunchAtLogin()`; `openLoginItems()`; `measuredModules` + `remeasure(for:)` + `settingsDidChange(_:)`; `measuredContentWidth(for:)`; `contentFittingWidth(for:)`; `installedStatusItem`; `popoverAppearanceName`; `isPanelOpen`; internal `togglePopover()`; `popover.delegate` and `.darkAqua`; `isolated deinit`; `StatusItemRootView(state:settings:)` | 329 |
| `system-monitorTests/Presentation/StatusItemControllerTests.swift` | +256 / −24 — `StatusItemReleaseProbe`, `withController` helper, the four existing cases moved onto the new init and released, eight new MBW-9/11/12/13 cases | 303 |
| `system-monitor/Presentation/Settings/SettingsView.swift` | +26 added, 3 rewired — `SettingsFormIntent.setVisibility/moveUp/moveDown`; `ModuleSettingsRow`'s toggle and two chevrons now go through them | 306 |
| `system-monitorTests/Presentation/SettingsViewTests.swift` | +96 — two reorder cases and two visibility cases in two extensions | 229 |
| `system-monitor/App/AppDelegate.swift` | +7 / −1 — compilation-required call-site update only (deviation 1) | 40 |
| `openspec/changes/polish-module/tasks.md` | 6.3–6.6 marked `[x]` | unchanged otherwise |

Batch-F authored total: roughly 905 changed lines (additions + deletions), inside the ledger's 2400-line work-unit cap and covered by the recorded `size:exception`. `system-monitor.xcodeproj/project.pbxproj` is unmodified — convention 16 applied after every `xcodebuild` run and `git status --short system-monitor.xcodeproj` is empty.

### Test and warning counts

- Before batch F: 497 test cases, 0 failures.
- After the carried amendment: 501. After 6.4: 509. After 6.6: **518 test cases, 0 failures** (`TEST` exit 0).
- Counting method: `rg -c "' passed on '"` over the captured log. Caveat discovered this batch: `xcodebuild` interleaves its own timestamped stderr into stdout and occasionally corrupts one `Test case '…' passed on …` line (observed literally as `passed o2026-09-06 16:08:25.978 xcodebuild[…]`), so the count carries ±1 noise. Unique test-function names in the final run: 431.
- Warnings: 0. Gate run as required — `fd -e swift . system-monitorTests system-monitor -x touch {}` then `xcodebuild … -quiet build-for-testing` (exit 0), `rg -c "warning:"` reporting no matches, so the test target was recompiled too. Two `no 'async' operations occur within 'await' expression` warnings appeared mid-batch on `await PanelVisibilitySpy()` and were removed before the gate (the existing `SamplingCadenceTests` precedent constructs it without `await`).

### Deviations from the design

1. **`AppDelegate` call-site edit (compilation-required).** The new initialiser has no defaults for `settings:` and `launchAtLogin:`, so `AppDelegate.applicationDidFinishLaunching` could not compile unchanged. The minimum was applied: the existing `StatusItemController(state: state)` call now also passes `SettingsState(store: UserDefaultsSettingsStore())` and `SMAppServiceLaunchAtLogin()`, with a comment pointing at 7.1. No other batch G work was done — no `SamplingCadenceController`, no `SettingsWindowController`, no `panelObserver`, no `openSettings`, no sampler cadence seeding, no new stored properties, no `showSettings()`, and `system_monitorApp.swift` is untouched. The controller retains the `SettingsState` it is handed, so nothing is deallocated early. Task 7.1 replaces this call wholesale.
2. **MBW-13 "No duplicate transitions" uses the design's named fallback, and the case was renamed.** `togglePopover()` cannot open a popover in the test host: a `.transient` popover does not display while its application is inactive, and `NSApp.isActive` is `false` there (measured, together with a present button in a real window). The design anticipated this ("if the popover cannot display headless…"), so the case is now `togglingTwiceNeverReportsASecondOpen` and asserts the mechanism MBW-13 rests on rather than the display: after two toggles `isPanelOpen` is `false` and no two consecutive opens were reported, and — because the popover demonstrably never displayed — the recorder is **empty**. That last assertion is not vacuous: it is exactly what fails if anyone reports the open from inside `togglePopover()` instead of from the delegate, which is the implementation that would double-count. The case also branches: if a host ever does display the popover it asserts the full `[open, closed]` sequence instead of silently passing on an empty one. The delegate half of MBW-13 is covered directly and unconditionally by `thePopoverDelegateReportsEachTransitionOnce`.
3. **`SettingsFormIntent` grew three members the design does not name.** The design writes the toggle binding and both move buttons inline in `SettingsView`. They moved behind named main-actor compositions for the reason batch E already recorded for the stepper (deviation 2 there) and the batch E gate then demanded: a closure inside a `Button` or a `Binding` setter is unreachable from any test, so the chevron-to-direction pairing and the toggle's polarity were uncovered. Behaviour is unchanged — each member is the same single `SettingsState` call the view made before.
4. **`StatusItemControllerTests` was restructured, not just re-initialised.** The design's line says "existing four cases (`:28-70`) with the new init". The four cases now run through a `withController` helper that releases the controller at the end of each case, because convention 14 requires every `NSStatusItem` created in tests to be removed and the old shape leaked four of them per run. One case was renamed (`theStatusItemIsSizedFromTheWidestContent` → `theStatusItemIsSizedFromTheCurrentModuleSet`) because the item is no longer sized from a fixed widest set but from the user's current module list.
5. **MBW-12 uses a `StatusItemReleaseProbe` object instead of two `weak var` locals.** The design writes `weak var item = controller.installedStatusItem` and `weak var weakController` in the test body. Convention 2 forbids `@MainActor` tests, and a non-isolated body cannot write main-actor weak references without a concurrency diagnostic, so both live on a small `@MainActor` probe class that builds, records and releases in one main-actor step. The assertion is the design's: end the scope, one `await MainActor.run {}`, both `nil`. The probe additionally reports whether it ever held a live pair, so a probe that built nothing fails instead of reporting a vacuous release.
6. **MBW-11 "Palette untouched" landed in `StatusItemControllerTests`.** `memAccent` was already asserted in `StatusItemReadingsTests`, but `cardBackground` was not asserted anywhere. The scenario belongs to MBW-11, whose other scenario is in this file, so both tokens are pinned here against the same `sRGB(_:)` helper the other suite uses.
7. **Menu key equivalents are hints, and this is stated in code.** The design gives "Settings…" `keyEquivalent: ","`; Quit keeps its existing `"q"`. Because the menu is attached and detached around `performClick`, neither is a working global shortcut — they are what the user reads next to the item. A doc comment says so, so nobody later "fixes" a shortcut that was never meant to fire from there. Cmd+, itself is task 7.2's job.
8. **`panelObserver` is retained, not held weakly.** The design's signature is silent. A strong reference matches "every collaborator is retained by `AppDelegate`" and creates no cycle (`SamplingCadenceController` never refers back to the controller). The observer registered on `SettingsState` is the one that must be weak, and is: `settings.observe { [weak self] … }`, per the standing batches B/D warning that the observer list is append-only and never pruned. `releasingTheControllerRemovesItsStatusItem` passing is the proof that this capture is correct.

### Issues found

- None blocking. The one behavioural surprise (headless popover display) is recorded as deviation 2 and was already anticipated by the design.

### Open items for batch G (Phase 7 and 8)

- **7.1 `AppDelegate`, exact order from `design.md:296-305`:** `UserDefaultsSettingsStore()` → `SettingsState(store:)` → `MetricsState()` → `MetricsSampler(state:cpuProvider:memoryProvider:topologyProvider:interval: SamplingCadence.effective(configured: settingsState.samplingInterval, panelOpen: false))` → `SamplingCadenceController(sampler:settings:)` → `SettingsWindowController(settings:)` → `StatusItemController(state:settings:launchAtLogin: SMAppServiceLaunchAtLogin(), panelObserver: cadence, openSettings: { [settingsWindow] in settingsWindow.show() })` → `sampler.start()`. Every collaborator retained (replacing the three optionals at `AppDelegate.swift:10-12`); `applicationWillTerminate` unchanged. **Delete the batch-F stopgap first** — the current call builds its own throwaway `SettingsState`, and leaving it would give the app two settings objects, so the settings window and the widget would disagree.
- **`showSettings()`** must call the *same* `SettingsWindowController` instance the status item was given. `eachControllerOwnsItsOwnWindow` (batch E) proves two controllers mean two windows, which is what ST-5 forbids.
- **7.2 `system_monitorApp.swift`:** keep `SwiftUI.Settings { EmptyView() }` fully qualified (the Domain `Settings` type shadows the scene; never revert that) and add `.commands { CommandGroup(replacing: .appSettings) { Button("Settings…") { appDelegate.showSettings() }.keyboardShortcut(",", modifiers: .command) } }` using the `@NSApplicationDelegateAdaptor` instance at `:5`. Fallback if the replacement does not take on macOS 26 is design decision 13 (retarget the `NSApp.mainMenu` item whose key equivalent is ",").
- **7.3 PRD 6.1 amendment** (Application holds two `@Observable` objects, `MetricsState` and `SettingsState`) and the section 10 Instruments note. **7.4 `openspec/config.yaml`** lines 24, 25 and 90.
- **8.1/8.2 verification:** the task text still says "expect roughly 370 cases"; the real figure after phases 1–6 is **518** (from a 299-case pre-change baseline), so record the actual number rather than the estimate. The warning gate must force a recompile (`fd … -x touch {}`) or it reports zero warnings without rebuilding the test target.
- **8.3 manual, ST-5 activation:** the S3 fallback in `SettingsWindowController` is deliberately not implemented. Its trigger is exactly this check — "window becomes key on first show from the context menu". The default `errorPresenter`'s `NSAlert` shares the same activation risk and inherits the same fallback.
- **8.6 manual, MBW-13 real popover:** the only MBW-13 assertion the automated suite cannot make is that a real popover open/close pair reaches the cadence controller, because the test host is never active. Confirm by opening and closing the panel on the development machine and watching the sampling rate change.
- **8.5 manual, MBW-9:** the one-module and two-module widths are now asserted in the suite against 130 pt and 230 pt; the manual check adds the visual confirmation that the bar really shrinks and the order really follows the settings list.
- Standing: `SettingsState.observers` is append-only and never pruned. Any future registrant must capture `[weak self]` — `SamplingCadenceController` and now `StatusItemController` both do.
- Timing in this batch: each incremental `TEST` run took roughly 1–2 min; the forced full recompile for the warning gate about 2 min. Suite-scoped runs (`-only-testing:…/StatusItemControllerTests`) came back in well under a minute and were worth using for the diagnostic loop. Note that `-only-testing` down to a single Swift Testing function silently ran nothing and still printed `** TEST SUCCEEDED **`; filter at suite level instead.

### Batch F gate amendments (orchestrator, 2026-09-06)
- Cross-reference fix: the MBW-13 real popover open/close round trip is manual task 8.4 (panel close drops to one update per 2 s), not 8.6 (launch-at-login round trip).
- Carried batch E amendment is only partly closed: `SettingsFormIntent` move compositions are covered, but the chevron-to-intent binding in `SettingsView.swift:250-266` remains uncovered by construction (swapping the two Button bodies passes all 518 cases). Residual risk routed to manual task 8.5 (reordering MEM/CPU changes the widget order).
- Uncovered production branch under the headless MBW-13 fallback: `togglePopover()` `popover.isShown == true` -> `performClose(nil)` (`StatusItemController.swift:213-217`) never executes in the test host because a transient popover cannot display while `NSApp.isActive` is false. Attached to manual task 8.4.
- Batch G first item: `SettingsViewTests.swift:145,163` cite a non-existent ST-6 scenario "Move buttons reorder the widget"; add that scenario to `specs/settings/spec.md` ST-6 (the requirement prose already mandates move controls) and retarget the comment at :210 to the requirement prose.

## Batch G — Phase 7 (Composition root, commands, docs) + Phase 8 automated verification

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-g-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:90786e4392e8e128c7d0d75d097b85d64ae1dc495fb187cf28d503abbcdd9009"}` (parent token continued, zero ledger mutation; no untracked declaration demanded, not settled by this actor)
- Work unit: `apply-batch-g-phase-7-composition-root-commands-docs-and-phase-8-automated-verification`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`
- Engram mirror: this section only is saved under topic key `sdd/polish-module/apply-progress-batch-g`. The combined observation `sdd/polish-module/apply-progress` is at the 50,000-character cap and was **not** updated; batches A–D remain under that key, E under `…-batch-e`, F under `…-batch-f`.
- Skills loaded: `swiftui-patterns`, `swift-concurrency-6-2`, `swift-testing` (all three present at the injected paths).

### Carried amendment (batch F gate, executed before 7.1)

`system-monitorTests/Presentation/SettingsViewTests.swift:145,163` cited an ST-6 scenario, "Move buttons reorder the widget", that the `settings` delta did not contain. Closed by adding the scenario rather than deleting the citation, because the ST-6 requirement prose already mandates the move controls and the two cases really do pin them:

```
#### Scenario: Move buttons reorder the widget

- GIVEN a settings form over `menuBarModules == [.cpu, .memory]`
- WHEN the move-down intent runs for `.cpu`
- THEN the persisted order is `[.memory, .cpu]`
- AND repeating the move for a module already at that edge persists nothing
```

The comment at `:206-208` (over `theVisibilityToggleCommitsTheRequestedStateInBothDirections`) cited "Toggles follow the current order", a scenario about row ordering, not about committing. It now cites the ST-6 requirement prose ("a visibility toggle per `MetricModule` listed in the current order"), which is what the case actually proves. Two verification notes were added to the delta so ST-6's control wiring (`SettingsViewTests`) and the composition root's half of ST-5/ST-7 (`AppDelegateCompositionTests`) name the files that cover them. Traceability in `tasks.md` moved from 83 scenarios (ST 32) to 84 (ST 33).

### Tasks completed

- [x] 7.1 **RED→GREEN** `system-monitor/App/AppDelegate.swift` — the design's construction order, every collaborator retained, `showSettings()`; driven by the new `system-monitorTests/App/AppDelegateCompositionTests.swift`
- [x] 7.2 **GREEN** `system-monitor/App/system_monitorApp.swift` — `SwiftUI.Settings { EmptyView() }` kept qualified, `.commands { CommandGroup(replacing: .appSettings) … }` added (no unit test can reach it; handed to manual check 8.3)
- [x] 7.3 **DOC** `PRD.md` — 6.1 names both `@Observable` objects, 6.4 covers `SettingsState`, the tree gains the M4 files, section 10 points at the recorded Instruments numbers
- [x] 7.4 **DOC** `openspec/config.yaml` — deployment target, Swift version and the "no commits yet" line corrected against `project.pbxproj` and `git rev-list`
- [x] 8.1 Full `TEST`: exit 0, **525 cases, 0 failures**
- [x] 8.2 Zero-warning gate with a forced test-target recompile: exit 0, no `warning:` match, `project.pbxproj` clean
- [ ] 8.3–8.7 **MANUAL** — handed to the user; each task in `tasks.md` now carries the exact steps and the expected observation

42 of 42 automated tasks complete across phases 1–8 (36 through batch F, 6 here; validator-corrected count). The five manual checks are the only outstanding work.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| Carried amendment | `openspec/.../specs/settings/spec.md`, `Presentation/SettingsViewTests.swift` | Spec + comment | 518/518 baseline (`TEST` exit 0) | N/A — the delta gained the scenario the existing cases already assert; no test or production behaviour changed | Yes — 525 cases, 0 failures in the batch's final run | N/A — the two move cases (each with its edge no-op) and the two toggle cases already triangulate the scenario | Comment retargeted to the requirement prose it actually proves |
| 7.1 | `App/AppDelegateCompositionTests.swift` (new) | Composition root over the real graph (real `UserDefaults`, real `SMAppService` read, real Mach providers, real `NSStatusItem`, real `NSWindow`) | 518/518 | Yes — `value of type 'AppDelegate' has no member 'showSettings'`, `no member 'settingsState'`, `no member 'settingsWindow'`, `'sampler' is inaccessible due to 'private' protection level`, `'statusItemController' is inaccessible due to 'private' protection level` (exit 65) | Yes — 525 cases, 0 failures (+7) | Yes — 7 cases: the three identity bindings (widget, window, panel observer) in one case; closed-cadence seeding asserted both against the rule and against `idleInterval`; open **and** close transitions through the real popover delegate; both entry-point orders (command first, menu first) asserted on `windowNumber`; termination stopping the sampler; the delegate's release removing the status item | None needed |
| 7.2 | none — unreachable from the unit target | SwiftUI `Scene` command | 525/525 | N/A — see deviation 2 | `build` exit 0, 0 warnings | Handed to manual check 8.3 | None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, 525 test cases, 0 failures. During the cycle: RED run exit 65 with the five compile errors above, GREEN run exit 0 / 525 |
| Runtime harness command/scenario and exact result | The most real harness in the change. `AppDelegateCompositionTests` calls `applicationDidFinishLaunching` on a genuine `AppDelegate`, which builds `UserDefaultsSettingsStore()` over `.standard`, reads the live `SMAppService.mainApp.status` when the menu is built, installs a real `NSStatusItem`, starts the real sampler over `MachCPUProvider`/`MachMemoryProvider`/`IORegistryCoreTopologyProvider`, opens a real settings window and fires the real context-menu item through `target.perform(action:with:)`. Every case terminates the delegate (stopping the sampler) and closes the window in a `defer`; `releasingTheDelegateRemovesTheStatusItem` watches two weak references go `nil`, so nothing is left in the menu bar (convention 14). The suite never mutates a setting, so it cannot disturb the installed app's stored preferences. The one boundary it cannot cross is the SwiftUI command (7.2), which needs a running `App` scene |
| Rollback boundary | Delete `system-monitorTests/App/AppDelegateCompositionTests.swift`; `git checkout --` on `system-monitor/App/AppDelegate.swift`, `system-monitor/App/system_monitorApp.swift`, `PRD.md` and `openspec/config.yaml`; drop the two accessors from `system-monitor/Presentation/MenuBar/StatusItemController.swift` (`observedSettings`, `panelVisibilityObserver`) and the one from `system-monitor/Presentation/Settings/SettingsWindowController.swift` (`boundSettings`); revert the ST-6 scenario and the two verification notes in `specs/settings/spec.md` and the comment hunk in `SettingsViewTests.swift`. Batches A–F are untouched, except that reverting `AppDelegate.swift` to `HEAD` also removes batch F's compilation-required stopgap, so the two must be reverted together |

### Files created

| File | Lines |
|---|---|
| `system-monitorTests/App/AppDelegateCompositionTests.swift` | 288 |

Registered with `git add -N` immediately after creation. It is the first file under `system-monitorTests/App/`; the synchronized root group picked the new directory up with no `project.pbxproj` edit (convention 6).

### Files modified

| File | Batch-G change | Size after |
|---|---|---|
| `system-monitor/App/AppDelegate.swift` | +55 / −14 against the batch-F stopgap — the design's construction order, six retained collaborators (internal `private(set)` for the composition test), the closed-cadence seed, `showSettings()`; `applicationWillTerminate` unchanged | 81 |
| `system-monitor/App/system_monitorApp.swift` | +19 / −0 — `.commands { CommandGroup(replacing: .appSettings) { Button("Settings\u{2026}") { appDelegate.showSettings() }.keyboardShortcut(",", modifiers: .command) } }`; the `SwiftUI.Settings` qualification kept verbatim | 35 |
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | +16 / −0 — `observedSettings` and `panelVisibilityObserver` test accessors (deviation 1) | 345 |
| `system-monitor/Presentation/Settings/SettingsWindowController.swift` | +8 / −0 — `boundSettings` test accessor (deviation 1) | 102 |
| `system-monitorTests/Presentation/SettingsViewTests.swift` | +1 — carried amendment, comment retargeted | 230 |
| `PRD.md` | +10 / −5 (validator-corrected) — 6.1 tree and bullet, 6.4 observation note, section 10 Instruments note | 357 |
| `openspec/config.yaml` | 3 lines rewritten (24, 25, 90) | 99 |
| `openspec/changes/polish-module/specs/settings/spec.md` | +11 — ST-6 scenario and two verification notes | 247 |
| `openspec/changes/polish-module/tasks.md` | 7.1–7.4, 8.1, 8.2 marked `[x]`; traceability 83 → 84; 8.1's "roughly 370 cases" corrected to 525; a "handed to user" block appended to each of 8.3–8.7 | 132 |

Batch-G authored total: about 500 changed lines (288 new + roughly 210 modified), well inside the ledger's 2400-line work-unit cap and covered by the recorded `size:exception`. `system-monitor.xcodeproj/project.pbxproj` is unmodified — convention 16 applied after each of the 5 `xcodebuild` runs, and `git status --short system-monitor.xcodeproj` is empty.

### Test and warning counts

- Before batch G: 518 test cases, 0 failures (verified by a baseline `TEST` at the start of this batch: exit 0, 518).
- After 7.1: 525. After 7.2 (`build` only): unchanged. Final `TEST`: **525 test cases, 0 failures, exit 0**. +7 cases, all seven in the new composition suite; the 518 pre-existing ones all still pass.
- Counting method: `rg -c "' passed on '"` over the captured log (batch D/F caveat still applies: `xcodebuild` interleaves timestamped stderr and can corrupt one line, so the figure carries ±1 noise). `rg -c "' failed on '"` reports no matches.
- Cumulative: 299 cases before the change, 525 after (+226), with five wall-clock sampler-loop cases replaced by deterministic `ManualClock` ones in batch B.
- Warnings: **0**. Gate run as the standing open item requires — `fd -e swift . system-monitorTests system-monitor -x touch {}` then `xcodebuild … -quiet build-for-testing` (exit 0), `rg -c "warning:"` reporting no matches, so the test target was recompiled too. `xcodebuild … -quiet build` also exits 0 with no warnings and no errors.
- `git diff --stat | tail -1`: `42 files changed, 5408 insertions(+), 163 deletions(-)` (tracked files only; the 27 new files are intent-to-add). Untracked entries: `.pi/` (not ours) and `openspec/changes/polish-module/`.

### Deviations from the design

1. **Three internal test accessors were added to production types: `StatusItemController.observedSettings`, `StatusItemController.panelVisibilityObserver`, `SettingsWindowController.boundSettings`.** The design names `installedStatusItem` and the window controller's read-only accessors as test-visible; these three follow that precedent for the one invariant the composition root exists to guarantee. Without them "the app has exactly one `SettingsState` and one `SettingsWindowController`" is unprovable: a second state loaded from the same store exposes the same interval and the same module list, so every value assertion agrees with the bug. Each accessor is a read-only computed property over an existing stored `let`, and none widens the type beyond the app module.
2. **Task 7.2 has no automated test, by construction.** A `CommandGroup` only exists while a SwiftUI `App` scene runs; the unit target never instantiates `SystemMonitorApp`, so neither the menu item nor its Cmd+, key equivalent is reachable. Strict TDD's rule is "RED first where a test can reach the behaviour" — this is the documented exception, and it is why the design already listed the command as manual check 1. The reachable half is covered: `AppDelegateCompositionTests` proves `showSettings()` (the command's target) shows the same window the context menu shows, in both orders.
3. **`AppDelegate`'s six collaborators are internal `private(set) var`, not private.** The design says "every collaborator is retained by `AppDelegate` (replacing the three optionals)". Retention is unchanged; only visibility differs, and for the same reason as deviation 1 — the composition test reads them. Documented in the file so nobody outside the tests starts using them as a service locator.
4. **The composition suite is tagged `.integration`.** It reads real `UserDefaults`, the live `SMAppService` status and real Mach counters, which is what the tag means in this project. As batch C recorded, the tag does not exclude it from the default `TEST` run.
5. **The batch-F `AppDelegate` stopgap was deleted, not extended.** It built a throwaway `SettingsState` inline in the `StatusItemController` call. Leaving it would have given the app two settings objects — the widget following one and the settings window the other — which is exactly what `launchingBuildsOneSettingsObjectSharedByEveryCollaborator` now fails on.
6. **`PRD.md` was amended in three places, not one.** The task names 6.1 and the section 10 note. Section 6.4's "`MetricsState` is `@MainActor @Observable`" would have been left stale by a 6.1-only edit, and the 6.1 directory tree still listed a `LaunchAtLogin` file under `Infrastructure/System` that this change replaced with two real adapters. Both are the same amendment, applied consistently.
7. **`openspec/config.yaml` line 24 says 26.5 for every target, not "app target 15.0".** Verified before editing: all six `MACOSX_DEPLOYMENT_TARGET` entries in `project.pbxproj` read `26.5` and all six `SWIFT_VERSION` entries read `6.0`; `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is set on the app target's two configurations only. `project.pbxproj` was not edited.

### Issues found

- None blocking. The composition test depends on the machine's stored `UserDefaults` for one assertion pair: if a developer has saved a 2 s interval, `aPanelTransitionOnTheStatusItemReachesTheSampler` compares open against closed cadences that happen to be equal, and that case alone would tolerate a missing panel observer. The identity case (`panelVisibilityObserver === cadence`) covers exactly that hole unconditionally, which is why it exists.

### Ready for verify

- **Tasks**: 42 of 47 done (validator-corrected). All 42 automated tasks across phases 1–8 are complete and green. The 5 outstanding are manual: 8.3 (settings entry points, including Cmd+,), 8.4 (interval and cadence, plus the real popover open/close), 8.5 (module visibility, order and the chevron binding), 8.6 (launch-at-login round trip, dark chrome, reduce motion), 8.7 (Instruments numbers).
- **Known gaps carried into verify**:
  - **MBW-13 headless branch** — `togglePopover()`'s `popover.isShown == true → performClose(nil)` arm (`StatusItemController.swift:213-217`) never executes in the test host, because a transient popover cannot display while `NSApp.isActive` is false. Routed to manual 8.4.
  - **Chevron binding** — the two `Button` bodies in `SettingsView.swift` that call `SettingsFormIntent.moveUp`/`moveDown` are uncovered by construction; swapping them passes all 525 cases. The intents themselves are covered. Routed to manual 8.5.
  - **Cmd+, reachability** — deviation 2. The `CommandGroup` binding is unverified until manual 8.3; the fallback if it does not take on macOS 26 is design decision 13.
  - **Launch-at-login mutations** — convention 11 forbids calling `enable()`/`disable()` on the real adapter from tests, so every registration transition is proven only through the fake. Routed to manual 8.6.
  - **S3 activation fallback** — deliberately not implemented in `SettingsWindowController`; its trigger is manual 8.3's "key on first show".
- **Delivery**: nothing committed (convention 15). `git status --short` lists exactly the intended files: 15 tracked modifications (`PRD.md`, `openspec/config.yaml`, 8 production Swift files — `AppDelegate`, `system_monitorApp`, `MetricsSampler`, `MetricModule`, `StatusItemController`, `StatusItemView`, `CPUCard`, `MemoryCard` — and 5 test Swift files), 27 intent-to-add new files, and two untracked directories — `.pi/` (not part of this change) and `openspec/changes/polish-module/`. No `project.pbxproj` change, no stray files.

### Batch G gate amendments (orchestrator, 2026-09-06)
- Deviation 8 recorded: `system-monitorTests/App/AppDelegateCompositionTests.swift` is a test file outside the design rev 2 File Changes table (first file under `system-monitorTests/App/`). Justified: the composition-root identity invariants (one `SettingsState`, one `SettingsWindowController`, cadence controller as the panel observer) are unprovable from any listed suite. The design table has been extended with a row for it; `specs/settings/spec.md` verification note softened accordingly.

## Batch H — Correction: manual check 8.3 (Settings window renders empty)

- Date: 2026-09-06
- Ledger token request id: `polish-module-batch-h-actor-20260906`
- Ledger acquire: `{"state": "proceed", "token": "sha256:2aae191f1bbc0da36136573f64e307ebf44eaed003f1fbd3defeb54d0d651179"}` (parent token continued, zero ledger mutation; nothing settled by this actor)
- Work unit: `correction-batch-h-manual-8-3-settings-window-renders-empty`
- Test command (`TEST`): `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`
- Engram mirror: this section only, under topic key `sdd/polish-module/apply-progress-batch-h`. The combined `sdd/polish-module/apply-progress` observation is at the 50,000-character cap and was **not** touched.
- Skills loaded: `swiftui-patterns`, `swift-testing`, `swiftui-uikit-interop` (all three present).
- Delivery: single PR with the recorded `size:exception`; this batch adds about 82 changed lines to it.

### The defect

Manual check 8.3, first run (user, 2026-09-06): right-click -> "Settings..." opened the owned window, but it presented only a title bar about 360 pt wide with no content under it. ST-5's "first show creates the window" was satisfied on every automated assertion — visible, titled "Settings", one reusable instance — and the window was still unusable, because nothing in the suite looked at its size.

### Root cause — hypothesis revised by measurement

The incoming hypothesis was "the content size resolves to 360 x 0". The RED measurement says it resolves to **(0.0, 0.0)** — zero width as well as zero height. The ~360 pt the user saw is the window's own minimum title-bar width, not the form's fixed width leaking through.

Probe numbers taken from the unmodified batch-G code, on a real window in the test host:

| Measurement | Value |
|---|---|
| `NSHostingView(rootView: SettingsRootView(...)).fittingSize` | `(360.0, 244.0)` |
| `NSHostingController(...).view.fittingSize` | `(360.0, 244.0)` |
| `NSHostingController(...).preferredContentSize` | `(0.0, 0.0)` |
| `NSHostingController(...).sizingOptions` | `NSHostingSizingOptions(rawValue: 7)` — `.standardBounds` = `[.minSize, .intrinsicContentSize, .maxSize]` |
| `window.contentView!.frame.size` after `show()` | **`(0.0, 0.0)`** |

So the form is not the collapsing party: hosted in an `NSHostingView` it measures a healthy 360 x 244. The failure is the controller-to-window handoff. `NSHostingController`'s default `sizingOptions` is `.standardBounds` (raw 7), which publishes the SwiftUI content's minimum, intrinsic and maximum sizes on the hosted **view** but never sets the controller's `preferredContentSize` (raw 8, absent). `NSWindow` sizes its content area from `preferredContentSize`, so `contentRect: .zero` was never replaced. `SettingsView` being a grouped `Form` — a scrolling container that accepts any proposed height instead of pushing back — is what makes that zero survive as a rendered (rather than clipped) layout. Design rev 2's parenthetical "(default `sizingOptions` size the window from the form)" was simply wrong about which sizing option is on by default.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 8.3 correction | `Presentation/SettingsWindowControllerTests.swift` | Presentation AppKit host (real `NSWindow`) | 525/525 from batch G, re-proved by the RED run: 525 passed with only the new case failing | Two stages. **RED-1** (test only): `TEST` exit 65, `value of type 'SettingsWindowController' has no member 'windowContentSize'`. **RED-2** (inert accessor + provisional constant added so the assertion could execute): `TEST` exit 65, 525 passed, `theFirstShowPresentsTheWholeForm()` failed on **both** expectations with `window content size was Optional((0.0, 0.0))` | Yes — `TEST` exit 0, 527 cases, 0 failures | Yes — `theWindowIsNeverShorterThanTheFormItHosts()` compares the window content height against the height the hosted form measures for itself, so a floor constant smaller than the form fails it. That is the case a "Fake It" hardcoded size passes the first test with and fails here | None needed — the fix is one expression plus its constant |

The RED was split deliberately. Stage 1 is the strict-TDD compile failure (the test names production that does not exist). Stage 2 added only two inert declarations — the read-only `windowContentSize` accessor and a placeholder `SettingsView.formHeight` the view did not yet read — so the assertion could run and **report the measured number** instead of a compile error. Neither declaration changes behaviour; the assertion still failed, on the defect, with the measurement quoted above. A temporary `measurementProbe()` case carried the four hosting measurements out of the same run and was deleted before GREEN.

Getting those numbers out needed one detour worth recording: `xcodebuild -quiet` drops Swift Testing's `#expect` comment messages from stdout, and a test-target file write to `/private/tmp` is refused by the sandbox. The measurements were read with `-resultBundlePath` plus `xcrun xcresulttool get test-results tests --path <bundle> --format json`.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` (full unit target) — exit 0, **527** test cases, 0 failures. Counting method `rg -c "' passed on '"` |
| Runtime harness command/scenario and exact result | Real runtime boundary. Both new cases drive a real `NSWindow` through `SettingsWindowController.show()` in the test host and read back `window.contentView!.frame.size`; the triangulation case additionally renders `SettingsRootView` in a real `NSHostingView` over the controller's own `boundSettings` and compares the two measurements. `withSettingsWindow` closes every window in its `defer`, no case asserts `isKeyWindow`, and the suite keeps its `.timeLimit(.minutes(1))`. The one thing the harness still cannot prove is what the user sees on screen — hence 8.3 stays `[ ]` and pending re-run |
| Rollback boundary | Revert the `makeWindow()` body and its doc comment plus the `windowContentSize` accessor in `system-monitor/Presentation/Settings/SettingsWindowController.swift`, drop `SettingsView.formHeight` from `system-monitor/Presentation/Settings/SettingsView.swift`, and drop the two appended cases in `system-monitorTests/Presentation/SettingsWindowControllerTests.swift`. Nothing else in batches A-G is touched; no other production file, no other test file |

### Files modified

| File | Batch-H change | Size after |
|---|---|---|
| `system-monitor/Presentation/Settings/SettingsWindowController.swift` | `makeWindow()` now sets the content size explicitly from the hosted view's `fittingSize` floored at `SettingsView.formHeight`, before `center()`; the method doc explains why, and the type doc gained a "Sizing:" paragraph; new read-only `windowContentSize` test accessor | 133 (was 102) |
| `system-monitor/Presentation/Settings/SettingsView.swift` | New `static let formHeight: CGFloat = 280` next to `formWidth`, documented against the measured 244 pt natural height | 315 (was 306) |
| `system-monitorTests/Presentation/SettingsWindowControllerTests.swift` | Two cases appended: `theFirstShowPresentsTheWholeForm()` and `theWindowIsNeverShorterThanTheFormItHosts()` | 151 (was 116) |
| `openspec/changes/polish-module/tasks.md` | 8.3 keeps `[ ]`; a first-run FAILED line added under it | 133 |
| `openspec/changes/polish-module/design.md` | The `SettingsWindowController.show()` paragraph now specifies explicit sizing, marked **Revision 2.1 (batch H correction)** | 512 |
| `openspec/changes/polish-module/specs/settings/spec.md` | ST-5 requirement prose now mandates the explicit content sizing; new scenario "First show presents the whole form" | 253 |

Authored delta: +75 net lines over three Swift files (about 82 changed lines counting the doc lines rewritten in place), inside the ledger's 600-line cap for this work unit and covered by the recorded `size:exception`. `system-monitor.xcodeproj/project.pbxproj` reverted after each of the 5 `xcodebuild` runs; `git status --short system-monitor.xcodeproj` is empty. Nothing committed, HEAD is still `f41bc05`, and the intent-to-add staging is untouched.

### Test and warning counts

- Before batch H: 525 test cases, 0 failures.
- RED-2: 525 passed, 1 case failing on 2 expectations (`TEST` exit 65).
- After GREEN: **527** test cases, 0 failures (`TEST` exit 0). +2 cases, both in `SettingsWindowControllerTests`.
- The batch prompt anticipated 526 (one new case). The extra case is the strict-TDD triangulation described above; adding only the first test would have let a hardcoded height smaller than the form pass.
- Warnings: 0. Gate run in full — `fd -e swift . system-monitorTests system-monitor -x touch {}` then `xcodebuild ... -quiet build-for-testing` (exit 0), `rg -c "warning:"` reporting no matches, so the test target was recompiled too.
- `SettingsViewTests` (fixed 360 pt width; save-error footer grows the height) passes unchanged — see deviation 1 for why it was left alone.

### Deviations from the batch prompt

1. **No `.frame(minHeight:)` was added to `SettingsView`.** The prompt asked for one "so the form never collapses in any host". The measurement says the form does not collapse in any host: in an `NSHostingView` it fits at 360 x 244. The collapse was entirely the window's un-set content rect. Adding a `minHeight` would have had one real effect — clamping `NSHostingView.fittingSize` to that floor — and `SettingsViewTests` pins two measurements that depend on the unclamped value: `theFormGrowsWhenASaveFails` asserts the failing form is **strictly taller** than an identical clean one, which collapses to an equality the moment both natural heights fall under a shared floor. The fix therefore lives only where the defect is, in `makeWindow()`, and the existing view suite passes untouched.
2. **The floor is 280 pt, chosen from the measurement rather than the prompt's 280-340 range midpoint.** The two standard sections measure 244 pt. 280 is the lowest value in the suggested range, clearing the natural height by 36 pt of headroom for the save-error footer and for larger accessibility text without opening a window that is mostly empty space. `max(fittingSize.height, formHeight)` keeps the form authoritative whenever it needs more.
3. **Two new test cases, not one** (see the test counts above).
4. **One new read-only production accessor, `SettingsWindowController.windowContentSize`.** It follows the precedent set in batch E (`windowStyleMask`, `hostedRootViewType`) and batch G (`boundSettings`): a computed property over the same optional window, no widening of the type. Without it, the defect is unobservable from a test — a zero-sized window reports `isVisible == true` and the right title.

### Issues found

- Design rev 2's claim that the hosting controller's "default `sizingOptions` size the window from the form" is factually wrong for `NSHostingController` on macOS: `.standardBounds` does not include `.preferredContentSize`. Corrected in design.md as Revision 2.1. Any future window built by copying that paragraph would have reproduced this bug.
- The ST-5 automated suite proved identity, lifetime and reuse but never size, and passed at 100% against a window the user could not use. The new scenario closes that gap in the spec, not only in the suite.

### Open items

- **Manual check 8.3 must be re-run by the user.** It stays `[ ]` in `tasks.md`. The expected observation is unchanged except that the window must now present the whole form: right-click -> "Settings..." shows a 360 x 280 pt content area with the "Sampling interval" stepper and the "Menu bar modules" rows, in front and key.
- The S3 activation fallback is still deliberately unimplemented; its trigger is the same 8.3 re-run ("key on first show").
- Cmd+, reachability (`CommandGroup(replacing: .appSettings)`, batch G deviation 2) is still unverified and rides on the same re-run.

### Manual check results (user, 2026-09-06)
- 8.3 PASSED after correction H: right-click → "Settings…" shows the form (interval "1,0 s" in the user locale, CPU/MEM rows with correct chevron enablement), the window comes to the front and is key with normal title bar and traffic lights (no S3 fallback needed); Cmd+, with the app active brings back the same window, never a second or empty one. ST-5 and MBW-10 closed; Cmd+, `CommandGroup(replacing: .appSettings)` works on macOS 26 (design decision 13 fallback not needed).
- 8.4 PASSED: 0.5 s updates about twice per second within one tick of the change; 5 s gives one update per 5 s with the panel open; closing the panel drops the sparkline to one advance per 2 s regardless of the setting; two clicks on the item open then close the panel. ST-7, CM-1, CM-2 closed; the MBW-13 real popover open/close pair and the `togglePopover()` performClose arm are confirmed at runtime.
- 8.5 PASSED: hiding MEM shrinks the item to the CPU module alone; showing it restores the two-module width; MEM up chevron renders MEM before CPU and the down chevron restores CPU before MEM. MBW-1, MBW-9 closed; the chevron-to-intent binding (W-2) is confirmed at runtime: up is up.
- 8.6 PASSED: Launch at Login toggles the Login Items entry on and off with the menu check mark following the live status; the approval path (title "(Requires Approval)…" routing to Login Items), dark popover chrome under light system appearance, and Reduce Motion making the ring gauge jump all confirmed by the user. LAL-4, MBW-11, MC-10 closed; W-4 (real SMAppService mutations) confirmed at runtime.

#### 8.7 Instruments (user, 2026-09-06)
- Run 1, panel CLOSED, 10:02 wall time, Time Profiler (Release profile build): total sampled CPU 9.85 s = about 1.6% of one core on average; main thread 9.01 s; heaviest stack CFRunLoopRun → CFRunLoopDoTimer (4.08 s) → NSStatusItem (3.86 s) → NSView layoutSubtreeIfNeeded (2.65 s) → SwiftUI ViewGraph/AttributeGraph updates. No PanelView bodies in the heaviest stack, so G3 (build the panel hosting controller on show) is NOT indicated. Verdict: MISSES the PRD section 10 "under 1%" closed-panel goal by about 0.6 points; the cost is the status item widget redraw per 2 s tick (roughly 300 ticks, about 30 ms sampled CPU per tick, dominated by AppKit status-item layout rather than SwiftUI body evaluation). Resident memory not captured by Time Profiler; to be read from Activity Monitor during run 2.
- Run 2, panel OPEN, 10:03 wall time, Time Profiler + SwiftUI instrument: total sampled CPU 40.77 s = about 6.8% of one core on average; main thread 38.79 s; heaviest stack CFRunLoopRun → CFRunLoopDoSource (16.59 s) → CA::Transaction commit (16.36 s) / run (9.46 s) → SwiftUI closure in View update (6.18 s) → ViewGraph.update (2.72 s) → DisplayList. Thermal state nominal throughout. Interpretation: with the panel open the cost is Core Animation layer commits of the panel (ring gauges, history graphs, core bars, stacked bar) on every tick, not body evaluation; no PRD target exists for the open state. Combined verdict: functional checks all pass; the closed-panel CPU goal (under 1%) is missed at about 1.6%; recommended follow-up change: status-item and panel redraw optimization (AppKit status item layout per tick; CA commit size of the panel; G3 hosting-controller-on-show as a candidate).
