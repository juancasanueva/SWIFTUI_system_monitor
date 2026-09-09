```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:e17479bbd34b3d32b30b77304dca13817be67e2fb2991980db4bf5dce678b72b
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 26/26
scenarios: 67/67
test_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test
test_exit_code: 0
test_output_hash: sha256:e17479bbd34b3d32b30b77304dca13817be67e2fb2991980db4bf5dce678b72b
build_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build
build_exit_code: 0
build_output_hash: sha256:c6c942ae32f10d7ae726b8b899d44fd7f6b4deed6071a90a8ef56e6e4c438946
```

## Verification Report

**Change**: disk-module (PRD M5 — "Disk — ship v1", F10, R10.1–R10.11)
**Version**: `specs/disk-metrics/spec.md` DM-1..DM-15 (42 scenarios) + `specs/disk-card/spec.md` DC-1..DC-11 (25 scenarios)
**Mode**: Strict TDD
**Verified**: 2026-09-10

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 37 |
| Tasks complete | 33 |
| Tasks incomplete | 4 — all MANUAL, user-owned (7.3, 7.4, 7.5, 7.6) |
| Automated tasks incomplete | 0 |

Tasks 7.3–7.6 are `open (manual, user-owned)`. They require a running app in front of a human and an Instruments session; the apply phase cannot execute them and they are not failures. They do not block this verdict.

### Build & Tests Execution

**Build**: Passed — `xcodebuild … -quiet build`, exit 0, 0 `warning:` lines, 0 `error:` lines.

**Tests**: 561 unique passing cases, 0 failures on the run of record.

| # | Command | Exit | Unique passed | Failed | `warning:` | `error:` | Output sha256 |
|---|---------|------|---------------|--------|-----------|---------|---------------|
| 1 | `FULL` (run of record) | 0 | 561 | 0 | 0 | 0 | `e17479bb…78b72b` |
| 2 | `FULL` (confirming run) | 65 | 560 | 1 (`system_monitorUITests.testLaunchPerformance()`) | 0 | 0 | `32c058c7…88c783` |
| 3 | `FULL` (rerun after the flake) | 0 | 561 | 0 | 0 | 0 | `f278d145…d20729` |
| 4 | `UNIT` (`-only-testing:system-monitorTests`) | 0 | 558 | 0 | 0 | 0 | `6faf7ada…36be3` |
| 5 | `BUILD` (`build`) | 0 | — | — | 0 | 0 | `c6c942ae…438946` |

Counts reconcile with apply's recorded figures exactly: unit 558, `FULL` 561 (the three `system_monitorUITests` template cases). Two independent `FULL` runs (1 and 3) agree at 561/0, which is the safer evidence the `-quiet` line-dropping hazard requires.

Run 2's single failure is `system_monitorUITests.testLaunchPerformance()`, the pre-existing flaky Xcode-template launch-performance case. Evidence it is not this change's: it lives in the UI test target, which `git status` shows untouched by this change; batch C already proved it fails on a clean baseline with every disk file removed; and it passed in runs 1 and 3 here as well as in both of apply's `FULL` runs. Reported per protocol, not treated as a regression.

`system-monitor.xcodeproj/project.pbxproj` is clean after five xcodebuild invocations — `git status --short` on that path is empty, so no convention 6 revert was needed in this phase.

**Coverage**: Not available. The project ships no shared `.xcscheme`, so code coverage is not configured on the scheme and no coverage report is produced by the test command. PRD section 8's "Domain + Application 80%+" target therefore **cannot be measured from this run**, and no number is asserted in its place. This is a measurement gap, not a failure.

### Spec Compliance Matrix — disk-metrics (DM-1 … DM-15)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| DM-1 | Fake provider satisfies both halves | `DiskMetricsProviderPortTests > eachKindReturnsItsOwnScriptedValuesInOrder` | COMPLIANT |
| DM-1 | Scripted failures are independent | `DiskMetricsProviderPortTests > scriptedFailuresHitOneKindWithoutDisturbingTheOther` | COMPLIANT |
| DM-2 | Timestamp participates in equality | `DiskSnapshotTests > countersOneMillisecondApartAreNotEqual` | COMPLIANT |
| DM-3 | Reference capacity | `DiskSnapshotTests > theReferenceCapacityDerivesUsedAndFraction` (`used == 432_068_000_000`, `fraction` ±0.0005) | COMPLIANT |
| DM-3 | Free exceeds total | `DiskSnapshotTests > freeAboveTotalSaturatesUsedAtZeroWithoutWraparound` | COMPLIANT |
| DM-3 | Zero total | `DiskSnapshotTests > aZeroTotalKeepsTheFractionExactlyZero` (also asserts not NaN, not infinite) | COMPLIANT |
| DM-3 | Full volume | `DiskSnapshotTests > aFullVolumeReportsFractionExactlyOne` | COMPLIANT |
| DM-4 | Reference rate | `DiskThroughputCalculatorTests > theReferenceWindowYieldsTheReferenceRates` (`27_100_000` / `2_200_000`) | COMPLIANT |
| DM-4 | Elapsed time scales the rate | `DiskThroughputCalculatorTests > halvingTheWindowDoublesBothRates` (`54_200_000`) | COMPLIANT |
| DM-4 | No baseline | `DiskThroughputCalculatorTests > noBaselineYieldsNoRates` | COMPLIANT |
| DM-4 | No drivers | `DiskThroughputCalculatorTests > aReadingWithoutDriversYieldsNoRates` | COMPLIANT |
| DM-4 | Non-positive elapsed time | `DiskThroughputCalculatorTests > aZeroWindowYieldsNoRates` + `aBackwardsWindowYieldsNoRates` (both halves) | COMPLIANT |
| DM-4 | Negative read delta nils both rates | `DiskThroughputCalculatorTests > aFallingReadCounterNilsBothRates` | COMPLIANT |
| DM-4 | Negative write delta nils both rates | `DiskThroughputCalculatorTests > aFallingWriteCounterNilsBothRates` | COMPLIANT |
| DM-4 | Re-seeded baseline recovers on the next tick | `DiskThroughputCalculatorTests > theReSeededBaselineRecoversOnTheNextTick` (both rates `1_000`) | COMPLIANT |
| DM-5 | Never read | `DiskCapacityCadenceTests > aCapacityNeverReadAlwaysRefreshes` | COMPLIANT |
| DM-5 | Under the minimum | `DiskCapacityCadenceTests > justUnderTheMinimumDoesNotRefresh` + `theSameInstantDoesNotRefresh` (both cases) | COMPLIANT |
| DM-5 | At the minimum | `DiskCapacityCadenceTests > exactlyTheMinimumRefreshes` | COMPLIANT |
| DM-6 | First step publishes capacity without throughput | `MetricsSamplerStepTests > theFirstDiskStepPublishesCapacityWithBothRatesNil` (`memory != nil`, `cpu == nil`) | COMPLIANT |
| DM-6 | Second step publishes rates | `MetricsSamplerStepTests > theSecondDiskStepPublishesTheReferenceRates` (`27_100_000`) | COMPLIANT |
| DM-6 | Call counts advance together | `MetricsSamplerStepTests > allThreeProvidersAreReadOncePerStep` (3/3/3) | COMPLIANT |
| DM-7 | One capacity read under 10 s | `MetricsSamplerStepTests > capacityIsReadOnceWhileEveryStampStaysUnderTenSeconds` (`capacityCalls == 1`, `throughputCalls == 4`, all four snapshots carry the first capacity) | COMPLIANT |
| DM-7 | Refresh once the cadence is crossed | `MetricsSamplerStepTests > capacityIsReadAgainOnTheFirstStampTenSecondsLater` (`capacityCalls == 2`, last two snapshots carry the second capacity) | COMPLIANT |
| DM-8 | Restart costs one throughput-unavailable tick | `MetricsSamplerLoopTests > aRestartCostsOneThroughputUnavailableDiskTick` (rates `nil`, `capacityCalls` +1, next iteration non-nil) | COMPLIANT |
| DM-8 | Unchanged interval keeps the baseline | `MetricsSamplerLoopTests > applyingTheIntervalAlreadyInEffectKeepsTheDiskBaseline` | COMPLIANT |
| DM-9 | Off-main reads | `MetricsSamplerLoopTests > everyReadHappensOffTheMainThread` (3 recorded flags, all `false`) | COMPLIANT |
| DM-10 | Throughput throws, capacity keeps rendering | `MetricsSamplerStepTests > aThroughputThrowStillPublishesTheCachedCapacity` (+ triangulating `aThroughputThrowReplacesPublishedRatesWithNil`) | COMPLIANT |
| DM-10 | Throughput throw skips the refresh that tick | `MetricsSamplerStepTests > aThroughputThrowSkipsThatTicksCapacityRefresh` | COMPLIANT |
| DM-10 | Capacity throws before any success | `MetricsSamplerStepTests > aCapacityThrowBeforeAnySuccessPublishesNothingForDisk` | COMPLIANT |
| DM-10 | Capacity throws after a success | `MetricsSamplerStepTests > aCapacityThrowAfterASuccessKeepsTheCachedCapacity` (call-0 capacity, rate `2_710_000`) | COMPLIANT |
| DM-10 | CPU throws, disk still publishes | `MetricsSamplerStepTests > aThrowingCPUReadDoesNotPreventTheDiskPublish` | COMPLIANT |
| DM-11 | Apply stores the latest only | `MetricsStateTests > applyingTwoDiskSnapshotsKeepsOnlyTheSecond` + `theStateExposesNoDiskHistoryProperty` | COMPLIANT |
| DM-11 | Other state untouched | `MetricsStateTests > applyingDiskLeavesTheCPUAndMemoryStateAlone` | COMPLIANT |
| DM-12 | Sandboxed shape (`.integration`) | `IOKitDiskIntegrationTests > theSandboxedHostSeesAtLeastOneDriverWithBytesRead` | COMPLIANT |
| DM-12 | Counters are monotonic with advancing stamps (`.integration`) | `IOKitDiskIntegrationTests > twoReadsAreMonotonicAndTheStampAdvances` | COMPLIANT |
| DM-12 | Repeated reads (`.integration`) | `IOKitDiskIntegrationTests > fiftyConsecutiveReadsAllSucceed` | COMPLIANT |
| DM-13 | Sandboxed shape (`.integration`) | `VolumeCapacityIntegrationTests > theBootVolumeReportsAConsistentPairAboveTheRawAvailableSpace` | COMPLIANT |
| DM-13 | Provider delegates (`.integration`) | `VolumeCapacityIntegrationTests > theProviderDelegatesCapacityToTheComposedReader` | COMPLIANT |
| DM-13 | Missing or negative value rejected | `VolumeCapacityReaderTests > aMissingTotalIsRejected`, `aMissingFreeIsRejected`, `aNegativeTotalIsRejected`, `aNegativeFreeIsRejected` | COMPLIANT |
| DM-14 | Real graph runs with disk (`.integration`) | `AppDelegateCompositionTests > theRealGraphPublishesRealDiskReadings` | COMPLIANT |
| DM-14 | Modules untouched | `AppDelegateCompositionTests > theDiskModuleNeverEntersTheMenuBarModuleSet` + `publishingDiskReadingsLeavesTheStatusItemWidthUnchanged` | COMPLIANT |
| DM-15 | PRD text | Document check against `PRD.md` (see "DM-15 document verification") | COMPLIANT |

### Spec Compliance Matrix — disk-card (DC-1 … DC-11)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| DC-1 | Card renders from a fixed input | `PanelViewTests > theDiskCardRendersFromItsSnapshotAlone` | COMPLIANT |
| DC-1 | Card order | `PanelViewTests > thePanelStacksCPUThenMemoryThenDisk` (`cards == [.cpu, .memory, .disk]`, `Set == allCases`) | COMPLIANT |
| DC-1 | Live update while open | `PanelViewTests > theDiskGaugeTextFollowsTheAppliedSnapshot` (`"87.4%"`) | COMPLIANT |
| DC-2 | Sections | `DiskCardModelTests > theCardHasAHeaderAGaugeWithRowsAndAThroughputFooter` | COMPLIANT |
| DC-3 | One-decimal gauge | `DiskCardModelTests > theGaugeShowsOneFractionDigit` (`"87.4%"`, `"100.0%"`) + `theGaugeFractionFollowsTheSnapshot` | COMPLIANT |
| DC-3 | Locale decimal separator | `DiskCardModelTests > theGaugeUsesTheLocaleDecimalSeparator` (`"87,4%"`) | COMPLIANT |
| DC-3 | Header symbol resolves | `DiskCardModelTests > theHeaderSymbolResolvesAsAnSFSymbol` (`internaldrive`) | COMPLIANT |
| DC-4 | Three rows | `DiskCardModelTests > theRowsReadUsedFreeAndTotalFromTheSnapshot` (`Used 432.07 GB`, `Free 62.29 GB`, `Total 494.35 GB`) | COMPLIANT |
| DC-4 | Rows under de_DE | `DiskCardModelTests > theRowValuesFollowTheInjectedLocale` | COMPLIANT |
| DC-5 | Two decimals under en_US | `ByteFormatterTests > capacityValuesKeepTwoFractionDigitsUnderEnglish` | COMPLIANT |
| DC-5 | Decimal comma under de_DE | `ByteFormatterTests > theCapacityDecimalSeparatorComesFromTheLocale` | COMPLIANT |
| DC-5 | Exact multiple and clamping | `ByteFormatterTests > anExactDecimalMultipleDropsItsFractionDigits`, `capacityZeroRendersWithDigitsRatherThanBeingSpelledOut`, `capacitiesAboveTheSignedRangeClampInsteadOfTrapping` | COMPLIANT |
| DC-6 | Megabytes per second | `ThroughputFormatterTests > megabyteRatesCarryOneFractionDigit` (`"27.1 MB/s"`, `"2.2 MB/s"`) | COMPLIANT |
| DC-6 | Decimal comma | `ThroughputFormatterTests > theThroughputDecimalSeparatorComesFromTheLocale` (`"27,1 MB/s"`) | COMPLIANT |
| DC-6 | Whole values keep one fraction digit | `ThroughputFormatterTests > aWholeValueStillShowsItsFractionDigit` (`"1.0 GB/s"`) | COMPLIANT |
| DC-7 | Populated footer | `DiskCardModelTests > theFooterReadsThenWrites` (texts and `["Read", "Write"]`) | COMPLIANT |
| DC-7 | Distinct icons resolve | `DiskCardModelTests > theReadAndWriteSymbolsDifferAndResolve` | COMPLIANT |
| DC-7 | Unavailable rates | `DiskCardModelTests > missingRatesRenderEmDashesWithoutLosingTheirLabels` (U+2014, `"unavailable"`) | COMPLIANT |
| DC-8 | Nil model | `DiskCardModelTests > theNilSnapshotKeepsTheFullSkeletonWithEmDashes` (explicitly asserts `!= "0%"` and `!= "0.0%"`) | COMPLIANT |
| DC-8 | Height is stable | `PanelViewTests > theFirstDiskSnapshotFillsTheCardWithoutResizingThePanel` (`after == before`) | COMPLIANT |
| DC-9 | Token value | `PaletteTests > theDiskAccentMatchesTheProductPalette` (`#3DD68C`, `== memFree`) | COMPLIANT |
| DC-9 | Chrome parity | `DiskCardModelTests > theCardChromeMatchesTheOtherPanelCards` | COMPLIANT (see SUGGESTION S1) |
| DC-10 | Reduce motion | `DiskCardModelTests > theGaugeAnimationDelegatesToTheCPUCard` (`nil`) | COMPLIANT |
| DC-10 | Motion allowed | `DiskCardModelTests > theGaugeAnimationDelegatesToTheCPUCard` (`== CPUCardModel.gaugeAnimation(reduceMotion: false)`, non-nil) | COMPLIANT |
| DC-11 | Three-card height | `PanelViewTests > thePanelGrowsByTheFullDiskCard` (`>= cpu + memory + disk + chrome`, `> 620`, `>` two-card height) | COMPLIANT |

**Compliance summary**: 67/67 scenarios compliant, 26/26 requirements. No scenario is `UNTESTED`, `FAILING` or `PARTIAL`.

Every expected value was checked against the spec text literally. No weakened, widened or altered expectation was found: the reference figures (`432_068_000_000`, `27_100_000`, `2_200_000`, `54_200_000`, `1_000`, `"87.4%"`, `"100.0%"`, `"432.07 GB"`, `"27.1 MB/s"`) appear verbatim in the assertions, and the only tolerance in the suite is DM-3's own `± 0.0005` on `fraction`. Several tests assert *more* than their scenario demands (DM-4's write rate at the half window, DM-10's triangulating throw after real rates were published, DM-14's wait for non-nil rates); none asserts less.

### DM-15 document verification (`PRD.md`)

| Item | Required | Observed | Result |
|---|---|---|---|
| 6.2 value types | `DiskThroughputCounters` + `VolumeCapacity` behind the two-method port | `PRD.md:241-256` — `readThroughput()` / `readCapacity()` named, both structs with their documented fields | COMPLIANT |
| 6.2 `DiskSnapshot` | saturating `used`, `total == 0` guard, cap at 1, paired rates | `PRD.md:258-266` | COMPLIANT |
| No `DiskCounters` | absent | `rg DiskCounters PRD.md` → no match | COMPLIANT |
| R10.5 | `.decimal` | `PRD.md:170` reads `ByteCountFormatStyle(style: .decimal)` | COMPLIANT |
| No `.file` style | absent | `rg '\.file\b' PRD.md` → no match | COMPLIANT |
| 6.3 sandbox proof | `ENABLE_APP_SANDBOX = YES` + the two `.integration` suites | `PRD.md:278-279` cite `project.pbxproj:401,435`, `IOKitDiskIntegrationTests` and `VolumeCapacityIntegrationTests` | COMPLIANT |
| Section 10 | popover height growth, still fits 14" | `PRD.md:374` — "678 pt with two cards → 871 pt with three (the Disk card adds 175 pt)" | COMPLIANT |

### Coherence (Design)

| Decision / element | Followed? | Evidence |
|---|---|---|
| Layer placement of all 10 new files | Yes | Domain models/ports/services, `Infrastructure/{IOKit,System}`, `Presentation/{Panel,Components}` exactly as `design.md:246-261` |
| Domain signatures (`DiskThroughputCounters`, `VolumeCapacity`, `DiskSnapshot`, port, `Rates?`, `shouldRefresh`) | Yes | Verbatim; `DiskThroughputCalculator.swift:37-58`, `DiskCapacityCadence.swift:20-28` |
| `DiskSamplingStep` restart semantics | Yes | Step built **inside** the detached closure (`MetricsSampler.swift:230-238`), so `apply(interval:)` → `stop()`/`start()` yields a fresh step; `inlineDiskStep` untouched. Pinned by `aRestartCostsOneThroughputUnavailableDiskTick` and `applyingTheIntervalAlreadyInEffectKeepsTheDiskBaseline` |
| Cadence stamped with the throughput instant | Yes | `MetricsSampler.swift:83` passes `now: current.timestamp`; no clock read inside the step (convention 19) |
| Decision 2 throughput-throw behaviour | Yes | `MetricsSampler.swift:117-140` `withoutThroughput()`: cadence skipped, `previous` kept, cached capacity republished with `nil` rates, one-off capacity read when nothing cached leaving `capacityReadAt == nil`. Doc-commented in place and pinned by two tests |
| `PanelView.cards` order seam | Yes | `PanelView.swift:29` `[.cpu, .memory, .disk]`; body is `ForEach` + switch, so it cannot drift |
| Chrome constants (16 / 14 / 6 / 6 / 13 / 16) | Yes | `DiskCard.swift:172-177`; identical to `MemoryCard.swift:171-177` (verified by reading both) |
| Symbols `internaldrive` / `arrow.down.doc` / `arrow.up.doc` | Yes | `DiskCard.swift:39-44`; machine-resolved by two tests. Decision 6's fallback pair correctly unused |
| `advanced()` algorithm steps 1–4 | Yes | `MetricsSampler.swift:71-115` follows the design step for step |
| `DiskSnapshot` capacity init declared in the type body | **No** | Declared in a `nonisolated extension` (`DiskSnapshot.swift:35-58`) — see WARNING W1 |
| `DiskSamplingStep.init(provider:)` | **No** | Memberwise initialiser only — see WARNING W2 |
| Decision 3 unit-selection wording | Implementation correct, design text wrong | See WARNING W3 |

### Conventions 1–19 and hexagonal boundaries

| Check | Result |
|---|---|
| 1 — every new Domain/Infrastructure/pure Presentation type is `nonisolated` + `Sendable`, nested types included | Pass. 13 of 15 new top-level types carry explicit `nonisolated`; the two that do not (`DiskCard`, `ThroughputLabel`) are SwiftUI views, which the convention places on the main actor, matching `CPUCard`/`MemoryCard`/`PanelView` |
| 2 — tests never `@MainActor` | Pass. No `@MainActor` on any test function; it appears only on helper factories (`PanelViewTests.swift:44,51,58,63`, `AppDelegateCompositionTests.swift:78,100,122`), which the convention permits |
| 3 — detached `.utility` loop, only Sendable captures, no `self` | Pass (`MetricsSampler.swift:213-224`) |
| 4 — fakes use `Synchronization.Mutex`, zero-based throw indexes, record `Thread.isMainThread` | Pass. `FakeDiskProvider` stores a single `let Mutex<Script>`, no `@unchecked Sendable` |
| 5 — `.timeLimit(.minutes(1))` is the only time-limit trait | Pass. Present on `MetricsSamplerLoopTests`, both `.integration` disk suites and `VolumeCapacityReaderTests`; no other time-limit trait anywhere |
| 6 — `project.pbxproj` never edited | Pass. Clean after five xcodebuild invocations in this phase; no revert needed |
| 7 — widget untouched, `statusItem.length` unchanged | Pass. `MetricModule.swift` untouched (`[.cpu, .memory]`); asserted behaviourally by `publishingDiskReadingsLeavesTheStatusItemWidthUnchanged` |
| 8 — `.integration` suites prove sandboxed access | Pass. 13 `.integration` cases green in the sandboxed test host |
| 9 — locale whitespace normaliser, `en_US` + `de_DE` pins | Pass. Per-suite normaliser in `ByteFormatterTests`, `ThroughputFormatterTests`, `DiskCardModelTests` |
| 10 — strict TDD, stated unit command | Pass. Every task pair has RED evidence in `apply-progress.md`; two REDs (2.5, 2.7, 5.1) are behavioural rather than compile-level |
| 17 — every IOKit handle released in a `defer`, matching dictionary never released by the caller | Pass. `IOKitDiskProvider.swift` — `defer { IOObjectRelease(iterator) }` and `defer { IOObjectRelease(driver) }`; the consumed matching dictionary is commented and never released |
| 18 — IOKit names as literals unless the compile proves the SDK constants | Pass, SDK-constant branch. The four `private static let`s alias `kIOBlockStorageDriverClass`, `…StatisticsKey`, `…StatisticsBytesReadKey`, `…StatisticsBytesWrittenKey` with the header citations kept as comments. The convention explicitly permits this once the compile proves exposure, which it did |
| 19 — `ManualClock` in loop suites; cadence and rate scenarios scripted, never wall-clock | Pass. The only real sleeps are in `.integration` suites where DM-12 itself demands "two reads at least 120 ms apart" |
| No IOKit / Mach / sysctl / Foundation-volume API outside Infrastructure | Pass. `rg` over `system-monitor/` excluding `Infrastructure/` returns nothing |
| `DiskCard` takes only a `DiskSnapshot?` | Pass. `DiskCard.swift:168` is the single stored property; the only environment read is `accessibilityReduceMotion`, which DC-10 requires and `CPUCard`/`MemoryCard` also use |
| No `MetricHistory` for disk | Pass. `MetricsState.swift` declares only `cpuHistory` and `memoryHistory`; absence pinned by `theStateExposesNoDiskHistoryProperty` |
| `MetricModule.allCases` unchanged | Pass. `[.cpu, .memory]`; file untouched in `git status` |
| Composition root injects the real provider | Pass. `AppDelegate.swift:43` — `IOKitDiskProvider(capacity: VolumeCapacityReader())`; the temporary `UnwiredDiskProvider` is fully removed (`rg` returns no match) |

### PRD success criteria — M5 / R10.1–R10.11 traceability

| PRD requirement | Where it is satisfied | Evidence |
|---|---|---|
| R10.1 read throughput | DM-1, DM-12 | `IOKitDiskProvider.readThroughput()`; 6 `.integration` cases |
| R10.2 read capacity | DM-3, DM-13 | `VolumeCapacityReader`; 7 `.integration` cases |
| R10.3 throughput rates | DM-2, DM-4, DM-6 | `DiskThroughputCalculator`, reference rates green |
| R10.4 negative-delta re-seed | DM-4 | `theReSeededBaselineRecoversOnTheNextTick` |
| R10.5 decimal formatting | DC-5, DC-6, DM-15 | `ByteFormatter.capacity` / `.throughput`; PRD amended to `.decimal` |
| R10.6 rows and footer | DC-4, DC-7 | Used/Free/Total plus read/write footer |
| R10.7 10 s capacity cadence | DM-5, DM-7 | `DiskCapacityCadence`; `capacityCalls == 1` under 10 s |
| R10.8 no history | DM-11, DC-2 | No `MetricHistory`; `sections` carries no graph and no bar |
| R10.9 unavailable state | DM-10, DC-7, DC-8 | Em dashes with `"unavailable"`; failures isolated |
| R10.10 accessibility and chrome | DC-3, DC-7, DC-9 | Header trait, per-reading labels, palette token |
| R10.11 widget unchanged | DM-14 | `MetricModule.allCases` and status-item width asserted |
| PRD 2 success metric (values match Finder) | Task 7.3 | **Open — manual, user-owned** |
| PRD 8 / 10 profiling | Task 7.6 | **Open — manual, user-owned**; no Instruments figure is available for this report |
| PRD 8 coverage target (Domain + Application 80%+) | — | **Not measurable** — coverage is not configured on the scheme |

### TDD Compliance

| Check | Result | Details |
|-------|--------|---------|
| TDD Evidence reported | Yes | Six "TDD Cycle Evidence" tables in `apply-progress.md`, one per batch A–F+G |
| All tasks have tests | Yes | 21 disk test files exist on disk; every RED row names a file that is present |
| RED confirmed (tests exist) | Yes | 21/21 test files verified present; every observed RED failure is quoted with its compiler or assertion message |
| GREEN confirmed (tests pass) | Yes | Every named suite passes in this phase's own runs; no suite listed as green in apply is red now |
| Triangulation adequate | Yes | Every multi-scenario requirement has one case per scenario; DM-4 has 10 cases for 8 scenarios, DC-8 covers model and height separately |
| Safety Net for modified files | Yes | Each batch that modified a pre-existing suite recorded a pre-edit green run (`MetricsStateTests` 39/39, `PanelViewTests` 7/7, `PaletteTests`+`ByteFormatterTests` 10/10, `AppDelegateCompositionTests` 7/7); `N/A (new)` rows correspond to genuinely new files |
| Behavioural (not just compile-level) REDs | Yes | Tasks 2.5, 2.7 and 5.1 produced failing assertions on a compiling target, which is the stronger form |

**TDD Compliance**: 7/7 checks passed.

### Test Layer Distribution

| Layer | Tests | Files | Tools |
|-------|-------|-------|-------|
| Unit (Domain, Application, Presentation, pure Infrastructure seam) | 545 | — | Swift Testing (`@Test` / `#expect`) |
| Integration (`.integration`, sandboxed test host: live IOKit, live boot volume, real composition graph) | 13 | 3 files + 3 cases in `AppDelegateCompositionTests` | Swift Testing + real hardware |
| UI (pre-existing Xcode template) | 3 | 1 | XCTest / XCUITest |
| **Total (FULL)** | **561** | | |

Of the disk work specifically: 21 new or extended test files contribute roughly 120 disk-specific cases, 13 of which read live hardware.

### Assertion Quality

Every disk test file was scanned for the banned patterns. No tautology, no assertion that never calls production code, no ghost loop, no smoke-test-only case, and no mock-heavy file was found. Specific strengths worth recording:

- The negative assertions cannot pass vacuously: `theStateExposesNoDiskHistoryProperty` asserts the `cpuHistory`/`memoryHistory` labels **are** present in the same reflection pass that proves no disk history is.
- `theNilSnapshotKeepsTheFullSkeletonWithEmDashes` asserts the em dash *and* explicitly `!= "0%"` and `!= "0.0%"`, so DC-8's prohibition is pinned rather than implied.
- `theDiskGaugeTextFollowsTheAppliedSnapshot` asserts the before-state is the em dash, so "the empty panel invented a reading" would fail.
- Empty-collection and type-only assertions are always paired with value assertions.

**Assertion quality**: All assertions verify real behaviour. 0 CRITICAL, 0 WARNING.

### Quality Metrics

**Linter**: Not configured in this project — no SwiftLint configuration is present.
**Type checker / compiler**: Passed — `build` and `build-for-testing` both exit 0 with zero warnings under Swift 6 strict concurrency and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

### Issues Found

**CRITICAL**: None.

**WARNING**:

1. **W1 — `DiskSnapshot`'s capacity initialiser is declared in an extension, not in the type body.** `system-monitor/Domain/Models/DiskSnapshot.swift:35-58` versus `design.md:52`. The signature is byte-identical; the move preserves the synthesised memberwise initialiser that DM-3's `used > total` clamp scenario needs, and the extension carries an explicit `nonisolated` because an extension does not inherit the type's isolation under this project's default-MainActor setting. Documented in `apply-progress.md` deviations A1 and B2. No spec is affected. Accepted, recorded so archive merges the design with this known difference.
2. **W2 — `DiskSamplingStep` declares no `init(provider:)`.** `design.md:91` sketches one; the implementation uses the memberwise initialiser only (`MetricsSampler.swift:57-61`), because a custom initialiser would suppress the memberwise form that the loop, `sampleOnce()` and the step-level tests all construct. `tasks.md` 2.4 explicitly mandates this, so the task list and the design disagree and the task list won. No spec is affected.
3. **W3 — `design.md:207` (decision 3) is self-contradictory and its wording should be corrected before it becomes the record.** It says the unit is "the largest one whose scaled value rounded to one fraction digit stays below 1000", but its own two examples (999 949 → `999.9 kB/s`, 999 950 → `1.0 MB/s`) require the **smallest** such unit — under a literal "largest" reading, 999 949 B/s would select TB. The implementation (`ByteFormatter.throughput`) and the tests follow the examples and DC-6, so behaviour is correct; only the design prose is wrong. Archive should carry the corrected wording.
4. **W4 — one of three `FULL` runs was red on a case outside this change.** `system_monitorUITests.testLaunchPerformance()` failed in run 2 (exit 65) and passed in runs 1 and 3. It is the Xcode-template launch-performance case in the UI target, which this change does not touch, and batch C already reproduced the failure on a clean baseline with every disk file removed. Reported per the flake protocol; not a regression and not a blocker. It will keep failing intermittently for future phases.

**SUGGESTION**:

1. **S1 — DC-9 chrome parity is pinned as literals, not as a comparison.** `DiskCardModelTests > theCardChromeMatchesTheOtherPanelCards` asserts `DiskCard.cardPadding == 16` and so on, because `MemoryCard`'s equivalents are `private static` and unreachable. Parity was confirmed by reading both files during this verification (`MemoryCard.swift:171-177`: 16 / 14 / 6 / 6 / 13 — identical), but a future `MemoryCard` restyle would silently break the parity DC-9 requires without failing any test. Promoting `MemoryCard`'s constants to internal `nonisolated static` in a later change would close this.
2. **S2 — DC-6's below-1-kB vocabulary is pinned under `en_US` only for non-zero values.** The requirement asks that the sub-kilobyte vocabulary and the zero string be pinned under both locales. `"0 B/s"` is pinned under both; `"512 B/s"` and `"999 B/s"` are pinned under `en_US` only. There is no behavioural risk — below 1 kB the implementation emits an integer with `grouping(.never)` and no fraction digit, so the string is locale-invariant — but a `de_DE` pin would make that invariance explicit rather than incidental.
3. **S3 — coverage cannot be measured.** The project ships no shared `.xcscheme`, so code coverage is not enabled and PRD section 8's "Domain + Application 80%+" target has no number attached to it. Enabling coverage on a shared scheme would let a future verify report state it instead of skipping it.
4. **S4 — convention 18 resolved to the SDK-constant branch, which is conformance, not deviation.** `apply-progress.md` lists the `kIOBlockStorageDriver*` aliasing among its deviations, but convention 18's own text permits exactly this once the compile proves `import IOKit.storage` exposes the constants, which a standalone `xcrun swiftc` probe and the project build both did. Recorded so archive does not carry it forward as an outstanding deviation.

### Open manual checks (user-owned, not failures)

| Task | Status | What it still owes |
|---|---|---|
| 7.3 Card correctness (PRD 2 success metric) | open (manual, user-owned) | Four numbers: card Total, card Free, Finder Total, Finder Available (|Δ| ≤ 100 MB); footer moves during a large copy and settles afterwards |
| 7.4 Unavailable and motion states | open (manual, user-owned) | Em dashes rather than `0%` / `0.0 MB/s`; VoiceOver reads "unavailable"; Reduce Motion makes the ring jump |
| 7.5 Layout | open (manual, user-owned) | CPU / Memory / Disk at 12 pt gaps and 320 pt width; 871 pt still fits a 14" display; widget width and module set unchanged |
| 7.6 Instruments (PRD 8 / 10) | open (manual, user-owned) | Average CPU and resident size with the panel closed for 10 minutes against the ~1.6% M4 baseline. **This figure was owed to this report and is not available**, so no profiling claim is made here |

The automated evidence covers the machine-checkable half of every one of these four: DC-8 and DC-10 pin the unavailable and motion behaviour at the model level, DC-1 and DC-11 pin the order and the measured 871 pt height, DM-14 pins the widget width, and DM-13's `.integration` suite pins capacity against the live boot volume. What remains is human confirmation on real hardware, which no test can substitute for.

### Native runtime ledger

Acquire (`request-id disk-module-verify-actor-20260910`, `--work-unit verify-rev-1`, `--max-attempts 2`, `--max-changed-lines 3600`, `--untracked-scope=exclude`, `--expected-untracked-inventory=sha256:5c6326e8…`, `--token sha256:8ce65d8f…`) — accepted on the first call; the inventory hash the prompt carried was still current:

```json
{
  "state": "proceed",
  "token": "sha256:8ce65d8f4e80347cc932de7dc8f0c632466d43ea521852adf6549e6f3a93c6cb"
}
```

Settlement follows the persistence of this report, as the verify contract requires, with `--request-id disk-module-verify-settle-20260910`, `--outcome passed`, `--evidence-revision sha256:e17479bbd34b3d32b30b77304dca13817be67e2fb2991980db4bf5dce678b72b` (the sha256 of the `FULL` run of record), `--harness-disposition reused`, `--diagnosis`, `--cleanup-evidence` and `--process-evidence`, under the same token. Its raw JSON is reported in this phase's return envelope, because it cannot be written into the bytes it attests.

This phase wrote no production or test code and committed nothing. The only file it created is this report.

### Verdict

**PASS WITH WARNINGS** — all 26 requirements and all 67 scenarios are covered by tests that passed at runtime, both builds are warning-free, the hexagonal boundaries and conventions 1–19 hold, and `PRD.md` carries the DM-15 alignment; four warnings are recorded, none of which blocks archive: two documented design-interface deviations, one design-prose defect to correct during archive, and one pre-existing flaky UI-template case outside this change.

### What archive must know

1. **Nothing is committed.** The whole change is one uncommitted working tree: 17 modified tracked files, 21 new untracked source and test files, plus `openspec/changes/disk-module/`. Delivery stays user-owned.
2. **`.gitignore` and `openspec/config.yaml` were already modified before this change began** and are not part of it. Do not fold them into the disk-module candidate.
3. **Correct `design.md:207` when merging the design into the record** — decision 3 must read "smallest", not "largest" (W3). This is the one artifact edit archive genuinely owes.
4. **Two design-interface deviations are permanent and intentional** (W1, W2). The specs of record are unaffected; if archive regenerates any interface listing from `design.md`, it must carry the extension-declared `DiskSnapshot` initialiser and the absence of `DiskSamplingStep.init(provider:)`.
5. **Tasks 7.3–7.6 remain open and are the user's.** Archive must not mark them complete, and PRD 8's profiling figure is still unrecorded.
6. **Coverage is unmeasured**, not failing (S3). No coverage number should be asserted in the archived record.
7. **`system_monitorUITests.testLaunchPerformance()` is flaky** (W4). A red `FULL` run whose only failure is that case is not a regression; rerun once.
8. **Two capability specs are new**: `disk-metrics` (DM-1..DM-15) and `disk-card` (DC-1..DC-11), 67 scenarios total, to be merged as specs of record.
