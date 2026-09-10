```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:ba5dff0e1f3815404f9e7f523b922402be49337881585ed89cfe99e5fd70d5d9
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 28/28
scenarios: 79/79
test_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests
test_exit_code: 0
test_output_hash: sha256:bb4cf6ddffc0f2480d82429ee21763f90373b50e4c7eb0f5fed1b4c648ddcb44
build_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build
build_exit_code: 0
build_output_hash: sha256:db3f6383428aa07144961fa6529da611eca9ef836d389d25e2fc50c7c05c38f6
```

## Verification Report

**Change**: network-module (PRD M6 — "Network", F11, section 5.8 R11.1–R11.11)
**Revision**: 2 — supersedes revision 1 in place
**Version**: `specs/network-metrics/spec.md` NM-1..NM-13 (43 scenarios) + `specs/network-card/spec.md` NC-1..NC-13 (30 scenarios) + `specs/disk-card/spec.md` delta DC-1, DC-11 (6 scenarios) = **28 requirements / 79 scenarios**
**Mode**: Strict TDD
**Verified**: 2026-09-10

### Why revision 2

Revision 1 was written against a 75-scenario spec set and reported `28/75`. Two post-verify source corrections then amended the specs and the native dispatcher refused archive with `persisted verification report is stale: verify result total 75 does not match actual scenario count 79`. The corrections are:

1. **`R3-zero-interface-baseline`** (native review lineage `review-6998e0189040a8d8`, reliability lens, CRITICAL, one bounded correction). `NetworkThroughputCalculator.rates` now guards `previous.interfaceCount > 0` as well as `current.interfaceCount > 0`. NM-4 gained the scenario "Zero-interface baseline yields nil" (+1).
2. **IFMIB 64-bit counters** (user-requested after manual check 7.3). `SysctlNetworkProvider` now reads `ifmibdata` per interface via `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL}` because the `NET_RT_IFLIST2` `if_data64` byte counters wrap at 2^32 on this driver. NM-10 and NM-11 were rewritten and gained three scenarios (+3).

75 + 1 + 3 = **79**, which is what this report is measured against. Two revision-1 findings are affected: **W1 (zero-interface path)** and the report's **IFMIB/routing-socket source claims** are superseded — the code, the specs and the PRD now describe the interface MIB, and the zero-interface *baseline* defect that W1 gestured at is fixed and tested. The narrower coverage-depth residue of W1 survives as W1' below.

All 79 scenarios were re-measured against the current spec files and the current tree in this phase; nothing was carried over from revision 1 without re-checking it.

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 37 |
| Tasks complete | 37 |
| Tasks incomplete | 0 |

`rg -c "^- \[x\]" tasks.md` → 37; `rg -c "^- \[ \]"` → 0. Tasks **7.3–7.7 were confirmed passed by the user on 2026-09-10** on the IFMIB build: live rates through 4 GB with no em dash and no apparent totals reset (7.3), Total In / Total Out against Activity Monitor (7.4), the 14" visible-frame cap (7.5), accent / em dash / Reduce Motion (7.6), and Time Profiler under 1% with the panel closed (7.7). The user reported pass/fail only, so **the 7.3 peak figures and the 7.7 CPU and resident-size figures were confirmed by the user, figure not reported**. Revision 1's W5 ("five manual tasks open, one owes this report a figure") is therefore closed as to status and reduced to a recording gap, carried below as W5'.

Task 3.3 is a contingency the task text authorises to record itself as skipped ("not needed, every Darwin name imported at 3.2"); it is counted complete.

### Build & Tests Execution

**Build**: Passed — `xcodebuild … -quiet build`, exit 0, **0** `warning:` lines and 0 `error:` lines under Swift 6 strict concurrency with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

**Tests**: **670** distinct passing cases on `FULL`, **0** failed. All three commands were run in the foreground in this phase.

| # | Command | Exit | Distinct passed | Failed | `warning:` | `error:` | Output sha256 |
|---|---------|------|-----------------|--------|-----------|---------|---------------|
| 1 | `BUILD` = `xcodebuild … -quiet build` | 0 | — | — | 0 | 0 | `db3f6383…c05c38f6` |
| 2 | `UNIT` = `xcodebuild … -quiet test -only-testing:system-monitorTests` | 0 | **667** | 0 | 0 | 0 | `bb4cf6dd…648ddcb44` |
| 3 | `FULL` = `xcodebuild … -quiet test` | 0 | **670** | 0 | 0 | 0 | `ba5dff0e…fd70d5d9` |

Observed lines, as run:

- `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build`: **exit 0, 0 warnings, 0 errors**.
- `xcodebuild … -quiet test -only-testing:system-monitorTests`: **exit 0, 667 distinct cases passed, 0 failed, 0 warnings**.
- `xcodebuild … -quiet test`: **exit 0, 670 distinct cases passed, 0 failed, 0 warnings**.

Counts reconcile three ways. `system-monitorTests` declares **667** `@Test` cases (`rg -c "^\s*@Test"` summed over the target) and `UNIT` ran 667 distinct names, so every declared case ran. `FULL` = 667 unit + 3 `system_monitorUITests` template cases (`testExample`, `testLaunchPerformance`, `system_monitorUITestsLaunchTests.testLaunch`) = **670**. Apply recorded 667 unit after the IFMIB correction; this phase reproduces it exactly.

Both figures required the tolerant match apply and revision 1 documented, and the hazard fired again in this phase — in both logs, in two different shapes:

- `UNIT` line 842: `Test case 'MetricsSamplerLoopTests/st2026-09-10 14:39:42.180 xcodebuild[10820:913819] [MT] IDETestOperationsObserverDebug: …` — an interleaved observer timestamp overwrote the rest of `startSeedsTheDeltaThenPublishesAfterTheStartupGap()`. A naive `Test case '<id>'` match reports 666.
- `FULL` line 865: `_ case 'MetricsSamplerLoopTests/everyReadHappensOffTheMainThread()' passed …` — here the timestamp ate the **`Test`** prefix instead, so even a `Test case '` match loses it. A `case '<id>'` match reports 670; the stricter one reports 669.

Both cases ran and passed; both logs contain zero `failed` lines and both commands exited 0. This is recorded as **W7'** because the two logs demonstrate that the truncation is not always in the same place and no single regex is safe on its own: match on `case '<id>'`, count failures separately, and cross-check against the `@Test` declaration count.

**No XCUITest automation-mode timeout occurred** in this phase's `FULL` run, so no re-run was needed. It remains a known intermittent (S3).

`system-monitor.xcodeproj/project.pbxproj` is clean after this phase's three xcodebuild invocations — absent from `git diff --name-only`, so no convention 5 revert was needed.

**Coverage**: Not available. `openspec/config.yaml` sets `coverage_threshold: 0`, `coverage_command: ""` and `testing.coverage.available: false`; the project ships no shared `.xcscheme`, so code coverage is not enabled on the test action. PRD section 8's "Domain + Application 80%+" target cannot be measured from this run and no number is asserted in its place. A measurement gap, not a failure (S1).

### Static checks

| Check | Command | Result |
|---|---|---|
| Nothing committed | `git log -1 --format=%h` | `de40106` — unchanged; the whole change is one uncommitted working tree |
| Project file untouched | `git diff --name-only` | `project.pbxproj` absent; 18 modified tracked files, 19 untracked entries |
| No XCTest in the unit target | `rg -n "import XCTest" system-monitorTests` | No match |
| Domain imports Foundation only | `rg -o "^import .*" system-monitor/Domain` | 26 files, 26 × `import Foundation`, nothing else |
| Presentation never touches the kernel | `rg -n "sysctl\|if_msghdr\|ifmibdata" system-monitor/Presentation` | No match |
| No IFLIST2 walk left in production | `rg -n "if_msghdr2\|NET_RT_IFLIST2" system-monitor/` | One hit only — `SysctlNetworkProvider.swift:13`, the doc comment NM-10 **requires**, explaining why the routing socket is not used. No code path, no constant, no struct |
| Interface MIB is the live source | `rg -n "IFMIB_IFDATA\|IFDATA_GENERAL\|ifmibdata" …/SysctlNetworkProvider.swift` | `countMIB` :52, `dataMIB(index:)` :59, `ifmibdata` read at :178-192 |
| NM-11's non-trapping flag conversion | `SysctlNetworkProvider.swift:156` | `flags: Int32(bitPattern: data.ifmd_flags)` |
| Reference image present | `ls docs/reference/06-panel-network.png` | 53 634 bytes, untracked, untouched |

### Spec Compliance Matrix — network-metrics (NM-1 … NM-13, 43 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| NM-1 | Fake provider returns scripted counters in order | `NetworkMetricsProviderPortTests > scriptedCountersAreReturnedInOrder` (+ `anExhaustedScriptRepeatsTheLastValue`, `theFakeIsUsableThroughThePortItself`) | ✅ COMPLIANT |
| NM-1 | Scripted failure is observable | `NetworkMetricsProviderPortTests > aScriptedFailureThrowsOnItsCallWhileTheCursorHolds` | ✅ COMPLIANT |
| NM-2 | Timestamp participates in equality | `NetworkSnapshotTests > countersOneMillisecondApartAreNotEqual` (+ `countersWithTheSameFieldsAndStampAreEqual`) | ✅ COMPLIANT |
| NM-2 | Summed counters carry the interface count | `NetworkSnapshotTests > summedCountersCarryTheInterfaceCountAndTheSummedBytes` (+ `aDifferentInterfaceCountBreaksEquality`) | ✅ COMPLIANT |
| NM-3 | Rates travel together | `NetworkSnapshotTests > theReferenceSnapshotCarriesBothTotalsAndBothRates` (`3_850_000_000` / `2_760_000_000` / `5_000` / `78_000`) | ✅ COMPLIANT |
| NM-3 | Totals without rates | `NetworkSnapshotTests > aSnapshotWithoutRatesStillCarriesBothTotals` (+ `snapshotsCompareByValueIncludingTheRates`) | ✅ COMPLIANT |
| NM-4 | Reference rate | `NetworkThroughputCalculatorTests > theReferenceWindowYieldsTheReferenceRates` | ✅ COMPLIANT |
| NM-4 | Elapsed time scales the rate | `NetworkThroughputCalculatorTests > halvingTheWindowDoublesBothRates` (`10_000` / `156_000`) | ✅ COMPLIANT |
| NM-4 | No baseline | `NetworkThroughputCalculatorTests > noBaselineYieldsNoRates` | ✅ COMPLIANT |
| NM-4 | No interfaces | `NetworkThroughputCalculatorTests > aReadingWithoutInterfacesYieldsNoRates` | ✅ COMPLIANT |
| NM-4 | **Zero-interface baseline yields nil** (new) | `NetworkThroughputCalculatorTests > aZeroInterfaceBaselineYieldsNoRates` (idle previous, populated current 1 s later → `nil`) + `MetricsSamplerStepTests > theIdleToPopulatedTransitionCostsOneRateFreeTick` (the whole provider → step → state → history crossing) | ✅ COMPLIANT |
| NM-4 | Non-positive elapsed time | `NetworkThroughputCalculatorTests > aZeroWindowYieldsNoRates` + `aBackwardsWindowYieldsNoRates` (both halves) | ✅ COMPLIANT |
| NM-4 | Negative inbound delta nils both rates | `NetworkThroughputCalculatorTests > aFallingInboundCounterNilsBothRates` | ✅ COMPLIANT |
| NM-4 | Negative outbound delta nils both rates | `NetworkThroughputCalculatorTests > aFallingOutboundCounterNilsBothRates` | ✅ COMPLIANT |
| NM-4 | Re-seeded baseline recovers on the next tick | `NetworkThroughputCalculatorTests > theReSeededBaselineRecoversOnTheNextTick` (triangulated by `unchangedCountersYieldZeroRatesRatherThanNil`) | ✅ COMPLIANT |
| NM-5 | First step publishes totals without rates | `MetricsSamplerStepTests > theFirstNetworkStepPublishesTotalsWithBothRatesNil` | ✅ COMPLIANT |
| NM-5 | Second step publishes rates | `MetricsSamplerStepTests > theSecondNetworkStepPublishesTheReferenceRates` | ✅ COMPLIANT |
| NM-5 | Call counts advance together | `MetricsSamplerStepTests > allFourProvidersAreReadOncePerStep` (3/3/3/3) | ✅ COMPLIANT |
| NM-6 | Restart costs one rates-unavailable tick | `MetricsSamplerLoopTests > aRestartCostsOneRatesUnavailableNetworkTick` (`ManualClock`) | ✅ COMPLIANT |
| NM-6 | Unchanged interval keeps the baseline | `MetricsSamplerLoopTests > applyingTheIntervalAlreadyInEffectKeepsTheNetworkBaseline` | ✅ COMPLIANT |
| NM-7 | Off-main reads | `MetricsSamplerLoopTests > everyReadHappensOffTheMainThread` (`readOnMainThread` all `false`, count ≥ 2) | ✅ COMPLIANT |
| NM-8 | Throw publishes nothing and keeps the last snapshot | `MetricsSamplerStepTests > aNetworkThrowAfterRatesKeepsThePublishedRatesAndBothHistories` (+ `aNetworkThrowPublishesNothingAndKeepsTheLastSnapshot`) | ✅ COMPLIANT |
| NM-8 | The next success is a re-seed tick | `MetricsSamplerStepTests > theSuccessAfterANetworkThrowIsARateFreeReSeedTick` | ✅ COMPLIANT |
| NM-8 | CPU throws, network still publishes | `MetricsSamplerStepTests > aThrowingCPUReadDoesNotPreventTheNetworkPublish` | ✅ COMPLIANT |
| NM-9 | Both histories grow together | `MetricsStateTests > applyingThreeRatedSnapshotsGrowsBothHistoriesTogether` | ✅ COMPLIANT |
| NM-9 | Nil rates append nothing | `MetricsStateTests > applyingASnapshotWithoutRatesStoresItAndAppendsNothing` | ✅ COMPLIANT |
| NM-9 | Other state untouched | `MetricsStateTests > applyingNetworkLeavesTheOtherMetricsAlone` (+ `applyingTheOtherMetricsLeavesTheNetworkStateAlone`, `freshStateHasNoNetworkSnapshotAndTwoEmptyHistories`) | ✅ COMPLIANT |
| NM-9 | Capacity bounds both histories | `MetricsStateTests > theInjectedCapacityBoundsBothNetworkHistories` | ✅ COMPLIANT |
| NM-10 | Sandboxed shape (`.integration`) | `SysctlNetworkIntegrationTests > theSandboxedHostSeesAtLeastOneInterfaceWithBytesIn` — proves interface-MIB `sysctl` reaches through App Sandbox | ✅ COMPLIANT |
| NM-10 | Counters are monotonic with advancing stamps (`.integration`) | `SysctlNetworkIntegrationTests > twoReadsAreMonotonicAndTheStampAdvances` (+ `theStampSitsBetweenTheInstantsSurroundingTheRead`) | ✅ COMPLIANT |
| NM-10 | Repeated reads (`.integration`) | `SysctlNetworkIntegrationTests > fiftyConsecutiveReadsAllSucceed` (+ `theInterfaceCountIsStableBetweenReads`) | ✅ COMPLIANT |
| NM-10 | No admitted interface is not an error | No adapter-level test drives a zero-admitted read; this host admits ~14 interfaces and the adapter exposes no injection seam. Asserted one layer up against fixtures (`MetricsSamplerStepTests > aScriptWithNoAdmittedInterfacePublishesZeroTotalsWithoutRates`, `NetworkSnapshotTests > theIdleFixtureIsAValidReadingWithoutInterfaces`); both code paths (`SysctlNetworkProvider.swift:144` `guard count > 0 else { return Self.empty() }` and the loop admitting none, `:146-170`) read directly in this phase. See **W1'** | ⚠️ PARTIAL |
| NM-10 | **Counters are not 32-bit truncated** (`.integration`, new) | `SysctlNetworkIntegrationTests > theSummedCountersAreNotTruncatedToThirtyTwoBits` — the adapter's `bytesIn` must be `>= max(ifmd_data.ifi_ibytes)` over the admitted interfaces, read independently by the test. On this machine the largest is 13 563 204 219 (`en1`), well above 2^32, so the assertion bites | ✅ COMPLIANT |
| NM-10 | **Sum matches the MIB within one tick** (`.integration`, new) | `SysctlNetworkIntegrationTests > theAdapterTotalsMatchTheSumOfThePerInterfaceMIBCounters` — both sources must admit the same interface count and the totals must agree within a 50 MB tolerance absorbing traffic between the two reads. See **W8** | ✅ COMPLIANT |
| NM-10 | **A missing index is a gap, not a failure** (new) | `SysctlNetworkProviderTests > theMissingInterfaceErrnosAreSkippedAndEveryOtherOneIsNot` — parameterised, 8 rows (`ENOENT`/`ENXIO`/`EINVAL` → skip; `EPERM`/`EACCES`/`ENOMEM`/`EFAULT`/`0` → do not skip). The *classification* is asserted; the wiring that turns it into a `continue` versus `throw ReadError.interfaceRead(index:errno:)` lives in the private `interface(at:)` (`:183-189`) and is static-only evidence. See **W9** | ⚠️ PARTIAL |
| NM-10 | Sums saturate | `SysctlNetworkProviderTests > anOverflowingSumPinsAtTheMaximumInsteadOfWrapping` (+ `theLastSumThatStillFitsIsNotSaturated`, `twoOrdinaryTotalsAddUpExactly`, `addingZeroLeavesATotalUnchanged`) | ✅ COMPLIANT |
| NM-11 | Admitted interfaces | `SysctlNetworkProviderTests > theFilterMatchesTheTruthTable` (parameterised, 9 rows; `0x6/0x8863`, `0x6/0x0`, `0xff/0x0` admitted) | ✅ COMPLIANT |
| NM-11 | Rejected interfaces | `SysctlNetworkProviderTests > theFilterMatchesTheTruthTable` (`0x18` lo0, `0x1` utun, `0xd1` bridge, `0x37` gif, `0x39` stf rejected) | ✅ COMPLIANT |
| NM-11 | Loopback flag overrides an admitted type | `SysctlNetworkProviderTests > theLoopbackFlagRejectsAnOtherwiseAdmittedType` | ✅ COMPLIANT |
| NM-11 | Link state is not required | `SysctlNetworkProviderTests > neitherUpNorRunningIsRequired` | ✅ COMPLIANT |
| NM-12 | Real graph publishes network (`.integration`) | `AppDelegateCompositionTests > theRealGraphPublishesRealNetworkReadings` (real `AppDelegate`, real `SysctlNetworkProvider`, totals `> 0`, rates non-nil) | ✅ COMPLIANT |
| NM-12 | Modules and widget untouched | `AppDelegateCompositionTests > publishingNetworkReadingsLeavesTheModulesAndWidgetUnchanged` | ✅ COMPLIANT |
| NM-13 | PRD and config text | Document check against `PRD.md` and `openspec/config.yaml`, re-run against the corrected rows (see "NM-13 document verification") | ✅ COMPLIANT |

### Spec Compliance Matrix — network-card (NC-1 … NC-13, 30 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| NC-1 | Card renders from fixed inputs | `PanelViewTests > theNetworkCardRendersFromItsSnapshotAndHistoriesAlone` (`NSHostingView`, height `> 120`) | ✅ COMPLIANT |
| NC-1 | Card order | `PanelViewTests > thePanelStacksCPUThenMemoryThenDiskThenNetwork` (`cards == [.cpu, .memory, .disk, .network]`, `Set == allCases`) | ✅ COMPLIANT |
| NC-1 | Live update while open | `PanelViewTests > theNetworkReadingsFollowTheAppliedSnapshot` (`"5.0 kB/s"` under `en_US`) | ✅ COMPLIANT |
| NC-2 | Sections | `NetworkCardModelTests > theCardHasAHeaderARatesAndTotalsRowAndAGraphLast` | ✅ COMPLIANT |
| NC-3 | Header symbol resolves | `NetworkCardModelTests > theHeaderSymbolResolvesAsAnSFSymbol` (`globe` through `NSImage(systemSymbolName:accessibilityDescription:)`) | ✅ COMPLIANT |
| NC-3 | Header title and tint | `NetworkCardModelTests > theHeaderTitleIsNetwork` pins the title; the accent and the `.isHeader` trait have no view-level assertion. Read directly at `NetworkCard.swift:276` (`.foregroundStyle(Palette.networkAccent)`) and `:281` (`.accessibilityAddTraits(.isHeader)`); the token value is pinned by `PaletteTests > networkTokensMatchTheProductPalette`; the rendered accent was confirmed by the user in manual check 7.6. See **W2'** | ⚠️ PARTIAL |
| NC-4 | Populated readings under en_US | `NetworkCardModelTests > theReadingsShowDownloadThenUploadUnderEnglish` (`"5.0 kB/s"`, `"78.0 kB/s"`, labels `"Download"`/`"Upload"`) | ✅ COMPLIANT |
| NC-4 | Readings under de_DE | `NetworkCardModelTests > theReadingsFollowTheInjectedLocaleDecimalSeparator` (`"5,0 kB/s"`, `"78,0 kB/s"`) | ✅ COMPLIANT |
| NC-4 | Distinct icons resolve | `NetworkCardModelTests > theDirectionIconsDifferAndBothResolve` (+ `eachReadingCarriesItsOwnDirectionIcon`); the amended icon-only-tint clause is pinned by `theReadingColoursAreDownloadThenUpload` | ✅ COMPLIANT (see **W3'**) |
| NC-5 | Two rows under en_US | `NetworkCardModelTests > theRowsAreTotalInThenTotalOutUnderEnglish` (`Total In 3.85 GB`, `Total Out 2.76 GB`) | ✅ COMPLIANT |
| NC-5 | Rows under de_DE | `NetworkCardModelTests > theRowValuesFollowTheInjectedLocale` (`"3,85 GB"`, `"2,76 GB"`) | ✅ COMPLIANT |
| NC-5 | Extreme totals do not trap | `NetworkCardModelTests > anExtremeTotalFormatsInsteadOfTrapping` (`0` starts with `"0"`, `UInt64.max` formats) | ✅ COMPLIANT |
| NC-6 | Rates unavailable, totals present | `NetworkCardModelTests > unavailableRatesRenderEmDashesWhileTheTotalsStillFormat` (U+2014, `"unavailable"`, rows still real) + `anUnavailableRateIsNeverRenderedAsZero` | ✅ COMPLIANT |
| NC-7 | Nil model | `NetworkCardModelTests > aNilSnapshotRendersTheFullSkeleton` | ✅ COMPLIANT |
| NC-7 | Height is stable | `PanelViewTests > theFirstNetworkSnapshotFillsTheCardWithoutResizingThePanel` (`after == before`) | ✅ COMPLIANT |
| NC-8 | Shared divisor keeps the ratio | `NetworkCardModelTests > bothSeriesDivideByTheSharedMaximum` (`graphScale([5_000], [78_000]) == 78_000`) | ✅ COMPLIANT |
| NC-8 | Floor flattens an idle link | `NetworkCardModelTests > theFloorFlattensAnIdleLinkInsteadOfAmplifyingNoise` (`graphScale([500], [800]) == 10_000`, every value `< 0.1`) | ✅ COMPLIANT |
| NC-8 | Values stay clamped | `NetworkCardModelTests > normalisationKeepsEveryValueWithinTheUnitRange` + `aSingleSpikeStaysClampedAndTheSeriesKeepTheirLength` (+ `theSeriesAreTruncatedToTheVisibleCapacity`) | ✅ COMPLIANT |
| NC-9 | Two series equal two single-series geometries | `HistoryGraphSeriesTests > twoSeriesProduceTheTwoSingleSeriesPointArrays` (+ `theSeriesOrderIsThePointArrayOrder`) | ✅ COMPLIANT |
| NC-9 | Existing call sites unchanged | `HistoryGraphSeriesTests > theSingleSeriesConvenienceBuildsTheOneSeriesGraph`; corroborated statically — `CPUCard.swift` and `MemoryCard.swift` are absent from `git diff --name-only` | ✅ COMPLIANT (see S2) |
| NC-9 | Fewer samples and empty series | `HistoryGraphSeriesTests > aPartialSeriesBesideAnEmptySeriesKeepsItsOwnGeometry` + `aSeriesWithNoSamplesProducesOneEmptyPointArray` | ✅ COMPLIANT |
| NC-9 | Equatable redraw skip | `CanvasComponentEqualityTests > multiSeriesHistoryGraphsWithTheSameSeriesCompareEqual` | ✅ COMPLIANT |
| NC-10 | Token values | `PaletteTests > networkTokensMatchTheProductPalette` (`networkDownload == sRGB(0x3DD68C) == memFree == diskAccent`, `networkUpload == sRGB(0x4D8DFF) == cpuAccent`, `networkAccent == sRGB(0xC659E4)`) | ✅ COMPLIANT |
| NC-10 | Chrome parity | `NetworkCardModelTests > theCardChromeMatchesTheDiskCard` (padding 16, section spacing 14, row spacing 6, graph height 48, `cardPadding == DiskCard.cardPadding`, `Palette.cardCornerRadius`) | ✅ COMPLIANT |
| NC-11 | Four-card height | `PanelViewTests > thePanelGrowsByTheFullNetworkCard` (measured 1049 pt against the computed three-card 871 pt) | ✅ COMPLIANT |
| NC-12 | Taller than the visible frame | `PanelLayoutTests > aPanelTallerThanTheVisibleFrameIsPinnedBelowIt` (1050/945 → 921) + `StatusItemControllerTests > theControllerCapsTheFourCardPanelToA14InchVisibleFrame` (real four-card state → 921.0) + `PanelViewTests > aSuppliedMaxHeightPinsThePanelAndScrollsItsCards` | ✅ COMPLIANT |
| NC-12 | Shorter than the visible frame | `PanelLayoutTests > aPanelShorterThanTheVisibleFrameKeepsItsFittingHeight` (871/1132 → 871) + `StatusItemControllerTests > theControllerSuppliesNoCapWhenTheFourCardPanelFits` + `theControllerMeasuresThePanelRatherThanAFixedHeight` | ✅ COMPLIANT |
| NC-12 | Exactly at the cap | `PanelLayoutTests > aPanelExactlyAtTheCapIsNotCapped` (921/945 → 921, `maxHeight == nil`; triangulated by `aNonPositiveCapIsNotApplied`, `aCustomMarginIsHonoured`, `theMarginDecidesWhetherAPanelNearTheFrameIsCapped`) | ✅ COMPLIANT |
| NC-13 | Reduce motion | `NetworkCardModelTests > reducedMotionRemovesTheAnimation` (`nil`) | ✅ COMPLIANT |
| NC-13 | Motion allowed | `NetworkCardModelTests > theCardBorrowsTheCPUCardAnimationWhenMotionIsAllowed` (non-nil and `== CPUCardModel.gaugeAnimation(reduceMotion: false)`) | ✅ COMPLIANT |

### Spec Compliance Matrix — disk-card delta (DC-1, DC-11, 6 scenarios)

| Requirement | Scenario | Test | Result |
|-------------|----------|------|--------|
| DC-1 | Card renders from a fixed input | `PanelViewTests > theDiskCardRendersFromItsSnapshotAlone` (unchanged, still green) | ✅ COMPLIANT |
| DC-1 | Card order (now four cards) | `PanelViewTests > thePanelStacksCPUThenMemoryThenDiskThenNetwork` | ✅ COMPLIANT |
| DC-1 | Live update while open | `PanelViewTests > theDiskGaugeTextFollowsTheAppliedSnapshot` (`"87.4%"`) | ✅ COMPLIANT |
| DC-11 | Three-card height | `PanelViewTests > thePanelGrowsByTheFullDiskCard` (unchanged lower bound, still green) | ✅ COMPLIANT |
| DC-11 | Four-card height | `PanelViewTests > thePanelGrowsByTheFullNetworkCard` | ✅ COMPLIANT |
| DC-11 | Height is bounded by the visible frame | `PanelLayoutTests` (6 cases) + `StatusItemControllerTests` (3 cases) + `PanelViewTests > aSuppliedMaxHeightPinsThePanelAndScrollsItsCards`; the on-glass "scrolls instead of being clipped" half was confirmed by the user in manual check 7.5 | ✅ COMPLIANT |

**Compliance summary**: **79/79 scenarios** have a covering test that passed at runtime and **28/28 requirements** are covered. No scenario is `UNTESTED` or `FAILING`. Three of the 79 are `PARTIAL` — the covering test passes but reaches only part of the scenario (NM-10 "No admitted interface is not an error"; NM-10 "A missing index is a gap, not a failure"; NC-3 "Header title and tint"). All three are coverage-depth gaps recorded as W1', W9 and W2', not missing tests.

Every expected value was re-checked against the current spec text literally. The reference figures (`3_850_000_000`, `2_760_000_000`, `5_000`, `78_000`, `10_000`, `156_000`, `1_000`, `10_000` as the floor, `"5.0 kB/s"`, `"78,0 kB/s"`, `"3.85 GB"`, `"2,76 GB"`, `921`, `871`, `1049`, `0x3DD68C`, `0x4D8DFF`, `0xC659E4`, `13 563 204 219`, `678 301 696`) appear verbatim in the assertions or the artefacts that cite them. No expectation was weakened or widened by either correction; both corrections *added* assertions and neither relaxed one.

### NM-13 document verification

The design's "PRD Alignment" list has 18 items (17 in `PRD.md`, one in `openspec/config.yaml`). All 18 were re-checked in this phase, with particular attention to the rows the IFMIB correction rewrote.

| Item | Required | Observed | Result |
|---|---|---|---|
| 1 | Header Draft v4, date 2026-09-10 | `PRD.md:5` — "Draft v4 (Network card added on 2026-09-10 as F11 / M6; GPU moved to M7)" | ✅ |
| 2 | Section 1 fourth-card sentence | `PRD.md:19` | ✅ |
| 3 | Anti-goals split + Activity Monitor success metric | `PRD.md:35`, `:43` | ✅ |
| 4 | F2 wording, new F11 row, F9 still Future | `PRD.md:52`, `:61`, `:59` | ✅ |
| 5 | New 4.6 referencing `06-panel-network.png` | `PRD.md:106-113` | ✅ |
| 6 | R2.2 order, new R2.5 scroll rule | `PRD.md:129`, `:132` (24 pt margin) | ✅ |
| 7 | R5.1 / R5.2 wording | `PRD.md:161-162` | ✅ |
| 8 | New 5.8 with R11.1–R11.11 | `PRD.md:189-200`, all eleven present | ✅ |
| 8a | **R11.1 corrected to the interface MIB** | `PRD.md:190` — names `IFMIB_SYSTEM`/`IFMIB_IFCOUNT`, `IFMIB_IFDATA`/`IFDATA_GENERAL`, `struct ifmibdata`, `ifmd_data`, "no entitlement", and states `NET_RT_IFLIST2` is **not** used because the driver fills only the low 32 bits (corrected 2026-09-10, cross-referring to 6.3) | ✅ |
| 8b | **R11.4 corrected for the zero-interface baseline** | `PRD.md:193` — "A reading covering no interface (R11.2) is likewise never one end of a window, as baseline or as current … the first populated tick after such a reading costs one rate-free tick instead" | ✅ |
| 9 | 6.1 tree | `PRD.md` Services/`NetworkThroughputCalculator (M6)`, `SysctlNetworkProvider`, `NetworkCard, PanelLayout (M6)`, multi-series `HistoryGraph` | ✅ |
| 10 | 6.2 models with the port comment | `PRD.md:297-300` — `readCounters()`, `NetworkThroughputCounters` | ✅ |
| 11 | **6.3 data-source row corrected** | `PRD.md:325` — the `IFMIB_IFDATA`/`IFDATA_GENERAL` → `ifmibdata` → `ifmd_data.ifi_ibytes`/`ifi_obytes` source with `net/if_mib.h` line citations (`:79`, `:80`, `:86`, `:94`, `:100`), the sparse-index `ENOENT`/`ENXIO`/`EINVAL` rule, the sandbox proof named, and the dated correction paragraph carrying the measured 13 563 204 219 vs 678 301 696 | ✅ |
| 12 | 7.1 token rows | `PRD.md:360-365` — `networkAccent #C659E4` with the sampling note superseding the design's `#A66BFF` | ✅ |
| 13 | 7.3 note | `PRD.md:385` | ✅ |
| 14 | Section 8 rows | `PRD.md:392-396` — the Domain row now names "the network Δ/Δt rule with its own re-seed (R11.4) and the interface filter truth table (R11.2)" | ✅ |
| 15 | Section 9 `M6 Network`, GPU at `M7` | `PRD.md:410`, `:439` | ✅ |
| 16 | Section 10 popover-height and interface-churn rows, open question 3 answered | `PRD.md:425` (1049 = 370+278+175+166+60, ~945 visible, 921 cap), `:426` interface churn citing R11.4/R11.3 | ✅ |
| 17 | Section 11 milestone reference `M7` | `PRD.md:439` | ✅ |
| 18 | `openspec/config.yaml` rule and context line | `:69` `F1..F11` / `M1..M6`; `:17` `Draft v4: v1 = CPU + RAM + Disk; M6 Network (F11) added 2026-09-10; GPU deferred to v2 as M7`. No other key changed | ✅ |

### Coherence (Design)

`design.md` is attempt 2 with a dated **"Amendment to decision 2 (2026-09-10, after manual check 7.3)"** section (`:219-223`) and the decision-2 table row flagged `amended`. The delivered adapter matches the amended text verbatim.

| Decision / element | Followed? | Evidence |
|---|---|---|
| Layer placement of the 7 new source files | Yes | `Domain/{Models,Ports,Services}`, `Infrastructure/System/SysctlNetworkProvider.swift`, `Presentation/Panel/{NetworkCard,PanelLayout}.swift` |
| Domain signatures (`NetworkThroughputCounters`, memberwise-only `NetworkSnapshot`, single-method port, `Rates` + `rates(previous:current:)`) | Yes | Verbatim; the paired-rate type makes "one rate without the other" unrepresentable |
| **Decision 2 as amended** — interface MIB, `ReadError { countQuery(errno:), interfaceRead(index:errno:) }`, `isMissingInterface(errno:)` seam, `Int32(bitPattern:)` | Yes | `SysctlNetworkProvider.swift:41-47`, `:52-61`, `:108-110`, `:156`. `sizeQuery`, `listRead`, `malformedMessage`, the `if_msghdr` walk, its stride and length guards and the three layout constants are all gone, as the amendment requires — none of them describes anything reachable without a variable-length buffer |
| `NetworkSamplingStep` memberwise initialiser only | Yes | `provider` and `previous` with no custom `init`, as `CPUSamplingStep`/`DiskSamplingStep` do |
| `networkProvider:` required and placed after `diskProvider:` | Yes | `MetricsSampler.swift` |
| All four reads before any publish; publish order cpu → memory → disk → network | Yes | `sampleOnce()` and the detached loop body |
| Restart semantics — step built inside the detached closure | Yes | Pinned behaviourally by `aRestartCostsOneRatesUnavailableNetworkTick` and `applyingTheIntervalAlreadyInEffectKeepsTheNetworkBaseline` |
| Decision 3 — a throw drops the baseline | Yes | `advanced()` returns `(nil, NetworkSamplingStep(provider:previous: nil))`; pinned by `theSuccessAfterANetworkThrowIsARateFreeReSeedTick` |
| Decision 5 — multi-series `HistoryGraph`, one shared baseline, retained convenience init | Yes | CPU and Memory call sites byte-identical |
| Decision 6 — symbol set | Yes, fallback unused | `globe`, `arrow.down.circle.fill`, `arrow.up.circle.fill` all resolve |
| Decision 7 — `PanelLayout` rule, `PanelRootView`, cap applied before `show` | Yes | `screenMargin = 24`, `height(...) = maxHeight(...) ?? fitting`; `updatePanelCap()` in `togglePopover()`'s show branch. Confirmed on glass by manual 7.5 |
| Decision 8 — palette tokens | Yes, with the replacement its own tolerance rule prescribes | `networkAccent` measured `0xC659E4` (raw device bytes); confirmed on the running app by manual 7.6 |
| Decision 9 — composition root | Yes | `AppDelegate.swift` injects `SysctlNetworkProvider()`; `PlaceholderNetworkProvider` fully removed |
| Decision 11 — `.animation(_, value: snapshot)` on the rates/totals row | Yes | `NetworkCard.swift`; animation from `NetworkCardModel.animation(reduceMotion:)` |
| `PanelLayout` imports `CoreGraphics` only | Yes, narrower than required | The compiler now enforces "AppKit stays out of the layout rule" |
| `normalised(_:scale:)` returns zeros for a non-positive scale | Yes, inside latitude | Unreachable through `graphSeries` (floor 10 000) but prevents `NaN`/`inf` for a direct caller |
| Design's `networkAccent` estimate and "~1050 pt" placeholder | Superseded by measurement | `#C659E4`, 1049 pt, 921 pt |
| The routing-socket `min(length, raw.count)` clamp recorded in revision 1 | **Obsolete** | The whole walk it guarded no longer exists. Nothing in the adapter allocates a variable-length buffer, so the clamp, the stride guard and `malformedMessage` are gone rather than deviations |

Every deviation `apply-progress.md` records is a readability or safety judgement inside the design's stated latitude, is documented in place, and changes no observable behaviour. None breaks a spec.

### Conventions 1–9 and hexagonal boundaries

| Check | Result |
|---|---|
| 1 — every new Domain/Infrastructure/pure Presentation type is `nonisolated` + `Sendable`, nested types included | Pass. `NetworkThroughputCounters`, `NetworkSnapshot`, `NetworkMetricsProvider`, `NetworkThroughputCalculator` + `Rates`, `SysctlNetworkProvider` + `ReadError`, `NetworkSamplingStep`, `HistoryGraphSeries`, `PanelLayout`, `NetworkCardModel`, `NetworkCardRow`, `NetworkCardSection` |
| 2 — tests never `@MainActor`; they `await` main-actor members | Pass. `await MainActor.run` where a `HistoryGraph` must be constructed |
| 3 — fakes use `Synchronization.Mutex`, zero-based `throwOnCall`, record `Thread.isMainThread` | Pass. `FakeNetworkProvider` |
| 4 — loop suites on `ManualClock`; rate scenarios scripted, never wall-clock | Pass. The only real sleeps are in `SysctlNetworkIntegrationTests`, where NM-10 itself demands "two reads at least 120 ms apart" |
| 5 — `project.pbxproj` never edited | Pass. Absent from `git diff --name-only` and clean after this phase's three xcodebuild runs |
| 6 — locale strings pinned under `en_US` and `de_DE` with the whitespace normaliser | Pass |
| 7 — `sysctl` names from `Darwin` with header citations | Pass, **and strengthened by the correction**. `CTL_NET`, `PF_LINK`, `NETLINK_GENERIC`, `IFMIB_SYSTEM`, `IFMIB_IFCOUNT`, `IFMIB_IFDATA`, `IFDATA_GENERAL`, `ifmibdata`, `IFT_ETHER`, `IFT_CELLULAR`, `IFF_LOOPBACK` all import through `Darwin`, each cited to a `net/if_mib.h`, `net/if_types.h` or `net/if.h` line. The convention's "nil-buffer sizing, one allocation, `loadUnaligned`" clause described the routing-socket walk and no longer applies: `ifmibdata` is fixed-size, so there is no sizing call, no allocation and no unaligned load |
| 8 — graph colours are Presentation tokens; `MetricsState` never sees a colour, unit or normalised value | Pass |
| 9 — do not commit | Pass. `git log -1` is still `de40106` |
| Domain imports Foundation only | Pass. All 26 Domain files |
| Presentation never touches sockets, Mach or the MIB | Pass. `rg "sysctl\|if_msghdr\|ifmibdata" system-monitor/Presentation` returns nothing |
| Only the `NetworkSnapshot` value crosses to the main actor | Pass. Pinned behaviourally by `everyReadHappensOffTheMainThread` |
| No new `MetricModule` case, no persisted setting | Pass. Asserted behaviourally by `publishingNetworkReadingsLeavesTheModulesAndWidgetUnchanged` |

### PRD success criteria — M6 / R11.1–R11.11 traceability

| PRD requirement | Where it is satisfied | Evidence |
|---|---|---|
| R11.1 source and scope (interface MIB) | NM-1, NM-10 | `SysctlNetworkProvider.readCounters()`; 9 `.integration` cases in the sandboxed host, two of which are independent MIB witnesses |
| R11.2 interface filter | NM-11 | 9-row parameterised truth table plus two dedicated cases |
| R11.3 totals since boot | NM-3, NC-5 | Reference snapshot; `UInt64.max` formats without trapping |
| R11.4 rates Δ/Δt with the negative-delta re-seed **and the zero-interface baseline rule** | NM-4 | 11 calculator cases, including `aZeroInterfaceBaselineYieldsNoRates` and the re-seed recovery |
| R11.5 first tick totals without rates; restart costs one tick | NM-5, NM-6 | Step and loop suites under `ManualClock` |
| R11.6 a failed read publishes nothing and drops the baseline | NM-8 | Four failure-isolation cases |
| R11.7 two 120-sample histories appended together | NM-9 | Four state cases, including the capacity bound |
| R11.8 shared graph scale, stroke-only lines | NC-8, NC-9 | Shared divisor, 10 kB/s floor, `fillOpacity 0` |
| R11.9 formatting reuse | NC-4, NC-5 | `ByteFormatter.throughput` / `.capacity` under both locales |
| R11.10 unavailable states and stable skeleton height | NC-6, NC-7 | Em dashes with `"unavailable"`; `after == before` height |
| R11.11 palette and no menu bar module | NC-10, NM-12 | Token equalities; `MetricModule.allCases` and `statusItemLength` asserted |
| R2.5 visible-frame scroll cap | NC-12, DC-11 | `PanelLayout` rule plus the controller's real 921.0 pt measurement; confirmed on the 14" display (7.5) |
| PRD 2 success metric (totals match Activity Monitor) | Task 7.4 | **Confirmed passed by the user 2026-09-10** on the IFMIB build; the two pairs were not reported back, so no figure is recorded here |
| PRD 8 / 10 profiling (average CPU under 1%, resident size) | Task 7.7 | **Confirmed passed by the user 2026-09-10** (Time Profiler, panel closed, under 1%); the figure and the resident size were not reported back. See **W5'** |
| PRD 8 coverage target (Domain + Application 80%+) | — | **Not measurable** — coverage is not configured on the scheme (S1) |

### TDD Compliance

| Check | Result | Details |
|-------|--------|---------|
| TDD Evidence reported | ✅ | Seven "TDD Cycle Evidence" tables in `apply-progress.md` (batches A–G), one for the NC-4 corrective re-run, one for the `R3-zero-interface-baseline` review correction and one for the IFMIB correction — **ten in total** |
| All tasks have tests | ✅ | Every RED row names a file that exists; all network test files were opened and read in this phase |
| RED confirmed (tests exist / fail first) | ✅ | Every RED is quoted with its compiler or assertion message. Compile-level REDs: 1.1, 1.3, 1.5, 2.1, 3.1, 4.1, 4.3, 4.5, 4.7, 4.9, NC-4 re-run. Behavioural REDs on a compiling target (the stronger form): 2.3 (4 failing scenarios), 2.5, 2.7 (3 failing), 3.4 (4 failing against a zero-interface stub), 4.8 (`(panel.height → 1049.0) > (threeCardHeight → 1049.0)`), 5.1 (a 5 s `awaitValue` deadline expiring against the placeholder) |
| **RED before GREEN for correction 1 (`R3-zero-interface-baseline`)** | ✅ | Calculator: `-only-testing:…/NetworkThroughputCalculatorTests` → `exit=65`, `aZeroInterfaceBaselineYieldsNoRates()` failed on both test processes; after the guard, exit 0, 11 distinct cases passed. Sampler: with the guard temporarily reverted, `exit=65`, `theIdleToPopulatedTransitionCostsOneRateFreeTick()` failed with 6 recorded issues; guard restored, exit 0, 38 passed. **A ghost-green was caught and removed** — the first script `[idle, referencePrevious, referenceCurrent]` passed even with the guard reverted, because `NetworkFixtures.idle` and `referencePrevious` are both stamped `at: 0`, so step 2 was a zero-length window satisfied by the `elapsed > 0` guard. The script was rewritten with explicit counters stamped 0, 1 and 2 to produce a true RED |
| **RED before GREEN for correction 2 (IFMIB)** | ✅ | `-only-testing:…/SysctlNetworkIntegrationTests` → `exit=65`, **both** new cases failed on both test processes as *assertion* failures rather than thrown errors — which also proves the sandboxed host reaches the interface MIB. After the rewrite: exit 0, 9 distinct cases passed. The unit seams stayed green throughout: `SysctlNetworkProviderTests` exit 0, 8 passed. The correction brief's sketch would have produced a *compile* RED (throwing a `ReadError` case that does not exist yet); apply deliberately used an independent `MIBUnavailable` witness error so the test compiles against the old adapter and fails on the truncation it exists to detect. That is the stronger RED, and it is recorded as a deviation from the brief |
| RED precedes GREEN for every implementation task | ✅ | 1.1→1.2, 1.3→1.4, 1.5 paired, 2.1→2.2, 2.3→2.4, 2.5→2.6, 2.7→2.8, 3.1→3.2, 3.4 paired, 4.1→4.2, 4.3→4.4, 4.5→4.6, 4.7→4.8, 4.9→4.10, 5.1 paired, NC-4 re-run paired, correction 1 paired (twice), correction 2 paired. 6.1/6.2 are DOC-only with no executable scenario; 7.1/7.2 are verification runs; 3.3 is a contingency correctly recorded as skipped |
| GREEN confirmed (tests pass) | ✅ | Every suite listed as green in apply passes in this phase's own runs. No suite is red now |
| Triangulation adequate | ✅ | NM-4 has 11 cases for 9 scenarios; NM-8 has 4 for 3; NM-9 has 6 for 4; NM-10/NM-11 have 8 unit cases (two of them parameterised over 9 and 8 rows) plus 9 `.integration` cases for 12 scenarios; NC-2..NC-13 have 23 cases for 26 scenarios with the multi-value ones split. The single-case rows (the 5.1 modules check, the NC-4 colour order) are genuine single-scenario requirements |
| Safety Net for modified files | ✅ | Every batch that edited a pre-existing suite recorded a pre-edit green run: 558/558, 584/584, 18/18, 12/12, 16/16, 37/37, 33/33, 10/10, 22/22. Both corrections edited pre-existing suites and both recorded their pre-edit baselines (11-case and 38-case suites, and the 9-case integration suite). `N/A (new)` rows correspond to genuinely new files, which `git status` confirms are untracked |

**TDD Compliance**: **8/8 checks passed** (the two correction rows are additional to revision 1's seven).

### Test Layer Distribution

| Layer | Distinct cases | Files | Tools |
|-------|----------------|-------|-------|
| Unit (Domain, Application, Presentation, pure Infrastructure seams) | 613 | — | Swift Testing (`@Test` / `#expect`) |
| Integration (`.integration` and composition suites — live interface MIB, live Mach/IOKit, real composition graph, `NSHostingView`/`NSStatusItem` measurement) | 54 | 7 | Swift Testing + real system APIs |
| **`system-monitorTests` target subtotal (`UNIT`)** | **667** | | |
| E2E / UI (pre-existing Xcode template) | 3 | 1 | XCTest / XCUITest |
| **Total (`FULL`)** | **670** | | |

Of the network work specifically, **79 cases live in 8 new test files** (`NetworkSnapshotTests` 9, `NetworkThroughputCalculatorTests` 11, `NetworkMetricsProviderPortTests` 7, `SysctlNetworkProviderTests` 8, `SysctlNetworkIntegrationTests` 9, `HistoryGraphSeriesTests` 6, `NetworkCardModelTests` 23, `PanelLayoutTests` 6), plus roughly 30 more added to 9 pre-existing files. Eleven of them read the live interface MIB or drive the real composition graph (`SysctlNetworkIntegrationTests` 9, `AppDelegateCompositionTests` +2). The `.integration` tools are declared available in `openspec/config.yaml` and were exercised in this phase's runs, so no test uses a capability the project does not have.

**A revision-1 claim corrected.** Revision 1's W4 said the `.integration` scenarios are "green only in a run that includes the sandboxed test host" and that `UNIT` "does not prove NM-10 or NM-12". That is wrong, and this phase disproves it directly: the `.integration`-tagged suites live inside the `system-monitorTests` target, so `-only-testing:system-monitorTests` runs all of them. `SysctlNetworkIntegrationTests` (9 distinct cases) and `AppDelegateCompositionTests` (12) appear in full in the `UNIT` log, alongside `IOKitDiskIntegrationTests`, `MachIntegrationTests`, `MachMemoryIntegrationTests`, `SMAppServiceLaunchAtLoginIntegrationTests` and `VolumeCapacityIntegrationTests`. The only thing `FULL` adds over `UNIT` is the three XCUITest cases. W4 is withdrawn.

### Changed File Coverage

Coverage analysis skipped — no coverage tool is configured (`coverage_command: ""`, `testing.coverage.available: false`, `coverage_threshold: 0`). No per-file percentage is asserted.

### Assertion Quality

Every network test file, including everything both corrections added, was scanned for the banned patterns. No tautology, no assertion that never calls production code, no ghost loop, no smoke-test-only case and no mock-heavy file was found. Strengths worth recording:

- `theSummedCountersAreNotTruncatedToThirtyTwoBits` asserts a *relationship* (`adapter total >= largest single-interface counter`) rather than a hardware figure, so it passes trivially on a machine that has moved under 4 GB since boot and bites on any truncating source on one that has not. Its `#require(interfaces.map(\.bytesIn).max(), "no admitted interface")` prevents the empty-collection degeneracy that would otherwise make it vacuous.
- `theAdapterTotalsMatchTheSumOfThePerInterfaceMIBCounters` asserts `interfaces.count == counters.interfaceCount` **before** comparing totals, so a source that admitted a different interface set could not pass by coincidence.
- `aZeroInterfaceBaselineYieldsNoRates` uses explicitly stamped counters rather than the shared fixtures, precisely because chaining `idle` before `referencePrevious` produced a zero-length window and a ghost green (see TDD Compliance).
- `anUnavailableRateIsNeverRenderedAsZero` pins NC-6's prohibition explicitly rather than implying it.
- `theReadingColoursAreDownloadThenUpload` asserts the colour array *and* that its count equals `rateReadings`' count, so the view's `zip` cannot silently drop a badge.
- `theRealGraphPublishesRealNetworkReadings` discriminates on `totalIn > 0` / `totalOut > 0` rather than "rates are eventually non-nil"; the old placeholder produced a non-nil `0 B/s` pair, so a weaker assertion would have passed against the stand-in.
- The only type-only assertion, `#expect(animation != nil)` in `NetworkCardModelTests`, is paired in the same test with `#expect(animation == CPUCardModel.gaugeAnimation(reduceMotion: false))`.
- Every loop in the new tests is bounded by construction (`for index in 1...count` guarded by `count > 0`; `for _ in 0..<50`), so none can iterate zero times over a filtered collection.

**Assertion quality**: All assertions verify real behaviour. **0 CRITICAL, 0 WARNING.**

### Quality Metrics

**Linter**: Not configured — `swiftlint` is installed but there is no `.swiftlint.yml` and it is not wired into the build, so no lint result is asserted.
**Type checker / compiler**: ✅ Passed — `build` exits 0 with **zero warnings** under Swift 6 strict concurrency and `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.

### Issues Found

**CRITICAL**: None.

**WARNING**:

1. **W1' — NM-10's "No admitted interface is not an error" still has no adapter-level test.** Both zero-interface paths (`SysctlNetworkProvider.swift:144` `guard count > 0 else { return Self.empty() }`, and the `1...count` loop admitting nothing) are unreachable on this host, which admits about fourteen interfaces, and the adapter exposes no injection seam. The behaviour is asserted one layer up against fixtures. Revision 1's W1 also carried a *risk* claim — that an untested zero-interface reading might be mishandled — and that half is **superseded**: the review found the real defect (the zero-interface reading being accepted as a delta baseline), it was fixed in `NetworkThroughputCalculator`, and it is now covered by two tests. What survives is the narrower coverage-depth gap. Not blocking.
2. **W2' — NC-3's tint and header trait remain static-only evidence.** `theHeaderTitleIsNetwork` pins the title; nothing asserts that the globe carries `Palette.networkAccent` or that the header adds `.isHeader`. Both were read directly (`NetworkCard.swift:276`, `:281`), the token value is pinned by `PaletteTests`, and **manual check 7.6 confirmed the rendered accent on the running app**, which reduces but does not remove the risk that a restyle drops the tint without failing a test.
3. **W3' — NC-4's colour clause is pinned at the model, not at the pixel.** `NetworkCardModel.readingColors` is the single source of truth the view zips against and the test asserts the array and its length. The view's `zip(rateReadings, readingColors)` and `ThroughputLabel`'s split (icon takes the supplied colour, value text stays `Palette.textPrimary`) were confirmed by reading, not asserted. This is the residue of the NC-4 amendment and is the strongest coverage available without a rendering test.
4. **W5' — the manual figures were confirmed but not reported.** Tasks 7.3–7.7 all passed on the IFMIB build, so no manual check is open. However the user reported pass/fail only: task 7.3's peak rate figures and task 7.7's average-CPU and resident-size numbers were **confirmed by the user, figure not reported**. PRD sections 8 and 10 ask for the M6 profiling number next to the M5 baseline, and this report therefore records the *verdict* (under 1%) without the *value*. Archive should not invent one.
5. **W6' — the `networkAccent` pin is a raw-device-byte value.** `0xC659E4` is the densest globe pixel from `NSBitmapImageRep.bitmapData`; the same pixel converted to sRGB reads `0xD276EA`, because `docs/reference/06-panel-network.png` carries an "Odyssey G5" display profile. Digital Color Meter reports native values by default, which is the mode manual 7.6 used; a future check in an sRGB-converted mode will appear to disagree by roughly 0x0C/0x1D/0x06 per channel. A colour-profile artefact, not a defect.
6. **W7' — `-quiet` logs drop characters, in more than one place.** Reproduced twice in this phase, in two different shapes: `UNIT` lost the tail of `startSeedsTheDeltaThenPublishesAfterTheStartupGap()` (a `Test case '<id>'` match reports 666 instead of 667), and `FULL` lost the leading `Test` of `everyReadHappensOffTheMainThread()` (even a `Test case '` match reports 669 instead of 670). Match on `case '<id>'`, count `failed` lines separately, and cross-check against the `@Test` declaration count. Related: `-only-testing` takes the Swift Testing *suite type* name, never a file name — `…/CanvasComponentsTests` exits 0 having run zero cases.
7. **W8 — the truncation witness reads the same MIB the adapter reads** (native review #2 advisory `R3-truncation-witness-shares-source`). `admittedMIBInterfaces()` in `SysctlNetworkIntegrationTests` issues its own `IFMIB_IFDATA`/`IFDATA_GENERAL` calls, so it is independent of the *adapter*, not of the *source*. It would catch an adapter that truncated, mis-summed or mis-filtered; it could not catch the interface MIB itself under-reporting. That residual risk is what the cross-source comparison in the correction record (13 563 204 219 via the MIB against 678 301 696 via the routing socket) covers, and that comparison is a one-off probe, not a test. Not blocking.
8. **W9 — NM-10's "A missing index is a gap, not a failure" is pinned at the seam, not at the wiring.** The 8-row truth table proves `isMissingInterface(errno:)` classifies correctly, but nothing asserts that `interface(at:)` turns a `true` into `return nil` (a skipped index) and a `false` into `throw ReadError.interfaceRead(index:errno:)`. That wiring (`SysctlNetworkProvider.swift:183-189`) was read directly in this phase and is three lines. Reaching it from a test would need an errno-injection seam the amended design deliberately did not add.
9. **W10 — three native-review advisory findings are recorded as later work, not fixed.** Review #2 (lineage `review-75a9871bf4b6e760`, approved with no correction) left four advisory non-blocking findings. `R3-truncation-witness-shares-source` is W8 above. The other three are carried unfixed: **`R3-all-gaps-become-valid-empty`** (a machine where *every* index answers a missing-interface errno yields a valid `interfaceCount == 0` reading rather than a failure — correct per NM-10, but indistinguishable from "no interface passed the filter"); **`R3-cap-not-reapplied-while-shown`** (`updatePanelCap()` runs in `togglePopover()`'s show branch, so a display change *while the popover is open* does not re-cap until the next open); **`R3-churn-without-net-fall`** (if one interface disappears and another appears between two ticks such that the summed counters do not fall, the window is admitted and the rate is slightly wrong for that tick). All three are behaviour the specs currently permit; none contradicts a scenario.

**SUGGESTION**:

1. **S1 — coverage cannot be measured.** No shared `.xcscheme`, so PRD section 8's "Domain + Application 80%+" target still has no number attached, as at M5. Enabling coverage on a shared scheme would let a future verify report state it instead of skipping it.
2. **S2 — NC-9's "existing call sites unchanged" rests on a convenience-init equality plus a `git diff` reading.** Nothing would fail if a future change rewrote `CPUCard`/`MemoryCard` to the multi-series form. Low value to add; recorded for completeness.
3. **S3 — two documented intermittents did not fire in this phase.** The XCUITest automation-mode handshake timeout (`Timed out while enabling automation mode`, exit 65 with zero failed cases) and `system_monitorUITests.testLaunchPerformance()`. A future red `FULL` whose only failure is one of those two is not a regression; re-run once.
4. **S4 — `MachIntegrationTests.swift:107` is conditionally enabled** (`@Test(.enabled(if: SysctlReader().performanceLevelCount == 2))`). It ran in both of this phase's test runs, so `UNIT` reported the full 667. On a machine with a different performance-level topology the count would be 666 and that is not a missing test.
5. **S5 — the interface MIB costs one `sysctl` per interface per tick.** The routing socket needed two calls total; the MIB needs about twenty on this machine, every second. Manual 7.7 confirmed the average CPU stays under 1%, so this is not a problem today, but it is the figure to watch if the sampling interval is ever shortened or the machine grows many interfaces.

### Open items

**None blocking.** All 37 tasks are complete and all five manual checks were confirmed passed by the user on 2026-09-10.

Carried forward as later work, all advisory:

| Item | Kind | Where it is recorded |
|---|---|---|
| `R3-all-gaps-become-valid-empty` | Native review #2 advisory | W10 |
| `R3-cap-not-reapplied-while-shown` | Native review #2 advisory | W10 |
| `R3-churn-without-net-fall` (WARNING) | Native review #2 advisory | W10 |
| `R3-truncation-witness-shares-source` | Native review #2 advisory | W8 |
| Adapter-level zero-interface and errno-injection seams | Coverage depth | W1', W9 |
| NC-3 tint / `.isHeader` rendering assertion | Coverage depth | W2' |
| 7.3 peak and 7.7 CPU / resident-size figures | Recording gap | W5' |
| Design open question 5 (root-swap timing) | **Closed** by manual 7.5 — the cap applied on the first open; no move to `popoverWillShow` was needed | — |

### Verdict

**PASS WITH WARNINGS** — all **28 requirements** and all **79 scenarios** of the current spec set have covering tests that passed at runtime, with 3 scenarios reaching only partial depth (W1', W9, W2') and none untested or failing. `FULL` is 670/0 and `UNIT` is 667/0, both exit 0 with zero compiler warnings; `build` is exit 0 with zero warnings under Swift 6 strict concurrency. All 37 tasks are complete, including the five manual checks the user confirmed on the corrected IFMIB build. Strict-TDD RED evidence precedes GREEN for every implementation task **and for both post-verify corrections**, one of which caught and removed a ghost green. The hexagonal boundaries and conventions 1–9 hold, no production code retains the routing-socket walk, and `PRD.md` plus `openspec/config.yaml` carry the full NM-13 alignment including the corrected R11.1, R11.4 and 6.3 rows. Nine warnings and five suggestions are recorded; **none blocks archive**. Revision 1's W1 (risk half) and W4 are withdrawn, and revision 1's IFMIB/routing-socket source claims are superseded.

### What archive must know

1. **Nothing is committed.** The whole change is one uncommitted working tree at `de40106`: 18 modified tracked files, 19 untracked entries (new source and test files, `docs/reference/06-panel-network.png`, and `openspec/changes/network-module/`). Delivery stays user-owned.
2. **All 37 tasks are complete**, including manual checks 7.3–7.7, which the user confirmed on 2026-09-10 on the IFMIB build. The 7.3 peak and 7.7 CPU/resident figures were **not reported back**; archive must not invent them and PRD sections 8/10 keep the verdict without the value.
3. **Two capability specs are new** — `network-metrics` (NM-1..NM-13, **43** scenarios) and `network-card` (NC-1..NC-13, **30** scenarios) — and `disk-card`'s DC-1 and DC-11 are MODIFIED by a non-destructive delta (**6** scenarios). DC-2..DC-10 are unchanged and must be preserved verbatim when the delta is merged.
4. **The spec files are authoritative over the Engram spec mirror.** Engram observation `sdd/network-module/spec` (8291) predates three amendments: NC-4's icon-only tint, NM-4's "either reading" clause plus the "Zero-interface baseline yields nil" scenario, and NM-10/NM-11's rewrite to the interface MIB with three new scenarios. Merge the files, never the mirror.
5. **The data source is the interface MIB, not the routing socket.** `NET_RT_IFLIST2` appears exactly once in production, as the doc comment at `SysctlNetworkProvider.swift:13` that NM-10 requires. Any archived listing regenerated from an older artefact must not reintroduce the routing-socket description.
6. **The design's `networkAccent` estimate `#A66BFF` and its "~1050 pt" placeholder are superseded** by the measured `#C659E4` and 1049 pt / 921 pt. `design.md` decision 2 is flagged amended with a dated amendment section.
7. **Coverage is unmeasured, not failing** (S1). No coverage number should be asserted in the archived record.
8. **`ThroughputLabel.swift`, `DiskCard.swift`, `CPUCard.swift`, `MemoryCard.swift`, `MetricModule.swift` and `project.pbxproj` were deliberately not modified.** DC-7 and the shared-component reuse depend on that, and it is what makes the NC-4 amendment correct rather than a workaround.
9. **Both native reviews are closed.** Review #1 (`review-6998e0189040a8d8`) approved after one bounded correction; review #2 (`review-75a9871bf4b6e760`) approved with no correction. Both were acknowledged and their authority burned. Review #2's four advisory findings are carried in W8 and W10 as later work.
