# Archive Report: network-module (PRD M6 — "Network")

**Change**: `network-module`
**Created**: 2026-09-10 · **Archived on**: 2026-09-10
**Archived to**: `openspec/changes/archive/2026-09-10-network-module/`
**Artifact store**: hybrid (OpenSpec files under `openspec/` + Engram observations)
**Milestone**: PRD Draft v4 M6 "Network"; feature F11 and requirements R11.1–R11.11 (section 5.8); also R2.2 (fourth card in the CPU, Memory, Disk, Network order), R2.5 (visible-frame scroll rule), R5.1 (one sampler drives every provider), R5.2 (120-sample histories), R5.3 (off-main reads); PRD sections 4.6, 6.1, 6.2, 6.3, 7.1 (`networkAccent`, `networkDownload`, `networkUpload`), 7.3, 8, 9, 10.
**Explicitly deferred**: no Network menu bar module and no `MetricModule`, settings or widget change (F9 stays Future, PRD open question 3 answered); no per-interface, per-process, latency, Wi-Fi-signal or VPN accounting; no since-app-launch totals; GPU stays v2 as M7.
**Status at close**: complete — verified `pass_with_warnings` (revision 2), 0 CRITICAL findings, 0 blockers; 37/37 tasks complete including all five user-owned manual checks; two new capability specs created and one existing spec of record (`disk-card`) modified by a two-requirement destructive delta composed natively.

This report is the terminal record of the cycle. It describes the state of the change **at close**.
Where it cites `apply-progress.md` or `verify-report.md`, those are intermediate snapshots and are
attributed to their moment in time, never restated as current fact. Section 5 records what this phase
checked against repository evidence and what it found.

---

## 1. Traceability

### Engram observation IDs (hybrid mirror)

| Artifact | Topic key | Observation ID |
|---|---|---|
| Session preflight | — | 8287 (auto, hybrid, single-pr, unlimited review budget; 2026-09-10) |
| Exploration | `sdd/network-module/explore` | 8288 |
| Pre-proposal handoff | `sdd/network-module/pre-proposal` | 8289 |
| Research | — | not selected (user skipped research 2026-09-10; the SDK header facts are cited in the exploration) |
| Proposal | `sdd/network-module/proposal` | 8290 |
| Specs (2 new capabilities + 1 delta) | `sdd/network-module/spec` | 8291 — **stale mirror, see section 2.4** |
| Design | `sdd/network-module/design` | 8292 (upserted in place by `topic_key`) |
| Tasks | `sdd/network-module/tasks` | 8294 |
| Apply progress | `sdd/network-module/apply-progress` | 8296 (upserted across batches A–G) |
| Verify report | `sdd/network-module/verify-report` | 8302 (**revision 2**, upserted in place over revision 1) |
| State snapshot | — | 8300 |
| Archive report | `sdd/network-module/archive-report` | 8307 (this document) |

### Archived filesystem artifacts

| File | Present | Size (bytes) |
|---|---|---|
| `exploration.md` | yes | 12 152 |
| `proposal.md` | yes | 24 454 |
| `design.md` | yes | 57 483 |
| `tasks.md` | yes | 30 003 |
| `apply-progress.md` | yes | 81 722 |
| `verify-report.md` | yes (revision 2) | 58 180 |
| `state.yaml` | yes (`status: ARCHIVED`) | 11 721 |
| `specs/network-metrics/spec.md` | yes | 19 705 |
| `specs/network-card/spec.md` | yes | 13 584 |
| `specs/disk-card/spec.md` (delta) | yes | 3 273 |
| `archive-report.md` | this document (additive; did not exist in the pre-move snapshot) | — |

---

## 2. Specs synced to the source of truth

| Domain | Action | Details |
|---|---|---|
| `network-metrics` | **Created** | NM-1 … NM-13 — 13 requirements, 43 scenarios. Full-spec mechanical copy (`cp`), no main spec existed. |
| `network-card` | **Created** | NC-1 … NC-13 — 13 requirements, 30 scenarios. Full-spec mechanical copy (`cp`), no main spec existed. |
| `disk-card` | **Updated** | 2 requirements MODIFIED (DC-1, DC-11), 0 ADDED, 0 REMOVED, 0 RENAMED. Composed by `gentle-ai sdd-archive-compose` (exit 0). Requirement count unchanged at 11; scenario count 25 → 27. DC-2 … DC-10 preserved byte-identical. |

Untouched specs of record, confirmed by `git status --porcelain openspec/specs/`: `menu-bar-widget`, `settings`,
`launch-at-login`, `cpu-card`, `cpu-metrics`, `memory-card`, `memory-metrics`, `disk-metrics`, `core-topology`.
Only `openspec/specs/disk-card/spec.md` shows as modified.

### 2.1 Destructive-delta warning (`openspec/config.yaml` → `rules.archive`: "Warn before merging destructive deltas")

The `disk-card` delta is **destructive on two requirements**: it replaces the whole body of DC-1 and the whole
body of DC-11, including DC-1's "Card order" scenario text and DC-11's unbounded-popover clause. Nothing else in
`disk-card` was removed, and no requirement was deleted. Before/after below, followed by the full mechanical evidence.

#### DC-1 Presentational contract and panel placement — before

> `DiskCard` MUST accept only a `DiskSnapshot?` … `PanelView` MUST render `DiskCard(snapshot: state.disk)` third, after `MemoryCard`, inside the existing 12 pt-spaced stack at 320 pt width.
>
> Scenario "Card order": THEN the order is CPU, Memory, Disk

#### DC-1 — after

> `DiskCard` MUST accept only a `DiskSnapshot?` … `PanelView` MUST render `DiskCard(snapshot: state.disk)` third, after `MemoryCard` **and before the Network card**, inside the existing 12 pt-spaced stack at 320 pt width.
> (Previously: the Disk card was the last card and the panel order ended at Disk.)
>
> Scenario "Card order": THEN the order is CPU, Memory, Disk, **Network**

DC-1's other two scenarios ("Card renders from a fixed input", "Live update while open") are unchanged.

#### DC-11 Panel height — before

> `PanelView`'s fitting height MUST be at least the sum of the CPU, Memory and Disk card heights plus chrome; **the popover has no fixed content size, so it grows with the third card.** Existing lower-bound height assertions MUST stay green.
>
> Scenarios: "Three-card height" only (1 scenario).

#### DC-11 — after

> `PanelView`'s fitting height MUST be at least the sum of the CPU, Memory, **Disk and Network** card heights plus chrome, so it grows with the fourth card. **The presented panel height MUST be bounded by the visible-frame cap specified in `network-card` NC-12 rather than being unbounded, and content MUST NOT be clipped.** Existing lower-bound height assertions MUST stay green.
> (Previously: the height was the three-card sum and the popover had no fixed content size, so it grew without bound.)
>
> Scenarios: "Three-card height" (unchanged), **"Four-card height"** (new), **"Height is bounded by the visible frame"** (new) — 3 scenarios.

The visible-frame cap itself lives in `network-card` NC-12, which is now a spec of record; DC-11 only stops
claiming an unbounded popover. The measured behaviour behind the new clause: four-card fitting height 1 049 pt,
capped to 921 pt at a 945 pt visible frame, uncapped at 1 200 pt.

### 2.2 Native composition invocation (the only merge mechanism used)

```
gentle-ai sdd-archive-compose \
  --canonical "openspec/specs/disk-card/spec.md" \
  --delta "openspec/changes/network-module/specs/disk-card/spec.md" \
  --output "openspec/specs/disk-card/spec.md.compose-tmp"
# exit 0
mv "openspec/specs/disk-card/spec.md.compose-tmp" "openspec/specs/disk-card/spec.md"
```

No model-driven Read/Edit merge was performed on any spec. Requirement headings before and after the
composition: 11 → 11. Scenario headings: 25 → 27.

**One composer behaviour worth recording**: the delta file ends with a `## Verification notes` section
(implementation guidance for `PanelViewTests`), and the native composer carried that section through into
`openspec/specs/disk-card/spec.md`. That is the composer's output, not a model edit, and it was left exactly
as the tool produced it. A future editor of `disk-card` may want to drop it, since the other specs of record
carry no such section.

### 2.3 Mechanical readback evidence (verbatim)

Every copy and move below was performed with `cp`, `mv` or `git mv` only. No artifact content was routed
through Read/Write. Each `diff -r` printed **no output** (byte-identical); the exit status was 0.

```
### diff -r openspec/changes/network-module/specs/network-metrics/spec.md openspec/specs/network-metrics/.spec.md.MOdPru
(empty diff — pass)
### post-move diff -r openspec/changes/network-module/specs/network-metrics/spec.md openspec/specs/network-metrics/spec.md
(empty diff — pass)
### diff -r openspec/changes/network-module/specs/network-card/spec.md openspec/specs/network-card/.spec.md.VJlpnE
(empty diff — pass)
### post-move diff -r openspec/changes/network-module/specs/network-card/spec.md openspec/specs/network-card/spec.md
(empty diff — pass)
ALL COPIES OK
```

Archive move (`git mv` refused because the change folder is untracked — `fatal: source directory is empty,
source=openspec/changes/network-module` — so the contract's guarded `mv` fallback ran after proving the source
was unchanged against the pre-move recursive snapshot):

```
MOVE: git mv failed with status 128 (folder is untracked); evaluating plain mv fallback
### pre-fallback diff -r $snapshot_root/source openspec/changes/network-module
(empty diff — pass)
MOVE: plain mv fallback completed
### MANDATORY READBACK: diff -r $snapshot_root/source openspec/changes/archive/2026-09-10-network-module
(empty diff — pass)
ARCHIVE MOVE OK
```

`archive-report.md` (this file) is additive and did not exist in the pre-move snapshot, so it is excluded from
the source/destination comparison by the Mechanical Copy Contract.

### 2.4 The files were merged, never the Engram mirror

Engram observation 8291 (`sdd/network-module/spec`) predates three amendments and was **not** used as merge
input:

1. **NC-4** amended 2026-09-10 at the apply gate to icon-only tint (the reused `ThroughputLabel` colours only
   its icon; the value text keeps `Palette.textPrimary`).
2. **NM-4** amended after native review #1 — "either reading with `interfaceCount == 0`" plus the new scenario
   "Zero-interface baseline yields nil".
3. **NM-10 / NM-11** rewritten after manual check 7.3 to the IFMIB `IFDATA_GENERAL` per-interface source, with
   the `isMissingInterface(errno:)` seam and `Int32(bitPattern:)` conversion, adding three scenarios.

The merged specs of record therefore carry 43 + 30 network scenarios, not the mirror's pre-amendment counts.

---

## 3. Final state at close

### Verification (revision 2, 2026-09-10 — the authoritative record)

| Field | Value |
|---|---|
| Verdict | `pass_with_warnings` |
| Blockers / CRITICAL findings | 0 / 0 |
| Requirements | 28 / 28 covered |
| Scenarios | 79 / 79 covered (3 reach only partial depth: W1', W9, W2') |
| `UNIT` (`-only-testing:system-monitorTests`) | exit 0 — **667 passed / 0 failed**, 0 warnings |
| `FULL` (adds 3 XCUITest cases) | exit 0 — **670 passed / 0 failed**, 0 warnings |
| `BUILD` | exit 0 — **0 warnings** under Swift 6 strict concurrency |
| Evidence revision | `sha256:ba5dff0e1f3815404f9e7f523b922402be49337881585ed89cfe99e5fd70d5d9` |
| Validator | `gentle-ai sdd-verify-validate --requirements 28 --scenarios 79` → `valid: true` |
| Strict-TDD audit | 8/8 checks passed, including RED-before-GREEN for both post-verify corrections |
| Assertion quality | 0 CRITICAL, 0 WARNING |
| Coverage | not measurable (no shared `.xcscheme`); no number asserted — S1 |

**Revision 1 is superseded, not merely supplemented.** It reported `28/75` against a 75-scenario spec set and
the native dispatcher refused archive on the stale total. Revision 2 re-measured all 79 scenarios against the
current spec files and the current tree. Two of revision 1's findings are formally withdrawn: **W1's risk half**
(the zero-interface defect it gestured at was found by the review, fixed and tested) and **W4** (which claimed
`UNIT` does not exercise the `.integration` suites — it does, because those suites live inside the
`system-monitorTests` target, and `FULL` adds only the three XCUITest cases). Revision 1's routing-socket source
claims are superseded by the IFMIB rewrite.

### Task Completion Gate

| Metric | Value | Evidence |
|---|---|---|
| Tasks total | 37 | `tasks.md`, 7 phases |
| Checked `- [x]` | 37 | `grep -c '^\s*- \[x\]' tasks.md` → 37 |
| Unchecked `- [ ]` | **0** | `grep -c '^\s*- \[ \]' tasks.md` → 0 |

The gate passed on the persisted artifact with no reconciliation. No stale-checkbox repair was needed or
performed, and no partial-archive override was requested or used. Task 3.3 is a contingency whose own text
authorises recording itself as skipped ("not needed, every Darwin name imported at 3.2") and is counted complete.

**`state.yaml`'s `phases.apply` line still reads "automated tasks 32/37 … manual 7.3-7.7 open for the user".**
That is the apply phase's own history entry, true when apply wrote it, and it is preserved as audit trail. It is
**not** the state at close: manual 7.3–7.7 were confirmed passed by the user on 2026-09-10 and tasks are 37/37.
`phases.archive` records the final state.

---

## 4. What was delivered

**Domain** (all `nonisolated` + `Sendable`): `NetworkThroughputCounters` (`bytesIn`, `bytesOut`,
`interfaceCount`, adapter-stamped `ContinuousClock.Instant`), `NetworkSnapshot` (since-boot `totalIn`/`totalOut`
plus a rate pair that is both-or-neither), the single-method `NetworkMetricsProvider` port, and the pure
`NetworkThroughputCalculator` (Δbytes/Δt; `nil` when there is no baseline, when **either** reading has
`interfaceCount == 0`, when Δt ≤ 0, or on any negative delta, with the caller always re-seeding).

**Application**: `NetworkSamplingStep` as a `var` inside the existing single `Task.detached(priority: .utility)`
loop plus `inlineNetworkStep` for `sampleOnce()`; `MetricsSampler` gained a required `networkProvider:`; the
network read joins the same iteration as CPU, memory and disk before any publish (R5.1); `MetricsState.network`,
`networkDownloadHistory`, `networkUploadHistory` and `apply(network:)`, which appends to both histories or to
neither so the two series keep a shared x axis.

**Infrastructure**: `SysctlNetworkProvider` reading the interface MIB — the row count from
`{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT}`, then one
`{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL}` read per index into a
`struct ifmibdata` — with the pure `includes(type:flags:)` filter seam (`IFT_ETHER` + `IFT_CELLULAR`, not
`IFF_LOOPBACK`, no `IFF_UP`/`IFF_RUNNING` requirement), the pure `isMissingInterface(errno:)` sparse-index seam,
`Int32(bitPattern:)` for `ifmd_flags`, saturating sums, and `ReadError { countQuery(errno:),
interfaceRead(index:errno:) }`. 14 interfaces are admitted on the development machine; the sandboxed test host
is the proof of access.

**Presentation**: `NetworkCard` + pure `NetworkCardModel` (sections `[.header, .ratesAndTotals, .graph]`, two
12 pt `ThroughputLabel` readings, Total In / Total Out rows, em dash + "unavailable" for nil rates, shared-scale
`graphSeries` with a ~10 kB/s floor, `readingColors`, `animation(reduceMotion:)`); a multi-series
`HistoryGraph(series:capacity:)` with the single-series initialiser kept as a convenience so the CPU and Memory
call sites are byte-identical; `PanelLayout` with the pure visible-frame cap rule; `PanelRootView` and
`PanelView(maxHeight:)`; `StatusItemController` resolving the presenting screen's visible frame at show time;
`Palette.networkAccent` `0xC659E4`, `networkDownload` `0x3DD68C` (= `memFree`, `diskAccent`), `networkUpload`
`0x4D8DFF` (= `cpuAccent`).

**App**: the composition root constructs `SysctlNetworkProvider()` and injects it into the single sampler. No
`MetricModule` case, no persisted setting, no widget or login-item change.

**Documentation**: `PRD.md` to Draft v4 (F11, section 5.8 R11.1–R11.11, R2.5, milestone M6 Network, GPU → M7)
with dated correction notes on R11.1, R11.4, 6.1, 6.3 and section 8; `openspec/config.yaml` proposal rule widened
to F1..F11 / M1..M6 and its `context` line updated; `docs/reference/06-panel-network.png` added.

**Measured values for the record**: four-card panel 1 049 pt (370 CPU + 278 memory + 175 disk + 166 network +
60 chrome); Network card 166 pt; cap 921 pt at a 945 pt visible frame; `networkAccent` `0xC659E4` as raw device
bytes; 14 admitted interfaces on the development machine.

---

## 5. What this phase checked, and what it found

This phase re-derived every fact it could from the repository rather than trusting a handed claim.

| Claim handed to archive | Repository evidence at close | Outcome |
|---|---|---|
| Tasks 37/37, none unchecked | `grep -c` on the persisted `tasks.md`: 37 checked, 0 unchecked | **Confirmed** |
| Verify revision 2: 28/28, 79/79, `pass_with_warnings`, 0 critical | `verify-report.md` front matter and verdict section | **Confirmed** |
| Nothing committed; HEAD `de40106` | `git rev-parse --short HEAD` → `de40106`; no new commits | **Confirmed** |
| 18 modified tracked files + 19 untracked before archive | 19 modified + 21 untracked **after** archive; the deltas are exactly this phase's own writes (`openspec/specs/disk-card/spec.md`, `openspec/specs/network-card/`, `openspec/specs/network-metrics/`) and the change folder's new path | **Confirmed and reconciled** |
| No production code retains the routing-socket walk | `grep -rn 'NET_RT_IFLIST2' system-monitor/` → exactly one hit, the required doc comment at `SysctlNetworkProvider.swift:13` | **Confirmed** |
| PRD carries the corrected IFMIB data source | `PRD.md` R11.1 (:190), the 6.1 tree (:223), the 6.3 row (:325) and section 8 (:394) all describe the interface MIB with dated correction notes | **Confirmed** |
| The delta touches only DC-1 and DC-11 | Composer diff shows three hunks, all inside DC-1 and DC-11; DC-2…DC-10 byte-identical | **Confirmed** |
| No other spec of record is touched | `git status --porcelain openspec/specs/` lists only `disk-card` modified plus the two new directories | **Confirmed** |

**No contradiction was found between the launch prompt's final-state facts and repository evidence.** Nothing in
this section required an unrankable-contradiction record.

**One reading caveat about the archived artifacts themselves** (recorded, not corrected — the archive is an
immutable audit trail):

`design.md` carries a dated amendment section, "Amendment to decision 2 (2026-09-10, after manual check 7.3)",
which states plainly that decision 2 and the Infrastructure read shape above it were wrong and that the adapter
now reads the interface MIB. That amendment is authoritative for the design. However, several **other** passages
in the same file were not rewritten and still describe the routing socket: the Technical Approach bullet
(`design.md:11`), the interface sketch (`:114`), the imports paragraph (`:127`), the data-flow line (`:242`), the
file-changes row (`:261`) and the PRD-alignment items (`:363`, `:366`). `tasks.md` convention 7 (`:22`), the
batch C work-unit row (`:48`) and tasks 3.2/3.3 (`:76`, `:77`) likewise still name `NET_RT_IFLIST2`. A future
reader must take the **specs of record** (`openspec/specs/network-metrics/spec.md` NM-10, which explicitly
forbids the routing socket) and the production source as authoritative over those pre-amendment passages. The
same applies to the design's `networkAccent` estimate `#A66BFF` and its "~1050 pt" placeholder, superseded by
the measured `#C659E4` and 1 049 pt / 921 pt.

---

## 6. Manual checks (user-executed, 2026-09-10, on the corrected IFMIB build)

| Task | Check | Result |
|---|---|---|
| 7.3 | Live rates during a large download and upload | **Passed** — rates moved through 4 GB of transfer with no em dash and no apparent totals reset. **Peak figures were not reported back.** |
| 7.4 | Total In / Total Out against Activity Monitor's Data received / sent | **Passed** — same order of magnitude. |
| 7.5 | 14" visible-frame cap | **Passed** — the four-card popover pinned below the visible frame and scrolled to the Network card on the **first** open, so design open question 5 (root-swap timing) is closed with no move to `popoverWillShow`. |
| 7.6 | Rendered accent, unavailable state, Reduce Motion | **Passed** — globe accent matched the pinned value, the no-rate path showed em dashes rather than `0 B/s`, Reduce Motion changed nothing observable. |
| 7.7 | Instruments Time Profiler, panel closed | **Passed** — average CPU under 1% (PRD 10). **The CPU and resident-size figures were not reported back.** |

**The user reported pass/fail only.** Task 7.3's peak rate figures and task 7.7's average-CPU and resident-size
numbers were **confirmed by the user, figure not reported**. PRD sections 8 and 10 therefore keep the verdict
without the value, and this report does not invent one. Recorded as W5' in the verification report and carried
below as a recording gap.

---

## 7. Verification warnings and suggestions — disposition at close

All nine warnings and five suggestions are non-blocking; none contradicts a scenario.

| # | Warning | Disposition at close |
|---|---|---|
| W1' | NM-10's "No admitted interface is not an error" has no adapter-level test; both zero-interface paths are unreachable on a host that admits 14 interfaces and the adapter exposes no injection seam | **Carried as coverage depth.** The risk half of revision 1's W1 is withdrawn: the real defect (zero-interface reading accepted as a delta baseline) was found by review #1, fixed in the calculator and covered by two tests. |
| W2' | NC-3's tint and `.isHeader` are static-only evidence | **Carried.** Reduced by manual 7.6, which confirmed the rendered accent on the running app. |
| W3' | NC-4's colour clause is pinned at `NetworkCardModel.readingColors`, not at the pixel | **Accepted.** This is the strongest coverage available without a rendering test, and it is the residue of the NC-4 amendment. |
| W5' | Manual figures confirmed but not reported | **Carried as a recording gap.** See section 6. |
| W6' | The `networkAccent` pin `0xC659E4` is a raw-device-byte value; the same pixel in sRGB reads `0xD276EA` because the mockup PNG carries an "Odyssey G5" display profile | **Documented artefact, not a defect.** A future check in an sRGB-converted mode will appear to disagree by roughly 0x0C/0x1D/0x06 per channel. |
| W7' | `-quiet` xcodebuild logs drop characters, in more than one place and shape | **Documented method note.** Match on `case '<id>'`, count `failed` lines separately, cross-check against the `@Test` declaration count. Related: `-only-testing` takes the Swift Testing *suite type* name, never a file name. |
| W8 | The truncation witness reads the same MIB the adapter reads (review #2 advisory `R3-truncation-witness-shares-source`) | **Carried.** It is independent of the adapter, not of the source; the cross-source probe covering that residue was a one-off, not a test. |
| W9 | NM-10's "A missing index is a gap, not a failure" is pinned at the `isMissingInterface(errno:)` seam, not at the `interface(at:)` wiring | **Carried.** Reaching it from a test needs an errno-injection seam the amended design deliberately did not add. |
| W10 | Three review #2 advisory findings carried unfixed: `R3-all-gaps-become-valid-empty`, `R3-cap-not-reapplied-while-shown`, `R3-churn-without-net-fall` | **Carried as later work.** All three are behaviour the merged specs currently permit. |

Suggestions S1 (coverage unmeasurable — no shared `.xcscheme`), S2 (NC-9's "existing call sites unchanged" rests
on a convenience-init equality plus a diff reading), S3 (two documented intermittents: the XCUITest
automation-mode handshake timeout and `testLaunchPerformance()`), S4 (`MachIntegrationTests.swift:107` is
conditionally enabled on a two-performance-level topology, so 666 rather than 667 on a different machine is not
a missing test) and S5 (the interface MIB costs one `sysctl` per interface per tick — about twenty on this
machine — the figure to watch if the interval shortens) are recorded and carried.

---

## 8. Documented deviations that stand

1. **NC-4 was amended during apply, not implemented as originally written.** The original clause asked for
   coloured value text; the reused `ThroughputLabel` colours only its icon. The apply gate failed attempt 1 for
   recording the divergence nowhere; the spec was amended to icon-only tint (justified by mockup 4.6, the DC-7
   precedent and design decision 7), `NetworkCardModel.readingColors` plus a test were added, and the gate passed
   on attempt 2. `ThroughputLabel.swift` was deliberately **not** modified, which is what makes the amendment
   correct rather than a workaround.
2. **The IFMIB correction's RED was stronger than its brief.** The correction brief sketched a compile-level RED
   (throwing a `ReadError` case that did not yet exist); apply instead used an independent `MIBUnavailable`
   witness error so the test compiles against the old adapter and fails on the truncation it exists to detect.
   Recorded as a deliberate deviation.
3. **`ThroughputLabel.swift`, `DiskCard.swift`, `CPUCard.swift`, `MemoryCard.swift`, `MetricModule.swift` and
   `project.pbxproj` were deliberately not modified.** DC-7, the shared-component reuse and NC-9's "existing call
   sites unchanged" all depend on that.
4. **Task 3.3 was skipped by its own contingency clause** — every `Darwin` name imported at 3.2.
5. **A ghost green was caught and removed during correction 1.** The first sampler script
   `[idle, referencePrevious, referenceCurrent]` passed even with the guard reverted, because `NetworkFixtures.idle`
   and `referencePrevious` are both stamped `at: 0`, making step 2 a zero-length window already caught by the
   `elapsed > 0` guard. The script was rewritten with counters stamped 0, 1 and 2 to produce a true RED.

---

## 9. Delivery and repository state at close

**Nothing is committed. Delivery is user-owned.**

| Field | Value |
|---|---|
| HEAD | `de40106` (`chore(sdd): archive disk-module change and merge its specs of record`) |
| Branch | `main` |
| Modified tracked files | 19 (`git diff --shortstat`: 19 files changed, 1 400 insertions, 76 deletions) |
| Untracked entries | 21 |
| New commits created by this phase | **none** |

Modified tracked files: `PRD.md`, `openspec/config.yaml`, `openspec/specs/disk-card/spec.md` (this phase),
`system-monitor/App/AppDelegate.swift`, `Application/MetricsSampler.swift`, `Application/MetricsState.swift`,
`Presentation/Components/HistoryGraph.swift`, `Presentation/MenuBar/StatusItemController.swift`,
`Presentation/Panel/PanelView.swift`, `Presentation/Theme/Palette.swift`, and nine test files
(`AppDelegateCompositionTests`, `MetricsSamplerTests`, `MetricsStateTests`, `SamplingCadenceTests`,
`SettingsStateTests`, `CanvasComponentsTests`, `PanelViewTests`, `StatusItemControllerTests`,
`StatusItemReadingsTests`).

Untracked: 7 new source files (`NetworkSnapshot`, `NetworkThroughputCounters`, `NetworkMetricsProvider`,
`NetworkThroughputCalculator`, `SysctlNetworkProvider`, `NetworkCard`, `PanelLayout`), 10 new test files
(`NetworkMetricsProviderPortTests`, `NetworkSnapshotTests`, `NetworkThroughputCalculatorTests`,
`SysctlNetworkIntegrationTests`, `SysctlNetworkProviderTests`, `HistoryGraphSeriesTests`,
`NetworkCardModelTests`, `PanelLayoutTests`, `FakeNetworkProvider`, `NetworkFixtures`),
`docs/reference/06-panel-network.png`, `openspec/specs/network-card/`, `openspec/specs/network-metrics/` (this
phase) and `openspec/changes/archive/2026-09-10-network-module/` (this phase).

**Delivery strategy**: single PR under an accepted `size:exception`, recorded at the review workload guard on
2026-09-10 (forecast 2 000–2 600 changed lines, budget risk High, `review_budget_lines: unlimited`). Suggested
work units for commit boundaries are batches A–G plus the two corrections:

| Unit | Scope |
|---|---|
| A | Network Domain values, port, Δ/Δt rule, fake and fixtures |
| B | `MetricsState.network` + paired histories, `NetworkSamplingStep`, sampler wiring |
| C | `SysctlNetworkProvider` and its `.integration` suite |
| D | Palette tokens and the multi-series `HistoryGraph` |
| E | `NetworkCardModel`, `NetworkCard`, fourth card in the panel |
| F | `PanelLayout`, `PanelView(maxHeight:)`, show-time cap in `StatusItemController` |
| G | Composition root, PRD Draft v4, `openspec/config.yaml`, verification runs |
| + | Review correction (`R3-zero-interface-baseline`) |
| + | IFMIB 64-bit counter correction |

### Receipt-driven review outcome

Both native reviews are closed and their authority burned.

| Review | Lineage | Scope | Outcome |
|---|---|---|---|
| #1 | `review-6998e0189040a8d8` | medium, 36 files, 3 350 lines | Reliability lens found CRITICAL `R3-zero-interface-baseline`; **one bounded correction** (calculator guards `previous.interfaceCount > 0`, calculator + sampler transition tests, NM-4 and PRD R11.4 amended, ~117 lines against a 200-line budget); targeted validation approved; **acknowledged**. |
| #2 | `review-75a9871bf4b6e760` | medium, 36 files, 3 606 lines | Reliability lens approved with **no correction**; four advisory non-blocking findings; **acknowledged**. |

Advisory findings recorded for later work: `R3-host-dependent-composition-test`, `R3-integration-churn-flake`,
`R3-mixed-rate-snapshot`, `R3-short-ifinfo2-guard`, `R3-untested-message-walk` (review #1 — several superseded by
the IFMIB rewrite, which removed the message walk entirely); `R3-all-gaps-become-valid-empty`,
`R3-cap-not-reapplied-while-shown`, `R3-churn-without-net-fall` (WARNING),
`R3-truncation-witness-shares-source` (review #2).

A review outcome is informational; it never authorises delivery. Commit, push and PR remain the user's decision
under ordinary repository policy.

---

## 10. Bookkeeping — gates and attempt ledger

| Gate / unit | Outcome |
|---|---|
| Design gate | **FAIL** attempt 1, **PASS** attempt 2 (NC-13 coverage, shared reference fixture, `NET_RT_IFLIST2` citation) |
| Apply gate | **FAIL** attempt 1 (NC-4 divergence unrecorded), **PASS** on the corrective re-run after the spec was amended |
| Batch G first launch | Cut off by a provider rate limit **before any edit**; resumed and completed |
| Ledger | Every work unit settled `complete`: batches A–G, `review-correction`, `correction-ifmib-64bit-counters`, verify revision 2 |
| Verify | Revision 1 superseded **in place** by revision 2 after the dispatcher refused archive on a stale 75-scenario total |

---

## 11. Known debt and follow-ups

Nothing here blocks the change. Each item is a candidate for a future `/gentle-sdd-new`, not an open task of this
cycle.

| Item | Kind | Source |
|---|---|---|
| Adapter-level zero-interface path and an errno-injection seam for the sparse-index wiring | Coverage depth | W1', W9 |
| A rendering assertion for NC-3's tint and `.isHeader`, and for NC-4's icon/value colour split | Coverage depth | W2', W3' |
| `R3-cap-not-reapplied-while-shown`: a display change while the popover is open does not re-cap until the next open | Behaviour, spec-permitted | W10 |
| `R3-all-gaps-become-valid-empty`: a host where every index answers a missing-interface errno yields a valid `interfaceCount == 0` reading, indistinguishable from "no interface passed the filter" | Behaviour, spec-permitted | W10 |
| `R3-churn-without-net-fall`: interface churn that does not make the summed counters fall admits a slightly wrong rate for one tick | Behaviour, spec-permitted | W10 |
| Enable code coverage on a shared `.xcscheme` so PRD section 8's "Domain + Application 80%+" can be measured | Tooling | S1 |
| Record the 7.3 peak and 7.7 CPU / resident-size figures next to the M5 baseline in PRD sections 8 and 10 | Recording gap | W5' |
| One `sysctl` per interface per tick (~20 on this machine) — watch if the sampling interval shortens | Performance headroom | S5 |
| The `## Verification notes` section the composer carried into `openspec/specs/disk-card/spec.md` | Spec hygiene | section 2.2 |
| Pre-amendment routing-socket passages in the archived `design.md` and `tasks.md` | Reading caveat (immutable audit trail) | section 5 |

---

## 12. Next

1. **Delivery is user-owned.** Nothing was committed by any SDD phase. When ready: stage the 19 modified and 21
   untracked entries, commit as one PR under the accepted `size:exception` (or slice along batches A–G plus the
   two corrections), push, and open the PR.
2. **Rollback**, if needed, is the plan in `proposal.md`: the change is additive on top of `de40106`; deleting
   the new files and reverting the ten modified sources restores the M5 baseline, with no persisted setting,
   `UserDefaults` key, login item or `MetricModule` case to unwind.
3. No further SDD phase is required for `network-module`. The next milestone in PRD Draft v4 is **M7 (GPU, v2)**.

---

## SDD Cycle Complete

`network-module` has been explored, proposed, specified, designed, planned, implemented under strict TDD,
corrected twice under native review and user manual testing, verified at revision 2 with zero CRITICAL findings,
and archived. `network-metrics` and `network-card` are now specs of record, and `disk-card` DC-1 and DC-11
describe the four-card panel. Ready for the next change.
