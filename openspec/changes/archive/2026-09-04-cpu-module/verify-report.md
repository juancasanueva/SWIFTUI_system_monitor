```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:27e7f9b35cb7c3cdd14f105068d42c78f1db4dc86ce028295528e243fb62544e
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 30/30
scenarios: 61/61
test_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests
test_exit_code: 0
test_output_hash: sha256:87b476a932a4c321d35aa797cd44a3525bd2438a37c17d64602818d3d89a1a31
build_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build
build_exit_code: 0
build_output_hash: sha256:c3839431f70daa5c9fb522cf269739528b3ee18224f6100827df24f95fd61d9d
```

## Verification Report

**Change**: cpu-module
**Version**: specs as amended 2026-09-04 (40 pt sparkline on every module; 230 pt width budget)
**Mode**: Strict TDD

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 35 |
| Tasks complete | 35 |
| Tasks incomplete | 0 |
| Specs read | 4 (cpu-metrics, core-topology, menu-bar-widget, cpu-card) |
| Requirements | 30 |
| Scenarios | 61 |

Task checkbox state matches code state. Every file named by a task exists, and the two files
`tasks.md` never named (`CPUMetricsProviderPortTests.swift`, `CanvasComponentsTests.swift`,
`CPUCardTests.swift`, `PanelViewTests.swift`) are the additive RED gates that Strict TDD required
and that `apply-progress.md` declares.

### Build & Tests Execution

**Build**: PASSED — exit 0

```text
xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build
exit 0 — zero errors, zero warnings.
Output is 4 lines: the IDERunDestination notice and the multiple-matching-destination
warning (arm64 / x86_64 on the same host). No diagnostic from any source file.
```

**Tests**: PASSED — 188 passed, 0 failed, 0 skipped — exit 0

```text
xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests
exit 0
188 test cases executed across 23 suites, 0 failures, 0 known issues, 0 disabled.
Total observer window: 1.458 sec.
```

Per-suite case counts (verbatim from the run):

| Suite | Cases | Suite | Cases |
|---|---|---|---|
| CoreTopologyResolverTests | 22 | MetricsStateTests | 5 |
| PercentFormatterTests | 19 | MetricsSamplerLoopTests | 5 |
| CPUCardModelTests | 16 | CPUTicksTests | 5 |
| CPUUsageCalculatorTests | 15 | StatusItemControllerTests | 4 |
| MenuBarReadingsTests | 12 | PanelViewTests | 4 |
| MachIntegrationTests | 11 | PaletteTests | 4 |
| SparklineGeometryTests | 10 | MetricModuleTests | 4 |
| MetricHistoryTests | 8 | CanvasComponentEqualityTests | 4 |
| CoreBarGridTests | 8 | StatusItemReadingsTests | 3 |
| StatusItemMetricsTests | 7 | CPUSnapshotTests | 3 |
| MetricsSamplerStepTests | 7 | | |
| CPUMetricsProviderPortTests | 6 | | |
| CoreTopologyTests | 6 | **Total** | **188** |

The 11 `.integration` cases ran on real hardware inside the sandboxed test host, as expected.

**Coverage**: not available — the scheme is not run with `-enableCodeCoverage`, and no coverage
tool is configured for this project. Coverage analysis skipped (informational, not a failure).

### Spec Compliance Matrix

#### cpu-metrics — 9 requirements, 21 scenarios

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| Tick sample port | Fake provider satisfies the port | `CPUMetricsProviderPortTests > scriptedFakeReturnsEachSampleInOrder` | COMPLIANT |
| Per-core usage from tick deltas | Idle delta yields total usage | `CPUUsageCalculatorTests > coreUsageIsOneMinusTheIdleShareOfTheDelta` | COMPLIANT |
| Per-core usage from tick deltas | Nice ticks fold into user | `CPUUsageCalculatorTests > niceTicksAreReportedAsUserTime` | COMPLIANT |
| Per-core usage from tick deltas | Counter wrap-around | `CPUUsageCalculatorTests > wrappedCountersProduceTheShortDelta`; `CPUTicksTests > deltaWrapsAroundWhenTheCounterOverflows` | COMPLIANT |
| Per-core usage from tick deltas | Zero total delta | `CPUUsageCalculatorTests > identicalSamplesReportZeroUsageInsteadOfNaN` | COMPLIANT |
| Aggregate usage from summed deltas | Unequal per-core deltas | `CPUUsageCalculatorTests > aggregatesUseSummedDeltasNotTheMeanOfCoreRatios` | COMPLIANT |
| Per-level averages | Mean per level | `CPUUsageCalculatorTests > levelAveragesAreTheArithmeticMeanOfTheirCores` | COMPLIANT |
| Per-level averages | All cores unknown | `CPUUsageCalculatorTests > unknownTopologyHasNoLevelAverages`; `aLevelWithoutCoresHasNoAverage` | COMPLIANT |
| Snapshot preconditions | Missing previous sample | `CPUUsageCalculatorTests > firstSampleProducesNoSnapshot` | COMPLIANT |
| Snapshot preconditions | Core count mismatch | `CPUUsageCalculatorTests > mismatchedCoreCountsProduceNoSnapshot` | COMPLIANT |
| History ring buffer | Drop oldest beyond capacity | `MetricHistoryTests > appendingBeyondCapacityDropsTheOldestValue` | COMPLIANT |
| History ring buffer | Suffix and empty | `MetricHistoryTests > suffixReturnsTheNewestValuesOldestToNewest`; `emptyHistoryHasNoOrderedValuesAndNoSuffix` | COMPLIANT |
| History ring buffer | Capacity one | `MetricHistoryTests > capacityOneKeepsOnlyTheMostRecentValue` | COMPLIANT |
| Sampler publishes only from the second sample | One step publishes nothing | `MetricsSamplerStepTests > theFirstStepOnlyRetainsTheSample` | COMPLIANT |
| Sampler publishes only from the second sample | Second step publishes | `MetricsSamplerStepTests > theSecondStepPublishesExactlyOneSnapshot` | COMPLIANT |
| Sampler publishes only from the second sample | History stays bounded | `MetricsStateTests > historyStaysBoundedAtOneHundredTwentySamples` | COMPLIANT |
| Startup double-sample and cadence | Real value within 200 ms | `MetricsSamplerLoopTests > startPublishesARealValueWithinTwoHundredMilliseconds` | COMPLIANT |
| Startup double-sample and cadence | Injected interval drives the loop | `MetricsSamplerLoopTests > theInjectedIntervalKeepsTheLoopPublishing` | PARTIAL (W1) |
| Loop resilience and cancellation | Throwing provider keeps looping | `MetricsSamplerStepTests > aThrowingReadPublishesNothingAndKeepsThePreviousSample`; `stepKeepsItsPreviousSampleWhenTheReadThrows` | COMPLIANT |
| Loop resilience and cancellation | Stop cancels | `MetricsSamplerLoopTests > stopFreezesThePublishedCount`; `startIsIdempotentSoStopHaltsEveryIteration` | COMPLIANT |
| Loop resilience and cancellation | Off-main sampling | `MetricsSamplerLoopTests > everyReadHappensOffTheMainThread` | COMPLIANT |

#### core-topology — 6 requirements, 13 scenarios

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| Topology model and port | Level lookup | `CoreTopologyTests > levelLookupReturnsTheLevelStoredAtThatIndex` | COMPLIANT |
| Topology model and port | Missing index | `CoreTopologyTests > levelLookupOutsideTheCoreRangeIsUnknown` | COMPLIANT |
| Cores ordered P then E | E-first fake topology | `CPUUsageCalculatorTests > efficiencyFirstTopologyIsReorderedPerformanceFirst` | COMPLIANT |
| Cores ordered P then E | P-first fake topology | `CPUUsageCalculatorTests > performanceFirstTopologyKeepsItsOrder` | COMPLIANT |
| Cores ordered P then E | All unknown keeps Mach order | `CPUUsageCalculatorTests > unknownTopologyKeepsMachOrder` | COMPLIANT |
| Level resolution from the hardware description | Cluster type mapping | `CoreTopologyResolverTests > clusterTypeMapsToItsPerformanceLevel(clusterType:expected:)` | COMPLIANT |
| Count cross-check | Consistent counts | `CoreTopologyResolverTests > matchingCountsProduceAFullyResolvedTopology` | COMPLIANT |
| Count cross-check | P count mismatch | `CoreTopologyResolverTests > aPerformanceCountMismatchYieldsAnAllUnknownTopology` | COMPLIANT |
| Count cross-check | Total mismatch against Mach | `CoreTopologyResolverTests > aTotalMismatchYieldsAnAllUnknownTopologySizedToTheExpectedTotal` | COMPLIANT |
| Count cross-check | One "M" entry poisons the topology | `CoreTopologyResolverTests > aSingleUnrecognisedClusterTypePoisonsTheWholeTopology` | COMPLIANT |
| Degradation on unavailable sources | No perflevel split | `CoreTopologyResolverTests > aMissingPerformanceCountYieldsAnAllUnknownTopology`; `aMissingEfficiencyCountYieldsAnAllUnknownTopology` | COMPLIANT |
| Degradation on unavailable sources | Registry unreadable | `CoreTopologyResolverTests > noEntriesAtAllYieldAnAllUnknownTopologySizedToTheMachCount` | COMPLIANT |
| Real-hardware verification | Integration shape check | `MachIntegrationTests > topologySizeMatchesTheMachCoreCount`; `perLevelCountsMatchTheSysctlValuesOnAppleSilicon`; `topologyIsEitherFullyResolvedOrFullyUnknown` | COMPLIANT |

#### menu-bar-widget — 7 requirements, 13 scenarios

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| Data-driven module list | Order preserved | `MenuBarReadingsTests > readingsFollowTheMenuBarOrder`; `MetricModuleTests > menuBarOrderIsCPUThenMemory` | COMPLIANT |
| Integer percentage value | Integer formatting | `PercentFormatterTests > integerRoundsToTheNearestWholePercent(fraction:expected:)`; `MenuBarReadingsTests > theCPUValueIsAWholePercentage(total:expected:)` | COMPLIANT |
| Integer percentage value | No snapshot yet | `MenuBarReadingsTests > theCPUValueReadsZeroPercentBeforeTheFirstSnapshot` | COMPLIANT |
| Sixty-sample sparkline | Last 60 of 120 | `MenuBarReadingsTests > theSparklineUsesTheNewestSixtySamples`; `StatusItemMetricsTests > theSparklineStillHoldsSixtySamples` | COMPLIANT |
| Sixty-sample sparkline | Partial history | `MenuBarReadingsTests > aPartialHistoryKeepsEveryStoredSample`; `SparklineGeometryTests > aPartialHistoryIsRightAlignedAtTheCapacityStep` | COMPLIANT |
| Sixty-sample sparkline | Empty history | `MenuBarReadingsTests > anEmptyHistoryProducesNoSamples`; `SparklineGeometryTests > anEmptyHistoryProducesNoPoints` | COMPLIANT |
| Fixed-width, jitter-free layout | Length stable across updates | `StatusItemControllerTests > theStatusItemLengthDoesNotChangeWhenTheValueChanges` | COMPLIANT |
| Fixed-width, jitter-free layout | Sizing options disabled | `StatusItemControllerTests > theHostingViewDoesNotResizeItselfFromItsContent` | COMPLIANT |
| Fixed-width, jitter-free layout | Width budget (< 230 pt) | `StatusItemControllerTests > theWidgetStaysUnderTheWidthBudgetAtFullScale` | COMPLIANT |
| Live updates | Value follows state | `MenuBarReadingsTests > theCPUValueFollowsTheSnapshotTotal` | COMPLIANT |
| Live updates | Equal data compares equal | `CanvasComponentEqualityTests > sparklinesWithTheSameSamplesCompareEqual`; `MenuBarReadingsTests > readingsBuiltFromTheSameStateCompareEqual` | COMPLIANT |
| Legibility | Accent from module | `StatusItemReadingsTests > cpuUsesTheCPUAccent`; `memoryUsesTheMemoryAccent`; `everyModuleResolvesToADistinctAccent` | COMPLIANT |
| Every module renders a sparkline | MEM placeholder still has a sparkline | `StatusItemMetricsTests > everyModuleReservesItsSparklineArea(module:)`; `theSparklineKeepsItsFortyPointWidth`; `MenuBarReadingsTests > theMemoryModuleStaysAPlaceholder`; `StatusItemControllerTests > theWidgetStaysUnderTheWidthBudgetAtFullScale` | COMPLIANT |

#### cpu-card — 8 requirements, 14 scenarios

| Requirement | Scenario | Test | Result |
|---|---|---|---|
| Presentational contract | Card renders from fixed inputs | `PanelViewTests > thePanelRendersTheCPUCardRatherThanAPlaceholder` (runtime `NSHostingView` render) | COMPLIANT (S4) |
| Presentational contract | Live update while open | `PanelViewTests > theGaugeTextFollowsTheStateTotal`; `applyingASnapshotWithCoresGrowsThePanelWithBarGroups` | COMPLIANT |
| Header and gauge | One-decimal formatting | `CPUCardModelTests > theGaugeTextIsTheTotalAtOneDecimal`; `PercentFormatterTests > oneDecimalUsesASingleFractionDigitUnderEnglish(fraction:expected:)` | COMPLIANT |
| Header and gauge | Locale decimal separator | `PercentFormatterTests > oneDecimalUsesTheLocaleDecimalSeparator` | COMPLIANT |
| Key/value rows | Four rows on Apple Silicon | `CPUCardModelTests > aSplitSnapshotProducesUserSystemAndBothLevelRows` | COMPLIANT |
| Key/value rows | Two rows when levels unknown | `CPUCardModelTests > aSnapshotWithoutLevelAveragesProducesOnlyUserAndSystem` | COMPLIANT |
| History graph | Full history | `CPUCardModelTests > theGraphUsesEveryHistoryValueOldestFirst` | COMPLIANT |
| History graph | Short history | `CPUCardModelTests > theGraphToleratesFewerSamplesThanTheCapacity`; `theGraphOfAnEmptyHistoryHasNoSamples` | COMPLIANT |
| Per-core bars grouped P then E | 8 P + 4 E | `CPUCardModelTests > aSplitSnapshotProducesAPerformanceGroupThenAnEfficiencyGroup` | COMPLIANT |
| Per-core bars grouped P then E | 16 P-cores wrap | `CoreBarGridTests > sixteenCoresWrapIntoTwoFullRows`; `noRowHoldsMoreThanEightBars` | COMPLIANT |
| Per-core bars grouped P then E | Bar label | `CPUCardModelTests > aBarLabelIsTheCoreUsageAsAWholePercent` | COMPLIANT |
| Degraded "Cores" layout | Intel or mismatch topology | `CPUCardModelTests > anAllUnknownSnapshotProducesASingleCoresGroup` | COMPLIANT |
| No-snapshot placeholder | Nil snapshot | `CPUCardModelTests > aMissingSnapshotProducesNoBarGroups`; `theGaugeReadsZeroBeforeTheFirstSnapshot`; `aMissingSnapshotStillProducesZeroedUserAndSystemRows` | COMPLIANT |
| Palette and card surface | Token values | `PaletteTests > accentTokensMatchTheProductPalette`; `surfaceTokensMatchTheProductPalette`; `textTokensMatchTheProductPalette`; `cardSurfaceUsesTheDocumentedCornerRadius` | COMPLIANT |

**Compliance summary**: 61/61 scenarios have a passing covering test — 60 COMPLIANT, 1 PARTIAL (covered by a passing test whose timing bound is looser than the scenario states, W1), 0 UNTESTED, 0 FAILING.

### Correctness (Static Evidence)

| Requirement area | Status | Notes |
|---|---|---|
| Startup double-sample | Implemented | `MetricsSampler.start()` seeds `previous`, sleeps `startupGap` (default 100 ms), then switches `gap = interval`. |
| Off-main sampling | Implemented | `Task.detached(priority: .utility)`; only `CPUSnapshot` crosses back via `await state.apply(cpu:)`. |
| Loop resilience | Implemented | `CPUSamplingStep.advanced()` returns `(nil, self)` on a failed read, so `previous` survives and the loop continues. |
| Cancellation | Implemented | `stop()` cancels the task and nils it; the loop breaks on a cancelled `clock.sleep`. |
| Aggregate math | Implemented | Summed deltas, wrapping subtraction, zero-delta guard, nice folded into user. |
| Topology all-or-nothing | Implemented | `CoreTopologyResolver` degrades to `CoreTopology.unknown(coreCount:)` on any mismatch, duplicate or out-of-range logical id. |
| Widget fixed width | Implemented | `sizingOptions = []`; `statusItem.length` from `measuredContentWidth()` once; `valueWidth` measured from `"100%"`. |
| Widget geometry (amended spec) | Implemented | `sparklineWidth = 40`, `elementSpacing = 4`, `moduleSpacing = 6`, `horizontalPadding = 2`; every module draws a sparkline unconditionally; measured 221 pt against the 230 pt budget. |
| Card surface | Implemented | `Palette.cardBackground` in a `RoundedRectangle(cornerRadius: Palette.cardCornerRadius)` (12); no stroke/border anywhere in `CPUCard.swift`. |
| Reduce-motion gate | Implemented | `@Environment(\.accessibilityReduceMotion)`; `.animation(reduceMotion ? nil : Self.gaugeAnimation, value:)`. |
| Composition root | Implemented | `AppDelegate` builds `MetricsState`, `MachCPUProvider`, `IORegistryCoreTopologyProvider(sysctl:)`, `MetricsSampler`, `StatusItemController(state:)`; `start()` on launch, `stop()` on terminate; strong refs held. |

### Isolation Convention (`system-monitor/swift6-nonisolated-domain`)

| Check | Result | Evidence |
|---|---|---|
| Domain / Ports / Infrastructure / test doubles are `nonisolated` | PASS | Only three type declarations in `Domain`, `Application`, `Infrastructure`, `Tests/Support` lack `nonisolated`: `MetricsState` and `MetricsSampler` (both intentionally `@MainActor`) and `extension Tag` (a Swift Testing tag namespace). |
| Nested types explicitly `nonisolated` | PASS | All four nested declarations carry it: `MachCPUProvider.ReadError`, `CoreTopologyResolver.Entry`, `FakeCPUProvider.ScriptedError`, `FakeCPUProvider.Script`. |
| No test is `@MainActor` | PASS | Zero `@Suite` or `@Test` declarations are `@MainActor`. The six `@MainActor` occurrences in tests are all on `private` helper functions that touch `NSHostingView` / `MetricsState` (`PanelViewTests.fittingSize`, `StatusItemMetricsTests.contentWidth`, two `makeSampler` helpers) plus two `defer { Task { @MainActor in ... } }` teardown closures. This is required, not a violation. |
| `MetricsState` is `@MainActor @Observable` | PASS | `MetricsState.swift:9-11`. |
| Sampler loop is `Task.detached` | PASS | `MetricsSampler.swift:86` — `Task.detached(priority: .utility)`. |

### Repository Hygiene

| Check | Result | Evidence |
|---|---|---|
| `project.pbxproj` not edited | PASS | 5 `PBXFileSystemSynchronizedRootGroup` entries, zero `PBXBuildFile` entries, and zero references to any new file (`MetricHistory`, `CPUCard`, `MetricsSampler`, `Palette`, `Sparkline`). New files are picked up by the synchronized root group. |
| No new dependencies | PASS | No `Package.swift`, `Package.resolved`, `Podfile` or `Cartfile`; zero `XCRemoteSwiftPackageReference` / `packageReferences` in the project file. |
| No commits | PASS | `git log` reports `your current branch 'main' does not have any commits yet`. The whole tree is untracked. |

### Coherence (Design)

| Decision | Followed? | Notes |
|---|---|---|
| Hexagonal four layers, one dependency direction | Yes | Domain has no SwiftUI/AppKit import; `CPUCard` takes only `CPUSnapshot?` + `MetricHistory`. |
| `@MainActor` sampler launching one `Task.detached` loop | Yes | Verbatim. |
| `@MainActor @Observable MetricsState` | Yes | Verbatim. |
| Every Domain/Infra/formatter/double `nonisolated` + `Sendable` | Yes | Verified above. |
| Nested types explicitly `nonisolated` | Yes | All four named in design.md:199 are present and annotated. |
| `sizingOptions = []`, length measured once from `measurementReadings` | Yes | design.md:206-207. |
| Domain/Application/Infrastructure type signatures | Yes | `CPUTicks`, `CPUTickSample`, `PerformanceLevel`, `CoreTopology`, `CoreUsage`, `CPUSnapshot`, `MetricHistory`, both ports, `CPUUsageCalculator`, `CPUSamplingStep`, `MachCPUProvider`, `SysctlReader`, `CoreTopologyResolver`, `Palette`, `ModuleReading` all match. |
| `PercentFormatter.oneDecimal` via FormatStyle `.percent` | No — W2 | Uses `.number` + literal `%`. Required by the spec; design.md:169 is stale. |
| `IORegistryEntryFromPath("IODeviceTree:/cpus")`, `logical-cpu-id` as `OSData` | No — W3 | Uses `IOServiceMatching("AppleARMPE")` children and accepts both `CFNumber` and data. Spec-neutral on the mechanism; design.md:156-157 is stale. |
| `contentFittingWidth { hostingView.fittingSize.width }` | No — W4 | Measures a throwaway default-sizing `NSHostingView`. Mandated by `tasks.md` 6.4; design.md:209 is stale. |
| 40 pt sparkline, 230 pt budget | Yes | design.md:207 and :209 were already amended for both corrections. |

### TDD Compliance

| Check | Result | Details |
|---|---|---|
| TDD Evidence reported | PASS | `apply-progress.md` carries a 21-row "TDD Cycle Evidence" table plus two per-correction cycle tables. |
| All tasks have tests | PASS | 35/35 tasks; every RED task names a test file that exists. |
| RED confirmed (test files exist) | PASS | 21/21 named test files verified present on disk. Each RED row records a concrete compiler or assertion failure (`cannot find 'X' in scope`, `no member 'start'`, `argument passed to call that takes no arguments`, exit 65), not a generic "written". |
| GREEN confirmed (tests pass now) | PASS | 188/188 pass on this independent run; every suite named in the evidence table is present in the run output. |
| Triangulation adequate | PASS | Case counts per row (9, 14, 6, 15, 5, 7, 5, 22, 5, 2, 4, 19, 7, 13, 8, 16, 4, 16, 4) all exceed one, and the two multi-scenario requirements use parameterized cases (`clusterTypeMapsToItsPerformanceLevel`, `theCPUValueIsAWholePercentage`, `everyModuleReservesItsSparklineArea`, `integerRoundsToTheNearestWholePercent`). No "single-case" row. |
| Safety net for modified files | PASS | Every row records a prior green count (4/4 → 165/165) before the next RED; the only gap is the documented 6.2→6.4 host-bootstrap window, explained in `apply-progress.md` and re-proven green at 185/185. |
| Corrections followed the cycle | PASS | Both 2026-09-04 corrections record safety net, a real RED (expected 40 got 60; constants 0/2/0 vs 4/6/2), GREEN, triangulation and refactor. The second correction explicitly notes that raising the controller assertion alone would not have been RED. |

**TDD Compliance**: 7/7 checks passed.

### Test Layer Distribution

| Layer | Tests | Files | Tools |
|---|---|---|---|
| Unit | 169 | 13 | Swift Testing |
| Integration | 19 | 3 | Swift Testing + real host (`MachIntegrationTests` 11 `.integration`, `PanelViewTests` 4 rendered `NSHostingView`, `StatusItemControllerTests` 4 real `NSStatusItem`) |
| E2E | 0 | 0 | not installed (no XCUITest target) |
| **Total** | **188** | **16** | |

Every layer used is backed by a tool actually present in the project. The manual smoke run
(task 6.6) is recorded in `apply-progress.md` but is not machine-verifiable here; it is not
counted toward scenario compliance, and no scenario depends on it.

### Changed File Coverage

Coverage analysis skipped — no coverage tool detected (the scheme does not enable code coverage).
This is informational and does not affect the verdict.

### Assertion Quality

301 `#expect` and 25 `#require` across 16 test files.

| Check | Result |
|---|---|
| Tautologies (`#expect(true)`, `1 == 1`) | None found |
| Assertions with no production call | None found |
| Ghost loops (assertions over a possibly-empty collection) | None found — no `#expect` appears inside a `for` body |
| Orphan empty-collection assertions | None — `anEmptyHistoryProducesNoSamples` and `theGraphOfAnEmptyHistoryHasNoSamples` each have non-empty companions (`aPartialHistoryKeepsEveryStoredSample`, `theGraphUsesEveryHistoryValueOldestFirst`) |
| Lone type-only assertions | None — the single `#expect(total != nil)` (`MetricsSamplerTests.swift:221`) sits beside `#expect(keptPublishing)` in the same case |
| Smoke-test-only cases | None — the rendered-view cases assert concrete widths/sizes, not mere existence |
| Implementation-detail coupling | None — no CSS/class/mock-call-count assertions; the layout tests assert public constants and measured geometry |
| Mock/assertion ratio | Healthy — 2 hand-written test doubles (`FakeCPUProvider`, `FakeCoreTopologyProvider`) against 301 assertions |
| Suppressed failures (`withKnownIssue`, `.disabled`) | None found |

**Assertion quality**: All assertions verify real behavior. 0 CRITICAL, 0 WARNING.

### Quality Metrics

**Linter**: not available — no SwiftLint/SwiftFormat configuration in the project.
**Type checker**: PASS — `xcodebuild build` exit 0 with zero errors and zero warnings under Swift 6
strict concurrency; the isolation convention is compiler-enforced.

### Deviation Adjudication

Every deviation recorded in `apply-progress.md`, adjudicated against the spec as acceptance criterion.

| # | Deviation | Verdict |
|---|---|---|
| 1 | `.timeLimit(.minutes(1))` instead of `.seconds(5)` | Spec-compliant. No spec mandates a time limit. Swift Testing genuinely rejects sub-minute limits (`'seconds' is unavailable: Time limit must be specified in minutes`). See S1. |
| 2 | Extra `CPUMetricsProviderPortTests.swift` | Spec-compliant. Covers cpu-metrics "Fake provider satisfies the port", which had no task-named test file. |
| 3 | `CPUTicks`/`CPUSnapshot` suites inside `CoreTopologyTests.swift` | Spec-compliant. Organizational only. See S2. |
| 4 | `MetricHistory` custom `==` (capacity + ordered) | Spec-compliant. The spec requires `Equatable`; semantic equality is the correct reading for a ring buffer, and it is triangulated by `wrappedHistoriesWithTheSameContentAreEqual` + `historiesWithDifferentContentAreNotEqual`. |
| 5 | `PercentFormatter.oneDecimal` uses `.number` + literal `%` | Spec-compliant, design mismatch. Foundation `.percent` yields `"40,2 %"` (U+00A0) under `de_DE`, which fails the cpu-card "Locale decimal separator" scenario requiring `"40,2%"`. Code is right; design.md:169 must be amended. **W2** |
| 6 | `IORegistryCoreTopologyProvider` uses `AppleARMPE` children, CFNumber `logical-cpu-id` | Spec-compliant, design mismatch. The spec constrains the semantics (`cluster-type` keyed by logical CPU id), not the traversal path. Proven by 11 green `.integration` cases on real hardware. design.md:156-157 must be amended. **W3** |
| 7 | Additive pure helpers (`SparklineGeometry`, `CoreBarGrid.rows`, `CPUCardModel`, `level(forClusterType:)`) | Spec-compliant. No design signature changed; each helper lives in a file the design already names, and each exists to give Strict TDD a RED gate for a view task. Good practice. |
| 8 | `Palette.cardCornerRadius` added | Spec-compliant. Turns the spec's "12 pt corner radius" into one asserted constant. |
| 9 | Additive test files (`CanvasComponentsTests`, `CPUCardTests`, `PanelViewTests`, second `PaletteTests` suite) | Spec-compliant. Required by Strict TDD for tasks that name no test file. |
| 10 | Menu-bar scenarios split across phases 5 and 6 | Spec-compliant. Matches the `tasks.md` schedule; all scenarios are now covered. |
| 11 | MEM renders no sparkline | Superseded and correctly retired. The amended spec requires a sparkline on every module; `ModuleLabel` now renders `Sparkline` unconditionally and `sparklineModules`/`showsSparkline(_:)` were deleted. Verified. |
| 12 | Widget spacing tightened to 2/6 then 0/2/0 | Superseded. The 230 pt correction restored 4/6/2, confirmed in source and pinned by `theLayoutKeepsItsReadableSpacing`. |
| 13 | `contentFittingWidth` measures a throwaway default-sizing view | Spec-compliant, design mismatch. Necessary: with `sizingOptions = []` the live hosting view reports a zero fitting size, so the design's accessor would measure nothing. Mandated by `tasks.md` 6.4 and kept honest by `theStatusItemIsSizedFromTheWidestContent` (`statusItemLength == contentFittingWidth`). design.md:209 must be amended. **W4** |
| 14 | `ModuleReading: Identifiable` | Spec-compliant. Additive; the three stored properties match the design. |
| 15 | Additive pure surface in `StatusItemView.swift` | Spec-compliant. `sparklineWidth`, `valueWidth`, `measurementReadings` match the design; the rest are layout constants the width-budget scenario needs to be assertable. |
| 16 | `AppDelegate.applicationWillTerminate` calls `sampler.stop()` | Spec-compliant. Additive lifecycle symmetry beyond the design's `start()`-only requirement. |

No deviation breaks a spec. Three (5, 6, 13) leave `design.md` describing something the code
deliberately does not do, and need a design amendment before archive.

### Risk Rating

**Risk 1 — wall-clock loop tests (flakiness): MEDIUM.**
The five `MetricsSamplerLoopTests` cases drive a real `ContinuousClock` and poll at 5 ms.
`startPublishesARealValueWithinTwoHundredMilliseconds` polls against a hard 200 ms deadline while
the sampler needs a 100 ms startup gap plus a 10 ms interval, leaving roughly 90 ms of margin; the
case took 0.179 s wall time in this run. `startIsIdempotentSoStopHaltsEveryIteration` and
`stopFreezesThePublishedCount` took 0.391 s each. Under a loaded machine, a shared CI runner, or a
Debug build with sanitizers, the 200 ms case is the one that can flip red. Mitigations already in
place: the suite carries `.timeLimit(.minutes(1))`, each case builds a fresh sampler, and no case
mixes `sampleOnce()` with loop state. The clean fix is available and unused — `MetricsSampler`
already injects `clock: any Clock<Duration>`, and the cpu-metrics scenario's GIVEN literally says
"a sampler started with a test clock". Moving these five cases onto a controllable clock would
remove the flakiness class entirely and would also let W1 pin the real 100 ms cadence.

**Risk 2 — status-item tests creating real `NSStatusItem` instances: MEDIUM.**
Each of the four `StatusItemControllerTests` cases constructs a real `NSStatusItem` in the test host
and never removes it, so a run leaks four items until the host exits. Two distinct exposures:
(a) *environment* — this needs a real window-server session; the suite would not survive a headless
CI runner, and it will not fail cleanly, it will fail as host breakage the way the documented
6.2→6.4 bootstrap crash did; (b) *measurement fragility* — `theWidgetStaysUnderTheWidthBudgetAtFullScale`
depends on system font metrics for `"CPU"`, `"MEM"` and `"100%"` at 11 pt. The widget measures
221 pt against a 230 pt budget, so only 9 pt of headroom absorbs any font or OS metric change.
It worked here without entitlement or workaround and no case was skipped. Reasonable mitigations:
release each item in a suite teardown, and treat the 9 pt headroom as a known constraint for M3
(a third module needs roughly 110 pt more and cannot fit).

### Issues Found

**CRITICAL**: None.

**WARNING**:

1. **W1 — Cadence scenario is not pinned to its timing bound.** cpu-metrics "Injected interval
   drives the loop" states: 10 ms interval, runs for 100 ms, at least 5 snapshots.
   `theInjectedIntervalKeepsTheLoopPublishing` polls for up to **1500 ms** for `count >= 5`
   (`MetricsSamplerTests.swift:217`). The count is asserted; the cadence is not — a sampler running
   15× slower than specified would still pass. Marked PARTIAL. Fix: assert the count within a
   deadline close to 100 ms, ideally on an injected test clock.
2. **W2 — design.md:169 is stale.** It specifies `oneDecimal` "via FormatStyle `.percent`"; the code
   uses `.number.precision(.fractionLength(1)).grouping(.never).locale(locale)` plus a literal `%`.
   The code is correct (the spec's `de_DE` scenario forbids the U+00A0 that `.percent` inserts);
   the design must be amended.
3. **W3 — design.md:156-157 is stale.** It specifies `IORegistryEntryFromPath(kIOMainPortDefault,
   "IODeviceTree:/cpus")` and `logical-cpu-id` as little-endian `OSData`; the code matches
   `AppleARMPE` and accepts both a `CFNumber` and data. The code is correct and hardware-verified;
   the design must be amended.
4. **W4 — design.md:209 is stale.** It specifies
   `var contentFittingWidth: CGFloat { hostingView.fittingSize.width }`; the code measures a
   throwaway default-sizing `NSHostingView` because the live view has `sizingOptions = []` and
   reports zero. The code is correct and `tasks.md` 6.4 mandates it; the design must be amended.
5. **W5 — wall-clock loop tests carry a real flakiness class.** See Risk 1. MEDIUM.
6. **W6 — status-item tests need a GUI session and leak four `NSStatusItem`s.** See Risk 2. MEDIUM.
7. **W7 — `apply-progress.md` "Issues Found" #6 is stale.** It still asserts the 200 pt budget, a
   197.0 pt measurement, a 60 pt sparkline and "M3 cannot add a MEM sparkline without raising the
   budget" — all three statements were overtaken by the two 2026-09-04 corrections. Deviation 11 in
   the same file was correctly marked SUPERSEDED; issue 6 was not. Documentation only, no code
   impact, but it will mislead the archive reader.

**SUGGESTION**:

1. **S1 — `.timeLimit` granularity.** `.timeLimit(.minutes(1))` is the tightest guard Swift Testing
   allows (`.seconds` is marked unavailable), so the loop suite's hang guard is 60 s rather than the
   5 s `tasks.md` asked for. Per-case polling deadlines keep the real runtime under 0.4 s, so the
   practical exposure is small. Separately: the locally installed `swift-testing` skill
   (`~/.config/opencode/skills/swift-testing/SKILL.md`, lines 52, 315 and 379) documents
   `.timeLimit(.seconds(30))` / `.seconds(5)`, which does not compile. The skill file is wrong and
   the implementation is right; worth correcting the skill so this is not re-litigated.
2. **S2 — file naming.** `CoreTopologyTests.swift` also hosts the `CPUTicks values` and
   `CPUSnapshot values` suites. Splitting them would make the test tree match the model tree.
3. **S3 — half of the Legibility requirement is unasserted.** menu-bar-widget "Legibility" requires
   both that the value uses the system label color and that the label and sparkline use the module
   accent. Its single scenario covers only the accent, and only the accent is tested. Consider a
   scenario for the value color, or accept it as a visual-only property.
4. **S4 — `CPUCard` is never instantiated directly in a test.** cpu-card "Card renders from fixed
   inputs" is satisfied at runtime through `PanelViewTests` rendering `PanelView` (which constructs
   `CPUCard(snapshot:history:)`) and at compile time by three `#Preview`s — which the scenario's
   own wording ("in a preview or test") permits. A direct `NSHostingView(rootView: CPUCard(...))`
   case would assert the "no environment beyond the inputs" clause literally.

### Verdict

**PASS WITH WARNINGS**

All 35 tasks are complete and match the code state; the build and the full suite both pass on an
independent run (188 passed, 0 failed, exit 0); all 61 spec scenarios have a passing covering
test, one of them only partially bounded rather than untested; TDD evidence is corroborated; the
isolation convention, the untouched `project.pbxproj`, the absence of new dependencies and the
zero-commit repository state all verify clean. Nothing blocks archive. Before archiving, amend
`design.md` for the three deviations the code deliberately made (W2, W3, W4) and correct the stale
`apply-progress.md` issue 6 (W7); W1, W5 and W6 are test-robustness debt that should be scheduled
but does not invalidate the implementation.
