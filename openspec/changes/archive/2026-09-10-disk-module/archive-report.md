# Archive Report: disk-module (PRD M5 — "Disk — ship v1")

**Change**: `disk-module`
**Created**: 2026-09-06 · **Archived on**: 2026-09-10
**Archived to**: `openspec/changes/archive/2026-09-10-disk-module/`
**Artifact store**: hybrid (OpenSpec files under `openspec/` + Engram observations)
**Milestone**: PRD M5 "Disk — ship v1"; feature F10 and requirements R10.1–R10.11; also R2.2 (third card in the CPU, Memory, Disk order), R5.1 (one sampler drives every provider), R5.3 (off-main reads); PRD sections 4.5, 6.1, 6.2, 6.3, 7.1 (`diskAccent`), 7.3, 8, 10.
**Explicitly deferred**: no Disk menu bar module and no `MetricModule` or settings change (R10.11, PRD open question 3); no disk history graph or ring buffer (R10.8); the amber-to-green gradient ring stays P2 (R10.10); GPU stays v2 (PRD section 11).
**Status at close**: complete — verified `pass_with_warnings` (revision 1), 0 CRITICAL findings, 0 blockers; 37/37 tasks complete including all four user-owned manual checks; two new capability specs merged as specs of record with no existing spec of record touched.

This report is the terminal record of the cycle. It describes the state of the change **at close**.
Where it cites `apply-progress.md` or `verify-report.md`, those are intermediate snapshots and are
attributed to their moment in time, never restated as current fact. Section 5 records two places where
this phase found repository evidence contradicting a claim it was handed.

---

## 1. Traceability

### Engram observation IDs (hybrid mirror)

| Artifact | Topic key | Observation ID |
|---|---|---|
| Session preflight | — | 8265 (auto, hybrid, single-pr, unlimited review budget; 2026-09-06) |
| Exploration | `sdd/disk-module/explore` | 8266 |
| Pre-proposal handoff | `sdd/disk-module/pre-proposal` | 8267 |
| Research | — | not selected (user skipped research 2026-09-06; the IOKit, Foundation and sandbox facts were header-verified in the exploration) |
| Proposal | `sdd/disk-module/proposal` | 8268 |
| Specs (2 new capabilities) | `sdd/disk-module/spec` | 8269 |
| Design | `sdd/disk-module/design` | 8274 (revision 1 — see the divergence note in section 5) |
| Tasks | `sdd/disk-module/tasks` | 8275 |
| Apply progress | `sdd/disk-module/apply-progress` | 8276 (batches A–C + head of D), 8278 (batch D in full), 8279 (batch E), 8280 (batches F+G) — split because the combined artifact is 68 184 characters against Engram's 50 000-character observation limit |
| Verify report | `sdd/disk-module/verify-report` | 8281 (revision 1) |
| State snapshot | — | 8270 |
| Archive report | `sdd/disk-module/archive-report` | 8283 (this document) |

### Archived filesystem artifacts

| File | Present |
|---|---|
| `exploration.md` | yes |
| `proposal.md` | yes |
| `specs/disk-metrics/spec.md` (DM-1..DM-15, 42 scenarios) | yes |
| `specs/disk-card/spec.md` (DC-1..DC-11, 25 scenarios) | yes |
| `design.md` | yes (with the W3 correction applied by this phase) |
| `tasks.md` (37/37 complete) | yes |
| `apply-progress.md` | yes |
| `verify-report.md` (revision 1) | yes |
| `state.yaml` (`status: ARCHIVED`) | yes |
| `archive-report.md` | this document (additive at archive time) |

`research.md` is absent by design: the research lane was unselected.

---

## 2. Specs synced to the source of truth

| Capability | Delta type | Destructive? | Merged |
|---|---|---|---|
| `disk-metrics` | **New capability** (full spec: DM-1..DM-15, 42 scenarios) | No | Created `openspec/specs/disk-metrics/spec.md` — mechanical `cp`, byte-identical to the delta |
| `disk-card` | **New capability** (full spec: DC-1..DC-11, 25 scenarios) | No | Created `openspec/specs/disk-card/spec.md` — mechanical `cp`, byte-identical to the delta |

**No existing spec of record was modified.** Confirmed before the merge:
`rg -l -i "disk" openspec/specs/` and `rg -n "DM-[0-9]|DC-[0-9]|Disk" openspec/specs/` both returned no
matches, so neither delta had a main spec to compose into and the native `sdd-archive-compose` path was not
required. The proposal's own "Modified Capabilities: None" holds at close: `core-topology`, `cpu-card`,
`cpu-metrics`, `launch-at-login`, `memory-card`, `memory-metrics`, `menu-bar-widget` and `settings` are
byte-unchanged, and their file modification times are all older than this archive.

The `rules.archive` requirement "Warn before merging destructive deltas" had nothing to warn about: two
additive new capabilities, zero removed or rewritten requirements, zero prior normative text lost.

Post-merge `rg` verification:

- Each requirement ID occurs **exactly once** in its spec of record: DM-1..DM-15 (1 each), DC-1..DC-11 (1 each).
- Scenario counts in the specs of record: `disk-metrics` 42, `disk-card` 25 — 67 total, matching the verified count.
- `rg 'ADDED Requirements|MODIFIED Requirements|REMOVED Requirements|RENAMED Requirements|^# Delta for|\(Previously:' openspec/specs/` → **no matches**. No delta scaffolding survived into the source of truth.

### Mechanical readback evidence

New specs of record (`cp` → `diff -r` → `mv` → `diff -r`), verbatim:

```text
### diff -r openspec/changes/disk-module/specs/disk-metrics/spec.md openspec/specs/disk-metrics/.spec.md.KEVRHA
(exit 0)
### post-move diff -r openspec/changes/disk-module/specs/disk-metrics/spec.md openspec/specs/disk-metrics/spec.md
(exit 0)
### diff -r openspec/changes/disk-module/specs/disk-card/spec.md openspec/specs/disk-card/.spec.md.DYA7Q7
(exit 0)
### post-move diff -r openspec/changes/disk-module/specs/disk-card/spec.md openspec/specs/disk-card/spec.md
(exit 0)
ALL SPEC COPIES PASSED
```

Archive folder move (recursive pre-move snapshot vs. destination), verbatim:

```text
MOVE: git mv refused (status 128; change folder is untracked) — falling back to plain mv
### pre-fallback diff -r $snapshot_root/source openspec/changes/disk-module
(exit 0)
### MANDATORY READBACK: diff -r $snapshot_root/source openspec/changes/archive/2026-09-10-disk-module
(diff -r exit status: 0)
READBACK PASSED — no differences
```

`git mv` was refused because the change folder was never tracked (`git ls-files openspec/changes/disk-module`
→ 0 files). The skill's fallback path applied: the source was confirmed byte-identical to the pre-move
recursive snapshot and the destination confirmed absent before `mv` ran. This archive touched neither the git
index nor `HEAD`.

`state.yaml` and this `archive-report.md` were edited/added **after** the readback, so the empty diff above is
evidence of the artifacts exactly as they left the active change folder. The `design.md` W3 correction
(section 5) was applied **before** the snapshot was taken and is therefore inside the byte-identity proof.

---

## 3. Final state at close

These are the authoritative final numbers, per the Final-State Authority hierarchy.

| Fact | Value at close |
|---|---|
| Tasks | **37/37 complete** (33 automated + 4 user-owned manual) |
| Requirements / scenarios | **26/26 requirements, 67/67 scenarios** COMPLIANT |
| Verdict | `pass_with_warnings` (revision 1, 2026-09-10) — 0 blockers, 0 CRITICAL, 4 warnings, 4 suggestions |
| Full test suite | **561 unique cases passed, 0 failed, 0 `warning:` lines** (runs 1 and 3 agree) |
| Unit target | 558 passed, 0 failed |
| Build | exit 0, **0 warnings**, 0 errors under Swift 6 strict concurrency |
| Coverage | **unmeasured** — not configured on the scheme, so PRD section 8's 80 % Domain+Application target has no number attached |
| Commits | **6 conventional commits already on `main`** (`8db467c`..`3a100df`) — see section 9 |
| Diff `41fea44`..`3a100df` | 36 files changed, +3239 / −36 |
| Popover height | 678 pt (two cards) → **871 pt** (three cards; the Disk card adds 175 pt, the shortest of the three because it has no graph) |

Evidence revision recorded by `sdd-verify`: `sha256:e17479bbd34b3d32b30b77304dca13817be67e2fb2991980db4bf5dce678b72b`
(test output hash, identical to the run-of-record hash). Build output hash:
`sha256:c6c942ae32f10d7ae726b8b899d44fd7f6b4deed6071a90a8ef56e6e4c438946`.

### Task Completion Gate

`tasks.md` in the archived folder contains 37 checkboxes, **37 marked `[x]` and 0 marked `[ ]`**. Native
`gentle-ai sdd-status` independently reported `taskProgress: {total: 37, completed: 37, pending: 0,
allComplete: true}` and `dependencies.archive: ready` / `nextRecommended: archive`. The gate passed with no
reconciliation: no stale checkbox was flipped by this phase.

Note the ranking this resolves. `verify-report.md` revision 1 records "33 complete, 4 incomplete — all MANUAL,
user-owned (7.3, 7.4, 7.5, 7.6)". That was true *at verification time on 2026-09-10*. The user executed all
four after that report was written, and `tasks.md` carries a "Manual checks closed" section with the evidence.
**37/37 is the state at close**; the snapshot's "4 incomplete" is valid history, not a current fact.

---

## 4. What was delivered

**Domain** (`Foundation` only; every type `nonisolated` + `Sendable` + `Equatable`)
- `DiskThroughputCounters`: cumulative `bytesRead`/`bytesWritten` (`UInt64`, summed across every block storage driver), `driverCount`, and a `ContinuousClock.Instant` stamped by the adapter at read time and participating in equality.
- `VolumeCapacity` (`total`, `free`) and `DiskSnapshot` (stored `used` computed once in `init` with saturating subtraction; `fraction` guarded at `total == 0` and capped at 1; `readBytesPerSecond`/`writeBytesPerSecond` always both nil or both set).
- `DiskMetricsProvider` port with two independent reads (`readThroughput()`, `readCapacity()`), defined before any adapter.
- `DiskThroughputCalculator.rates(previous:current:)` returning an optional `Rates` pair, so "one rate without the other" is unrepresentable. Returns nil on a nil baseline, `driverCount == 0`, `Δt <= 0`, or either negative byte delta, and the baseline is re-seeded on every tick (R10.4).
- `DiskCapacityCadence.shouldRefresh(lastReadAt:now:minimum:)` with a 10 s default (R10.7).

**Application**
- `DiskSamplingStep`: a `Sendable` value holding the baseline counters, the cached capacity and the instant of the last successful capacity read, with `advanced() -> (snapshot, next)`. It lives as a `var` created **inside** the detached closure and as `inlineDiskStep` for `sampleOnce()`, exactly like `CPUSamplingStep`.
- `MetricsSampler` gained a required `diskProvider:` parameter and reads CPU, memory and disk in the same iteration before any publish (R5.1), on `Task.detached(priority: .utility)` (R5.3).
- Failure isolation (R10.9, DM-10): a `readThroughput()` throw publishes the cached capacity with nil rates and skips the cadence check; a `readCapacity()` throw changes neither the cache nor its stamp so the read retries next tick; nothing publishes when no capacity was ever cached. Neither throw stops the loop.
- Restart semantics (DM-8, the CM-2 analogue): `apply(interval:)` builds a fresh step, so the first tick of the new loop re-reads capacity and re-seeds the baseline, costing exactly one throughput-unavailable tick.
- `MetricsState.disk: DiskSnapshot?` with `apply(disk:)` and **no history** (R10.8, R5.2).

**Infrastructure**
- `IOKitDiskProvider`: iterates `IOServiceMatching("IOBlockStorageDriver")`, sums `Statistics` → `Bytes (Read)`/`Bytes (Write)` with `addingReportingOverflow` saturating at `UInt64.max`, counts only drivers whose dictionary was readable, stamps `ContinuousClock.now` after the sum, and releases the iterator and every driver handle in `defer` while never releasing the consumed matching dictionary. `ReadError { matchingUnavailable, ioKitCall(kern_return_t) }`.
- `VolumeCapacityReader`: `URLResourceValues` on `/` with `.volumeTotalCapacityKey` and `.volumeAvailableCapacityForImportantUsageKey`, plus a pure static `capacity(total:free:) throws(ReadError)` conversion seam that is unit-tested without touching the file system.
- **App Sandbox proof**: the app target sets `ENABLE_APP_SANDBOX = YES`, and the `.integration` suites `IOKitDiskIntegrationTests` and `VolumeCapacityIntegrationTests` run inside the sandboxed test host. The proposal's highest-likelihood risk — that the sandbox filters `IOBlockStorageDriver` `Statistics` — was cleared empirically in batch C with no entitlement.

**Presentation**
- `Palette.diskAccent = sRGB(0x3DD68C)` carrying the "two tokens, one colour" note (same value as `memFree`, the `memCached` precedent).
- `ByteFormatter.capacity(_:locale:)` on `.decimal` and `ByteFormatter.throughput(_:locale:)` (1000-steps `B`/`kB`/`MB`/`GB`/`TB`, exactly one fraction digit at `kB` and above, integer bytes below 1 kB, `/s` suffix, `0 B/s` for zero, negative and NaN).
- `DiskCardModel`: a pure `nonisolated enum` deriving `sections == [.header, .gaugeAndRows, .throughput]`, symbol names, rows, gauge text and fraction, throughput readings and the reduce-motion animation (delegating to `CPUCardModel`, the MC-10 precedent). `DiskCard` is a thin switch; the view tree is identical for nil and populated snapshots, so height is stable by construction.
- `ThroughputLabel` component (icon + monospaced value, `accessibilityLabel` "Read"/"Write", `accessibilityValue` "unavailable" for nil rates) and `PanelCard`/`PanelView.cards = [.cpu, .memory, .disk]` making DC-1's card order a pure array assertion.

**App and documentation**
- `AppDelegate` composition root constructs `IOKitDiskProvider(capacity: VolumeCapacityReader())` and injects it into the single sampler. `MetricModule.allCases` stays `[.cpu, .memory]` and `statusItemLength` is unchanged (R10.11, DM-14).
- `PRD.md` alignment (DM-15): section 6.2 now describes the two-value port (`DiskThroughputCounters` + `VolumeCapacity` behind `DiskMetricsProvider`); R10.5 reads `.decimal`; section 6.3 replaces "Unverified under App Sandbox" with the `ENABLE_APP_SANDBOX = YES` citation and the `.integration` evidence; section 10 records 678 pt → 871 pt and that the popover still fits a 14" display. The Draft v3 header was left unchanged, per this repository's convention for alignment edits.

---

## 5. Contradictions found and resolved by this phase

The archive skill requires that a claim it is handed which repository evidence contradicts be recorded
explicitly rather than resolved silently. Two occurred.

### 5.1 The W3 design correction had not actually been applied

- **Claimed**: `state.yaml:21` (written 2026-09-10 by the orchestrator) and the archive launch prompt both stated `design.md:207 "largest"->"smallest" fixed by the orchestrator 2026-09-10`, i.e. that the design already read "the smallest unit whose scaled value rounded to one fraction digit stays below 1000".
- **Observed at archive time (2026-09-10)**: `design.md:207` still read *"the unit is the **largest** one whose scaled value rounded to one fraction digit stays below 1000"*. The Engram mirror `sdd/disk-module/design` (8274) also still read "largest" and was still at revision 1, created 2026-09-09 22:14:06 and never revised.
- **Resolution**: this phase applied the correction itself, which `verify-report.md` W3 had assigned to archive in the first place ("Correct `design.md:207` when merging the design into the record — this is the one artifact edit archive genuinely owes"). The archived `design.md:207` now reads *"the unit is the **smallest** one whose scaled value rounded to one fraction digit stays below 1000"*. The change is prose-only: `ByteFormatter.throughput`, its tests and DC-6 always followed the examples (999 949 → `999.9 kB/s`, 999 950 → `1.0 MB/s`), which require the smallest such unit.
- **Known residual divergence**: the Engram design mirror **8274 still carries the uncorrected "largest" wording** in decision 3. It was not re-saved, because re-authoring a 42 KB artifact through the model to fix one word is exactly the silent-truncation risk the mechanical-copy contract forbids. A reader of 8274 should apply this one-word correction; the archived `design.md` is the corrected record.
- Note also that the launch prompt called this "decision 7". It is **decision 3** ("Throughput vocabulary and zero") in the design's architecture-decision table; decision 7 is "Disk step state".

### 5.2 The work was already committed before archive ran

- **Claimed**: the archive launch prompt stated "Nothing is committed yet; the orchestrator will commit the seven work units A–G from `tasks.md` after the archive", and `state.yaml:22` recorded `nothing committed as of 2026-09-10`. `verify-report.md` likewise recorded, at verification time, "the whole change is one uncommitted working tree: 17 modified tracked files, 21 new untracked source and test files".
- **Observed at archive time**: `HEAD` is `dfd2c959`, six disk-module commits are on `main` (`8db467c`..`3a100df`), every disk source and test file is tracked, and `git status --short` shows no modified Swift file at all.
- **Resolution**: repository state is directly verifiable and outranks a prompt assertion about repository state. The commits are real and are recorded in section 9. Both the prompt and the two snapshots were written before those commits landed; their claim is valid history, not a current fact. This archive itself committed nothing and staged nothing.

---

## 6. Manual checks (user-executed, 2026-09-10)

All four passed. Evidence for 7.3 and 7.5 is a popover screenshot; 7.4 and 7.6 were confirmed verbally.

| Check | Result |
|---|---|
| **7.3** Card correctness (PRD 2 success metric) | **PASSED** — Disk card renders third with live values: **77.7 %**, Used **383.95 GB**, Free **110.43 GB**, Total **494.38 GB** (Used + Free = Total exactly). Throughput footer live at **4.6 MB/s** read and **285.7 kB/s** write and moving with real I/O. |
| **7.4** Unavailable and motion states | **PASSED** — em dashes rather than `0%` or `0.0 MB/s`; VoiceOver reads "unavailable"; Reduce Motion makes the disk ring jump instead of sweeping. |
| **7.5** Layout | **PASSED** — CPU / Memory / Disk at 12 pt gaps and 320 pt width, matching `docs/reference/05-panel-disk.png`; the 871 pt popover still fits a 14" display; the menu bar widget width and module set are unchanged (R10.11). Locale rendering confirmed with a decimal comma. The ring is solid: the gradient ring stays P2 by product decision, not a defect. |
| **7.6** Instruments (PRD sections 8 / 10) | **PASSED** — confirmed by the user. Note that `verify-report.md` recorded this figure as owed and unavailable at verification time; the check was executed afterwards. No specific average-CPU or resident-size number was recorded into an artifact, so this archive asserts the user's pass and no profiling number. |

---

## 7. Verification warnings and suggestions — disposition at close

**CRITICAL**: none, at verification time and at close.

| ID | At verification (2026-09-10) | Disposition at close |
|---|---|---|
| **W1** | `DiskSnapshot`'s capacity initialiser is declared in a `nonisolated` extension, not in the type body (`design.md:52`) | **Open and intentional.** The move preserves the synthesised memberwise initialiser that DM-3's `used > total` clamp scenario needs; the extension carries an explicit `nonisolated` because an extension does not inherit the type's isolation under default-MainActor. Signature byte-identical. No spec affected. |
| **W2** | `DiskSamplingStep` declares no `init(provider:)` although `design.md:91` sketches one | **Open and intentional.** A custom initialiser would suppress the memberwise form the loop, `sampleOnce()` and the step tests all construct; `tasks.md` 2.4 mandates the memberwise form and the task list won. No spec affected. |
| **W3** | `design.md:207` decision 3 self-contradictory ("largest" vs. examples requiring "smallest") | **CLOSED by this phase** — see section 5.1. Prose only; behaviour was always correct. Engram 8274 retains the old wording. |
| **W4** | One of three `FULL` runs red on `system_monitorUITests.testLaunchPerformance()` | **Open, out of scope.** Xcode-template launch-performance case in the UI target, which this change never touches; batch C reproduced the failure on a clean baseline with every disk file removed. Not a regression, not a blocker; it will keep failing intermittently. |
| **S1** | DC-9 chrome parity pinned as literals (16 / 14 / 6) rather than a comparison | **Open.** `MemoryCard`'s equivalents are `private static` and unreachable. Parity was confirmed by reading both files (`MemoryCard.swift:171-177` → 16 / 14 / 6 / 6 / 13, identical), but a future `MemoryCard` restyle would silently break DC-9 without failing a test. See follow-up 3. |
| **S2** | DC-6's below-1-kB vocabulary pinned under `en_US` only for non-zero values | **Open, no behavioural risk.** Below 1 kB the implementation emits an integer with `grouping(.never)` and no fraction digit, so the string is locale-invariant; `"0 B/s"` is pinned under both locales. A `de_DE` pin would make the invariance explicit rather than incidental. |
| **S3** | Coverage cannot be measured | **Open.** No shared `.xcscheme` ships, so coverage is not enabled and PRD section 8's target has no number. `openspec/config.yaml` correctly records `coverage_threshold: 0` and `coverage.available: false`. **No coverage number is asserted anywhere in this archived record.** |
| **S4** | The `kIOBlockStorageDriver*` aliasing is conformance, not deviation | **Accepted and applied.** Convention 18 explicitly permits the SDK-constant branch once the compile proves `import IOKit.storage` exposes the constants, which both a standalone `xcrun swiftc` probe and the project build did. Section 8 lists it as a resolved convention branch, not as outstanding deviation. |

---

## 8. Documented deviations that stand

These are intentional and permanent. If any future artifact regenerates an interface listing from `design.md`,
it must carry them.

1. **`DiskSnapshot`'s capacity initialiser lives in a `nonisolated` extension**, not the type body — preserves the memberwise initialiser DM-3 needs (W1).
2. **`DiskSamplingStep` has no `init(provider:)`** — the memberwise initialiser is the only one, per `tasks.md` 2.4 (W2).
3. **IOKit class and property names resolved to the SDK `kIOBlockStorageDriver*` constants** rather than private literals — convention 18's permitted branch, proven by compile (S4).
4. **Throughput unit selection is the *smallest* unit whose rounded value stays below 1000** — the corrected decision-3 wording (section 5.1).
5. **`ByteFormatter.capacity(0)` renders `"0 bytes"` / `"0 Byte"`** — the exact ICU strings, pinned at the first RED rather than assumed.
6. **DM-10's first scenario is triangulated with an extra case** — design decision 2's documented deviation from the SHOULD: a throughput throw on call 0 with nothing cached reads capacity once, publishes it with nil rates, leaves `capacityReadAt == nil`, and the next successful tick reads capacity again and stamps it.
7. **DM-14's case waits for non-nil rates** rather than asserting them on the first published snapshot.
8. **DC-9 chrome parity is pinned as the literals 16 / 14 / 6** because `MemoryCard`'s constants are `private static` (S1).

---

## 9. Delivery and repository state at close

**This archive committed nothing and staged nothing.** The implementation, however, was already delivered
before the archive phase ran (section 5.2).

| Commit | Subject | Work unit(s) | Stat |
|---|---|---|---|
| `8db467c` | `feat(disk): domain values, provider port, throughput rate and capacity cadence rules` | A (phase 1) | 12 files, +912 |
| `0eb18ea` | `feat(disk): IOKit block-storage throughput adapter and boot-volume capacity reader` | C (phase 3) | 5 files, +480 |
| `4632731` | `feat(sampling): disk sampling step with capacity cadence, restart semantics and failure isolation` | B (phase 2) + F (phase 5 composition root) | 8 files, +854 / −12 |
| `e14d3a0` | `feat(panel): disk accent token, decimal capacity and per-second throughput formatting` | D (tasks 4.1–4.6) | 5 files, +249 / −4 |
| `20e6b6b` | `feat(panel): Disk card with ring gauge, capacity rows and throughput footer as the third card` | E (tasks 4.7–4.10) | 5 files, +717 / −8 |
| `3a100df` | `docs: align the PRD with the shipped disk module` | G (task 6.1, DM-15) | 1 file, +27 / −12 |

Units B and F landed in one commit rather than two, so the seven planned work units became six commits.
Conventional commits throughout; **no attribution or co-author trailers** on any of them, per repository policy.

| Check | Value |
|---|---|
| `HEAD` | `dfd2c959` (`chore: ignore the CodeGraph index and Pi local state` — a pre-existing `.gitignore` change, **not part of this change**) |
| Disk work diff `41fea44`..`3a100df` | 36 files changed, +3239 / −36 |
| Uncommitted after this archive | `openspec/config.yaml` (modified), `openspec/changes/archive/2026-09-10-disk-module/` (new), `openspec/specs/disk-card/` (new), `openspec/specs/disk-metrics/` (new) |
| Active changes directory | `openspec/changes/` holds only `archive/`; `disk-module` is gone from it |
| Git index | untouched by this archive |

The four uncommitted paths above are this archive's own output plus the config correction in section 10, and
are the natural content of a single follow-up `chore(sdd): archive disk-module change and merge its specs of
record` commit — the same shape as `9e77e42` for `polish-module`. Delivery remains user-owned.

### Receipt-driven review outcome

The START consent envelope (medium risk, 38 files, 3283 lines, lineage `review-004c751229d68643`) was relayed
on 2026-09-10 and the user chose **"Not now, just this once"**. The exact provider-owned decline invocation ran
and returned `consent: declined_this_candidate`. **No review lineage and no receipt exist for this change**,
and delivery followed ordinary repository policy. The native assessment recorded medium risk, with the reason
given as an executable change in `.gitignore` — which belongs to the separate `dfd2c95` chore commit, not to
the disk work. The decline was candidate-scoped and is not the receipt-driven-development kill switch.

---

## 10. `openspec/config.yaml` — staleness corrected

One statement in the config became false because of this change and was corrected:

```diff
 rules:
   proposal:
-    - Reference the PRD feature ID (F1..F9) and milestone (M1..M4) the change serves.
+    - Reference the PRD feature ID (F1..F10) and milestone (M1..M5) the change serves.
```

PRD Draft v3 defines F10 and M5, and this change served exactly those, so the old range would have forbidden
the proposal that shipped it. Nothing else in the config was edited by this phase.

Checked and left alone as still true: the `context` block already read "Draft v3: v1 = CPU + RAM + Disk,
F10/M5 added 2026-09-06" (an uncommitted edit that predates this phase); `coverage.available: false` and
`verify.coverage_threshold: 0` remain accurate (S3); `rules.design`'s "Domain imports Foundation only" holds,
since `ContinuousClock.Instant` is stdlib; `rules.apply`'s "Do not commit" remains the correct instruction to
the apply phase; `Keep GPU work out of v1 scope` is unaffected.

---

## 11. Bookkeeping — attempt ledger

| Work unit | Outcome |
|---|---|
| Batch A (phase 1, Domain) | settled `passed`, then **BLOCKED (`maintainer_decision`)** — settle counted 1202 changed lines (909 authored plus untracked `tasks.md`/`apply-progress.md`) against `--max-changed-lines 900`. The budget was exceeded only because untracked planning files were counted. The user approved a maintainer **reset** on 2026-09-09 (revision `sha256:d15dfe05…`). |
| Batches B, C, D, E | settled `complete` (B at 767 lines, C at 1392 lines) |
| Batches F+G | acquired 3600 lines as one unit; settled `complete` |
| Verify revision 1 | acquired on the first call and settled `passed` with evidence revision `sha256:e17479bb…78b72b`, `--harness-disposition reused` |

**No ledger decision is open at close.**

Review workload: `delivery_strategy: single-pr` with `review_budget_lines: unlimited` and a `size:exception`
accepted by the user up front at preflight (observation 8265). The tasks forecast recorded 1900–2500 estimated
changed lines, `400-line budget risk: High`, `Chained PRs recommended: No`, `Decision needed before apply: No`.
Actual: +3239 / −36 across 36 files, above the high end of the forecast. Units A–G were apply and commit
boundaries, never separate PRs.

---

## 12. Known debt and follow-ups

None of these belongs to this change; all are recorded so a future reader does not rediscover them.

1. **Closed-panel redraw optimization** — carried over from M4, still a separate unclaimed SDD change (`redraw-optimization`): status-item AppKit layout cost per tick, panel Core Animation commit size, building the popover hosting controller on `popoverWillShow`, and the idle cadence as a product knob. M4 closed with an accepted PRD-section-10 miss (about 1.6 % closed-panel CPU against an under-1 % goal); this change added a disk step whose capacity read runs at most every 10 s.
2. **Gradient ring for the Disk card stays P2** (R10.10) — a product decision confirmed at pre-proposal, re-confirmed by manual check 7.5, not a defect.
3. **`system_monitorUITests.testLaunchPerformance()` is flaky** — an Xcode template case in the UI target. A red `FULL` run whose only failure is that case is not a regression; rerun once. Untouched by this change.
4. **Promote `MemoryCard`'s chrome constants to internal `nonisolated static`** so DC-9 can assert parity by comparison instead of literals (S1).
5. **Pin DC-6's sub-kilobyte strings under `de_DE`** as well, making the locale invariance explicit (S2).
6. **Enable code coverage on a shared scheme** so a future verify report can attach a number to PRD section 8's 80 % target (S3).
7. **Engram design mirror 8274 needs the one-word decision-3 correction** — see section 5.1.

---

## 13. Next

- **SDD cycle for `disk-module`: complete.** No further phase is pending.
- **PRD M5 is closed.** With M1–M5 archived, v1 scope (CPU + RAM + Disk) is complete.
- Recommended follow-up change: **`redraw-optimization`** — the M4 performance miss, still unclaimed, and the only known item standing between the current build and PRD section 10's target.
- F7 (light mode / appearance setting) and GPU (PRD section 11, v2) remain out of v1 and unclaimed.
- Remaining user-owned action: commit this archive's output (`openspec/changes/archive/2026-09-10-disk-module/`, `openspec/specs/disk-card/`, `openspec/specs/disk-metrics/`, `openspec/config.yaml`) as one `chore(sdd)` commit, with no attribution trailers.

## SDD Cycle Complete

`disk-module` has been explored, proposed, specified, designed, broken into tasks, implemented under strict
TDD across five layers, verified against every requirement and scenario, manually confirmed on real hardware,
and archived. Two new capability specs — `disk-metrics` and `disk-card` — are now specs of record, and PRD
milestone M5 is closed.
