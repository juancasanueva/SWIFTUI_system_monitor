# Archive Report: memory-module (PRD M3 — "Memory end to end")

**Change**: `memory-module`
**Archived on**: 2026-09-06
**Archived to**: `openspec/changes/archive/2026-09-06-memory-module/`
**Artifact store**: hybrid (OpenSpec files under `openspec/` + Engram observations)
**Milestone**: PRD M3; feature F4 (Memory card), R4.1–R4.6, R5.1–R5.4
**Status at close**: complete — verified PASS WITH WARNINGS (rev 2), 0 CRITICAL findings, destructive `menu-bar-widget` delta merged with explicit user confirmation

This report is the terminal record of the cycle. It describes the state of the change **at close**.
Where it cites `apply-progress.md` or `verify-report.md`, those are intermediate snapshots and are
attributed to their moment in time, never restated as current fact.

---

## 1. Traceability

### Engram observation IDs (hybrid mirror)

| Artifact | Topic key | Observation ID |
|---|---|---|
| session preflight | — | 8215 |
| exploration | `sdd/memory-module/explore` | 8216 |
| change state | `sdd/memory-module/state` | 8217 (upserted at archive time to `ARCHIVED`) |
| product decision — Used formula (batch D) | — | 8218 |
| research (rev 2) | `sdd/memory-module/research` | 8219 |
| proposal | `sdd/memory-module/proposal` | 8220 |
| spec (3 capabilities, rev 3) | `sdd/memory-module/spec` | 8221 |
| design (rev 3) | `sdd/memory-module/design` | 8222 |
| design gate result | — | 8223 |
| tasks | `sdd/memory-module/tasks` | 8224 |
| apply-progress, batches A–C | `sdd/memory-module/apply-progress` | 8226 |
| apply-progress, batch D | `sdd/memory-module/apply-progress-batch-d` | 8230 |
| verify-report (rev 2) | `sdd/memory-module/verify-report` | 8227 |
| manual check 7.3 PASSED | — | 8229 |
| archive report (this document) | `sdd/memory-module/archive-report` | 8231 |

All pre-existing observations were confirmed present in the Engram project `swiftui_system_monitor`
(path `/Users/juancasanueva/programming/swiftUI/system-monitor`) at archive time.

**The Engram `apply-progress` mirror is split in two** (8226 = batches A–C, 8230 = batch D) because a
single observation is capped at 50 000 characters. The complete document is the archived file
`apply-progress.md`. A reader who consults only 8226 sees a change that predates the batch D
correction; both ids must be read together.

### Archived filesystem artifacts

`openspec/changes/archive/2026-09-06-memory-module/`

- `exploration.md`
- `research.md`
- `proposal.md`
- `design.md` (revision 3)
- `tasks.md` (35/35 complete, 0 unchecked)
- `apply-progress.md` (batches A, B, C, D — the single complete document)
- `verify-report.md` (revision 2)
- `state.yaml` (updated at archive time to `status: ARCHIVED`, `closed: 2026-09-06`)
- `specs/memory-metrics/spec.md`
- `specs/memory-card/spec.md`
- `specs/menu-bar-widget/spec.md` (the delta)
- `archive-report.md` (this file — additive, written after the move)

---

## 2. Specs synced to the source of truth

| Domain | Action | Requirements | Scenarios | Notes |
|---|---|---|---|---|
| `memory-metrics` | Created | 10 (MM-1..MM-10) | 23 | New main spec, copied whole |
| `memory-card` | Created | 10 (MC-1..MC-10) | 20 | New main spec, copied whole |
| `menu-bar-widget` | Updated | 7 → 8 | 13 → 19 | 1 ADDED (MBW-7), 2 MODIFIED (MBW-1, MBW-8), 0 REMOVED, Purpose amended |
| `cpu-metrics`, `core-topology`, `cpu-card` | Unchanged | — | — | Not referenced by the delta |

Source of truth now at `openspec/specs/memory-metrics/spec.md`, `openspec/specs/memory-card/spec.md`
and `openspec/specs/menu-bar-widget/spec.md`.

### Destructive-merge warning record (`rules.archive`: "warn before merging destructive deltas")

The `menu-bar-widget` delta rewrites two existing requirements and supersedes one scenario. The user
was warned and confirmed explicitly on 2026-09-06 ("yes, archive it") after being told exactly which
requirements would be rewritten and which scenario would disappear. `verify-report.md` WARNING 6
raised the same gate. Per the config rule the before/after of every MODIFIED block is recorded here.

#### Purpose paragraph

- **Before**: "… rendered at a deterministic width that does not jitter. MEM renders its label, an empty 40 pt sparkline and a `0%` placeholder value until M3; every module in `menuBarOrder` renders a sparkline (decision 2026-09-04: 40 pt each; budget raised to 230 pt so normal spacing fits). Serves PRD R1.2, R1.3, R1.4, R1.6, R1.7, 6.5, 7.2."
- **After**: "… rendered at a deterministic width that does not jitter. MEM binds to `MetricsState.memory` and `memoryHistory`: integer percent of Used/Total and a 60-sample sparkline in `memAccent`; every module in `menuBarOrder` renders a sparkline (decision 2026-09-04: 40 pt each; budget raised to 230 pt so normal spacing fits). Serves PRD R1.2, R1.3, R1.4, R1.6, R1.7, R4.6, 6.5, 7.2."

The delta specified this amendment in prose (the OpenSpec delta format has no section for a Purpose
change), so it was applied as an edit to the Purpose prose only.

#### MODIFIED — `### Requirement: Data-driven module list (Layer: Presentation) — R1.2`

- **Before (body)**: "The status item view MUST render modules from `MetricModule.menuBarOrder` (CPU then MEM). The CPU module MUST bind to `MetricsState` from the environment; the MEM module MAY keep its placeholder value."
- **Before (scenarios)**: 1 — "Order preserved".
- **After (body)**: "ID MBW-1. The status item view MUST render modules from `MetricModule.menuBarOrder` (CPU then MEM). Both modules MUST bind to `MetricsState` from the environment: CPU to `cpu`/`cpuHistory`, MEM to `memory`/`memoryHistory`. No module MAY render a static placeholder value."
- **After (scenarios)**: 2 — "Order preserved" (unchanged text) and the new "Both modules follow state".

#### MODIFIED — `### Requirement: Every module renders a sparkline`

- **Before (body)**: "Every module in `menuBarOrder` MUST render a 40 pt sparkline in its accent color, including modules whose history is empty. Sparkline width is structural, never data-driven. Serves PRD F1, R1.2, R1.7."
- **Before (scenarios)**: 1 — "MEM placeholder still has a sparkline" (`- GIVEN menuBarOrder == [.cpu, .memory]` and the MEM history is empty / `WHEN` the widget renders / `THEN` the MEM module shows its label, an empty 40 pt sparkline area and `0%` / `AND` the total content width measured at `100%` for both modules is under 230 pt). **This scenario is gone from the spec of record** — deliberately, because MEM is no longer a placeholder.
- **After (body)**: "ID MBW-8. Every module in `menuBarOrder` MUST render a 40 pt sparkline in its accent color, including modules whose history is empty. Sparkline width is structural, never data-driven. Serves PRD F1, R1.2, R1.7, R4.6."
- **After (scenarios)**: 2 — "MEM live sparkline" (30 values rendered in `memAccent` with the integer percent) and "MEM empty history still has a sparkline" (the width-budget assertion the deleted scenario carried is preserved verbatim inside it).

Migration recorded by the delta and executed during apply: the test
`StatusItemReadingsTests.theMemoryModuleStaysAPlaceholder` was deleted and replaced by the MBW-7 and
MBW-8 cases. No behaviour lost coverage: the 230 pt width budget is still asserted by
`theMemoryModuleKeepsItsSparklineWithoutHistory` and
`StatusItemControllerTests.theWidgetStaysUnderTheWidthBudgetAtFullScale`.

#### ADDED — `### Requirement: MEM live value and sparkline (Layer: Presentation) — R1.3, R1.4, R4.2, R4.6`

MBW-7 with its four scenarios (MEM value from fraction, MEM newest 60 samples, MEM before first
snapshot, MEM accent) was appended to the Requirements section. Nothing else in
`openspec/specs/menu-bar-widget/spec.md` was touched: the six requirements the delta does not mention
(Integer percentage value, Sixty-sample sparkline, Fixed-width jitter-free layout, Live updates,
Legibility, plus the two modified ones) are all still present, in their original order.

Delta annotations belonging to the change (`(Previously: …)` lines, the `## ADDED/MODIFIED/REMOVED`
headings and the `## REMOVED Requirements — None.` note) were not carried into the spec of record;
they remain in the archived delta at `specs/menu-bar-widget/spec.md`.

### Mechanical readback evidence

Every copy and the archive move used shell commands only (`cp`, `cp -R`, `mktemp`, `mv`) and was
verified with `diff -r`. Every comparison produced **no output** (exit 0).

- `memory-metrics`: `diff -r openspec/changes/memory-module/specs/memory-metrics/spec.md <staged temp>` → no differences; `diff -r <change spec> openspec/specs/memory-metrics/spec.md` → no differences.
- `memory-card`: same two comparisons → no differences.
- Archive move: a recursive pre-move snapshot was taken with `cp -R`, then `diff -r <snapshot> openspec/changes/archive/2026-09-06-memory-module` → no differences.
- `git mv` failed with status 128 (`fatal: source directory is empty` — no file under `openspec/changes/memory-module/` was tracked; the folder was created after commit `60cca91`). The guarded fallback ran: the source was proven byte-identical to the snapshot and the destination proven absent before a plain `mv` was used. Expected consequence of an untracked working folder, not a defect.
- `openspec/specs/menu-bar-widget/spec.md` was **merged, not copied**: three targeted edits (Purpose, two MODIFIED blocks) plus one appended ADDED requirement, recorded above and confirmed by `git diff --stat` → 48 insertions, 7 deletions, and by a heading inventory showing 8 requirements / 19 scenarios.

---

## 3. Final state at close

Authoritative closing numbers. Where `verify-report.md` (rev 2) or `apply-progress.md` state
something different, the difference is called out; those documents are historical snapshots.

| Fact | Value |
|---|---|
| Tests | **299 passed, 0 failed, 0 skipped** (exit 0) — history 188 baseline → 249 (A) → 288 (B) → 294 (C) → 299 (D) |
| Build | clean — exit 0, zero compiler warnings under Swift 6 strict concurrency |
| Tasks | **35 / 35** complete, 0 unchecked (7 phases + the 4-task Phase 8 correction) |
| Requirements / scenarios | **23 / 23** and **51 / 51** traced to evidence (49 to a passing runtime test; MM-10 documentation, MC-10 inspection) |
| Verify verdict | rev 2 `pass_with_warnings` — 0 blockers, 0 CRITICAL, 10 warnings, 4 suggestions (Engram 8227) |
| Manual check (task 7.3) | **PASSED 2026-09-06** — see below |
| Coverage | not measured — the scheme does not enable code coverage (informational) |
| Tracked diff | 11 files changed, 651 insertions, 79 deletions (excluding `openspec/`) |
| New untracked files | 20 under `system-monitor/` and `system-monitorTests/` (9 production, 11 test) |
| `project.pbxproj` | untouched — `git status --short system-monitor.xcodeproj` empty |

Test command: `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`
Build command: `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build`

### Task Completion Gate

Passed without reconciliation. The persisted `tasks.md` showed 35 checked and 0 unchecked
implementation tasks before any spec sync or move, and native SDD status independently reported
`task_progress 35/35`, `dependencies.archive: ready`, `nextRecommended: archive`. No archive-time
checkbox repair was performed and none was needed.

---

## 4. The post-verify correction (batch D) — what actually shipped

Verification revision 1 (2026-09-06, `pass_with_warnings`) gated archive on the manual Activity
Monitor comparison (task 7.3). The user ran it and it **failed its 100 MB tolerance**: the card's Used
read 0.27–0.42 GB below Activity Monitor's "Memory Used", while Total, Wired, Compressed and App
matched exactly. A three-minute `vm_stat` window showed Activity Monitor's own unattributed remainder
(Used − App − Wired − Compressed) reaching 0.95 GB, which the shipped formula could not produce.

User decision 2026-09-06 (Engram 8218): "do it as the activity monitor does so the user sees the same
thing". The Totals matched, so design decision 3's `hw.memsize_usable` fallback was **not** applied;
the formula was corrected instead, under Strict TDD, as bounded work unit
`apply-correction-used-formula-activity-monitor-match` (design decision 14, revision 3):

- **Used** = Total ⊖ free_count × p ⊖ external_page_count × p — spelled Total ⊖ Free ⊖ Cached.
- **Cached** = (external + speculative) × p.
- **Free** = (free − speculative) × p.
- **App, Wired, Compressed**: unchanged. Purgeable pages leave App but stay inside Used.
- `Used + Cached + Free == Total` still holds by construction, because Free and Cached share exactly the speculative pages.
- Fixtures re-derived: `eightGiB.freeCount` 107 588 → **112 588** (so the card keeps its reference numbers), `reference.used` = **6 787 694 592**.
- `PRD.md` R4.2 and 6.2 amended to match; the formula is stated identically in `MemoryUsageCalculator.swift`, spec MM-2, spec MM-3, `design.md` decision 14, `PRD.md` R4.2 and `PRD.md` 6.2 (rev 2 Formula Consistency Audit).
- `SegmentLegend` was rewritten in the same batch: single-line `fixedSize` labels inside `ViewThatFits`, one row while it fits and two otherwise (design decision 15), fixing the observed mid-word breaks ("Compre / ssed").
- Phase 8 tasks 8.1–8.4 are complete.

Verification revision 2 re-traced all 51 scenarios against the amended spec text and re-ran the
suite: 299/299 tests, 35/35 tasks, `pass_with_warnings` (Engram 8227). Revision 1 is superseded.

### Manual verification, 2026-09-06 (Engram 8229) — the rev 2 archive gate, now CLOSED

`verify-report.md` rev 2 WARNING 1 states that archive is gated on the user's final visual re-check of
the rebuilt app, and that nothing in the repository can prove it. **That check was run after the
report was written and it passed.** Result on the Apple M4 Pro (24 GiB):

| Measurement | Card | Activity Monitor | Δ |
|---|---|---|---|
| Used | 17.32 GB | 17.38 GB | **60 MB** (metric: ≤ 100 MB) |
| Total | 24 GB | 24.00 GB | exact |
| Compressed | 2.57 GB | 2.57 GB | exact |
| Wired | 3.36 GB | 3.47 GB | sampling offset between the two readings |

The legend no longer wraps mid-word. Before the correction the Used gap was 0.27–0.42 GB. WARNING 1
is therefore **CLOSED at archive time**; the `verify-report.md` text preserved in this archive still
describes it as open, which is the correct historical record of the moment it was written.

---

## 5. Verification warnings — closing disposition

`verify-report.md` rev 2 (Engram 8227) raised 10 warnings. Two were closed after that report was
written; the rest are carried as documented debt or as deliberate records. No CRITICAL issue was ever
raised, so no archive block applied and no CRITICAL override was requested or used.

| ID | Subject | Disposition at close |
|---|---|---|
| W1 | User's final visual re-check outstanding; archive gated on it | **CLOSED** — run 2026-09-06, Δ 60 MB, within tolerance (section 4, Engram 8229). |
| W5 | `MemoryUsageCalculator.swift:10` doc comment read "Only file-backed and speculative pages leave Used", contradicting the spec's "free and file-backed" | **CLOSED** — one-line doc comment corrected post-verify to "Only free and file-backed pages leave Used"; the build was re-run clean afterwards. Code and formula were always correct; this was wording only. |
| W3 | `apply-progress.md` D24 and its roll-up claim a cosmetic `project.pbxproj` re-sort was "left as found" (12 files / 653 / 81) | **STALE PROSE, tree is correct** — the re-sort was reverted; `git status --short system-monitor.xcodeproj` is empty and the real tracked diff is **11 files, 651 insertions, 79 deletions**. `apply-progress.md` is archived unedited as an immutable snapshot; this report carries the real numbers (section 3). |
| W6 | `menu-bar-widget` delta is destructive; archive must confirm before rewriting the main spec | **CLOSED** — explicit user confirmation 2026-09-06 with the consequences stated; before/after recorded in section 2. |
| W7 | Engram `apply-progress` mirror split across 8226 and 8230 | **RECORDED** — both ids carried in section 1; the archived file is the single complete document. |
| W2 | MC-10 "Reduce motion" verified by code inspection only | **OPEN — debt.** The accessibility environment is not injectable from this unit target; the mechanism is byte-for-byte the `CPUCard` precedent. Same class of gap as CPUCard's. |
| W4 | MM-3 "Fraction" keeps pre-correction numbers on purpose (D20) | **ACCEPTED** — the scenario is a statement about `MemorySnapshot` arithmetic on a hand-built value, not about the calculator formula; MM-3's spec text was not amended. Flagged so a future reader does not mistake it for a stale expectation. |
| W8 | Wall-clock loop tests (debt W1/W5 inherited from `cpu-module`) | **OPEN — debt**, unchanged, not worsened: batch D added no wall-clock cases. |
| W9 | `StatusItemControllerTests` leak `NSStatusItem`s (debt W6 inherited) | **OPEN — debt**, pre-existing and untouched. |
| W10 | Design deviation D14 — new views omit the explicit `@MainActor` | **BENIGN** — `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` infers identical isolation; matches every existing view. |

### Suggestions carried forward (from `verify-report.md` rev 2)

- **S1** — closed by the W5 doc-comment fix above.
- **S2** — add an `.integration` assertion pinning `used + cached + free == total` against the real host, to catch a future refactor that reintroduces the literal `Total − free − external` form (which can overshoot when `speculative > free`).
- **S3** — promote MC-10 and the `CPUCard` reduce-motion precedent to real assertions when the accessibility environment becomes injectable.
- **S4** — migrate `MetricsSamplerLoopTests` onto the already-injected `clock: any Clock<Duration>` to remove the last wall-clock dependency.

### Configuration drift noted, not silently fixed

`openspec/config.yaml` still declares `swift_version: "5.0 (SWIFT_VERSION build setting)"` while the
project builds under Swift 6 strict concurrency (`project.pbxproj` says 6.0). Documentation only; no
code, test or spec depends on it. Recorded here rather than edited during archive.

---

## 6. Bookkeeping note — attempt ledger

Attempts settled complete for apply batches A, B and C, for correction batch D, and for verify
revision 2. One **maintainer reset was executed on 2026-09-06 with the user's authorization**: the
verify revision 1 work unit carried a 100-line budget while the report itself is 261 lines. This is an
accounting artifact of the attempt ledger, not a verification failure — both the build and the test
run settled at exit 0.

---

## 7. Repository state at close

| Check | State |
|---|---|
| Commits | **None made by this change.** Delivery is user-owned; `rules.apply` forbids committing. `tasks.md` proposes seven work units (one per phase) plus the batch D correction as an eighth. |
| Tracked changes | 11 files changed, 651 insertions, 79 deletions (outside `openspec/`) |
| New files | 20 untracked under `system-monitor/` and `system-monitorTests/` — 9 production (incl. `MachMemoryProvider`, `MemoryUsageCalculator`, `MemorySnapshot`, `MemoryPageCounts`, `MemoryMetricsProvider`, `ByteFormatter`, `StackedBar`, `SegmentLegend`, `MemoryCard`) and 11 test files (incl. `SegmentLegendTests`) |
| `project.pbxproj` | **Untouched.** New Swift files join the targets through `PBXFileSystemSynchronizedRootGroup`. |
| Dependencies | **None added.** |
| Isolation convention | `system-monitor/swift6-nonisolated-domain` holds: every new Domain/Infrastructure/formatting/model type and every nested type is explicitly `nonisolated` and `Sendable`; no test suite is `@MainActor`; no `@unchecked Sendable`. |
| Swift sources / `PRD.md` | Not modified by this archive phase. |

---

## 8. What shipped

M2 left the MEM slot showing a static `0%` with an empty sparkline and a `PlaceholderCard("Memory")`.
This change makes memory live end to end, reusing the port/adapter/sampler shape `cpu-module`
established:

- **Domain** — `MemoryPageCounts` (seven `natural_t` counters widened to `UInt64`, plus page size and total), the `MemoryMetricsProvider` port, the pure saturating `MemoryUsageCalculator` (Activity Monitor formula, revision 3), and `MemorySnapshot` with a stored `used`, a clamped `fraction` and `unattributedUsed`.
- **Application** — `MetricsState.memory` / `memoryHistory` (capacity 120) with a separate `apply(memory:)`, and a `MemorySamplingStep` read inline in the existing single `Task.detached(priority: .utility)` loop: one syscall per tick, memory publishes on iteration 1 while CPU keeps its second-sample rule, and either read failing never stops the other.
- **Infrastructure** — `MachMemoryProvider` over `host_statistics64(HOST_VM_INFO64)` into a caller-owned struct (no `vm_deallocate`), `host_page_size()` and `ProcessInfo.physicalMemory` cached at init, with a `validate(returnedCount:)` seam that makes the truncated-reply case a plain unit test.
- **Presentation** — four `Palette` tokens, `ByteFormatter` (`ByteCountFormatStyle(.memory)` over `Int64(clamping:)`), the metric-agnostic `StackedBar` / `StackedBarGeometry` and `SegmentLegend`, and the `MemoryCard` + pure `MemoryCardModel` pair (ring gauge, four rows, six-segment bar including the unlabelled `.unattributed` remainder, legend, history graph last). `PlaceholderCard` is deleted.
- **Menu bar** — `StatusItemReadings.build(cpu:cpuHistory:memory:memoryHistory:)` binds MEM to live state with no layout constant moved; the widget still measures under the 230 pt budget.
- **Composition root** — `AppDelegate` constructs and injects `MachMemoryProvider()`.

---

## 9. Next

**Next milestone: M4** (settings, launch at login, light mode, asset-catalog palette) as its own SDD
change. Constraints to carry forward: the 230 pt widget budget has roughly 9 pt of headroom, so a
third menu-bar module does not fit; memory pressure and swap remain out of v1 scope; GPU is PRD
section 11 (v2). The best available test-hardening work is the W8 clock migration and the S2
integration invariant. Delivery of this change — commits and any PR — remains user-owned and is
untouched by this archive.

## SDD Cycle Complete

`memory-module` has been explored, researched, proposed, specified, designed, planned, implemented
under Strict TDD, corrected once against the running system, independently verified, and archived.
`memory-metrics` and `memory-card` are new sources of truth under `openspec/specs/`, and
`menu-bar-widget` now describes a live MEM module.
