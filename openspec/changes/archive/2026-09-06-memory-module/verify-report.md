```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:11e149895d0b6c7de90cb7b2d31692367e4becf0d6b83dcab423060424b2e1dd
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 23/23
scenarios: 51/51
test_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests
test_exit_code: 0
test_output_hash: sha256:47da35a5597923e89330c6d15f8be85dfaa8964cd46759229937395d94cb60ef
build_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build
build_exit_code: 0
build_output_hash: sha256:760f562ec29e1896aef48d78d7482882999f6d0d396ff8ae4fdde0058a2e9aa8
```

## Verification Report

**Change**: memory-module
**Version**: specs `memory-metrics` (MM-1..MM-10), `memory-card` (MC-1..MC-10), `menu-bar-widget` delta (MBW-1, MBW-7, MBW-8)
**Mode**: Strict TDD
**Date**: 2026-09-06
**Revision**: 2

### Revision history

| Rev | Date | Verdict | Why it exists |
|---|---|---|---|
| 1 | 2026-09-06 | `pass_with_warnings` | First full verification after batches A–C. 294/294 tests, 30/31 tasks, task 7.3 (manual Activity Monitor comparison) still open and the only WARNING that gated archive. |
| 2 | 2026-09-06 | `pass_with_warnings` | Re-verification after the post-verify bounded correction (batch D, work unit `apply-correction-used-formula-activity-monitor-match`). The rev 1 gate — task 7.3 — was run by the user and **failed its tolerance**: the card's Used read 0.27–0.42 GB below Activity Monitor's "Memory Used", over the 100 MB target. The Used/Cached formula was corrected under Strict TDD, a legend word-breaking defect (MC-6) was fixed, and specs MM-2 / MC-5, `design.md`, `PRD.md` and `tasks.md` were amended. This revision re-traces all 51 scenarios against the amended spec text and re-runs the suite: 299/299 tests, 35/35 tasks. |

`evidence_revision` command:

```bash
{ git diff; git ls-files --others --exclude-standard system-monitor/ system-monitorTests/ \
  | LC_ALL=C sort | xargs bat -pp --paging=never; } | shasum -a 256
```

(20 untracked files under `system-monitor/` and `system-monitorTests/`, sorted with `LC_ALL=C`. One more than rev 1: `system-monitorTests/Presentation/SegmentLegendTests.swift`.)

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 35 |
| Tasks complete | 35 |
| Tasks incomplete | 0 |

Rev 1 counted 31 tasks with 7.3 open. Phase 8 (8.1–8.4) added four tasks for the correction, and 7.3 is now `[x]` carrying its recorded result: Total, Wired, Compressed and App matched Activity Monitor; Used did not, which is precisely what Phase 8 fixes. `rg -c "^- \[x\] "` → 35, `rg -c "^- \[ \] |^- \[~\] "` → 0.

The one runtime step that remains is the **user's final visual re-check of the rebuilt app** against Activity Monitor. It is deliberately *not* a task — apply-progress batch D files it under "Open Items Carried Forward" — so it does not make any task incomplete. It is WARNING 1 below and it gates archive.

### Build & Tests Execution

**Build**: ✅ Passed

```text
xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build
exit 0
```

The only `WARNING` line in the build log is xcodebuild's own destination notice (`Using the first of multiple matching destinations`, arm64 vs x86_64 on the same host id). Zero compiler `warning:` lines under Swift 6 strict concurrency.

**Tests**: ✅ 299 passed / 0 failed / 0 skipped

```text
xcodebuild ... -quiet test -only-testing:system-monitorTests
exit 0
rg -c "^Test case '"          → 299
rg -c "^Test case .* failed"  → 0
```

Rev 1 measured 294. Batch D added 5 cases: 2 from the new parameterized calculator case over both full fixtures (`cachedCountsSpeculativePagesAndKeepsPurgeableOnesInsideUsed`) and 3 from the new `SegmentLegendTests`. No case was deleted. The `.integration` suite `MachMemoryIntegrationTests` runs the real `host_statistics64` inside the sandboxed test host in the same run and is green under the corrected formula.

**Coverage**: ➖ Not available — no coverage tool is configured for this scheme, and the declared verification commands do not enable `-enableCodeCoverage`.

### Formula Consistency Audit (rev 2 focus)

The correction's central risk is the formula drifting between code and the five artifacts that state it. Verified by direct reading, plus a repo-wide search for the superseded wording:

| Source | Cached | Used | Matches? |
|---|---|---|---|
| `system-monitor/Domain/Services/MemoryUsageCalculator.swift:30,35` | `adding(external, speculative) × pageSize` | `subtracting(subtracting(total, free), cached)` | ✅ |
| spec `memory-metrics` MM-2 (line 27) | `(external + speculative) × pageSize` | `Total − free × pageSize − external × pageSize`, "which is Total − Free − Cached" | ✅ |
| spec `memory-metrics` MM-3 (line 65) | — | "MUST equal Total − Free − Cached (saturating)" | ✅ |
| `design.md` decision 14 (line 212) + calculator block (lines 69–74) | `Cached = external + speculative` | `Total − free × pageSize − external × pageSize` | ✅ |
| `PRD.md` R4.2 (lines 124–133) | `external_page_count + speculative_count` | `Total − free_count − external_page_count` (equivalently Total − Free − Cached) | ✅ |
| `PRD.md` 6.2 (lines 197–205) | — | `let used` commented "Total − Free − Cached" | ✅ |

`rg` over the repo for `external \+ purgeable`, `App \+ Wired \+ Compressed` and `Free = free_count` finds **no** surviving definition. The three remaining hits are all legitimate: `PRD.md:133` and `proposal.md:32` are the *explanatory note* that App + Wired + Compressed sits ~0.5 GB below Used (which the correction makes more true, not less); `design.md:212`'s "Rejected" column and `apply-progress.md:353`'s "Before" column deliberately record the superseded formula as history. `spec MM-10:191` and `tasks.md:83` name the strings as things that must *not* appear.

Arithmetic re-derived independently from the `reference` fixture (free 60 000, speculative 10 000, external 50 000, internal 200 000, purgeable 20 000, pageSize 16 384, total 8 589 934 592): Cached = 60 000 × 16 384 = 983 040 000; Free = 50 000 × 16 384 = 819 200 000; Used = 8 589 934 592 − 819 200 000 − 983 040 000 = **6 787 694 592**; unattributed = 397 934 592 (24 288 pages). Used + Cached + Free = 8 589 934 592 exactly. Every one of those numbers appears verbatim in `MemoryFixtures.swift:17-21`, in `MemoryCardModelTests.swift:124-130` and in spec MM-2's scenario. `eightGiB.freeCount` is 112 588 (`MemoryFixtures.swift:41`) and its derived used stays 5 926 092 800 → `"5.52 GB"` / 69.0%, so MC-3, MC-4 and the panel tests keep their pinned reference numbers.

### Spec Compliance Matrix

All test paths are relative to `system-monitorTests/`.

#### memory-metrics (10 requirements, 23 scenarios)

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| MM-1 | Fake provider satisfies the port | `Domain/MemoryMetricsProviderPortTests.swift:9 scriptedFakeReturnsEachCountsValueInOrder` | ✅ COMPLIANT |
| MM-1 | Scripted failure | `Domain/MemoryMetricsProviderPortTests.swift:33 scriptedCallsThrowAtTheRequestedZeroBasedIndex` | ✅ COMPLIANT |
| MM-2 | Reference counts at 16 KiB pages | `Domain/MemoryUsageCalculatorTests.swift:56 everyByteComponentFollowsTheActivityMonitorFormula` + `:71 usedIsTotalMinusFreeMinusCached` + `:102 cachedCountsSpeculativePagesAndKeepsPurgeableOnesInsideUsed` (all parameterized over `reference` + `eightGiB`) | ✅ COMPLIANT |
| MM-2 | Purgeable exceeds internal | `Domain/MemoryUsageCalculatorTests.swift:118 appSaturatesAtZeroWhenPurgeableExceedsInternal` | ✅ COMPLIANT |
| MM-2 | Speculative exceeds free | `Domain/MemoryUsageCalculatorTests.swift:130 freeSaturatesAtZeroWhenSpeculativeExceedsFree` | ✅ COMPLIANT |
| MM-2 | Free plus file-backed pages exceed Total | `Domain/MemoryUsageCalculatorTests.swift:139 usedSaturatesAtZeroWhenFreePlusCachedExceedTotal` | ✅ COMPLIANT |
| MM-2 | Large 32-bit counts do not overflow | `Domain/MemoryUsageCalculatorTests.swift:149 aFullThirtyTwoBitWiredCountWidensWithoutSaturating` | ✅ COMPLIANT |
| MM-3 | Fraction | `Domain/MemorySnapshotTests.swift:34 fractionIsTheUsedShareOfTotal` | ✅ COMPLIANT |
| MM-3 | Zero total | `Domain/MemorySnapshotTests.swift:41 fractionIsExactlyZeroWhenTotalIsZero` | ✅ COMPLIANT |
| MM-4 | Apply stores and appends | `Application/MetricsStateTests.swift:100 applyingAMemorySnapshotStoresItAndAppendsItsFraction` | ✅ COMPLIANT |
| MM-4 | History bounded | `Application/MetricsStateTests.swift:123 memoryHistoryStaysBoundedAtOneHundredTwentySamples` | ✅ COMPLIANT |
| MM-4 | CPU state untouched | `Application/MetricsStateTests.swift:137 applyingMemoryLeavesTheCPUStateAlone` | ✅ COMPLIANT |
| MM-5 | First step publishes memory only | `Application/MetricsSamplerTests.swift:167 theFirstStepPublishesMemoryWhileTheCPUIsStillSeeding` | ✅ COMPLIANT |
| MM-5 | Second step publishes both | `Application/MetricsSamplerTests.swift:183 theSecondStepPublishesBothMetrics` | ✅ COMPLIANT |
| MM-6 | Call counts advance together | `Application/MetricsSamplerTests.swift:199 bothProvidersAreReadOncePerStep` | ✅ COMPLIANT |
| MM-7 | Memory throws twice then recovers | `Application/MetricsSamplerTests.swift:214 aThrowingMemoryReadPublishesNothingAndRecoversOnTheNextStep` | ✅ COMPLIANT |
| MM-7 | Memory always throws | `Application/MetricsSamplerTests.swift:238 aPermanentlyFailingMemoryProviderNeverStopsTheCPU` | ✅ COMPLIANT |
| MM-7 | CPU throws, memory still publishes | `Application/MetricsSamplerTests.swift:259 aThrowingCPUReadDoesNotPreventTheMemoryPublish` | ✅ COMPLIANT |
| MM-8 | Off-main read | `Application/MetricsSamplerTests.swift:410 everyReadHappensOffTheMainThread` | ✅ COMPLIANT |
| MM-9 | Sandboxed shape (`.integration`) | `Infrastructure/MachMemoryIntegrationTests.swift:14,23,29,35,46` (5 cases) | ✅ COMPLIANT |
| MM-9 | Truncated response rejected | `Infrastructure/MachMemoryProviderTests.swift:45 aCountOneFieldShortIsRejected` + `:53 anEmptyReplyIsRejected` | ✅ COMPLIANT |
| MM-9 | Repeated reads (`.integration`) | `Infrastructure/MachMemoryIntegrationTests.swift:57 repeatedReadsSucceedAndAgreeOnTheHostConstants` | ✅ COMPLIANT |
| MM-10 | PRD text | Evidence kind: **PRD diff** — `PRD.md` R4.2/R4.3/6.2 read against MM-2/MM-3 (table above); `rg` confirms no `Used = App + Wired + Compressed` definition, no `Free = free_count` definition and no `vm_kernel_page_size` reference survives | ⚠️ PARTIAL (documentation requirement, no code seam) |

#### memory-card (10 requirements, 20 scenarios)

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| MC-1 | Card renders from fixed inputs | `Presentation/PanelViewTests.swift:102 thePanelStacksTheFullMemoryCardUnderTheCPUCard` (builds `MemoryCard(snapshot:history:)` and measures it in isolation) | ✅ COMPLIANT |
| MC-1 | Live update while open | `Presentation/PanelViewTests.swift:133 theMemoryGaugeTextFollowsTheAppliedSnapshot` | ✅ COMPLIANT |
| MC-1 | Panel grows with the memory card | `Presentation/PanelViewTests.swift:102` (pinned lower bound > 620 pt, measured 678 = 370 + 272 + 36; no placeholder titled "Memory") + `:119 theFirstMemorySnapshotFillsTheCardWithoutResizingThePanel` | ✅ COMPLIANT (see deviation D9) |
| MC-2 | Two decimals under en_US | `Presentation/ByteFormatterTests.swift:23` (parameterized) | ✅ COMPLIANT |
| MC-2 | Decimal comma under de_DE | `Presentation/ByteFormatterTests.swift:34 theDecimalSeparatorComesFromTheLocale` | ✅ COMPLIANT |
| MC-2 | Exact multiple has no trailing zeros | `Presentation/ByteFormatterTests.swift:41` (parameterized) | ✅ COMPLIANT |
| MC-2 | Zero and clamping | `Presentation/ByteFormatterTests.swift:52 zeroRendersWithDigitsRatherThanBeingSpelledOut` + `:63 valuesAboveTheSignedRangeClampInsteadOfTrapping` | ✅ COMPLIANT |
| MC-3 | One-decimal gauge | `Presentation/MemoryCardModelTests.swift:53` (parameterized `"69.0%"` / `"100.0%"`) | ✅ COMPLIANT |
| MC-3 | Locale decimal separator | `Presentation/MemoryCardModelTests.swift:64 theGaugeUsesTheLocaleDecimalSeparator` | ✅ COMPLIANT |
| MC-4 | Four rows | `Presentation/MemoryCardModelTests.swift:80 theRowsReadUsedTotalWiredAndCompressedFromTheSnapshot` | ✅ COMPLIANT |
| MC-5 | Segments sum to Total | `Presentation/MemoryCardModelTests.swift:105 theBarSplitsTotalIntoSixSegmentsInProductOrder` + `:131 theSegmentFractionsSumToOneAndTheAppColourCoversTheUnattributedUse` | ✅ COMPLIANT |
| MC-5 | Components exceed Used | `Presentation/MemoryCardModelTests.swift:147 componentsLargerThanUsedLeaveNoRemainderAndStayInsideTheBar` | ✅ COMPLIANT |
| MC-5 | No snapshot | `Presentation/MemoryCardModelTests.swift:172 aMissingSnapshotOrAnEmptyMachineDrawsNoSegments` | ✅ COMPLIANT |
| MC-6 | Legend entries | `Presentation/MemoryCardModelTests.swift:189 theLegendNamesFiveSegmentsAndSurvivesAMissingSnapshot`; layout defect covered by `Presentation/SegmentLegendTests.swift:51,64,84` | ✅ COMPLIANT |
| MC-7 | Full history | `Presentation/MemoryCardModelTests.swift:218 theGraphTakesTheNewestSamplesOldestFirst` | ✅ COMPLIANT |
| MC-7 | Short and empty history | `Presentation/MemoryCardModelTests.swift:218` (3 values) + `:234 aMissingSnapshotRendersAZeroedCardWithItsLegend` (0 values) | ✅ COMPLIANT |
| MC-7 | Section order | `Presentation/MemoryCardModelTests.swift:211 theCardLaysOutItsSectionsWithTheGraphLast` | ✅ COMPLIANT |
| MC-8 | Nil snapshot | `Presentation/MemoryCardModelTests.swift:234 aMissingSnapshotRendersAZeroedCardWithItsLegend` | ✅ COMPLIANT |
| MC-9 | Token values | `Presentation/StatusItemReadingsTests.swift:54 memorySegmentTokensMatchTheProductPalette` | ✅ COMPLIANT |
| MC-10 | Reduce motion | Evidence kind: **code inspection** — `MemoryCard.swift:160` `@Environment(\.accessibilityReduceMotion)`, `:231 .animation(reduceMotion ? nil : Self.gaugeAnimation, value: snapshot?.fraction)`, identical to the `CPUCard` precedent. Surface half is asserted (`PaletteTests:72 cardSurfaceUsesTheDocumentedCornerRadius`, `MemoryCard.swift:188-189 cardBackground` + `cardCornerRadius`) | ⚠️ PARTIAL (accessibility environment not injectable from this unit target) |

#### menu-bar-widget delta (3 requirements, 8 scenarios)

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| MBW-7 | MEM value from fraction | `Presentation/StatusItemReadingsTests.swift:195 theMemoryValueFollowsTheSnapshotFraction` | ✅ COMPLIANT |
| MBW-7 | MEM newest 60 samples | `Presentation/StatusItemReadingsTests.swift:212 theMemorySparklineUsesTheNewestSixtySamples` | ✅ COMPLIANT |
| MBW-7 | MEM before first snapshot | `Presentation/StatusItemReadingsTests.swift:204 theMemoryValueReadsZeroPercentBeforeTheFirstSnapshot` | ✅ COMPLIANT |
| MBW-7 | MEM accent | `Presentation/StatusItemReadingsTests.swift:223 theMemoryModuleCarriesTheMemoryAccent` (+ `:15 memoryUsesTheMemoryAccent` on the enum) | ✅ COMPLIANT |
| MBW-1 | Order preserved | `Presentation/StatusItemReadingsTests.swift:136 readingsFollowTheMenuBarOrder` | ✅ COMPLIANT |
| MBW-1 | Both modules follow state | `Presentation/StatusItemReadingsTests.swift:233 bothModulesFollowTheirOwnState` (`"42%"` / `"59%"`) | ✅ COMPLIANT |
| MBW-8 | MEM live sparkline | `Presentation/StatusItemReadingsTests.swift:383 theMemoryModuleRendersItsLiveSparkline` | ✅ COMPLIANT |
| MBW-8 | MEM empty history still has a sparkline | `Presentation/StatusItemReadingsTests.swift:405 theMemoryModuleKeepsItsSparklineWithoutHistory` + `StatusItemControllerTests theWidgetStaysUnderTheWidthBudgetAtFullScale` (< 230 pt) | ✅ COMPLIANT |

**Compliance summary**: 51/51 scenarios have evidence; **49 rest on a passing runtime test**, 2 on the non-runtime evidence kinds the specs themselves imply (MM-10 is a documentation requirement with no code seam; MC-10's accessibility environment is not readable from this unit target). 0 UNTESTED, 0 FAILING.

### Correctness (Static Evidence)

| Requirement | Status | Notes |
|---|---|---|
| MM-1 port shape | ✅ Implemented | `MemoryMetricsProvider` returns `MemoryPageCounts` with the seven counters + `pageSize` + `totalBytes`; port, counts and snapshot are `nonisolated`, `Sendable`, `Equatable`. |
| MM-2 corrected formula | ✅ Implemented | `MemoryUsageCalculator.swift:27-35`. All arithmetic in `UInt64` through `subtracting` (floor 0), `adding` (ceiling `.max`) and `bytes` (ceiling `.max`). Adapter widens `natural_t` before the calculator sees it. |
| MM-3 snapshot value | ✅ Implemented | Stored `used` (design decision 1), computed `fraction` guarded at `total == 0` and clamped at 1, computed `unattributedUsed` with an overflow guard (D6). |
| MM-4/MM-5/MM-6/MM-7/MM-8 | ✅ Implemented | One `MetricsSampler`, one `Task.detached(priority: .utility)` loop; memory read inline in the same iteration, `try?` isolation, published always, CPU still gated on its second sample. |
| MM-9 adapter | ✅ Implemented | Caller-owned `vm_statistics64_data_t`, no `vm_deallocate`, field count from `MemoryLayout`, `validate(returnedCount:)` seam, `host_page_size` only. |
| MM-10 PRD alignment | ✅ Implemented | Re-amended in batch D; verified in the Formula Consistency Audit above. |
| MC-1..MC-9 | ✅ Implemented | Pure `nonisolated enum MemoryCardModel` derives every rendered value; `MemoryCard` is layout only; `PanelView` renders it and `PlaceholderCard` is gone. |
| MC-10 | ✅ Implemented | Surface asserted; animation gate matches `CPUCard`. |
| MBW-1/7/8 | ✅ Implemented | `StatusItemReadings.build(cpu:cpuHistory:memory:memoryHistory:)`; MEM bound to `memory`/`memoryHistory`; no layout constant moved. |

### Coherence (Design)

| Decision | Followed? | Notes |
|---|---|---|
| 1 — `MemorySnapshot.used` is a stored `let` | ✅ Yes | Set only by the calculator; survives the correction unchanged (revision 3 widened which pages sit in `used`, not the shape). |
| 2 — sixth `.unattributed` segment in `memAccent`, no legend entry | ✅ Yes | `MemoryCardModelTests:105` pins `[.app, .unattributed, .wired, .compressed, .cached, .free]` and the accent width `(used − wired − compressed)/total`; the remainder grew from 14 288 to 24 288 pages exactly as decision 2 records. |
| 4 — page size via `host_page_size` only | ✅ Yes | `rg` over `system-monitor/` finds `host_page_size` at `MachMemoryProvider.swift:69`; the only mentions of `vm_kernel_page_size`/`vm_page_size` are in the doc comment at `:56` explaining why they are avoided. |
| 5 — `memoryProvider` is a required init parameter | ✅ Yes | Composition root injects `MachMemoryProvider()` in `AppDelegate`. |
| 9 — symmetric `build(cpu:cpuHistory:memory:memoryHistory:)` | ✅ Yes | `StatusItemView.swift:36`. |
| 14 — which pages leave Used (revision 3) | ✅ Yes | Code, both specs, design and PRD all agree (audit table above). |
| 15 — legend wraps by entry via `ViewThatFits` | ✅ Yes | `SegmentLegend.swift:38 ViewThatFits(in: .horizontal)`, `:57-58 .lineLimit(1).fixedSize(horizontal: true, vertical: false)`; five layout constants are `nonisolated static let` (D23). |
| Convention 1 — `nonisolated` + `Sendable` | ✅ Yes | `MemoryCardSection` at `MemoryCard.swift:41` is `nonisolated ... Sendable, Equatable, CaseIterable, Identifiable` with the section order `header, gaugeAndRows, stackedBar, legend, graph`. |
| Convention 2 — no `@MainActor` test suites | ✅ Yes | No suite carries `@MainActor`; `SegmentLegendTests` and `PanelViewTests` `await` `@MainActor` measurement helpers. |
| Convention — no `@unchecked Sendable` | ✅ Yes | The only two hits are doc comments in `FakeCPUProvider`/`FakeMemoryProvider` explaining its absence. |
| Convention 6 — `project.pbxproj` untouched | ✅ Yes | `git status --short system-monitor.xcodeproj` is **empty**. The cosmetic re-sort noted in apply-progress D24 was reverted; see WARNING 3. |
| D14 — views omit the explicit `@MainActor` | ⚠️ Benign deviation | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` infers identical isolation and it matches every existing view. Unchanged from rev 1. |
| D20 — `MemorySnapshotTests` left on pre-correction numbers | ⚠️ Accepted | See WARNING 4. |

### TDD Compliance

| Check | Result | Details |
|-------|--------|---------|
| TDD Evidence reported | ✅ | Four "TDD Cycle Evidence" tables in `apply-progress.md` (batches A, B, C, D). |
| All tasks have tests | ✅ | 35/35 tasks; the four non-test tasks (3.3 verification suite, 7.1/7.2/7.3 docs+manual, 8.4 artifacts) are explicitly marked N/A with reasons. |
| RED confirmed (tests exist) | ✅ | Every test file named in the batch D table exists and was read: `MemoryUsageCalculatorTests`, `MemoryFixtures`, `MemoryCardModelTests`, `MetricsSamplerTests`, `MemoryMetricsProviderPortTests`, `SegmentLegendTests`. |
| RED evidence is real | ✅ | Batch D 8.1 records 16 named failing cases at `exit=65` **before** the calculator changed — an assertion-level RED, not a compile error, which is the stronger form. 8.3 records a compile-level RED (`type 'SegmentLegend' has no member 'rowSpacing'`, then the main-actor isolation error). |
| GREEN confirmed (tests pass) | ✅ | All 299 cases pass on re-execution here, including every case named in the batch D RED list. |
| Triangulation adequate | ✅ | The new calculator case is parameterized over both full fixtures and pins three independent invariants; `SegmentLegendTests` exercises both `ViewThatFits` branches (one-row and two-row) plus an upper *and* lower height bound. |
| Safety Net for modified files | ✅ | 294/294 before 8.1; 296/296 before 8.3. Both recorded. |

**TDD Compliance**: 7/7 checks passed.

### Test Layer Distribution

| Layer | Tests | Files | Tools |
|-------|-------|-------|-------|
| Unit (pure values, models, formatting) | 77 in memory-owned files + memory cases inside `MetricsStateTests`, `MetricsSamplerStepTests`, `MenuBarReadingsTests`, `PaletteTests` | 7 memory-owned + 4 shared | Swift Testing |
| Integration — real kernel | 6 (`MachMemoryIntegrationTests`, `.integration` tag, real `host_statistics64` in the sandboxed host) | 1 | Swift Testing + Mach |
| Integration — rendered geometry | 3 `SegmentLegendTests` + 3 memory cases in `PanelViewTests` + 2 in `StatusItemMetricsTests` | 3 | `NSHostingView.fittingSize` |
| E2E | 0 | 0 | not installed (no XCUITest target) |
| **Total suite** | **299** | **32 suites** | |

111 cases added by this change over the 188-case baseline. No E2E tooling exists in the project, so the absence of E2E coverage is not a gap this change could have filled.

### Changed File Coverage

Coverage analysis skipped — no coverage tool detected for this scheme.

### Assertion Quality

Audited all 9 memory-owned test files plus the memory cases in the 4 shared suites.

- No tautologies (`#expect(true)`, `#expect(1 == 1)`) anywhere in the test target.
- No ghost loops. The single `for … in` inside `MemoryCardModelTests` (line 44) is in the `history(_:)` builder helper, not around assertions.
- Every empty-collection assertion has a companion non-empty test with the same setup: `segments(for: nil).isEmpty` (`:173`, `:204`, `:241`) is paired with `:105` asserting six segments with exact byte values; `graphSamples(for: history([])).isEmpty` (`:242`) is paired with `:218` asserting 120 and 3 samples; `memory.samples.isEmpty` (`StatusItemReadingsTests:208`, `:417`) is paired with `:212` asserting the newest 60.
- No type-only assertions standing alone, no CSS/implementation-detail coupling, no mocks (the fakes are scripted test doubles behind the Domain port, and every fake-based test asserts produced values).
- The three `SegmentLegendTests` cases carry only 4 `#expect`s but each is load-bearing rendered geometry with a stated failure mode in its message: the lower bound fails if the legend stays on one squeezed row, the upper bound fails if any label breaks across lines.

**Assertion quality**: ✅ All assertions verify real behavior — 0 CRITICAL, 0 WARNING.

### Quality Metrics

**Linter**: ➖ Not available — no SwiftLint/SwiftFormat configuration in the project.
**Type Checker**: ✅ No errors, no warnings — `xcodebuild build` exit 0, 0 compiler `warning:` lines under Swift 6 strict concurrency.

### Issues Found

**CRITICAL**: None.

**WARNING**:

1. **The user's final visual re-check is still outstanding, and it is the reason this revision exists.** Batch D corrected the formula because the rev 1 gate (task 7.3) failed its 100 MB tolerance. The correction is proven arithmetically and by 299 passing tests, but *nothing in this repository can prove the rebuilt card now matches Activity Monitor on the running machine* — that is the same class of evidence that caught the original defect. Before archive the user must launch the app, open Activity Monitor › Memory, and confirm (a) the card's Used row tracks "Memory Used" within 100 MB, (b) Total, Wired, Compressed and App still match, and (c) the legend reads `App Wired Compressed` / `Cached Free` on two clean rows with no word broken. Archive is gated on this.
2. **MC-10 "Reduce motion" remains verified by inspection only.** Unchanged from rev 1 and untouched by the correction. The mechanism is byte-for-byte the `CPUCard` precedent, but the SwiftUI accessibility environment is not injectable from this unit target, so no runtime assertion exists. Known coverage gap, not an unimplemented behaviour.
3. **`apply-progress.md` deviation D24 is now stale.** D24 (line 397) records that `project.pbxproj` "carries a two-line cosmetic diff … left as found", and the batch D roll-up (line 431) counts "12 files changed, 653 insertions, 81 deletions (the twelfth is the cosmetic `project.pbxproj` re-sort)". That re-sort was reverted afterwards: `git status --short system-monitor.xcodeproj` is empty and the real tracked diff is **11 files, 651 insertions, 79 deletions** — exactly 653 − 2 and 81 − 2. The tree is in the *better* state (convention 6 fully satisfied); only the prose lags. Archive should correct D24 and the roll-up line rather than trust them.
4. **MM-3 "Fraction" keeps its pre-correction numbers on purpose (D20).** `MemorySnapshotTests:34` hand-builds `used 6 623 854 592 / total 8 589 934 592 → 0.7711`. That snapshot is not producible by the corrected calculator from any fixture, but the scenario is a statement about `MemorySnapshot`'s arithmetic on a value type, not about the formula, and MM-3's spec text was not amended. Accepted; flagged so a future reader does not mistake it for a stale expectation.
5. **The calculator's doc comment leads with an imprecise sentence.** `MemoryUsageCalculator.swift:10` reads "Only file-backed and speculative pages leave Used", while spec MM-2, `PRD.md` R4.2 and the same doc comment's own closing clause (`:13-15`, "its 'Memory Used' is the total minus the free and file-backed pages") all say **free** and file-backed. Speculative pages leave Used only because they are already inside `free_count`; the sentence omits the truly-free pages. The formula statement two lines above (`:6-8`) and the code itself are correct, so this is wording, not a formula inconsistency — but it is the one sentence in the codebase that contradicts the spec's normative phrasing and it should be aligned.
6. **`menu-bar-widget` delta is destructive.** It MODIFIES two existing requirements and supersedes the scenario "MEM placeholder still has a sparkline" (and the deleted test `theMemoryModuleStaysAPlaceholder`). Per the proposal risk table, archive must explicitly confirm the merge before rewriting `openspec/specs/menu-bar-widget/spec.md`. Unchanged from rev 1.
7. **The Engram `apply-progress` mirror is split across two observations.** 8226 holds batches A–C, 8230 holds batch D, because one observation is capped at 50 000 characters. `openspec/changes/memory-module/apply-progress.md` is the single complete document. Anyone reading only 8226 sees a change that predates the correction; archive should carry both ids.
8. **Pre-existing wall-clock loop tests remain (debt W1/W5).** `MetricsSamplerLoopTests` still drives real time instead of the already-injected `clock: any Clock<Duration>`. Batch D added no wall-clock cases, so the debt is unchanged, not worsened.
9. **`StatusItemControllerTests` leak `NSStatusItem`s (debt W6).** Pre-existing and untouched.
10. **Design deviation D14** — new views omit the explicit `@MainActor` the design signature block spells out. Benign: identical inferred isolation, matches every existing view. Unchanged from rev 1.

**SUGGESTION**:

1. Fix the one-sentence doc drift in WARNING 5 while the correction is fresh; it is a two-word edit and it removes the only place a reader can learn the wrong rule.
2. Consider adding an `.integration` assertion that pins `used + cached + free == total` against the *real* host, not just the fixtures. The invariant now holds by construction, so such a test would be cheap and would catch a future refactor that reintroduces the literal `Total − free − external` form (which can overshoot when `speculative > free`).
3. When the accessibility environment becomes injectable, promote MC-10 and the `CPUCard` reduce-motion precedent to real assertions in one pass.
4. Migrating `MetricsSamplerLoopTests` to the injected `Clock` would remove the last wall-clock dependency.

### Verdict

**PASS WITH WARNINGS** — the bounded correction is coherent and complete. All 23 requirements and all 51 scenarios trace to evidence, 49 of them to a passing runtime test; the corrected `Cached = external + speculative` / `Used = Total − Free − Cached` formula is stated identically in `MemoryUsageCalculator.swift`, spec MM-2, spec MM-3, `design.md` decision 14, `PRD.md` R4.2 and `PRD.md` 6.2, with no superseded wording surviving anywhere outside deliberately historical "Before"/"Rejected" columns; 299/299 tests pass with a genuine assertion-level RED recorded before the fix; the build is warning-free; `project.pbxproj` is clean; and 35/35 tasks are complete. No CRITICAL issue blocks archive. The one thing this repository cannot prove is the thing that failed last time — the running app against Activity Monitor — so archive stays gated on the user's final visual re-check (WARNING 1).
