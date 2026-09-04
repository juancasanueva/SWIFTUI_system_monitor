# Archive Report: cpu-module (PRD M2 — "CPU end to end")

**Change**: `cpu-module`
**Archived on**: 2026-09-04
**Archived to**: `openspec/changes/archive/2026-09-04-cpu-module/`
**Artifact store**: hybrid (OpenSpec files under `openspec/` + Engram observations)
**Milestone**: PRD M2; features F1 (CPU module) and F3 (CPU card)
**Status at close**: complete — verified PASS WITH WARNINGS, 0 critical findings, archived intact

This report is the terminal record of the cycle. It describes the state of the change **at close**.
Where it cites `apply-progress.md` or `verify-report.md`, those are intermediate snapshots and are
attributed to their moment in time, never restated as current fact.

---

## 1. Traceability

### Engram observation IDs (hybrid mirror)

| Artifact | Topic key | Observation ID |
|---|---|---|
| exploration | `sdd/cpu-module/explore` | 8196 |
| proposal | `sdd/cpu-module/proposal` | 8199 |
| spec (all four capabilities) | `sdd/cpu-module/spec` | 8200 |
| design | `sdd/cpu-module/design` | 8201 |
| tasks | `sdd/cpu-module/tasks` | 8202 |
| apply-progress | `sdd/cpu-module/apply-progress` | 8203 |
| verify-report | `sdd/cpu-module/verify-report` | 8208 |
| change state | `sdd/cpu-module/state` | 8197 (upserted at archive time to `ARCHIVED`; previously held the interim "verified PASS WITH WARNINGS" note) |
| archive report (this document) | `sdd/cpu-module/archive-report` | 8209 |

All eight pre-existing observations were confirmed present in project `system-monitor` at archive time.

### Archived filesystem artifacts

`openspec/changes/archive/2026-09-04-cpu-module/`

- `exploration.md`
- `proposal.md`
- `design.md`
- `tasks.md` (35/35 complete)
- `apply-progress.md`
- `verify-report.md`
- `specs/cpu-metrics/spec.md`
- `specs/core-topology/spec.md`
- `specs/menu-bar-widget/spec.md`
- `specs/cpu-card/spec.md`
- `archive-report.md` (this file — additive, written after the move)

---

## 2. Specs synced to the source of truth

`openspec/specs/` previously held only `.gitkeep`. All four capability specs are therefore **new
main specs**, not deltas: each was copied whole with `cp` and verified byte-identical by `diff -r`.
No existing requirement was modified, removed, or renamed, so no destructive-merge confirmation was
required and `rules.archive` ("warn before merging destructive deltas") had nothing to warn about.

| Domain | Action | Requirements | Scenarios |
|---|---|---|---|
| `cpu-metrics` | Created | 9 | 21 |
| `core-topology` | Created | 6 | 13 |
| `menu-bar-widget` | Created | 7 | 13 |
| `cpu-card` | Created | 8 | 14 |
| **Total** | | **30** | **61** |

Source of truth now at:

- `openspec/specs/cpu-metrics/spec.md`
- `openspec/specs/core-topology/spec.md`
- `openspec/specs/menu-bar-widget/spec.md`
- `openspec/specs/cpu-card/spec.md`

### Mechanical readback evidence

Every copy and the archive move were performed with shell commands only (`cp`, `mktemp`, `mv`) and
verified with `diff -r`. Every comparison produced no differences.

- Spec sync, per domain: `diff -r <change spec> <staged temp>` → no differences; `diff -r <change spec> <main spec>` → no differences. Four domains, eight comparisons, all empty.
- Archive move: a recursive pre-move snapshot was taken with `cp -R`, then `diff -r <snapshot> openspec/changes/archive/2026-09-04-cpu-module` → no differences.
- `git mv` failed with status 128 because the repository has zero commits and the whole tree is
  untracked, so nothing is under version control. The guarded fallback ran: the source was proven
  unchanged against the snapshot and the destination proven absent before a plain `mv` was used.
  This is an expected consequence of the deliberate zero-commit repository state, not a defect.

---

## 3. Final state at close

These are the authoritative closing numbers, taken from the orchestrator's independent
post-correction verification, which supersedes any earlier snapshot figure.

| Fact | Value |
|---|---|
| Tests | **188 passed, 0 failed, 0 skipped** (exit 0) |
| Integration cases | 11 `.integration` cases, run on real Apple M4 Pro hardware |
| Build | clean — exit 0, zero errors, zero warnings under Swift 6 strict concurrency |
| Tasks | 35 / 35 complete, 0 unchecked |
| Spec scenarios | 61 / 61 covered by a passing test (60 COMPLIANT, 1 PARTIAL — see W1) |
| Verify verdict | PASS WITH WARNINGS — 0 critical, 7 warnings, 4 suggestions |
| Coverage | not measured — the scheme does not enable code coverage (informational) |

Test command: `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`
Build command: `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build`

### Task Completion Gate

Passed without reconciliation. The persisted `tasks.md` showed 35 checked and 0 unchecked
implementation tasks before any spec sync or move, and native SDD status independently reported
`taskProgress.allComplete: true`, `dependencies.archive: ready`, `nextRecommended: archive`. No
archive-time checkbox repair was performed and none was needed.

---

## 4. Mid-cycle amendments that changed the shipped behaviour

Two user decisions on 2026-09-04 amended the `menu-bar-widget` spec **after** `tasks.md` was
written. Both were implemented, re-verified, and are reflected in the archived spec and in the
main spec now in `openspec/specs/menu-bar-widget/spec.md`.

1. **Sparkline on every module.** Originally the CPU module alone rendered a 60 pt sparkline. Every
   module in `menuBarOrder` now renders a **40 pt** sparkline in its accent colour, including MEM
   whose history is empty. `StatusItemMetrics.sparklineModules` and `showsSparkline(_:)` were
   deleted; `ModuleLabel` renders `Sparkline` unconditionally. A new spec requirement, "Every module
   renders a sparkline", records this.
2. **Width budget raised 200 pt → 230 pt** (PRD R1.7 updated). Spacing was restored to
   4 / 6 / 2 (element / module / horizontal padding) after an intermediate tightening to 0 / 2 / 0.
   The widget measures **221 pt** with the spacing constants pinned by
   `theLayoutKeepsItsReadableSpacing`, leaving **9 pt of headroom**.

Both corrections followed the Strict TDD cycle (safety net → real RED → GREEN → triangulation) and
are recorded in `apply-progress.md`.

---

## 5. Verification warnings — closing disposition

`verify-report.md` (Engram 8208) raised 7 warnings at verification time. Four were closed by
amendments the orchestrator made **after** that report was written; three remain open as debt.
The `verify-report.md` text preserved in this archive still describes those four as open — that is
the correct historical record of the moment it was written, and is superseded here.

| ID | Subject | Disposition at close |
|---|---|---|
| W2 | `design.md` specified `PercentFormatter.oneDecimal` via FormatStyle `.percent`; code uses `.number` + literal `%` | **CLOSED** — `design.md` amended. The code was always correct: `.percent` inserts U+00A0 under `de_DE`, which violates the cpu-card "Locale decimal separator" scenario requiring `"40,2%"`. |
| W3 | `design.md` specified `IORegistryEntryFromPath("IODeviceTree:/cpus")` and `logical-cpu-id` as `OSData` | **CLOSED** — `design.md` amended to describe the shipped `IOServiceMatching("AppleARMPE")` child traversal and the CFNumber `logical-cpu-id` (with `OSData` still accepted). Hardware-verified by 11 green `.integration` cases. |
| W4 | `design.md` specified `contentFittingWidth { hostingView.fittingSize.width }` | **CLOSED** — `design.md` amended. With `sizingOptions = []` the live hosting view reports a zero fitting size, so width is measured on a separate default-sizing `NSHostingView`, as `tasks.md` 6.4 mandates. |
| W7 | `apply-progress.md` "Issues Found" #6 still asserted the 200 pt budget / 197 pt measurement / 60 pt sparkline | **CLOSED** — issue 6 amended to record the resolved state (230 pt budget, 221 pt measured, 40 pt sparklines on both modules, 9 pt headroom). |
| W1 | Cadence scenario not pinned to its timing bound | **OPEN — carried as debt.** See section 6. |
| W5 | Wall-clock loop tests carry a flakiness class | **OPEN — carried as debt.** See section 6. |
| W6 | Status-item tests need a GUI session and leak four `NSStatusItem`s | **OPEN — carried as debt.** See section 6. |

No CRITICAL issue was ever raised, so no archive block applied and no override was requested or used.

---

## 6. Carried debt and follow-ups (not blockers)

### W1 — loop-interval scenario is under-bounded (LOW severity, correctness of the test)

The cpu-metrics scenario "Injected interval drives the loop" states a 10 ms interval running for
100 ms producing at least 5 snapshots. `theInjectedIntervalKeepsTheLoopPublishing` polls for up to
**1500 ms** for `count >= 5`. The count is asserted; the cadence is not. A sampler running 15×
slower than specified would still pass. The scenario is marked PARTIAL, not untested. Fix: assert
the count within a deadline close to 100 ms, ideally on an injected test clock.

### W5 — five wall-clock loop tests on `ContinuousClock` (MEDIUM flake risk)

The five `MetricsSamplerLoopTests` cases drive a real `ContinuousClock` and poll at 5 ms.
`startPublishesARealValueWithinTwoHundredMilliseconds` runs against a hard 200 ms deadline while the
sampler needs a 100 ms startup gap plus a 10 ms interval — roughly 90 ms of margin; it took 0.179 s
in the verification run. Under load, a shared CI runner, or a sanitised Debug build, that case can
flip red. **The clean fix already exists and is unused**: `MetricsSampler` injects
`clock: any Clock<Duration>`, and the spec's own GIVEN says "a sampler started with a test clock".
Moving these five cases onto a controllable clock removes the flakiness class and simultaneously
lets W1 pin the real 100 ms cadence. Recommended for the M3 change or a dedicated test-hardening
change.

### W6 — `StatusItemControllerTests` create real `NSStatusItem` instances (MEDIUM)

Each of the four cases constructs a real `NSStatusItem` in the test host and never removes it, so a
run leaks four items until the host exits. Two exposures: (a) the suite requires a real
window-server session and would not survive a headless CI runner — and it would fail as host
breakage, not as a clean test failure, the same way the documented 6.2 → 6.4 bootstrap crash did;
(b) `theWidgetStaysUnderTheWidthBudgetAtFullScale` depends on system font metrics for `"CPU"`,
`"MEM"` and `"100%"` at 11 pt, and only **9 pt of headroom** absorbs any font or OS metric change.
Mitigations: release each item in a suite teardown, and treat the 9 pt headroom as a hard M3
constraint — a third menu-bar module needs roughly 110 pt more and cannot fit inside 230 pt.

### Residual documentation inconsistencies found during archive (documentation only, no code impact)

Recorded here rather than silently edited, because the archive is an immutable audit trail:

1. `design.md:183` still declares `StatusItemMetrics.sparklineWidth: CGFloat = 60`. The shipped code
   is `StatusItemView.swift:64 → static let sparklineWidth: CGFloat = 40`, which matches the amended
   spec. The same file's Rendering section already says 40 pt, so `design.md` is internally
   inconsistent on this one constant. This is the same class of staleness as W2/W3/W4 but was not
   enumerated by `verify-report.md`, so it was not covered by the post-verify amendment pass.
2. `tasks.md` 6.2 still reads "(60 pt sparkline, …)". Superseded by the 2026-09-04 amendment; the
   task itself is complete and the delivered value is 40 pt.
3. `design.md:300` (Testing Strategy) still specifies `.timeLimit(.seconds(5))`. Swift Testing
   rejects sub-minute limits; the shipped suite uses `.timeLimit(.minutes(1))`. See S1 below.
4. `design.md` "Open Questions" retains two unchecked boxes. Both were answered during apply: the
   `logical-cpu-id` assumption is validated by the green `.integration` topology cases on real
   hardware, and the `sizingOptions = []` button height was confirmed by the manual smoke run in
   task 6.6.

None of these affects code, tests, or the merged main specs. Each should be corrected if `design.md`
is ever revived as a working document; as an archived record its staleness is now documented.

### Outside the repository

The installed swift-testing skill file (`~/.config/opencode/skills/swift-testing/SKILL.md`, lines
52, 315, 379) documents `.timeLimit(.seconds(30))` / `.seconds(5)`, which **does not compile** —
Swift Testing marks `.seconds` unavailable for time limits and accepts minutes only. The skill file
is wrong and the implementation is right. Worth correcting the skill so this is not re-litigated on
the next change. This is a tooling artifact outside this repository and outside the archive's scope.

### Suggestions carried forward (from `verify-report.md`, unaddressed by design)

- **S1** — `.timeLimit(.minutes(1))` is the tightest guard Swift Testing allows, so the loop suite's
  hang guard is 60 s rather than the 5 s `tasks.md` asked for. Per-case polling keeps real runtime
  under 0.4 s, so practical exposure is small.
- **S2** — `CoreTopologyTests.swift` also hosts the `CPUTicks values` and `CPUSnapshot values`
  suites; splitting them would make the test tree mirror the model tree.
- **S3** — the menu-bar-widget "Legibility" requirement has two clauses (system label colour for the
  value, accent for label and sparkline) but only the accent clause is asserted.
- **S4** — `CPUCard` is never instantiated directly in a test; the scenario is satisfied through
  `PanelViewTests` rendering `PanelView` and by three `#Preview`s, which the scenario's own wording
  ("in a preview or test") permits.

---

## 7. Bookkeeping note — attempt ledger

All apply and verify attempts settled `passed`. One ledger anomaly is recorded here for the
maintainer: the **final verify objective exceeded its 500-line accounting** because declared
documentation files were charged against it, leaving a **pending maintainer reset**. This is a
bookkeeping artifact of the attempt ledger, not a verification failure — the verify run itself
settled `passed` with exit 0 on both build and test. A ledger reset is exceptional and requires an
explicit maintainer scope decision; it was deliberately not performed automatically.

---

## 8. Repository state at close

| Check | State |
|---|---|
| Commits | **Zero.** The repository has no commits; the entire tree is untracked. Nothing was committed during this change, by design — delivery is user-owned. |
| `project.pbxproj` | **Untouched.** New Swift files are picked up by `PBXFileSystemSynchronizedRootGroup` (5 entries, 0 `PBXBuildFile` entries, 0 references to any new file). |
| Dependencies | **None added.** No `Package.swift`, `Package.resolved`, `Podfile`, `Cartfile`; zero `XCRemoteSwiftPackageReference`. |
| Swift sources / tests | Not modified by this archive phase. |
| Isolation convention | `system-monitor/swift6-nonisolated-domain` verified clean: only `MetricsState` and `MetricsSampler` are `@MainActor` by design; all four nested types explicitly `nonisolated`; zero `@MainActor` suites or tests. |

---

## 9. What shipped

The M1 skeleton rendered a hardcoded "CPU 0%". This change delivers the first real metric end to end
and establishes the port/adapter/sampler pattern that M3 reuses:

- **Domain** — `CPUTicks` / `CPUTickSample`, `PerformanceLevel` / `CoreTopology`, `CoreUsage` /
  `CPUSnapshot`, `MetricHistory` (O(1) ring buffer), the `CPUMetricsProvider` and
  `CoreTopologyProvider` ports, and the pure `CPUUsageCalculator` (summed-delta aggregates, wrapping
  subtraction, nice folded into user, zero-delta guard, per-level means, P-then-E ordering).
- **Application** — `@MainActor @Observable MetricsState` (120-sample history) and `MetricsSampler`,
  a `@MainActor` class owning one `Task.detached(priority: .utility)` loop with an injectable
  interval, a 100 ms startup double-sample, error-tolerant iteration, and cancellation via `stop()`.
- **Infrastructure** — `MachCPUProvider` (`host_processor_info` with `defer vm_deallocate`),
  `SysctlReader`, the pure `CoreTopologyResolver` (all-or-nothing degradation), and
  `IORegistryCoreTopologyProvider` over `AppleARMPE`.
- **Presentation** — `Palette` (PRD 7.1 tokens), `PercentFormatter`, the Equatable `Canvas`
  components (`Sparkline`, `HistoryGraph`, `RingGauge`, `CoreBar`, `CoreBarGrid`, `KeyValueRow`),
  `CPUCard`, and the rebuilt menu-bar surface (`ModuleReading`, `StatusItemContent`,
  `StatusItemMetrics`) with `sizingOptions = []` and a status-item length measured once.
- **Composition root** — `AppDelegate` wires state, providers, sampler and controller, starts the
  sampler on launch and stops it on terminate.

---

## 10. Next

**Next milestone: M3 — Memory module, as its own SDD change.** The groundwork is in place: the MEM
widget module already renders its 40 pt sparkline area and a `0%` placeholder, so making it live
requires no menu-bar layout change. Carry into M3 the 9 pt width headroom as a hard constraint (a
third module does not fit inside 230 pt) and, ideally, the W1/W5 test-clock migration.

## SDD Cycle Complete

`cpu-module` has been explored, proposed, specified, designed, planned, implemented under Strict
TDD, independently verified, and archived. The four capability specs are now the project's source of
truth under `openspec/specs/`.
