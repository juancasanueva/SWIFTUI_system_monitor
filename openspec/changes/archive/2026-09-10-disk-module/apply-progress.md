# Apply Progress: Disk Module (PRD M5 — "Disk — ship v1")

Mode: **Strict TDD**. Artifact store: hybrid (this file plus Engram topic `sdd/disk-module/apply-progress`).
Delivery: single PR with `size:exception` accepted up front (`review_budget_lines: unlimited`). Apply never commits.

## Batch A — Phase 1 Domain foundation

Date: 2026-09-09. Work unit: `batch-a-domain-foundation` (tasks 1.1 – 1.7, requirements DM-1 – DM-5).
Scope guard honoured: only new files under `system-monitor/Domain/` and `system-monitorTests/`. No
`MetricsSampler`, `MetricsState`, Infrastructure, Presentation, App or `PRD.md` change.

### Native runtime ledger

Acquire (`request-id disk-module-batch-a-actor-20260909`, `--untracked-scope=exclude`,
`--expected-untracked-inventory=sha256:82bb4473…`):

```json
{
  "state": "proceed",
  "token": "sha256:d678477b2b1b0424a046fde220796a41096948a19931af1d4a0701ecee5d59ce"
}
```

Settle (`request-id disk-module-batch-a-settle-20260909`, `--outcome passed`,
`--evidence-revision sha256:90a8dec2d3346f99906c1c10d2a90a2b1a5d7541f9d9682be1506a82cef74c98`):

The first settle attempt was refused with `state: blocked`, `reason: undeclared_untracked`, because the
twelve files this batch created are untracked and the request carried no untracked ruling. It was rerun
once with `--untracked-scope=select`, one `--intended-untracked` entry per delivered file, and the
inventory hash the refusal reported. Raw refusal:

```json
{
  "state": "blocked",
  "reason": "undeclared_untracked",
  "exit": "SDD runtime settlement requires an untracked ruling this request does not carry: this attempt left eligible untracked files its candidate does not include, so settling now would record them as no change at all: openspec/changes/disk-module/design.md, openspec/changes/disk-module/exploration.md, openspec/changes/disk-module/proposal.md, openspec/changes/disk-module/specs/disk-card/spec.md, openspec/changes/disk-module/specs/disk-metrics/spec.md, openspec/changes/disk-module/state.yaml, openspec/changes/disk-module/tasks.md, system-monitor/Domain/Models/DiskSnapshot.swift, system-monitor/Domain/Models/DiskThroughputCounters.swift, system-monitor/Domain/Models/VolumeCapacity.swift and 9 more; rerun `gentle-ai sdd-attempt finish` or `gentle-ai sdd-attempt settle` with --untracked-scope=select --intended-untracked=<repo-relative-path> --expected-untracked-inventory=sha256:6fbf7eb2424bab5130514979777d95d4e64ebb6a8f4f2f2b0ea00addd5138aaa to account them, or --untracked-scope=exclude --expected-untracked-inventory=sha256:6fbf7eb2424bab5130514979777d95d4e64ebb6a8f4f2f2b0ea00addd5138aaa to leave them out on the record"
}
```

The second rerun was refused again for a stale inventory hash (`sha256:6fbf7eb…` had been computed before
this file existed) and was rerun once more with the hash that refusal reported,
`sha256:8adb03a2a2e5b990ca2767f058b69387be4ed46353e656b556c329f15c33b5b2`. That third call **recorded the
attempt** — `gentle-ai sdd-attempt status` now shows attempt ordinal 1 with `"outcome": "passed"` and this
batch's `evidence_revision` — but returned `blocked` because the recorded 1202 changed lines exceed the
`--max-changed-lines 900` the acquire set:

```json
{
  "state": "blocked",
  "reason": "maintainer_decision",
  "exit": "this work unit's attempt or changed-line budget needs a maintainer decision; run `gentle-ai sdd-attempt status --cwd <repo> --change <change>` for the accounting, then have a maintainer reset the objective with `gentle-ai sdd-attempt reset --cwd <repo> --change <change> --expected-revision <the revision that status prints> --request-id \"<unique-request-id>\" --reason \"<why-the-objective-is-being-reset>\" --actor \"<actor>\"`; turning receipt-driven review off does not clear this, because review governs delivery of a finished change, not whether a work unit may open; a base merged into the branch during the attempt is charged to the attempt: merge before begin or after finish, or have a maintainer reset"
}
```

Accounting from `gentle-ai sdd-attempt status --cwd . --change disk-module`:

```json
{
  "revision": "sha256:aed936fa032094de9c121f145e076043d359bbb5940566910938a89be8d02ee7",
  "objective": {
    "generation": 1,
    "work_unit": "batch-a-domain-foundation",
    "max_attempts": 2,
    "max_changed_lines": 900,
    "max_changed_lines_source": "explicit"
  },
  "attempts": [
    {
      "ordinal": 1,
      "outcome": "passed",
      "changed_lines": 1202,
      "evidence_revision": "sha256:90a8dec2d3346f99906c1c10d2a90a2b1a5d7541f9d9682be1506a82cef74c98",
      "harness_disposition": "reused",
      "changed_line_budget_exceeded": true
    }
  ],
  "cumulative_attempts": 1,
  "cumulative_changed_lines": 1202,
  "decision_required": true,
  "complete": false,
  "next_action": "reset"
}
```

**Maintainer decision owed before batch B opens.** The 1202 counted lines are the 909 authored source and
test lines plus this progress artifact and `tasks.md`, both of which are untracked and therefore counted
whole. Nothing here is compressible: the batch delivers twelve files the design specifies and 36 tests the
spec scenarios demand, and the accepted `size:exception` already covers the review side. The executor does
not reset the objective — a maintainer must run `gentle-ai sdd-attempt reset` with
`--expected-revision sha256:aed936fa032094de9c121f145e076043d359bbb5940566910938a89be8d02ee7`, or open
batch B under a larger `--max-changed-lines`. A realistic budget for a batch of this shape is 1400–1600
lines when the untracked planning artifacts are counted, or the acquire should pass
`--untracked-scope=select` listing only the code and test files.

### Tasks completed

- [x] 1.1 **RED** DM-2, DM-3 — `DiskSnapshotTests.swift` and `DiskFixtures.swift`
- [x] 1.2 **GREEN** DM-2, DM-3, DM-1 (shape) — `DiskThroughputCounters`, `VolumeCapacity`, `DiskSnapshot`, `DiskMetricsProvider`
- [x] 1.3 **RED** DM-4 — `DiskThroughputCalculatorTests.swift`
- [x] 1.4 **GREEN** DM-4 — `DiskThroughputCalculator.swift`
- [x] 1.5 **RED** DM-5 — `DiskCapacityCadenceTests.swift`
- [x] 1.6 **GREEN** DM-5 — `DiskCapacityCadence.swift`
- [x] 1.7 **RED→GREEN** DM-1 — `FakeDiskProvider.swift` and `DiskMetricsProviderPortTests.swift`

7/7 Phase 1 tasks complete. 7/28 tasks complete across the whole change.

### Files created

| File | Action | What it contains |
|---|---|---|
| `system-monitor/Domain/Models/DiskThroughputCounters.swift` | Created | `nonisolated struct … Sendable, Equatable` with `bytesRead`, `bytesWritten`, `driverCount`, `timestamp` |
| `system-monitor/Domain/Models/VolumeCapacity.swift` | Created | `total`/`free` in bytes |
| `system-monitor/Domain/Models/DiskSnapshot.swift` | Created | stored `total`, `free`, `used`, both optional rates, computed `fraction`; capacity initialiser in an extension |
| `system-monitor/Domain/Ports/DiskMetricsProvider.swift` | Created | two-method port, defined before any adapter |
| `system-monitor/Domain/Services/DiskThroughputCalculator.swift` | Created | nested `Rates` plus `rates(previous:current:) -> Rates?` |
| `system-monitor/Domain/Services/DiskCapacityCadence.swift` | Created | `minimumInterval` and `shouldRefresh(lastReadAt:now:minimum:)` |
| `system-monitorTests/Support/DiskFixtures.swift` | Created | one `base` instant, `instant(_:)`, `counters(...)`, `idle`, `referenceCapacity`, `referencePrevious`, `referenceCurrent`, `referenceSnapshot`, `climbing(steps:)` |
| `system-monitorTests/Support/FakeDiskProvider.swift` | Created | `Mutex<Script>` double with independent scripts, cursors and counters per kind |
| `system-monitorTests/Domain/DiskSnapshotTests.swift` | Created | 10 tests (DM-2, DM-3) |
| `system-monitorTests/Domain/DiskThroughputCalculatorTests.swift` | Created | 10 tests (DM-4) |
| `system-monitorTests/Domain/DiskCapacityCadenceTests.swift` | Created | 8 tests (DM-5) |
| `system-monitorTests/Domain/DiskMetricsProviderPortTests.swift` | Created | 8 tests (DM-1) |

Authored size: 909 lines across the twelve new files (single PR under the accepted `size:exception`).
`system-monitor.xcodeproj/project.pbxproj` was left untouched: xcodebuild re-sorted two `INFOPLIST_KEY_*`
lines during the runs and that noise was reverted with `git checkout --` (convention 6).

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 1.1 / 1.2 | `system-monitorTests/Domain/DiskSnapshotTests.swift` | Unit | N/A (new files only; full unit target green at 475 unique cases before the batch) | Ok Written | Ok 10/10 passed | Ok 10 cases | Ok Clean |
| 1.3 / 1.4 | `system-monitorTests/Domain/DiskThroughputCalculatorTests.swift` | Unit | N/A (new) | Ok Written | Ok 10/10 passed | Ok 10 cases | Ok Clean |
| 1.5 / 1.6 | `system-monitorTests/Domain/DiskCapacityCadenceTests.swift` | Unit | N/A (new) | Ok Written | Ok 8/8 passed | Ok 8 cases | Ok Clean |
| 1.7 | `system-monitorTests/Domain/DiskMetricsProviderPortTests.swift` | Unit | N/A (new) | Ok Written | Ok 8/8 passed | Ok 8 cases | Ok Clean |

Observed RED failures (each run with `-only-testing:system-monitorTests/<Suite>`):

1. Task 1.1 — `system-monitorTests/Support/DiskFixtures.swift:26:10: error: cannot find type 'DiskThroughputCounters' in scope`, plus `cannot find 'DiskSnapshot' in scope` and `cannot find 'VolumeCapacity' in scope` in `DiskSnapshotTests.swift`.
2. Task 1.3 — `system-monitorTests/Domain/DiskThroughputCalculatorTests.swift:18:13: error: cannot find 'DiskThroughputCalculator' in scope`.
3. Task 1.5 — `system-monitorTests/Domain/DiskCapacityCadenceTests.swift:15:13: error: cannot find 'DiskCapacityCadence' in scope`.
4. Task 1.7 — `system-monitorTests/Domain/DiskMetricsProviderPortTests.swift:17:10: error: cannot find type 'FakeDiskProvider' in scope`.

Observed GREEN results after each minimal implementation: the paired suite ran clean with no `error:`,
no `warning:` and no failing case — `DiskSnapshotTests` 10 passed, `DiskThroughputCalculatorTests`
10 passed, `DiskCapacityCadenceTests` 8 passed, `DiskMetricsProviderPortTests` 8 passed.

REFACTOR: no production restructuring was needed — each type came out at its final shape. The only
test-side cleanup was the shared `provider(throwThroughputOnCall:throwCapacityOnCall:)` factory in
`DiskMetricsProviderPortTests`, written that way from the start; the suites stayed green afterwards.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests` — **exit 0**, 475 unique passing test cases, **0 failures**, **0 compiler warnings**. The three log lines matching `failed` are test names (`aFailedSaveKeepsTheValueAndRecordsTheError`, `observersAreNotifiedEvenWhenTheSaveFailed`, `aFailedSaveAddsTheErrorFooterToTheForm`) that all passed. |
| Runtime harness command/scenario and exact result | N/A — this unit is pure values, pure rules and test doubles; it has no runtime boundary. The disk `.integration` harness arrives with batch C. |
| Rollback boundary | Delete `system-monitor/Domain/{Models/DiskThroughputCounters,Models/VolumeCapacity,Models/DiskSnapshot,Ports/DiskMetricsProvider,Services/DiskThroughputCalculator,Services/DiskCapacityCadence}.swift` and `system-monitorTests/{Support/DiskFixtures,Support/FakeDiskProvider,Domain/DiskSnapshotTests,Domain/DiskThroughputCalculatorTests,Domain/DiskCapacityCadenceTests,Domain/DiskMetricsProviderPortTests}.swift`. Nothing existing was modified, so the deletion restores the M4 baseline exactly. |

Final unit run of record: **exit 0**, 36 new disk test cases green, no pre-existing test disturbed.
Evidence revision `sha256:90a8dec2d3346f99906c1c10d2a90a2b1a5d7541f9d9682be1506a82cef74c98` is the
sha256 of that run's log.

### Deviations from design

1. **`DiskSnapshot`'s capacity initialiser is declared in an extension, not in the struct body.** The
   design writes `init(total:free:readBytesPerSecond:writeBytesPerSecond:)` inside the type; declaring it
   there suppresses the synthesised memberwise initialiser, and task 1.1 requires a *hand-built*
   `used > total` snapshot to pin the `fraction` clamp — which the capacity initialiser can never produce,
   because it computes `used` with a saturating subtraction. Moving the same initialiser, byte-for-byte in
   signature and behaviour, into an `extension DiskSnapshot` keeps the memberwise form available to tests.
   This also matches the design-gate note about not suppressing a memberwise initialiser that is used
   elsewhere. No caller signature changed.
2. Nothing else. Every other signature is the design's verbatim.

### Extra assertions beyond the task list (all spec-derived, none contradicting it)

- `DiskSnapshotTests` also pins that equal counters compare equal, that `driverCount` participates in
  equality, and that `VolumeCapacity`/`DiskSnapshot` compare by value (DM-1's `Equatable` requirement).
- `DiskThroughputCalculatorTests` also pins that unchanged counters are a **zero** rate, not a missing
  one, so an idle disk renders `0 B/s` rather than the em dash the Presentation batch reserves for
  unavailable rates.
- `DiskCapacityCadenceTests` also pins `minimumInterval == .seconds(10)` and that a backwards `now` does
  not force a refresh.

### Issues found

None. `Duration.components` gives exact fractional seconds for the 0.5 s window, so
`27_100_000 / 0.5 == 54_200_000` compares exactly; no tolerance was needed on any rate assertion.

### What batch B must know

1. **Fake initialiser (exact):**
   `FakeDiskProvider(throughput: [DiskThroughputCounters], capacities: [VolumeCapacity], throwThroughputOnCall: Set<Int> = [], throwCapacityOnCall: Set<Int> = [])`.
   The defaulted helper argument the design prescribes therefore compiles as written:
   `diskProvider: FakeDiskProvider = FakeDiskProvider(throughput: [], capacities: [DiskFixtures.referenceCapacity])`.
2. **Fake surface:** `readThroughput()`, `readCapacity()`, `throughputCallCount`, `capacityCallCount`,
   `readOnMainThread` (one list, appended by **both** kinds in call order — a test asserting "all false"
   over N throughput reads plus M capacity reads sees N+M entries), and `FakeDiskProvider.ScriptedError`.
   Throw indexes are zero-based and per kind; a throwing call advances that kind's count and leaves its
   cursor untouched; an exhausted script repeats its last value; an empty throughput script reads
   `DiskFixtures.idle` (`driverCount == 0`, so rates stay `nil`), an empty capacity script reads
   `DiskFixtures.referenceCapacity`.
3. **Fixture names (exact):** `DiskFixtures.base`, `.instant(_ seconds: Double)`,
   `.counters(read:written:driverCount:at:)` (`driverCount` defaults to 1, `at` is seconds after `base`),
   `.idle`, `.referenceCapacity` (494_354_000_000 / 62_286_000_000), `.referencePrevious` (at 0 s),
   `.referenceCurrent` (at 1 s), `.referenceSnapshot`, `.climbing(steps:)` (defaults to 400 counters, 1 s
   apart, growing by 27_100_000 / 2_200_000 per step, first stamp at 0 s).
4. **`DiskSnapshot` has two initialisers.** Use the four-argument capacity form
   `DiskSnapshot(total:free:readBytesPerSecond:writeBytesPerSecond:)` in production code; the memberwise
   five-argument form exists only so tests can build inconsistent values.
5. **`DiskThroughputCalculator.rates(previous:current:)` returns `Rates?`** with
   `readBytesPerSecond`/`writeBytesPerSecond`; it returns `nil` for a `nil` baseline, `driverCount == 0`,
   a non-positive window, or either counter falling. It never reads a clock.
6. **`DiskCapacityCadence.shouldRefresh(lastReadAt:now:minimum:)`** defaults `minimum` to
   `DiskCapacityCadence.minimumInterval` (10 s) and is inclusive at the boundary.
7. `DiskSamplingStep` (batch B) must still declare **no** custom initialiser, per tasks 2.4: build it as
   `DiskSamplingStep(provider: diskProvider, previous: nil, capacity: nil, capacityReadAt: nil)`.
8. Expect xcodebuild to re-sort the two `INFOPLIST_KEY_*` lines in `project.pbxproj` on some runs; revert
   that noise before finishing (convention 6).

### Workload / PR boundary

- Mode: single PR with `size:exception` explicitly accepted by the user (unlimited review budget).
- Current work unit: A (Phase 1, Domain foundation).
- Boundary: starts from the M4 baseline, ends with the Domain values, port, pure rules, fake and fixtures
  green under the unit command. Nothing is wired into the sampler yet, so the app behaviour is unchanged.
- Review budget impact: 909 authored lines, all additive and all covered by 36 new tests.

### Remaining tasks

Phases 2–7 (batches B–G): 2.1 – 2.8, 3.1 – 3.4, 4.1 – 4.10, 5.1, 6.1, 7.1 – 7.6.

## Batch B — Phase 2 Application

Date: 2026-09-09. Work unit: `batch-b-application` (tasks 2.1 – 2.8, requirements DM-6 – DM-11).
Scope: `system-monitor/Application/{MetricsState,MetricsSampler}.swift`, the four test helpers, the two
Application test files — plus two documented compile-driven edits outside that list (see Deviations).

### Native runtime ledger

The maintainer reset the objective after batch A (generation 2, `--max-changed-lines 1600`), so the
acquire below returned `proceed` on the first call and no untracked ruling was demanded at settle.

Acquire (`request-id disk-module-batch-b-actor-20260909`, `--max-attempts 2 --max-changed-lines 1600`,
`--untracked-scope=exclude`, `--expected-untracked-inventory=sha256:8adb03a2…`):

```json
{
  "state": "proceed",
  "token": "sha256:8cd7f7ec86d212dbf61e3a55d3129e2a587d8f597cf1ab95085f3c239f19fa16"
}
```

Settle (`request-id disk-module-batch-b-settle-20260909`, `--outcome passed`,
`--evidence-revision sha256:0ce09089b8dfa693804ba8bb791b372407890c96c474ebffdda4abc626a6bbd2`,
`--harness-disposition reused`). The first call was refused for a missing `--token`
(`Error: sdd-attempt settle requires --token; rerun ... with those missing flags`) and was rerun once
with the acquire's token:

```json
{
  "state": "complete",
  "exit": "this change's runtime objective (batch-b-application) is complete; to continue with the next ordered work unit, run `gentle-ai sdd-attempt acquire --cwd <repo> --change <change> --request-id \"<unique-request-id>\" --work-unit \"<a different label>\" --evidence-goal \"<stable-goal>\" --max-attempts <count> --max-changed-lines <count>`; rescope applies only to an objective that is not complete, and reset discards this scope instead of succeeding it"
}
```

Accounting from `gentle-ai sdd-attempt status --cwd . --change disk-module`: ordinal 2,
`objective_generation: 2`, `outcome: passed`, `changed_lines: 767`, `cumulative_changed_lines: 767`,
`decision_required: false`, `complete: true`, `next_action: complete`. **No maintainer decision is owed
before batch C**; batch C opens with a fresh `acquire` under a new `--work-unit` label.

### Tasks completed

- [x] 2.1 **RED** DM-11 — six disk cases added to `MetricsStateTests.swift`
- [x] 2.2 **GREEN** DM-11 — `MetricsState.disk` and `apply(disk:)`
- [x] 2.3 **RED** DM-6, DM-7 + the compile trap — six cases plus the defaulted fake in all four helpers
- [x] 2.4 **GREEN** DM-6, DM-7 — `DiskSamplingStep`, required `diskProvider:`, `inlineDiskStep`, `sampleOnce()`
- [x] 2.5 **RED** DM-10 — eight failure-isolation cases
- [x] 2.6 **GREEN** DM-10 — `withoutThroughput()` completes `advanced()`
- [x] 2.7 **RED** DM-8, DM-9 — two restart cases plus the disk half of `everyReadHappensOffTheMainThread`
- [x] 2.8 **GREEN** DM-8, DM-9 — disk read inside the detached `.utility` loop

8/8 Phase 2 tasks complete. 15/28 tasks complete across the whole change.

### Files changed

| File | Action | What was done |
|---|---|---|
| `system-monitor/Application/MetricsState.swift` | Modified | `private(set) var disk: DiskSnapshot?` and `apply(disk:)`, both doc-commented with why there is no `MetricHistory` (R10.8) |
| `system-monitor/Application/MetricsSampler.swift` | Modified | `nonisolated struct DiskSamplingStep` (`advanced()`, `withoutThroughput()`, `snapshot(capacity:rates:)`), required `diskProvider:` init parameter, `inlineDiskStep`, disk read in both the loop and `sampleOnce()`, refreshed doc comments |
| `system-monitor/App/AppDelegate.swift` | Modified | `private struct UnwiredDiskProvider` placeholder passed to the sampler (deviation 1) |
| `system-monitor/Domain/Models/DiskSnapshot.swift` | Modified | one word: the extension's capacity initialiser is now `nonisolated` (deviation 2) |
| `system-monitorTests/Application/MetricsStateTests.swift` | Modified | `// MARK: - Disk`: 6 cases (DM-11) |
| `system-monitorTests/Application/MetricsSamplerTests.swift` | Modified | defaulted `diskProvider:` in both `makeSampler` helpers; 6 step cases (DM-6, DM-7), 8 failure cases (DM-10), 2 loop cases (DM-8), disk half of `everyReadHappensOffTheMainThread` (DM-9) |
| `system-monitorTests/Application/SamplingCadenceTests.swift` | Modified | inline defaulted fake at the `MetricsSampler(` call site |
| `system-monitorTests/Application/SettingsStateTests.swift` | Modified | inline defaulted fake at the `MetricsSampler(` call site |

Authored size: **767 changed lines** (+755/−12 across the seven tracked files, plus one word in the
untracked `DiskSnapshot.swift`), inside the accepted `size:exception` single PR.
`system-monitor.xcodeproj/project.pbxproj` was untouched and, unlike batch A, no run re-sorted its
`INFOPLIST_KEY_*` lines (`git status` clean for that path).

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 2.1 / 2.2 | `system-monitorTests/Application/MetricsStateTests.swift` | Unit | Ok 39/39 (`MetricsStateTests` + both sampler suites) | Ok Written | Ok 18/18 passed | Ok 6 cases | Ok Clean |
| 2.3 / 2.4 | `system-monitorTests/Application/MetricsSamplerTests.swift` (`MetricsSamplerStepTests`) | Unit | Ok covered by the same 39/39 | Ok Written | Ok 21/21 passed | Ok 6 cases | Ok Clean |
| 2.5 / 2.6 | `system-monitorTests/Application/MetricsSamplerTests.swift` (`MetricsSamplerStepTests`) | Unit | Ok 21/21 from the previous GREEN | Ok Written | Ok 29/29 passed | Ok 8 cases | Ok `snapshot(capacity:rates:)` extracted, suites re-run green |
| 2.7 / 2.8 | `system-monitorTests/Application/MetricsSamplerTests.swift` (`MetricsSamplerLoopTests`) | Unit | Ok 12/12 loop cases before the edit | Ok Written | Ok 14/14 passed | Ok 3 cases | Ok Clean |

Observed RED failures:

1. Task 2.1 — compile-level, as batch A's REDs were:
   `MetricsStateTests.swift:183:29: error: value of type 'MetricsState' has no member 'disk'` plus
   `:192:21: error: no exact matches in call to instance method 'apply'` (11 errors in total).
2. Task 2.3 — the known trap fired exactly as tasks.md predicted:
   `SamplingCadenceTests.swift:102:27: error: extra argument 'diskProvider' in call`. The compiler stops
   at the first of the four sites, so all four had to carry the defaulted fake in this one step.
3. Task 2.5 — **behavioural** RED, not a broken target: 26 unique cases passed and 3 failed —
   `aThroughputThrowReplacesPublishedRatesWithNil()`,
   `aThroughputThrowWithNothingCachedReadsCapacityExactlyOnce()` and
   `theStepFromAThrowingFirstTickCachesCapacityWithoutAStamp()`. The five DM-10 scenarios the minimal
   2.4 implementation already satisfied stayed green throughout, which is what made the three failures
   meaningful.
4. Task 2.7 — **behavioural** RED: 11 passed, 3 failed — `aRestartCostsOneThroughputUnavailableDiskTick()`,
   `applyingTheIntervalAlreadyInEffectKeepsTheDiskBaseline()` and `everyReadHappensOffTheMainThread()`
   (the loop published no disk snapshot at all until 2.8).

Observed GREEN results: `MetricsStateTests` 18/18, `MetricsSamplerStepTests` 21/21 then 29/29,
`MetricsSamplerLoopTests` 14/14 — every run exit 0 with no `error:` and no `warning:`.

REFACTOR: `advanced()` and `withoutThroughput()` built a `DiskSnapshot` each; the construction was
extracted into one `snapshot(capacity:rates:)` helper taking the optional rate pair. The three affected
suites were re-run immediately afterwards: 61 unique cases, 0 failures.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests` — **exit 0**, **497 unique passing test cases**, **0 failures**, **0 `error:` lines**, **0 `warning:` lines**. That is batch A's 475 plus this batch's 22 new cases (6 + 6 + 8 + 2). |
| Runtime harness command/scenario and exact result | N/A — this unit is main-actor state plus a pure sampling step over fakes and `ManualClock`; the app's real disk provider does not exist until batch C, so there is no runtime boundary to exercise. `UnwiredDiskProvider` deliberately keeps the running app's behaviour identical to M4. |
| Rollback boundary | `git checkout -- system-monitor/Application/{MetricsState,MetricsSampler}.swift system-monitor/App/AppDelegate.swift system-monitorTests/Application/{MetricsStateTests,MetricsSamplerTests,SamplingCadenceTests,SettingsStateTests}.swift` and revert the one `nonisolated` word in `system-monitor/Domain/Models/DiskSnapshot.swift`. That restores the batch A state exactly; no batch A file is otherwise touched. |

Evidence revision `sha256:0ce09089b8dfa693804ba8bb791b372407890c96c474ebffdda4abc626a6bbd2` is the
sha256 of that final run's log.

### Deviations from design and from the batch scope

1. **`system-monitor/App/AppDelegate.swift` was modified, which batch B's scope guard excludes.** Making
   `diskProvider:` required (design decision 5, tasks 2.4) breaks the composition root the moment the
   parameter exists — `AppDelegate.swift:42:49: error: missing argument for parameter 'diskProvider'` —
   and the unit target cannot build while the app target does not compile. The plan defers the real
   `IOKitDiskProvider` to phase 5, so the minimal way through was a private `UnwiredDiskProvider` null
   object in the composition root whose two reads throw. The sampler treats that as a degraded tick, so
   nothing is published for disk and the running app behaves exactly as it did at M4. It is documented
   in place and is deleted by task 5.1. The rejected alternatives were a defaulted `diskProvider:` (no
   production implementation exists to default to) and an optional `diskProvider` with a nil branch,
   which design decision 13 rules out ("No production code gains a branch").
2. **`system-monitor/Domain/Models/DiskSnapshot.swift` gained one `nonisolated` keyword.** Batch A's
   capacity initialiser lives in an `extension DiskSnapshot`, and an extension does not inherit the
   type's isolation under this project's default-MainActor setting, so the first build of
   `DiskSamplingStep` failed with `MetricsSampler.swift:100:13: error: call to main actor-isolated
   initializer 'init(total:free:readBytesPerSecond:writeBytesPerSecond:)' in a synchronous nonisolated
   context`. Batch A's suites never caught it because they only call the initialiser from static `let`
   fixtures. Marking the initialiser `nonisolated` (convention 1) is the whole fix; no signature changed.
3. **`DiskSamplingStep` declares no custom `init(provider:)`**, following tasks 2.4 rather than the
   design interface block, which sketches one. A custom initialiser would suppress the memberwise form
   the loop, `sampleOnce()` and the step-level tests all use. This is the same call the batch A design
   gate made for `DiskSnapshot`.
4. Nothing else. The `advanced()` algorithm, the cadence stamped with the throughput instant, decision 2's
   one-off capacity read and the loop/`sampleOnce()` bodies follow `design.md` step for step.

### Extra assertions beyond the task list (all spec-derived, none contradicting it)

- `MetricsStateTests` pins the absence of a disk history by reflection, and proves the mirror is populated
  by asserting the `cpuHistory` and `memoryHistory` labels in the same test, so the negative assertion
  cannot pass vacuously.
- `MetricsSamplerStepTests` adds two value-level cases on `DiskSamplingStep` itself
  (`theDiskStepCarriesTheBaselineAndTheCapacityStampForward`,
  `theStepFromAThrowingFirstTickCachesCapacityWithoutAStamp`), mirroring the existing
  `stepAdvancesToTheNextPreviousSampleOnSuccess` precedent for CPU.
- `aThroughputThrowReplacesPublishedRatesWithNil` triangulates DM-10's first scenario: the spec's own
  wording (throw on call 1 after a successful tick 0) is satisfied even by an implementation that
  publishes nothing, because the tick-0 snapshot already had nil rates. Throwing on call 2, after rates
  were really published, is what forces the cached capacity to be republished with nil rates.
- `aThroughputThrowSkipsThatTicksCapacityRefresh` also asserts the refreshed capacity actually reaches
  the state on the recovering tick, not just that the call count moved.

### Issues found

1. The batch A isolation defect in deviation 2 — worth remembering for batches C–E: **any `extension` on
   a `nonisolated` Domain type needs its own `nonisolated`** under this project's default-MainActor
   isolation, and a fixture-only test will not catch the omission.
2. `gentle-ai sdd-attempt settle` requires `--token` even though the batch B prompt's settle recipe did
   not list it; the acquire token is the value it wants.

### What batch C must know

1. **`MetricsSampler` now takes `diskProvider: any DiskMetricsProvider` as a required parameter**, third
   in the initialiser, between `memoryProvider:` and `topologyProvider:`. Every construction site is
   already updated: `AppDelegate.swift` (with the placeholder), both `makeSampler` helpers in
   `MetricsSamplerTests.swift` and the inline sites in `SamplingCadenceTests.swift` and
   `SettingsStateTests.swift`.
2. **`UnwiredDiskProvider` in `system-monitor/App/AppDelegate.swift` must be deleted by task 5.1** and
   replaced with `IOKitDiskProvider(capacity: VolumeCapacityReader())`. Until then the shipped app
   publishes no disk snapshot, so any manual check of the card before batch F will show the em-dash
   skeleton — that is expected, not a defect.
3. **`DiskSamplingStep` lives in `MetricsSampler.swift`** (Application, not Domain) with the memberwise
   initialiser only: `DiskSamplingStep(provider:previous:capacity:capacityReadAt:)`. `advanced()` returns
   `(snapshot: DiskSnapshot?, next: DiskSamplingStep)`.
4. **The cadence is stamped with the throughput instant.** No clock is read inside the step, so any new
   scenario is scripted purely through `DiskFixtures.counters(..., at:)` stamps. The instants come from
   `DiskFixtures.base`, never from the `ManualClock` the loop sleeps on — the two are independent.
5. **`FakeDiskProvider.readOnMainThread` is one shared list** appended by both read kinds in call order.
   Two loop iterations produce three entries (2 throughput + 1 capacity), which is what
   `everyReadHappensOffTheMainThread` now asserts exactly.
6. Presentation (batch D/E) should read `MetricsState.disk` (`DiskSnapshot?`); there is no disk history
   and `PanelView` still renders two cards until task 4.10.
7. The unit target now stands at **497 unique passing cases**; task 7.1's "527 pre-existing tests" figure
   counts the `.integration` suites the `FULL` command adds.

### Workload / PR boundary

- Mode: single PR with `size:exception` explicitly accepted by the user (unlimited review budget).
- Current work unit: B (Phase 2, Application).
- Boundary: starts from batch A's Domain foundation, ends with the sampler reading disk in the same
  iteration as CPU and memory, publishing through `MetricsState.disk`, isolating every disk failure and
  restarting cleanly on an interval change. No user-visible change yet: no card renders disk, and the
  composition root's placeholder keeps the shipped app on its M4 behaviour.
- Review budget impact: 767 changed lines, 462 of them new test code.

### Remaining tasks

Phases 3–7 (batches C–G): 3.1 – 3.4, 4.1 – 4.10, 5.1, 6.1, 7.1 – 7.6.

## Batch C — Phase 3 Infrastructure

Date: 2026-09-09. Work unit: `batch-c-infrastructure` (tasks 3.1 – 3.4, requirements DM-12, DM-13).
Scope guard honoured exactly: two new files under `system-monitor/Infrastructure/` and three new files
under `system-monitorTests/Infrastructure/`. No Domain, Application, Presentation, App, entitlements or
`PRD.md` change; `AppDelegate.swift`'s `UnwiredDiskProvider` placeholder was left untouched for task 5.1.

### Native runtime ledger

Acquire (`request-id disk-module-batch-c-actor-20260909`, `--work-unit batch-c-infrastructure`,
`--max-attempts 2 --max-changed-lines 1600`, `--untracked-scope=exclude`,
`--expected-untracked-inventory=sha256:8adb03a2…`) returned `proceed` on the first call:

```json
{
  "state": "proceed",
  "token": "sha256:ce317b78b19a4deedb480a3e097e40bb7a393417035b00f6af3ea76a4a85117a"
}
```

Settle (`request-id disk-module-batch-c-settle-20260909`, `--outcome passed`,
`--evidence-revision sha256:76704bb4b88deee8e305b867e701214aa354d6929813280881181934cc6cab62`,
`--harness-disposition reused`). As in batch A, the first call was refused for a missing untracked
ruling — batch A's and batch B's disk files are still untracked, so every settle must account for them:

```json
{
  "state": "blocked",
  "reason": "undeclared_untracked",
  "exit": "SDD runtime settlement requires an untracked ruling this request does not carry: this attempt left eligible untracked files its candidate does not include, so settling now would record them as no change at all: openspec/changes/disk-module/apply-progress.md, openspec/changes/disk-module/design.md, openspec/changes/disk-module/exploration.md, openspec/changes/disk-module/proposal.md, openspec/changes/disk-module/specs/disk-card/spec.md, openspec/changes/disk-module/specs/disk-metrics/spec.md, openspec/changes/disk-module/state.yaml, openspec/changes/disk-module/tasks.md, system-monitor/Domain/Models/DiskSnapshot.swift, system-monitor/Domain/Models/DiskThroughputCounters.swift and 15 more; rerun `gentle-ai sdd-attempt finish` or `gentle-ai sdd-attempt settle` with --untracked-scope=select --intended-untracked=<repo-relative-path> --expected-untracked-inventory=sha256:09170250d4f9504f012f5eed929716ca7f9c0a870092c07f8a710ecf48782cd2 to account them, or --untracked-scope=exclude --expected-untracked-inventory=sha256:09170250d4f9504f012f5eed929716ca7f9c0a870092c07f8a710ecf48782cd2 to leave them out on the record"
}
```

It was rerun once with `--untracked-scope=select`, the inventory hash that refusal reported, and one
`--intended-untracked` entry for each of the seventeen untracked files under `system-monitor/**` and
`system-monitorTests/**` (no `openspec/**` entry was needed; the ledger accepted the request without
them):

```json
{
  "state": "complete",
  "exit": "this change's runtime objective (batch-c-infrastructure) is complete; to continue with the next ordered work unit, run `gentle-ai sdd-attempt acquire --cwd <repo> --change <change> --request-id \"<unique-request-id>\" --work-unit \"<a different label>\" --evidence-goal \"<stable-goal>\" --max-attempts <count> --max-changed-lines <count>`; rescope applies only to an objective that is not complete, and reset discards this scope instead of succeeding it"
}
```

Accounting from `gentle-ai sdd-attempt status --cwd . --change disk-module`: ordinal 3,
`objective_generation: 3`, `outcome: passed`, `changed_lines: 1392` (the 480 authored lines of this batch
plus the batches A/B untracked files counted whole by the `select` ruling), `cumulative_changed_lines:
1392` against the 1600 budget, `decision_required: false`, `complete: true`, `next_action: complete`.
**No maintainer decision is owed before batch D**; batch D opens with a fresh `acquire` under a new
`--work-unit` label. Note for batch D: the `select` ruling recounts every still-untracked disk file, so
a 1600-line budget leaves roughly 200 lines of headroom — batch D should acquire with a larger
`--max-changed-lines` (2200 or more) or the same refusal will fire at settle.

### Tasks completed

- [x] 3.1 **RED** DM-13 (pure seam) — `VolumeCapacityReaderTests.swift`
- [x] 3.2 **GREEN** DM-13 — `VolumeCapacityReader.swift`
- [x] 3.3 **RED→GREEN** DM-12 — `IOKitDiskIntegrationTests.swift` and `IOKitDiskProvider.swift`
- [x] 3.4 **RED→GREEN** DM-13 (real read) — `VolumeCapacityIntegrationTests.swift` and the
  `readCapacity()` delegation plus `DiskMetricsProvider` conformance on `IOKitDiskProvider`

4/4 Phase 3 tasks complete. 19/28 tasks complete across the whole change.

### Files created

| File | Action | What it contains |
|---|---|---|
| `system-monitor/Infrastructure/System/VolumeCapacityReader.swift` | Created | `nonisolated struct … Sendable` over `URL(fileURLWithPath: "/")`, nested `nonisolated enum ReadError { resourceValues(domain:code:), missingKey, negativeValue }`, the pure `static capacity(total:free:) throws(ReadError)` seam and `read()` |
| `system-monitor/Infrastructure/IOKit/IOKitDiskProvider.swift` | Created | `nonisolated struct … DiskMetricsProvider`, nested `nonisolated enum ReadError { matchingUnavailable, ioKitCall(kern_return_t) }`, the `IOBlockStorageDriver` iteration with saturating sums, `readCapacity()` delegating to the composed reader |
| `system-monitorTests/Infrastructure/VolumeCapacityReaderTests.swift` | Created | 9 plain unit cases on the conversion seam (no `.integration` tag, no file-system access) |
| `system-monitorTests/Infrastructure/IOKitDiskIntegrationTests.swift` | Created | 6 `.integration` cases (DM-12 shape, monotonicity, 50 reads) |
| `system-monitorTests/Infrastructure/VolumeCapacityIntegrationTests.swift` | Created | 7 `.integration` cases (DM-13 real read, provider delegation, unchanged rethrow, port conformance) |

Authored size: 480 lines across the five new files (single PR under the accepted `size:exception`).
`system-monitor.xcodeproj/project.pbxproj` was left untouched: xcodebuild re-sorted the two
`INFOPLIST_KEY_NSHumanReadableCopyright` lines again and that noise was reverted with
`git checkout --` before reporting (convention 6); `git status` is clean for that path.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 3.1 / 3.2 | `system-monitorTests/Infrastructure/VolumeCapacityReaderTests.swift` | Unit | N/A (new files only; unit target green at 497 unique cases before the batch) | Ok Written | Ok 9/9 passed | Ok 9 cases | Ok Clean |
| 3.3 | `system-monitorTests/Infrastructure/IOKitDiskIntegrationTests.swift` | Integration (`.integration`, sandboxed host) | N/A (new) | Ok Written | Ok 6/6 passed | Ok 6 cases | Ok Clean |
| 3.4 | `system-monitorTests/Infrastructure/VolumeCapacityIntegrationTests.swift` | Integration (`.integration`, sandboxed host) | Ok 6/6 from 3.3 plus 9/9 from 3.2 | Ok Written | Ok 7/7 passed | Ok 7 cases | Ok Clean |

Observed RED failures (each run with `-only-testing:system-monitorTests/<Suite>`):

1. Task 3.1 — `VolumeCapacityReaderTests.swift:17:28: error: cannot find 'VolumeCapacityReader' in scope`
   (24 errors in total, including `cannot infer contextual base in reference to member
   'volumeTotalCapacityKey'` because the nested `ReadError` did not exist yet).
2. Task 3.3 — `IOKitDiskIntegrationTests.swift:18:28: error: cannot find 'IOKitDiskProvider' in scope`
   (6 occurrences).
3. Task 3.4 — three distinct production gaps in one compile:
   `VolumeCapacityIntegrationTests.swift:51:52: error: argument passed to call that takes no arguments`
   (no `capacity:` initialiser), `:61:49: error: value of type 'IOKitDiskProvider' has no member
   'readCapacity'`, and `:85:45: error: value of type 'IOKitDiskProvider' does not conform to specified
   type 'DiskMetricsProvider'`. Two test-side syntax errors in the same compile
   (`'try' cannot appear to the right of a non-assignment operator`) were fixed in the test file before
   the GREEN step; they were mine, not production behaviour.

Observed GREEN results after each minimal implementation: the paired suite ran clean with no `error:`,
no `warning:` and no failing case — `VolumeCapacityReaderTests` 9 passed, `IOKitDiskIntegrationTests`
6 passed, `VolumeCapacityIntegrationTests` 7 passed.

REFACTOR: no restructuring was needed. `IOKitDiskProvider` was written with its three helpers
(`statistics(of:)`, `counter(_:in:)`, `saturatingSum(_:_:)`) extracted from the start, so the iteration
body stays five lines; `VolumeCapacityReader` came out at its final shape.

### The DM-12 sandbox risk did not materialise

The batch was launched with an explicit instruction to stop and report `blocked` if App Sandbox filtered
the `IOBlockStorageDriver` `Statistics` dictionary so that `driverCount >= 1` could not hold. It holds:
`theSandboxedHostSeesAtLeastOneDriverWithBytesRead()` passes inside the sandboxed test host with
`driverCount >= 1` and `bytesRead > 0`, and `fiftyConsecutiveReadsAllSucceed()` confirms every one of 50
reads sees at least one driver. No entitlement was added and no assertion was weakened. That is the
evidence PRD 6.3 needs at task 6.1: `ENABLE_APP_SANDBOX = YES` (project.pbxproj:401,435) with
`BUNDLE_LOADER = "$(TEST_HOST)"` (project.pbxproj:463,484) means these suites run inside the sandboxed
app.

### Convention 18 resolved in favour of the SDK constants

Convention 18 requires private Swift literals with header citations *unless the first compile proves
`import IOKit.storage` exposes the constants*. It does. A standalone probe
(`xcrun swiftc` against the macOS SDK) compiled and printed all four —
`kIOBlockStorageDriverClass` → `IOBlockStorageDriver`, `kIOBlockStorageDriverStatisticsKey` →
`Statistics`, `kIOBlockStorageDriverStatisticsBytesReadKey` → `Bytes (Read)`,
`kIOBlockStorageDriverStatisticsBytesWrittenKey` → `Bytes (Write)` — and the project target then
compiled against them with zero warnings. The four `private static let`s therefore alias the SDK
constants and keep the header citations
(`IOKit/storage/IOBlockStorageDriver.h:41,54,68,82`, verified line-for-line against the SDK header) as
documentation. This removes any chance of a typo in a hand-written `"Bytes (Read)"` literal.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests` — **exit 0**, **519 unique passing test cases**, **0 failures**, **0 `error:` lines**, **0 `warning:` lines**. That is batch B's 497 plus this batch's 22 new cases (9 + 6 + 7). |
| Runtime harness command/scenario and exact result | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test` (FULL, `.integration` suites inside the sandboxed test host) — **exit 0**, **522 unique passing test cases**, **0 failures**, **0 `error:` lines**, **0 `warning:` lines**. The 3 cases beyond the unit target are the Xcode-template UI target (`testExample`, `testLaunchPerformance`, `testLaunch`). This run is the real IOKit/volume runtime boundary: 13 of the 22 new cases read live hardware. |
| Rollback boundary | Delete `system-monitor/Infrastructure/{IOKit/IOKitDiskProvider,System/VolumeCapacityReader}.swift` and `system-monitorTests/Infrastructure/{VolumeCapacityReaderTests,IOKitDiskIntegrationTests,VolumeCapacityIntegrationTests}.swift`. Nothing existing was modified, so the deletion restores the batch B state exactly. |

Evidence revision `sha256:76704bb4b88deee8e305b867e701214aa354d6929813280881181934cc6cab62` is the
sha256 of the final FULL run's log.

### One pre-existing failure, proven not to be this batch's

An intermediate FULL run exited 65 with a single failing case,
`system_monitorUITests.testLaunchPerformance()` — the Xcode-template launch-performance test in the UI
target, which this batch does not touch. It was proven pre-existing and environmental rather than caused
by batch C: all five batch C files were moved out of the tree, `project.pbxproj` was reverted, and
`-only-testing:system-monitorUITests/system_monitorUITests/testLaunchPerformance` still exited 65 on that
clean baseline. The files were restored and the final FULL run of record exited 0 with that same case
passing, so it is flaky (it measures real app launch time under `XCTApplicationLaunchMetric`), not a
regression. Batch D should expect it to fail intermittently and re-run rather than chase it.

### Deviations from design

1. **The four IOKit name constants alias the SDK's `kIOBlockStorageDriver*` macros instead of being
   hand-written string literals.** The design's interface block writes them as literals; convention 18
   explicitly permits the SDK constants once the compile proves they are exposed, which it did (see
   above). The citations are kept as comments and the resolved values are byte-identical.
2. **`IOKitDiskProvider` was built in two steps rather than one.** Task 3.3 created it with
   `readThroughput()` only and no port conformance, because no failing test justified `readCapacity()`
   yet; task 3.4's RED then demanded the `capacity:` initialiser, `readCapacity()` and the
   `DiskMetricsProvider` conformance together. The end state is exactly the design's interface block.
3. Nothing else. `VolumeCapacityReader`'s signatures, the `ReadError` vocabularies, the iteration shape,
   the `defer` releases, the consumed matching dictionary, the saturating sums, the `ContinuousClock.now`
   stamp after the sum and the `driverCount == 0` return are the design's verbatim.

### Extra assertions beyond the task list (all spec-derived, none contradicting it)

- `VolumeCapacityReaderTests` also pins that a full volume reporting `free == 0` is **accepted** (0 is not
  negative), that a missing key is reported before a negative value, and that a pair negative on both
  sides reports the total first — so the reported `URLResourceKey` is deterministic rather than
  incidental.
- `IOKitDiskIntegrationTests` also pins that `driverCount` is stable between two reads, that the stamp
  falls between the `ContinuousClock.now` instants surrounding the call (proving the adapter stamps on
  the same clock the Domain rule subtracts on), and that two live readings feed
  `DiskThroughputCalculator.rates` into a non-negative pair — the first end-to-end proof that the real
  adapter satisfies the Domain rule's preconditions.
- `VolumeCapacityIntegrationTests` also pins the total against the raw `.volumeTotalCapacityKey` value,
  that repeated reads agree on the total, that `IOKitDiskProvider()`'s default reader reaches the boot
  volume, that the reader's error is rethrown **unchanged** (a missing volume path yields
  `VolumeCapacityReader.ReadError.resourceValues(domain: NSCocoaErrorDomain, code:
  NSFileReadNoSuchFileError)` out of `readCapacity()`, not an IOKit error), and that the adapter is
  usable through `any DiskMetricsProvider`.

### Issues found

1. `#expect(delegated.total == try reader.read().total)` does not compile (`'try' cannot appear to the
   right of a non-assignment operator`) inside the `#expect` macro; hoist the throwing call into a `let`
   first. Worth remembering for every later suite that compares two real reads.
2. The FULL command includes the Xcode-template UI target, so it is 3 cases wider than the unit target
   and can fail for reasons unrelated to this change (see above). Task 7.1's "527 pre-existing tests"
   figure will not match the unique-case count; the honest numbers now are 519 unit / 522 full.

### What batch D must know

1. **`IOKitDiskProvider(capacity: VolumeCapacityReader())` compiles and conforms to
   `DiskMetricsProvider`.** Task 5.1 can replace `UnwiredDiskProvider` in `AppDelegate.swift` with it
   verbatim; `IOKitDiskProvider()` alone works too, because `capacity:` is defaulted.
2. **Live reference values on this machine** (useful when task 7.3 compares against Finder): the boot
   volume reads `total > 0` and `free > 0` with `free >= volumeAvailableCapacity`, and the block-storage
   sum reports `driverCount >= 1` with `bytesRead > 0` on every one of 50 consecutive reads.
3. **Nothing user-visible changed yet.** The composition root still holds batch B's `UnwiredDiskProvider`
   placeholder, so the running app publishes no disk snapshot until task 5.1. A manual check of the card
   before batch F will still show the em-dash skeleton — expected, not a defect.
4. **The unit target now stands at 519 unique passing cases; the FULL command at 522.** Batch D's
   Presentation suites should be measured against those two numbers.
5. **Ledger budget**: settle recounts every still-untracked disk file under `system-monitor/**` and
   `system-monitorTests/**`, so batch D's `acquire` needs `--max-changed-lines` well above 1600 (2200+),
   and its settle will again need `--untracked-scope=select` with one `--intended-untracked` per file
   plus the inventory hash the first refusal reports.
6. Expect the two `INFOPLIST_KEY_NSHumanReadableCopyright` lines in `project.pbxproj` to be re-sorted by
   some runs; revert with `git checkout --` before reporting (convention 6).

### Workload / PR boundary

- Mode: single PR with `size:exception` explicitly accepted by the user (unlimited review budget).
- Current work unit: C (Phase 3, Infrastructure).
- Boundary: starts from batch B's Application wiring, ends with both real adapters existing, proven
  against live hardware inside the sandboxed test host, and satisfying the Domain port. Nothing is
  injected into the composition root yet, so the shipped app behaviour is still exactly M4's.
- Review budget impact: 480 authored lines, 264 of them new test code.

### Remaining tasks

Phases 4–7 (batches D–G): 4.1 – 4.10, 5.1, 6.1, 7.1 – 7.6.

## Batch D — Phase 4 Presentation formatting (4.1–4.6)

Date: 2026-09-09. Work unit: `batch-d-presentation-formatting` (tasks 4.1 – 4.6, requirements DC-5,
DC-6 and the DC-9 token scenario).
Scope guard honoured: only `system-monitor/Presentation/{Theme/Palette,Formatting/ByteFormatter}.swift`
and their test files. No `DiskCard`, `DiskCardModel`, `ThroughputLabel`, `PanelView`, Domain,
Application, Infrastructure, App or `PRD.md` change. `AppDelegate.swift`'s temporary
`UnwiredDiskProvider` was left untouched for batch F.

### Native runtime ledger

Acquire (`request-id disk-module-batch-d-actor-20260909`, `--work-unit batch-d-presentation-formatting`,
`--max-attempts 2`, `--max-changed-lines 2400`, `--untracked-scope=exclude`,
`--expected-untracked-inventory=sha256:09170250…`, `--token sha256:1b4f7f27…`) — accepted first time,
the inventory hash the prompt carried was still current:

```json
{
  "state": "proceed",
  "token": "sha256:1b4f7f279bf76be805ce0bea0a31724e26118c65d72bb5e7cf0aa098fc72d076"
}
```

Settle (`request-id disk-module-batch-d-settle-20260909`, `--outcome passed`,
`--evidence-revision sha256:85edc2fde904fb8366983fe49dabedec23c69024e03e21f429a7e8075bd0b55d`,
`--harness-disposition reused`). As batches A and C predicted, the first attempt was refused for a
missing untracked ruling. Raw refusal:

```json
{
  "state": "blocked",
  "reason": "undeclared_untracked",
  "exit": "SDD runtime settlement requires an untracked ruling this request does not carry: this attempt left eligible untracked files its candidate does not include, so settling now would record them as no change at all: openspec/changes/disk-module/apply-progress.md, openspec/changes/disk-module/design.md, openspec/changes/disk-module/exploration.md, openspec/changes/disk-module/proposal.md, openspec/changes/disk-module/specs/disk-card/spec.md, openspec/changes/disk-module/specs/disk-metrics/spec.md, openspec/changes/disk-module/state.yaml, openspec/changes/disk-module/tasks.md, system-monitor/Domain/Models/DiskSnapshot.swift, system-monitor/Domain/Models/DiskThroughputCounters.swift and 16 more; rerun `gentle-ai sdd-attempt finish` or `gentle-ai sdd-attempt settle` with --untracked-scope=select --intended-untracked=<repo-relative-path> --expected-untracked-inventory=sha256:b4ae67ab7e5b10a1ffb301c21585d70a16cdd7be29f45a878aedbd3eb7f10ea6 to account them, or --untracked-scope=exclude --expected-untracked-inventory=sha256:b4ae67ab7e5b10a1ffb301c21585d70a16cdd7be29f45a878aedbd3eb7f10ea6 to leave them out on the record",
  "detail": "…identical to exit…"
}
```

Rerun once with `--untracked-scope=select`,
`--expected-untracked-inventory=sha256:b4ae67ab7e5b10a1ffb301c21585d70a16cdd7be29f45a878aedbd3eb7f10ea6`
and one `--intended-untracked` per still-untracked file under `system-monitor/**` and
`system-monitorTests/**` (18 paths, the 17 batches A–C left plus this batch's
`ThroughputFormatterTests.swift`; the 8 `openspec/**` entries stayed out, as batch C established). Raw
result:

```json
{
  "state": "complete",
  "exit": "this change's runtime objective (batch-d-presentation-formatting) is complete; to continue with the next ordered work unit, run `gentle-ai sdd-attempt acquire --cwd <repo> --change <change> --request-id \"<unique-request-id>\" --work-unit \"<a different label>\" --evidence-goal \"<stable-goal>\" --max-attempts <count> --max-changed-lines <count>`; rescope applies only to an objective that is not complete, and reset discards this scope instead of succeeding it",
  "detail": "…identical to exit…"
}
```

### Completed tasks

- [x] 4.1 **RED** DC-9 (token) — `PaletteTests` in `system-monitorTests/Presentation/StatusItemReadingsTests.swift`
- [x] 4.2 **GREEN** DC-9 — `Palette.diskAccent`
- [x] 4.3 **RED** DC-5 — capacity cases in `system-monitorTests/Presentation/ByteFormatterTests.swift`
- [x] 4.4 **GREEN** DC-5 — `ByteFormatter.capacity(_:locale:)`
- [x] 4.5 **RED** DC-6 — `system-monitorTests/Presentation/ThroughputFormatterTests.swift`
- [x] 4.6 **GREEN** DC-6 — `ByteFormatter.throughput(_:locale:)`

### Files changed

| File | Action | What was done |
|------|--------|---------------|
| `system-monitor/Presentation/Theme/Palette.swift` | Modify | `diskAccent = sRGB(0x3DD68C)` with the "two tokens, one colour" note in `memCached`'s style (+5 lines) |
| `system-monitor/Presentation/Formatting/ByteFormatter.swift` | Modify | `capacity(_:locale:)`, `throughput(_:locale:)` and its three private helpers; type doc comment widened beyond memory (+81 / −4) |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Modify | One `PaletteTests` case pinning the token value and its equality with `memFree` (+10) |
| `system-monitorTests/Presentation/ByteFormatterTests.swift` | Modify | Five capacity cases: en_US, de_DE, exact multiple, zero, clamping (+59) |
| `system-monitorTests/Presentation/ThroughputFormatterTests.swift` | Create | Seven cases covering DC-6 and design decision 3 (94 lines) |

### ICU strings pinned by probe, not assumed

Task 4.3 required the exact zero string to be pinned at the RED rather than guessed, and the RED cannot
run a formatter that does not exist yet. Following batch C's `xcrun swiftc` precedent, a standalone
probe outside the repository formatted the seven candidate values through the design's exact style
(`ByteCountFormatStyle(style: .decimal, allowedUnits: .all, spellsOutZero: false,
includesActualByteCount: false)` on `Int64(clamping:)`) and printed them with the whitespace made
visible:

| Bytes | `en_US` | `de_DE` |
|---|---|---|
| 432 068 000 000 | `432.07 GB` | `432,07<NBSP>GB` |
| 62 286 000 000 | `62.29 GB` | `62,29<NBSP>GB` |
| 494 354 000 000 | `494.35 GB` | `494,35<NBSP>GB` |
| 512 000 000 000 | `512 GB` | `512<NBSP>GB` |
| 0 | `0 bytes` | `0 Byte` |
| `Int64.max` / `UInt64.max` | `9,223.37 PB` (identical) | `9.223,37 PB` (identical) |

Every value the spec names matched. Two facts the spec left open are now pinned by the tests: zero reads
`"0 bytes"` under `en_US` and `"0 Byte"` under `de_DE` (both satisfy "starts with 0"), and the clamped
maximum reads `"9,223.37 PB"`. Note that `en_US` uses a plain space while `de_DE` uses U+00A0 — exactly
the hazard convention 7's normaliser exists for.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 4.1 / 4.2 | `system-monitorTests/Presentation/StatusItemReadingsTests.swift` (`PaletteTests`) | Unit | Ok 10/10 (`PaletteTests` + `ByteFormatterTests`, exit 0) | Ok Written | Ok 6/6 passed | Ok 2 assertions (hex value and `memFree` identity) | Ok Clean |
| 4.3 / 4.4 | `system-monitorTests/Presentation/ByteFormatterTests.swift` | Unit | Ok 10/10 (same baseline run) | Ok Written | Ok 10/10 passed | Ok 5 new cases, 11 values | Ok Clean |
| 4.5 / 4.6 | `system-monitorTests/Presentation/ThroughputFormatterTests.swift` | Unit | N/A (new file) | Ok Written | Ok 7/7 passed | Ok 7 cases, 18 values | Ok Clean |

Safety net: `-only-testing:system-monitorTests/PaletteTests -only-testing:system-monitorTests/ByteFormatterTests`
before any edit — exit 0, 10 unique passing cases, no `error:` and no `warning:` line. Both suites are
the ones this batch modifies.

Observed RED failures (each run with `-only-testing:system-monitorTests/<Suite>`, all exit 65):

1. Task 4.1 — `error: type 'Palette' has no member 'diskAccent'`.
2. Task 4.3 — `error: type 'ByteFormatter' has no member 'capacity'`, plus
   `error: cannot infer contextual base in reference to member 'max'` from `ByteFormatter.capacity(.max, …)`
   whose parameter type did not exist yet.
3. Task 4.5 — `error: type 'ByteFormatter' has no member 'throughput'`.

Observed GREEN results after each minimal implementation, every run exit 0 with no `error:`, no
`warning:` and no failing case: `PaletteTests` 6 passed (5 pre-existing + 1 new), `ByteFormatterTests`
10 passed (5 pre-existing + 5 new), `ThroughputFormatterTests` 7 passed.

REFACTOR: no restructuring was needed. `throughput(_:locale:)` was written with its three private
helpers (`throughputUnits`/`throughputStep` constants, `throughputFractionDigits(for:)` and
`rounded(_:fractionDigits:)`) extracted from the start, so the unit-selection loop has no magic numbers
and the display rounding rule exists in exactly one place. The deliberate non-refactor is recorded as
decision 2 below.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests/ThroughputFormatterTests` — **exit 0**, **7 unique passing cases**, 0 failures. |
| Full unit target (the command of record) | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests` — **exit 0**, **532 unique passing test cases**, **0 failures**, **0 `error:` lines**, **0 `warning:` lines**. That is batch C's 519 plus this batch's 13 new cases (1 + 5 + 7). |
| Runtime harness command/scenario and exact result | N/A for this batch — both formatters are pure functions over injected `Locale` values with no runtime boundary. The unit `#Preview` the work-unit table names belongs to `ThroughputLabel`, which batch E creates; there is no view to preview yet. The locale hazard that a preview would expose is covered instead by pinning both `en_US` and `de_DE` strings with the whitespace normaliser. |
| Rollback boundary | `git checkout -- system-monitor/Presentation/Theme/Palette.swift system-monitor/Presentation/Formatting/ByteFormatter.swift system-monitorTests/Presentation/ByteFormatterTests.swift system-monitorTests/Presentation/StatusItemReadingsTests.swift` and delete `system-monitorTests/Presentation/ThroughputFormatterTests.swift`. Nothing outside Presentation formatting was touched, so that restores the batch C state exactly. |

Evidence revision `sha256:85edc2fde904fb8366983fe49dabedec23c69024e03e21f429a7e8075bd0b55d` is the
sha256 of the final unit run's log.

Convention 6 noise: the two `INFOPLIST_KEY_NSHumanReadableCopyright` / `INFOPLIST_KEY_LSUIElement` lines
in `system-monitor.xcodeproj/project.pbxproj` were re-sorted again by the test runs and were reverted
with `git checkout --` before reporting. The working tree carries no `project.pbxproj` change.

### Deviations from design

1. **None in the interfaces.** `Palette.diskAccent`, `ByteFormatter.capacity(_:locale:)` and
   `ByteFormatter.throughput(_:locale:)` have the design's verbatim signatures, the documented
   `ByteCountFormatStyle` configuration and decision 3's exact vocabulary, stepping rule, fraction
   digits, separator and suffix.
2. **The design's wording "the largest unit whose scaled value rounded to one fraction digit stays below
   1000" is implemented as the *smallest* such unit**, which is what its own two examples require: for
   999 949 B/s the literal "largest" reading would select TB (`0.0 TB` is also below 1000), while the
   design pins `999.9 kB/s`. The implementation steps up from `B` while the value, rounded for display,
   is still `>= 1000`. Both design examples and both boundary tests pass. This is a wording fix, not a
   behavioural change, but it is recorded because a later reader of decision 3 will hit the same phrase.

### Decisions taken inside the batch

1. **Zero and non-finite rates go through the same formatting path**, not through a `"0 B/s"` literal:
   the input is clamped to 0 at unit `B`, so the string is produced by the same code as every other
   value. Under both locales that yields the `"0 B/s"` decision 3 demands, and there is no second place
   where the zero string could drift from the unit vocabulary.
2. **The whitespace normaliser stays a per-suite `private static func`, duplicated rather than shared.**
   Convention 7 asks for the normaliser "reused from `ByteFormatterTests`", and the project's own
   precedent for reuse is a private copy per suite: `ByteFormatterTests`, `MemoryCardModelTests` and
   `SettingsFormModelTests` each already carry the identical four-line function. Extracting a shared
   `system-monitorTests/Support` helper would have edited three suites outside this batch's scope guard
   for no behavioural gain, so `ThroughputFormatterTests` carries the same copy with a comment naming
   its source.
3. **`throughput` lives on `ByteFormatter`, but its tests live in `ThroughputFormatterTests.swift`.**
   That is what tasks 4.5/4.6 prescribe, and it keeps the batch's focused command
   (`RUN ThroughputFormatterTests`) meaningful; the suite display name is "Throughput formatting".

### Extra assertions beyond the task list (all spec-derived, none contradicting it)

- `ByteFormatterTests` pins the de_DE strings for all three reference capacities, not only for
  432 068 000 000, and pins the exact zero string under **both** locales (`"0 bytes"` / `"0 Byte"`) on
  top of the required `hasPrefix("0")`.
- `ThroughputFormatterTests` adds `1_000 → "1.0 kB/s"` (the first value above the byte range) and
  `999 → "999 B/s"` (the last value inside it), so the `B`→`kB` boundary is pinned from both sides, and
  extends the corrupt-input case to `+infinity` and `-infinity` alongside the required negative and NaN.
- The de_DE case also pins `1_000_000_000 → "1,0 GB/s"`, proving the comma reaches a value whose
  fraction digit is a forced trailing zero.

### Issues found

1. `ByteFormatter.capacity(.max, locale:)` in a RED test produces a second, misleading compile error
   (`cannot infer contextual base in reference to member 'max'`) alongside the real missing-member one,
   because the parameter type that would give `.max` its base does not exist yet. It disappears at the
   GREEN step; it is not a test defect.
2. `xcodebuild -quiet` prints a `Test case '<Suite>/<name>(…)' passed` line per repetition, so the honest
   figure is the count of **unique** names. A parameterized `@Test` contributes exactly one unique name
   regardless of how many argument tuples it runs, which is why this batch's 13 new unique cases cover
   29 pinned value/locale pairs.
3. **Engram truncates an observation at 50,000 characters.** With batch D appended, this artifact reached
   68,184 characters, so the hybrid mirror had to be split: observation 8276 (topic
   `sdd/disk-module/apply-progress`) holds batches A–C in full and batch D only up to the cut, and
   observation 8278 (topic `sdd/disk-module/apply-progress-batch-d`, whose title names the truncation)
   carries this batch D section verbatim. **This file is the authoritative artifact.** Batch E should
   write the file first and mirror only its own section to Engram rather than re-saving the combination.

### What batch E must know

1. **The exact formatter API batch E will call** (both `nonisolated static` on `nonisolated enum
   ByteFormatter`, `system-monitor/Presentation/Formatting/ByteFormatter.swift`):
   - `ByteFormatter.capacity(_ bytes: UInt64, locale: Locale = .current) -> String` — decimal, base 1000.
     `DiskCardModel.rows(for:locale:)` feeds it `snapshot.used`, `capacity.free` and `capacity.total`,
     which are already `UInt64`, so no conversion is needed.
   - `ByteFormatter.throughput(_ bytesPerSecond: Double, locale: Locale = .current) -> String` — takes a
     **non-optional `Double`**. `DiskThroughputCalculator.Rates` is optional as a pair, so
     `throughputReadings(for:locale:)` must unwrap first and substitute
     `DiskCardModel.unavailableText` ("\u{2014}") itself; do **not** pass a sentinel like `0` or `-1`
     into the formatter for the unavailable path, because it would render `"0 B/s"`, which DC-7 forbids.
   - `ByteFormatter.memory(_:locale:)` is unchanged and still base 1024; the disk card must never call
     it.
2. **`Palette.diskAccent` exists** and equals `Palette.memFree` (`#3DD68C`) by design. Any new token test
   must keep asserting values only — a pairwise-distinctness assertion over the palette will now fail on
   two independent pairs (`memCached`/`cpuAccent` and `diskAccent`/`memFree`).
3. **Reference strings batch E can assert without re-deriving them**: rows read `Used 432.07 GB`,
   `Free 62.29 GB`, `Total 494.35 GB` under `en_US` and `432,07 GB` / `62,29 GB` / `494,35 GB` under
   `de_DE`; the footer reads `27.1 MB/s` and `2.2 MB/s` under `en_US`, `27,1 MB/s` under `de_DE`. The
   de_DE capacity strings contain U+00A0 before the unit, so every comparison needs the normaliser; the
   throughput strings use a plain space in both locales.
4. **The unit target now stands at 532 unique passing cases** (the FULL command should therefore report
   535, batch C's 522 plus these 13). Batch E's suites should be measured against those numbers.
5. **Ledger budget**: the settle ruling now recounts 18 untracked files under `system-monitor/**` and
   `system-monitorTests/**` (batch D added `ThroughputFormatterTests.swift`). Batch E adds at least two
   more source files and one more test file, so its `acquire` should stay at `--max-changed-lines 2400`
   or higher, and its settle will again need `--untracked-scope=select` with one `--intended-untracked`
   per file plus the inventory hash the first refusal reports.
6. **Expect the `project.pbxproj` re-sort noise** on some runs and revert it with `git checkout --`
   before reporting (convention 6). It happened again in this batch.
7. **`AppDelegate.swift` still holds `UnwiredDiskProvider`**, so the running app publishes no disk
   snapshot until batch F. A manual check of the card after batch E will show the em-dash skeleton —
   expected, not a defect.

### Workload / PR boundary

- Mode: single PR with `size:exception` explicitly accepted by the user (unlimited review budget).
- Current work unit: D (Phase 4, tasks 4.1 – 4.6, Presentation formatting).
- Boundary: starts from batch C's Infrastructure adapters, ends with every string the disk card will
  render being derivable and pinned under both locales. Still no user-visible change: no view consumes
  the new token or the two new formatter functions until batch E.
- Review budget impact: 253 changed lines (249 added, 4 removed), 163 of them new test code.

### Remaining tasks

Phase 4 tail and phases 5–7 (batches E–G): 4.7 – 4.10, 5.1, 6.1, 7.1 – 7.6.

## Batch E — Phase 4 Presentation card and panel (4.7–4.10)

Date: 2026-09-09. Work unit: `batch-e-presentation-card` (tasks 4.7 – 4.10, requirements DC-1, DC-2,
DC-3, DC-4, DC-7, DC-8, DC-9 chrome parity, DC-10, DC-11).
Scope guard honoured: only `system-monitor/Presentation/Panel/DiskCard.swift` (new),
`system-monitor/Presentation/Components/ThroughputLabel.swift` (new),
`system-monitor/Presentation/Panel/PanelView.swift` and their two test files. No Domain, Application,
Infrastructure, App, formatter, `Palette` or `PRD.md` change. `AppDelegate.swift`'s temporary
`UnwiredDiskProvider` was left untouched for batch F.

### Native runtime ledger

Acquire (`request-id disk-module-batch-e-actor-20260909`, `--work-unit batch-e-presentation-card`,
`--max-attempts 2`, `--max-changed-lines 3000`, `--untracked-scope=exclude`,
`--expected-untracked-inventory=sha256:b4ae67ab…`, `--token sha256:bd3b0c1d…`) — accepted first time,
the inventory hash the prompt carried was still current:

```json
{
  "state": "proceed",
  "token": "sha256:bd3b0c1d7508b340526762ccc80561247aaad6af643e170d4ca3f44b96c85140"
}
```

Settle (`request-id disk-module-batch-e-settle-20260909`, `--outcome passed`,
`--evidence-revision sha256:a9dc72a961fc40f56e000be10359db987d88c61d825772d185ff22919f4ff7f6`,
`--harness-disposition reused`). As batches A, C and D predicted, the first attempt was refused for a
missing untracked ruling, and the inventory hash had moved on from the one batch D recorded. Raw
refusal:

```json
{
  "state": "blocked",
  "reason": "undeclared_untracked",
  "exit": "SDD runtime settlement requires an untracked ruling this request does not carry: this attempt left eligible untracked files its candidate does not include, so settling now would record them as no change at all: openspec/changes/disk-module/apply-progress.md, openspec/changes/disk-module/design.md, openspec/changes/disk-module/exploration.md, openspec/changes/disk-module/proposal.md, openspec/changes/disk-module/specs/disk-card/spec.md, openspec/changes/disk-module/specs/disk-metrics/spec.md, openspec/changes/disk-module/state.yaml, openspec/changes/disk-module/tasks.md, system-monitor/Domain/Models/DiskSnapshot.swift, system-monitor/Domain/Models/DiskThroughputCounters.swift and 19 more; rerun `gentle-ai sdd-attempt finish` or `gentle-ai sdd-attempt settle` with --untracked-scope=select --intended-untracked=<repo-relative-path> --expected-untracked-inventory=sha256:5c6326e8fdf00cf4c1da4a2ea583b357dc8d4120d21640a1f21e47b93995967c to account them, or --untracked-scope=exclude --expected-untracked-inventory=sha256:5c6326e8fdf00cf4c1da4a2ea583b357dc8d4120d21640a1f21e47b93995967c to leave them out on the record",
  "detail": "…identical to exit…"
}
```

Rerun once with `--untracked-scope=select`,
`--expected-untracked-inventory=sha256:5c6326e8fdf00cf4c1da4a2ea583b357dc8d4120d21640a1f21e47b93995967c`
and one `--intended-untracked` per still-untracked file under `system-monitor/**` and
`system-monitorTests/**` (21 paths: batch D's 18 plus this batch's `ThroughputLabel.swift`,
`DiskCard.swift` and `DiskCardModelTests.swift`; the 8 `openspec/**` entries stayed out, as batches C
and D established). Raw result:

```json
{
  "state": "complete",
  "exit": "this change's runtime objective (batch-e-presentation-card) is complete; to continue with the next ordered work unit, run `gentle-ai sdd-attempt acquire --cwd <repo> --change <change> --request-id \"<unique-request-id>\" --work-unit \"<a different label>\" --evidence-goal \"<stable-goal>\" --max-attempts <count> --max-changed-lines <count>`; rescope applies only to an objective that is not complete, and reset discards this scope instead of succeeding it",
  "detail": "…identical to exit…"
}
```

### Completed tasks

- [x] 4.7 **RED** DC-2, DC-3, DC-4, DC-7, DC-8 (model), DC-9 (chrome), DC-10 —
  `system-monitorTests/Presentation/DiskCardModelTests.swift`
- [x] 4.8 **GREEN** DC-2, DC-3, DC-4, DC-7, DC-8 (model), DC-10 — the model half of
  `system-monitor/Presentation/Panel/DiskCard.swift` and
  `system-monitor/Presentation/Components/ThroughputLabel.swift`
- [x] 4.9 **RED** DC-1, DC-8 (height), DC-11 — five cases added to
  `system-monitorTests/Presentation/PanelViewTests.swift`
- [x] 4.10 **GREEN** DC-1, DC-8, DC-11 — the view half of `DiskCard.swift` and the rewritten
  `system-monitor/Presentation/Panel/PanelView.swift`

### Files changed

| File | Action | What was done |
|------|--------|---------------|
| `system-monitor/Presentation/Panel/DiskCard.swift` | Create | `DiskCardRow`, `DiskCardSection`, `DiskCardModel` (sections, symbol names, unavailable vocabulary, rows, gauge text/fraction/accessibility value, throughput readings, animation) and the `DiskCard` view (header, gauge with three rows, throughput footer, card chrome) plus two previews (273 lines) |
| `system-monitor/Presentation/Components/ThroughputLabel.swift` | Create | `ThroughputReading`, the `ThroughputLabel` view, its three `nonisolated static` layout constants and a preview (91 lines) |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modify | `PanelCard` enum, `nonisolated static let cards`, `ForEach` + switch body, `DiskCard(snapshot: state.disk)` third, refreshed doc comments, live preview now applies a disk snapshot (+42 / −4) |
| `system-monitorTests/Presentation/DiskCardModelTests.swift` | Create | 17 cases covering DC-2, DC-3, DC-4, DC-7, DC-8 (model), DC-9 chrome parity and DC-10 (227 lines) |
| `system-monitorTests/Presentation/PanelViewTests.swift` | Modify | Five cases for DC-1, DC-8 (height) and DC-11, two helpers, the three-card chrome constant and the refreshed height comments (+84 / −4) |

### Measured panel height (input to task 6.1)

The heights were measured, not estimated: four temporary `#expect(… == 0)` assertions were added to
`thePanelGrowsByTheFullDiskCard`, the run's `.xcresult` was read with
`xcrun xcresulttool get test-results tests`, and the assertions were removed again before the final
run (the working tree carries none of them).

| Measurement | Value |
|---|---|
| Three-card panel `fittingSize.height` | **871 pt** |
| CPU card at 296 pt | 370 pt |
| Memory card at 296 pt | 278 pt |
| Disk card at 296 pt | **175 pt** |
| Panel chrome (two spacings + top and bottom padding) | 48 pt |

370 + 278 + 175 + 48 = 871 exactly, so the panel is its three cards plus its own chrome and nothing
else. **Task 6.1 should write "two cards 678 pt → three cards 871 pt" into PRD section 10**; 871 pt
still fits a 14" display (1 512 × 982 pt of usable height).

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 4.7 / 4.8 | `system-monitorTests/Presentation/DiskCardModelTests.swift` | Unit | N/A (new file); `PanelViewTests` 7/7 green before any edit | Ok Written | Ok 17/17 passed | Ok 17 cases, both locales, populated / no-rates / nil snapshot | Ok Clean |
| 4.9 / 4.10 | `system-monitorTests/Presentation/PanelViewTests.swift` | Unit (view, `NSHostingView` fitting size) | Ok 7/7 (`PanelViewTests`, exit 0, no `error:`/`warning:`) | Ok Written | Ok 12/12 passed | Ok 5 cases: order, card-alone render, height stability, three-card height, live gauge | Ok Clean |

Safety net: `-only-testing:system-monitorTests/PanelViewTests` before any edit — exit 0, 7 unique
passing cases, no `error:` and no `warning:` line. That is the only pre-existing suite this batch
modifies.

Observed RED failures (each run with `-only-testing:system-monitorTests/<Suite>`, both exit 65):

1. Task 4.7 — 62 compiler errors, deduplicated to `error: cannot find 'DiskCardModel' in scope`,
   `cannot find 'DiskCardSection' in scope`, `cannot find 'DiskCard' in scope`,
   `cannot find 'ThroughputLabel' in scope`, plus the contextual-type follow-ons
   (`reference to member 'header' cannot be resolved without a contextual type`).
2. Task 4.9 — `error: type 'PanelView' has no member 'cards'`, `cannot find 'PanelCard' in scope` and
   the three `reference to member '<case>' cannot be resolved without a contextual type` follow-ons.

Observed GREEN results, both exit 0 with no `error:`, no `warning:` and no failing case:
`DiskCardModelTests` 17 passed, `PanelViewTests` 12 passed (7 pre-existing + 5 new).

REFACTOR: no restructuring was needed after GREEN. `DiskCardModel` was written with its row keys,
footer labels and the two private helpers (`capacityText`, `reading`) extracted from the start, so the
em-dash substitution exists in exactly one place per value kind; `DiskCard` and `PanelView` are
`ForEach` + `switch` over their pure order arrays, so neither can drift from the model.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests/DiskCardModelTests` — **exit 0**, **17 unique passing cases**, 0 failures. |
| Full unit target (the command of record) | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests` — **exit 0**, **555 unique passing test cases**, **0 failures**, **0 `error:` lines**, **0 `warning:` lines**. Run twice, identical both times. |
| Runtime harness command/scenario and exact result | The work-unit table names "open the popover manually", which cannot run in this batch: `AppDelegate` still injects `UnwiredDiskProvider`, so the live app would only show the em-dash skeleton (batch F wires the real provider, batch G runs the manual checklist). The runtime boundary that does exist here — SwiftUI actually laying the card out — is exercised in-process by the `NSHostingView` fitting-size cases, which measured a real 175 pt card and an 871 pt panel; the two `#Preview`s in `DiskCard.swift` and the one in `ThroughputLabel.swift` cover the visual check in Xcode. |
| Rollback boundary | `rm system-monitor/Presentation/Panel/DiskCard.swift system-monitor/Presentation/Components/ThroughputLabel.swift system-monitorTests/Presentation/DiskCardModelTests.swift` and `git checkout -- system-monitor/Presentation/Panel/PanelView.swift system-monitorTests/Presentation/PanelViewTests.swift`. Nothing outside the panel presentation was touched, so that restores the batch D state exactly. |

Evidence revision `sha256:a9dc72a961fc40f56e000be10359db987d88c61d825772d185ff22919f4ff7f6` is the
sha256 of the final unit run's log.

Convention 6 noise: the two `INFOPLIST_KEY_NSHumanReadableCopyright` lines in
`system-monitor.xcodeproj/project.pbxproj` were re-sorted again by the test runs and were reverted with
`git checkout --` before reporting. The working tree carries no `project.pbxproj` change.

### The unit-target count moved by 23, not 22

This batch added 22 test functions (17 + 5) but the total moved from batch D's recorded 532 to 555. The
extra name is **not** a new test: a run with `-skip-testing` on both touched suites reported 525 unique
passing names and silently omitted `MetricsSamplerStepTests/capacityIsReadOnceWhileEveryStampStaysUnderTenSeconds()`,
which passes in every full run. `xcodebuild -quiet` therefore drops the occasional `passed` line, so a
count taken from one log can be one short. 555 is the figure two consecutive full runs agree on, with
zero failures in both; batch D's 532 was almost certainly 533.

### Deviations from design

1. **None in the interfaces or the layout.** `DiskCardRow`, `DiskCardSection`, `ThroughputReading`,
   `DiskCardModel`, `ThroughputLabel`, `DiskCard`, `PanelCard` and `PanelView.cards` carry the design's
   verbatim shapes, names, constants and section composition.
2. **No SF Symbol fallback was needed.** `internaldrive`, `arrow.down.doc` and `arrow.up.doc` all
   resolve through `NSImage(systemSymbolName:accessibilityDescription:)` on this SDK, so design
   decision 6's `arrow.down.circle`/`arrow.up.circle` fallback pair stays unused. The resolution is
   machine-checked by two cases, not assumed.
3. **Design decision 4 ("no Unavailable caption") was followed literally**, and DC-8's height parity is
   satisfied by construction: `DiskCard` has no conditional view, so the nil and the populated tree are
   the same tree with different strings. The panel height test confirms it empirically (applying the
   first snapshot leaves `fittingSize` byte-identical).

### Decisions taken inside the batch

1. **The nil snapshot is distinguished from a zero reading in the model, never in the view.**
   `gaugeText`, `rows` and `throughputReadings` each substitute `unavailableText` themselves, so the
   view has no `if` and no default value; `ByteFormatter.throughput` is never called with a sentinel,
   which is what would have produced the `"0 B/s"` DC-7 forbids.
2. **`gaugeAccessibilityValue` is applied to the gauge with a second `.accessibilityValue`.**
   `RingGauge` already sets `.accessibilityValue(valueText)` internally, so the card's modifier overrides
   it. That is what makes VoiceOver read "unavailable" instead of "em dash" without teaching `RingGauge`
   about disks.
3. **`DiskCard`'s chrome constants are internal `nonisolated static`** as design decision 5 requires
   (`MemoryCard`'s equivalents are `private static` and unreachable from a test), and the parity test
   pins the literals plus `Palette.cardCornerRadius`, since the shared token is the corner-radius half
   of DC-9.
4. **The `PanelView` body became a `ForEach` over `Self.cards` with a `@ViewBuilder` switch**, matching
   `MemoryCard`'s `sections` mechanism, so DC-1's "card order" is an assertion on a value and the body
   cannot drift from it.
5. **The 678 pt comment was rewritten rather than deleted.** The two-card figure is kept as history and
   the measured three-card figure (871 pt) is pinned in the new test's comment, which is what task 4.9
   and design line 327 ask for.

### Extra assertions beyond the task list (all spec-derived, none contradicting it)

- The footer test also pins `symbolName` per direction and the `accessibilityValue` of a populated
  reading (it equals the text), so the "unavailable" value cannot leak into the normal path.
- `theFooterValuesFollowTheInjectedLocale` pins `"27,1 MB/s"` under `de_DE`, covering DC-6's locale
  scenario from the card model's side as well as the formatter's.
- `theGaugeFractionFollowsTheSnapshot` pins the reference fraction to ±0.0005 and the full-volume case
  at exactly 1, so the gauge cannot silently round or clamp.
- `theThroughputLabelGeometryFollowsTheExistingComponents` asserts
  `ThroughputLabel.iconFontSize == SegmentLegend.labelFontSize`, turning design decision 5's "the icon
  follows the legend label size" into a check that survives a future legend restyle.
- `thePanelStacksCPUThenMemoryThenDisk` also asserts `Set(PanelView.cards) == Set(PanelCard.allCases)`,
  so a fourth card can never be defined and silently left unrendered.

### Issues found

1. `xcodebuild -quiet` prints neither the `Expectation failed:` text nor the expression values, and the
   verbose run does not print them either — they live only in the result bundle. Reading a measured
   value therefore needs `-resultBundlePath` plus
   `xcrun xcresulttool get test-results tests --path <bundle> --format json`. That is how the 871/175 pt
   figures above were obtained.
2. The same `-quiet` mode occasionally omits one `passed` line (see "The unit-target count moved by 23").
   Counting unique names from a single log can therefore undercount by one; two runs agreeing is the
   safer evidence.
3. Constructing a view from a test needs a main-actor helper: the app target compiles with
   `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` while the **test target does not**, so `DiskCard(...)`
   cannot be built in a `nonisolated` test body. `PanelViewTests` gained a `@MainActor`
   `diskCardHeight(_:)` helper for exactly that reason (convention 2 stays intact: no test function is
   `@MainActor`).

### What batch F must know

1. **Nothing in the presentation layer is left to do for the card.** `PanelView` already renders
   `DiskCard(snapshot: state.disk)` third; the moment `AppDelegate` injects the real provider, the card
   fills in with no further Presentation change.
2. **`AppDelegate.swift` still holds `UnwiredDiskProvider`.** Batch F replaces it with
   `IOKitDiskProvider(capacity: VolumeCapacityReader())` and injects it into the single sampler
   (task 5.1). Until then the running app shows the em-dash skeleton — expected, not a defect.
3. **Baseline for batch F's safety net**: the unit target stands at **555 unique passing cases, 0
   failures** (`-only-testing:system-monitorTests`, exit 0, no warnings). `FULL` adds the `.integration`
   suites; batch C measured `FULL` at unit + 3.
4. **Ledger budget**: the settle ruling now counts **21** untracked files under `system-monitor/**` and
   `system-monitorTests/**`. Batch F modifies `AppDelegate.swift` (already tracked) and only extends an
   existing test file, so it adds no new untracked path — but it will still need
   `--untracked-scope=select` with those 21 paths and the inventory hash the first refusal reports. The
   hash changes between batches; never reuse a recorded one.
5. **Expect the `project.pbxproj` re-sort noise** and revert it with `git checkout --` before reporting
   (convention 6). It happened again in this batch.
6. **Task 6.1 (batch G) needs the number in this section**: PRD section 10 records "two cards 678 pt →
   three cards 871 pt", and the disk card itself measures 175 pt at 296 pt width.
7. **Engram mirror**: this batch E section is mirrored on its own under topic
   `sdd/disk-module/apply-progress-batch-e` because the combined file exceeds Engram's 50 000-character
   observation limit (observation 8276 holds batches A–C and the head of D, 8278 holds batch D). **This
   file remains the authoritative artifact.** Batch F should append its own section here and mirror only
   that section.

### Workload / PR boundary

- Mode: single PR with `size:exception` explicitly accepted by the user (unlimited review budget).
- Current work unit: E (Phase 4, tasks 4.7 – 4.10, the disk card and the third panel slot).
- Boundary: starts from batch D's formatters and palette token, ends with the disk card rendering third
  in the popover from `MetricsState.disk`. Still no user-visible change in the running app: the
  composition root publishes no disk snapshot until batch F.
- Review budget impact: 725 changed lines (717 added, 8 removed), 311 of them new test code.

### Remaining tasks

Phases 5–7 (batches F–G): 5.1, 6.1, 7.1 – 7.6.

## Batch F+G — Composition root, PRD alignment, automated verification (5.1, 6.1, 7.1, 7.2)

Date: 2026-09-09. Work unit: `batch-fg-composition-root-prd-verification` (tasks 5.1, 6.1, 7.1, 7.2;
requirements DM-14, DM-15). Tasks 7.3 – 7.6 are MANUAL and remain unchecked: they are the user's to run.
Scope guard honoured: only `system-monitor/App/AppDelegate.swift`,
`system-monitorTests/App/AppDelegateCompositionTests.swift`, `PRD.md`, `tasks.md` and this file were
touched. No Domain, Application, Infrastructure or Presentation source changed, and no
`project.pbxproj` edit was needed.

### Native runtime ledger

Acquire (`request-id disk-module-batch-fg-actor-20260909`, `--work-unit
batch-fg-composition-root-prd-verification`, `--max-attempts 2`, `--max-changed-lines 3600`,
`--untracked-scope=exclude`, `--expected-untracked-inventory=sha256:5c6326e8…`,
`--token sha256:2e50218d…`) — accepted first time, the inventory hash the prompt carried was still
current:

```json
{
  "state": "proceed",
  "token": "sha256:2e50218de074704c6cbb61836a0027e7480a4a2f1c3759e11f060d4551df2889"
}
```

Settle (`request-id disk-module-batch-fg-settle-20260909`, `--outcome passed`,
`--evidence-revision sha256:23e2afb9217c2ee0c122ee6fc896d5beeb121273ccfb671672524976ad7d4fa0`,
`--harness-disposition reused`, plus `--diagnosis`, `--cleanup-evidence` and `--process-evidence`).
Unlike batches A, C, D and E, **this settle was accepted on the first attempt with no untracked
ruling**, because the batch created no new untracked file: it modified three already-tracked files
(`AppDelegate.swift`, `PRD.md`, the composition test) and the acquire's `--untracked-scope=exclude`
inventory hash was still current at settle time. Raw result:

```json
{
  "state": "complete",
  "exit": "this change's runtime objective (batch-fg-composition-root-prd-verification) is complete; to continue with the next ordered work unit, run `gentle-ai sdd-attempt acquire --cwd <repo> --change <change> --request-id \"<unique-request-id>\" --work-unit \"<a different label>\" --evidence-goal \"<stable-goal>\" --max-attempts <count> --max-changed-lines <count>`; rescope applies only to an objective that is not complete, and reset discards this scope instead of succeeding it",
  "detail": "…identical to exit…"
}
```

The evidence revision is the sha256 of the second `FULL` log (`full-2.log`), this batch's command of
record for task 7.1. For cross-checking, the final unit-only log hashes
`sha256:042e24a5d0a564a5d0a9f674df4af6311c0b9c66f97bfeab73fd2885d3031125` and the first `FULL` log
`sha256:930f0ae77edd954eb88131169bdb757dab74de3048bb61da2c10dcb4a0209a3a`.

### Completed tasks

- [x] 5.1 **RED→GREEN** DM-14 — three cases added to
  `system-monitorTests/App/AppDelegateCompositionTests.swift`, then the real provider injected in
  `system-monitor/App/AppDelegate.swift`
- [x] 6.1 **DOC** DM-15 — `PRD.md` 6.2, R10.5, 6.3 and section 10 aligned with the shipped design
- [x] 7.1 `FULL` — exit 0, **561 unique passing cases**, 0 failures, run twice with identical results
- [x] 7.2 `BUILD` — `build-for-testing` and `build` both exit 0 with zero warnings

Still open: 7.3, 7.4, 7.5 and 7.6 are MANUAL checks for the user (see "Manual checks awaiting the
user" below).

### Files changed

| File | Action | What was done |
|------|--------|---------------|
| `system-monitorTests/App/AppDelegateCompositionTests.swift` | Modify | Two `@MainActor` helpers (`withRunningApp`, `awaitValue`) and three cases for DM-14: the real graph publishes a real capacity and then real throughput rates, the disk module never enters the menu bar module set, and publishing disk readings leaves the status item width at its module-set fitting width (+122 / −0) |
| `system-monitor/App/AppDelegate.swift` | Modify | `UnwiredDiskProvider` (the 24-line batch B placeholder, both reads throwing) deleted, `diskProvider:` now `IOKitDiskProvider(capacity: VolumeCapacityReader())`. Net against `HEAD`: +1 / −0, because the placeholder it removes was itself uncommitted |
| `PRD.md` | Modify | 6.2, R10.5, 6.3 and section 10 aligned (+27 / −12) |
| `openspec/changes/disk-module/tasks.md` | Modify | 5.1, 6.1, 7.1 and 7.2 marked `[x]` |

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|------|-----------|-------|------------|-----|-------|-------------|----------|
| 5.1 | `system-monitorTests/App/AppDelegateCompositionTests.swift` | Integration (`.integration`, real graph) | Ok 7/7 (`AppDelegateCompositionTests`, exit 0) | Ok Written | Ok 10/10 passed | Ok 3 cases: real readings, module set, widget width | Ok None needed |
| 6.1 | N/A — documentation task (DM-15 is verified by reading the PRD) | — | — | — | — | — | — |
| 7.1 / 7.2 | N/A — verification tasks | — | — | — | — | — | — |

Safety net: `-only-testing:system-monitorTests/AppDelegateCompositionTests` before any edit — exit 0,
**7 unique passing cases**, no `error:` and no `warning:` line. That suite is the only pre-existing one
this batch modifies.

Observed RED (`-only-testing:system-monitorTests/AppDelegateCompositionTests`, **exit 65**): the suite
compiled and failed on behaviour rather than on a missing symbol, which is the stronger RED here —
the placeholder provider satisfies `DiskMetricsProvider`, so only a case that reads real values can
tell it apart from the real adapter.

| Case | RED result | Why it failed |
|---|---|---|
| `theRealGraphPublishesRealDiskReadings()` | failed (10.0 s) | `UnwiredDiskProvider` throws both reads, so `MetricsState.disk` stayed `nil` and both 5 s polls timed out |
| `publishingDiskReadingsLeavesTheStatusItemWidthUnchanged()` | failed (5.2 s) | same cause: the `published` requirement was never met |
| `theDiskModuleNeverEntersTheMenuBarModuleSet()` | passed | the invariant half of DM-14's "Modules untouched" scenario, green before and after by design |

Observed GREEN, same command after the `AppDelegate` change: **exit 0**, **10 unique passing cases**
(7 pre-existing + 3 new), 0 failures, 0 `error:` lines, 0 `warning:` lines.

REFACTOR: none needed. The GREEN change is one constructor argument and the deletion of the
placeholder; the composition root reads exactly as the design specifies it.

### PRD alignment (task 6.1) — diff summary

`PRD.md` +27 / −12, four edits, all four items of the design's PRD alignment list (`design.md:337-342`):

| Location | Before | After |
|---|---|---|
| 6.2 | `struct DiskCounters` mixing capacity and counters in one value with a `timestamp` | The port's two reads named in a comment (`readThroughput()` / `readCapacity()`), then `DiskThroughputCounters` (`bytesRead`, `bytesWritten`, `driverCount`, `timestamp`) and `VolumeCapacity` (`total`, `free`) as separate values |
| 6.2, `DiskSnapshot` | `used: total − free`, `fraction: Double(used) / Double(total)` | `used` documented as saturating at 0, `fraction` shown with the `total == 0` guard and the cap at 1, and both rates documented as `nil` together (first sample, counter reset, `driverCount == 0`) |
| R10.5 | `ByteCountFormatStyle(style: .file)` | `ByteCountFormatStyle(style: .decimal)` — the parenthetical about decimal units and Finder was already correct and is unchanged |
| 6.3 | Disk throughput "Unverified under App Sandbox (v1 is not sandboxed)"; capacity row silent on the sandbox | Throughput: "Works in sandbox: the app target sets `ENABLE_APP_SANDBOX = YES` (`project.pbxproj:401,435`) and the `.integration` suite `IOKitDiskIntegrationTests` proves statistics access inside the sandboxed test host"; capacity gains "Works in sandbox (`VolumeCapacityIntegrationTests`)" |
| Section 10, "Popover grows with a third card" | "Height still fits content (R2.2); the Disk card is the shortest since it has no graph." | "Measured in M5: 678 pt with two cards → 871 pt with three (the Disk card adds 175 pt, the shortest of the three since it has no graph). Height still fits content (R2.2) and still fits a 14" display." |

Post-conditions checked by search, not by eye: `rg "DiskCounters" PRD.md` and `rg "\.file\b" PRD.md`
both return nothing. The two `project.pbxproj` line numbers were verified against the file
(`rg -n "ENABLE_APP_SANDBOX"` → lines 401 and 435).

The `Status | Draft v3` header and the `Date | 2026-09-06` row were left untouched, following the
PRD's own convention: the v2 → v3 bump (commit `6f3acb9`) accompanied a **scope** change (the Disk card
entering v1), while the previous alignment amendment (commit `9f733a9`, settings state and profiling
evidence) changed neither field. This edit aligns existing v3 scope with the shipped design, so it is
the second kind.

### Verification of record (tasks 7.1 and 7.2)

| Command | Exit | Result |
|---|---|---|
| `FULL` — `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test` (run 1) | **0** | **561 unique passing cases**, 0 failures, 0 `error:` lines, 0 `warning:` lines |
| `FULL` (run 2, for the count) | **0** | **561 unique passing cases**, 0 failures — identical to run 1 |
| `UNIT` — the same invocation with `-only-testing:system-monitorTests` | **0** | **558 unique passing cases**, 0 failures, 0 `warning:` lines |
| `BUILD` as `tasks.md` defines it — `build-for-testing` | **0** | 0 `warning:` lines, 0 `error:` lines |
| `build` — the plain app build | **0** | 0 `warning:` lines, 0 `error:` lines |

The arithmetic closes: batch E left the unit target at 555, this batch added 3 cases → 558, and `FULL`
adds the three `system_monitorUITests` cases → 561. The 527 pre-existing cases task 7.1 names are all
inside that figure and all green. `system_monitorUITests/testLaunchPerformance()` — the flaky Xcode
template case — passed in both `FULL` runs and was not touched.

The test target really did recompile: the `AppDelegateCompositionTests` edit forced it in the RED run
and again in the GREEN run and in `FULL`, all of which reported zero warnings under Swift 6 strict
concurrency. `build-for-testing` afterwards was therefore incremental, and its zero-warning result
confirms rather than establishes the recompile.

Convention 6: **no `project.pbxproj` noise appeared in this batch** — `git diff --stat` on it is empty
after five test runs and two builds, so nothing had to be reverted. That differs from batches C, D and
E, where the two `INFOPLIST_KEY_*` lines were re-sorted; the re-sort is evidently not deterministic and
must still be checked for, not assumed absent.

### Manual checks awaiting the user (7.3 – 7.6)

These four stay `- [ ]` in `tasks.md`. They cannot be executed by the apply phase: three need a running
app in front of a human and the fourth needs Instruments. Record the results here when they are done —
the verify phase reads them from this file.

| Task | What to do | What to look for |
|---|---|---|
| 7.3 Card correctness | Launch the app, open the popover, then start a large file copy and let it finish | The Disk card renders **third**, below CPU and Memory, with live values. Total and Free within **100 MB** of Finder's boot-volume figures (compare Finder's "Available" against the card's Free). The read and write footer values move during the copy and fall back to low values when it ends. **Record four numbers**: card Total, card Free, Finder Total, Finder Available |
| 7.4 Unavailable and motion states | Watch the card in its no-rate moments (the first tick after launch and right after changing the sampling interval), then enable System Settings › Accessibility › Display › Reduce Motion | Em dashes (`—`), never `0%`, `0.0%` or `0.0 MB/s`. With VoiceOver on, the gauge and the two throughput values read **"unavailable"**. With Reduce Motion on, the disk ring **jumps** to its new value instead of sweeping; with it off, it sweeps |
| 7.5 Layout | Open the popover on a 14" display | CPU, Memory, Disk stacked in that order with **12 pt** gaps at **320 pt** width; the taller popover (871 pt of content) still fits the display without clipping; the menu bar widget shows the **same two modules at the same width** as before the disk work (R10.11) |
| 7.6 Instruments | Time Profiler with the panel **closed** for 10 minutes, with the disk step running (capacity refreshes on its 10 s cadence) | Average CPU and resident size next to the M4 baseline of about **1.6% closed**. Note explicitly whether the disk step moved either number. This figure goes into the verify report |

### Deviations from design

1. **None in the composition root.** `AppDelegate` constructs
   `IOKitDiskProvider(capacity: VolumeCapacityReader())` verbatim as `design.md:256` and DM-14 specify,
   injects it into the single `MetricsSampler`, and changes nothing else: `MetricModule`, the settings
   module list, the widget and the login item are untouched, which the new cases assert rather than
   assume.
2. **The DM-14 test does more than the task line asks, in one direction only.** The task names "the
   real graph eventually publishes `disk != nil`". The case additionally waits for a snapshot whose
   rates are non-`nil` and pins the capacity's internal coherence (`free <= total`,
   `used == total − free`, `0 < fraction <= 1`). Reason: `disk != nil` alone is satisfied by the
   capacity read on its own, so it would not prove the IOKit **throughput** adapter is wired. The
   5 s poll deadline is a 50× margin over the ~100 ms the loop actually needs (`startupGap`), so the
   stronger assertion costs no flakiness.
3. **The "widget unchanged" scenario is split across two cases**, one value-level
   (`MetricModule.allCases`, `MetricModule.menuBarOrder`) and one behavioural (the status item width
   before and after two disk publishes, compared against `contentFittingWidth(for:
   settings.menuBarModules)`). The width is measured from the **settings'** module set, not from
   `MetricModule.menuBarOrder`, so a user who has hidden MEM would break a naive comparison against the
   full order; the case reads the launched delegate's own settings for that reason.
4. **`PRD.md` keeps its Draft v3 header** — see the reasoning under the PRD diff summary above.

### Decisions taken inside the batch

1. **A second launch helper rather than a change to `withLaunchedApp`.** The existing helper's body is
   synchronous, and the loop publishes from a detached task onto the main actor, so a case that waits
   inside it would hold the actor the publish needs. `withRunningApp` takes an `async` `@MainActor`
   body and is constrained to `T: Sendable` so the reading crosses back to the non-isolated test body
   legally (convention 2 stays intact: no test function is `@MainActor`).
2. **A polling deadline rather than a fixed sleep.** `awaitValue` re-reads every 20 ms until a value
   appears or 5 s elapse. A passing case costs about 100 ms; a graph that never publishes fails its own
   case instead of hanging until the suite's `.timeLimit(.minutes(1))`.
3. **The placeholder was deleted, not left behind a flag.** `UnwiredDiskProvider` existed only to give
   the required `diskProvider:` parameter a name between batches B and F; keeping it would leave a type
   in the app target that no code path can reach.
4. **Both `BUILD` readings are reported.** `tasks.md` defines `BUILD` as `build-for-testing` (which
   recompiles the test target) while the phase prompt names the plain `build`. Both were run and both
   are recorded, so neither definition is left unverified.

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests/AppDelegateCompositionTests` — **exit 0**, **10 unique passing cases**, 0 failures (RED before the production change: exit 65, 2 of those 10 failing). |
| Full command of record | `FULL` — **exit 0**, **561 unique passing cases**, **0 failures**, **0 `error:`**, **0 `warning:`**. Run twice, identical both times. |
| Runtime harness command/scenario and exact result | The real runtime boundary is exercised in-process: `AppDelegateCompositionTests` builds the production graph (real `UserDefaults`, real status item, real Mach and IOKit adapters), starts the sampler's detached loop and reads what it publishes — the boot volume's real capacity and real throughput rates. The remaining runtime check is the human one: manual tasks 7.3 – 7.6, listed above, are the user's to run. |
| Rollback boundary | `git checkout -- PRD.md system-monitorTests/App/AppDelegateCompositionTests.swift` and restore `AppDelegate.swift`'s batch B state (re-add `UnwiredDiskProvider` and point `diskProvider:` at it). That returns the tree to the end of batch E with every other batch intact. |

### Workload / PR boundary

- Mode: single PR with `size:exception` explicitly accepted by the user (unlimited review budget).
- Current work unit: F+G (Phase 5 task 5.1, Phase 6 task 6.1, Phase 7 tasks 7.1 and 7.2).
- Boundary: starts from batch E's rendered-but-unfed disk card, ends with the running app publishing
  real disk readings into it, the PRD describing what was actually built, and the full suite plus both
  builds green. This is the first batch with a user-visible effect in the running app.
- Review budget impact: 187 changed lines in this batch — 122 added in the test file, 26 in
  `AppDelegate.swift` (1 added, 25 removed: the swapped argument plus the 24-line placeholder) and 39
  in `PRD.md` (27 added, 12 removed) — on top of the batches before it.

### What verify must know

1. **Every automated task in the change is done.** 5.1, 6.1, 7.1 and 7.2 are `[x]`; only the four
   MANUAL tasks (7.3 – 7.6) remain, and they are the user's, not the phase's.
2. **DM-15 is verified by reading `PRD.md`**, as the design's test mapping says. The four edits and
   their post-conditions are listed above; `DiskCounters` and the `.file` style no longer appear.
3. **Counts to check against**: unit target **558**, `FULL` **561**, both at 0 failures, both builds
   warning-free. `-quiet` occasionally drops one `passed` line, so a single log can undercount by one;
   the figures here are the ones two consecutive runs agree on.
4. **`system_monitorUITests/testLaunchPerformance()` is a pre-existing flaky Xcode template case.** It
   passed in both `FULL` runs of this batch. If a later run trips on it, rerun once before treating it
   as a regression, and do not modify it.
5. **Nothing is committed.** Delivery stays user-owned (convention 9), and the whole change is still one
   uncommitted working tree.
