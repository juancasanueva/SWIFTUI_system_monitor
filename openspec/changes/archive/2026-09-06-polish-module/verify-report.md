```yaml
schema: gentle-ai.verify-result/v1
evidence_revision: sha256:0445c505d0f50607353d44f7b8beab6d9ea613f9eef2fa6933b13c3be7df852d
verdict: pass_with_warnings
blockers: 0
critical_findings: 0
requirements: 23/23
scenarios: 85/85
test_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests
test_exit_code: 0
test_output_hash: sha256:e45fa4148c69fc60356d04174d6914fe22da5187855ce07f0f33e857a02fbc1e
build_command: xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build-for-testing
build_exit_code: 0
build_output_hash: sha256:1997f6bccdceedce0ebddba98d8be2ed8d3be29b1d90ae5cbe82d450f69df812
```

## Verification Report

**Change**: polish-module (PRD M4 — "Polish — ship v1")
**Version**: design revision 2.1; 6 delta specs
**Mode**: Strict TDD
**Revision**: Revision 2 (2026-09-06): after correction batch H and manual checks 8.3–8.6; supersedes revision 1

### What changed since revision 1

Revision 1 verified batches A–G at 525 tests, 84 scenarios, 42/47 tasks, and listed eight warnings of which four (W-1..W-4) were explicitly gated on manual checks the user had not yet run. Since then:

1. **Correction batch H** fixed the defect manual check 8.3 exposed on its first run. `NSHostingController`'s default `sizingOptions` (`.standardBounds`) never sets `preferredContentSize`, so `NSWindow(contentRect: .zero)` kept a `(0, 0)` content area and the Settings window opened as a bare title bar. `makeWindow()` now calls `setContentSize` from the hosted view's `fittingSize` floored at `SettingsView.formHeight`. Two new tests, one new spec scenario, one design revision. 525 → 527 tests, 84 → 85 scenarios.
2. **Manual checks 8.3–8.6 were run by the user and all PASSED**, closing W-1 through W-4 and W-8 at runtime. `tasks.md` now shows 46/47 complete; only 8.7 (Instruments) remains.

### Completeness

| Metric | Value |
|--------|-------|
| Tasks total | 47 |
| Tasks complete | 46 |
| Tasks incomplete | 1 — task 8.7 (`MANUAL` Instruments, PRD 10) |
| Requirements | 23 |
| Scenarios | 85 |

Counts recomputed from `tasks.md`, not taken from `apply-progress.md`: 47 checkboxes, 46 `[x]`, 1 `[ ]`. Requirement and scenario totals recounted from the six delta spec files with the same heading grammar native status uses (`### Requirement:` / `#### Scenario:`): 1+3+4+1+7+7 = 23 requirements and 3+13+14+2+19+34 = 85 scenarios. The single scenario added since revision 1 is settings ST-5 "First show presents the whole form".

### Build & Tests Execution

**Build**: PASSED — zero warnings, zero errors under Swift 6 strict concurrency.

The warning gate requires a prerequisite that is not part of the build command itself: every Swift file in both `system-monitorTests` and `system-monitor` is first touched (`fd -e swift . system-monitorTests system-monitor -x touch {}`) so the compiler cannot serve cached object files. Only then is the recorded `build_command` invoked. This ordering is load-bearing — a plain `build` never compiles the test target, which is exactly how two `no 'async' operations occur within 'await' expression` warnings survived batch A undetected.

```text
fd -e swift . system-monitorTests system-monitor -x touch {}
xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet build-for-testing
exit 0 | rg -c "warning:" = 0 | rg -c "error:" = 0
```

**Tests**: 527 passed / 0 failed / 0 skipped.

```text
xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests
exit 0
rg -c "' passed on '" = 527
rg -c "' failed on '" = 0 (no matches)
```

The +2 over revision 1's 525 are exactly the two batch-H cases in `SettingsWindowControllerTests`: `theFirstShowPresentsTheWholeForm()` and `theWindowIsNeverShorterThanTheFormItHosts()`. The `.integration`-tagged suites are not excluded from the default command and did run.

**Repository state after both runs** (source untouched by verification):

| Check | Value |
|---|---|
| `HEAD` | `f41bc0535c53279e93824622450f468fe8bc0272` — unchanged, nothing committed |
| `git diff --stat \| tail -1` | `42 files changed, 5483 insertions(+), 163 deletions(-)` (revision 1: 5408 insertions; +75 is batch H's authored delta, exactly as `apply-progress.md` claims) |
| Intent-to-add files (`git status --short \| rg -c '^ A'`) | 27 — unchanged |
| `git status --short system-monitor.xcodeproj` | empty (reverted after each of the 2 `xcodebuild` runs, convention 16) |

**Coverage**: not available — no coverage tool is configured for this scheme. Informational only, per the strict-TDD module.

### Spec Compliance Matrix

All 85 scenarios have a covering test that passed at runtime. **Revision 1's two PARTIAL entries are now full COMPLIANT**: both were partial only because a binding could not be exercised headlessly, and the user has now exercised both on a running app.

#### settings — ST-1..ST-7 (7 requirements, 34 scenarios)

| Requirement | Scenario | Covering test | Result |
|---|---|---|---|
| ST-1 | Interval clamped at the low bound | `SettingsTests > theInitialiserClampsTheSamplingIntervalToTheSupportedRange`, `withSamplingIntervalClampsTheSameWayAndKeepsTheModules` | COMPLIANT |
| ST-1 | Interval clamped at the high bound | same parameterised grid | COMPLIANT |
| ST-1 | In-range interval preserved | same parameterised grid | COMPLIANT |
| ST-1 | Defaults | `defaultsAreOneSecondAndTheDefaultModuleOrder`, `theIntervalConstantsPinTheSupportedRange` | COMPLIANT |
| ST-1 | Duplicates dropped, order kept | `theInitialiserDropsLaterDuplicatesAndKeepsTheCallerOrder` | COMPLIANT |
| ST-1 | Empty list normalises to the default order | `anEmptyModuleListNormalisesToTheDefaultOrder` | COMPLIANT |
| ST-2 | Fake round trip | `SettingsStore port > theFakeReturnsTheSeededValueAndCountsTheLoad`, `anUnseededFakeLoadsTheDefaults` | COMPLIANT |
| ST-2 | Scripted save failure | `theFirstSaveThrowsAndTheSecondRecordsTheValue` | COMPLIANT |
| ST-3 | Round trip | `UserDefaultsSettingsStore > aSavedValueIsLoadedBackUnchanged`, `aSecondValueRoundTripsThroughTheSameKeys`, `savingTwiceLeavesTheSecondValue` | COMPLIANT |
| ST-3 | Missing keys | `anEmptySuiteLoadsTheDefaults` | COMPLIANT |
| ST-3 | Corrupt interval | `aCorruptIntervalFallsBackToTheDefaultWithoutThrowing`, `aNonFiniteIntervalFallsBackToTheDefault` | COMPLIANT |
| ST-3 | Out-of-range persisted interval | `anOutOfRangePersistedIntervalIsClampedOnLoad`, `anImplausiblySmallPersistedIntervalIsClampedOnLoad` | COMPLIANT |
| ST-3 | Unknown module raw values ignored | `unknownModuleRawValuesAreDropped` | COMPLIANT |
| ST-3 | Only unknown module raw values | `aListOfOnlyUnknownModulesNormalisesToTheDefaultOrder` | COMPLIANT |
| ST-4 | Loads on init | `SettingsState > initLoadsFromTheStoreWithoutSaving` | COMPLIANT |
| ST-4 | Persists on mutation | `setIntervalExposesAndPersistsTheNewValue` | COMPLIANT |
| ST-4 | Unchanged mutation does not persist | `repeatingTheSameIntervalDoesNotSaveAgain` | COMPLIANT |
| ST-4 | Mutation is clamped | `anOutOfRangeIntervalIsClampedBeforeItIsPersisted`, `anIntervalAboveTheMaximumIsClampedToFiveSeconds` | COMPLIANT |
| ST-4 | Save failure keeps the in-memory value | `aFailedSaveKeepsTheValueAndRecordsTheError`, `aLaterSuccessfulSaveClearsTheRecordedError` | COMPLIANT |
| ST-4 | Hiding a module persists | `hidingAModulePersistsTheShorterList` | COMPLIANT |
| ST-4 | Last module cannot be hidden | `theLastVisibleModuleIsRefusedAndNothingIsPersisted` | COMPLIANT |
| ST-4 | Reorder persists | `moveUpReordersAndPersists`, `moveDownReordersAndAnEdgeMoveIsANoOp` | COMPLIANT |
| ST-5 | First show creates the window | `Settings window controller > theFirstShowCreatesAVisibleWindowTitledSettings`, `noWindowExistsBeforeTheFirstShow` | COMPLIANT (manual-passed 8.3, 2026-09-06) |
| ST-5 | **First show presents the whole form** (new in revision 2) | `theFirstShowPresentsTheWholeForm` (width `== SettingsView.formWidth`, height `>= SettingsView.formHeight`), triangulated by `theWindowIsNeverShorterThanTheFormItHosts` (height `>=` the hosted form's own `fittingSize.height`) | COMPLIANT (manual-passed 8.3, 2026-09-06) |
| ST-5 | Second show reuses the window | `aSecondShowReusesTheSameWindow`, `closingHidesTheWindowAndTheNextShowReusesIt` | COMPLIANT (manual-passed 8.3, 2026-09-06) |
| ST-5 | Both entry points share the window | `AppDelegateCompositionTests > bothSettingsEntryPointsShowTheSameWindow`, `theCommandTargetReusesTheWindowTheContextMenuOpened` (asserted on `windowNumber` in both orders) | COMPLIANT (manual-passed 8.3 — the Cmd+, keystroke itself is now runtime-confirmed) |
| ST-6 | Stepper increments in half seconds | `SettingsFormModel > incrementingOneSecondYieldsOneAndAHalf`, `eachIncrementAddsOneHalfSecond`; `Settings view > theStepperIncrementCommitsOneHalfSecondUp`, `theStepperDecrementCommitsOneHalfSecondDown` | COMPLIANT |
| ST-6 | Stepper saturates at the bounds | `incrementingAtTheMaximumStaysAtTheMaximum`, `decrementingAtTheMinimumStaysAtTheMinimum`, `theStepperSaturatesAtTheUpperBoundWithoutPersisting`, `theStepperSaturatesAtTheLowerBoundWithoutPersisting` | COMPLIANT |
| ST-6 | Interval label under en_US | `theLabelUsesTheDecimalPointUnderEnglish` | COMPLIANT |
| ST-6 | Interval label under de_DE | `theLabelUsesTheDecimalCommaUnderGerman` | COMPLIANT |
| ST-6 | Last visible toggle disabled | `theOnlyVisibleModuleCannotBeToggledOff`, `theLastVisibleModuleToggleIsDisabledAndItsHideIsRefused` | COMPLIANT |
| ST-6 | Toggles follow the current order | `theRowsFollowTheUserOrderAndPinTheMoveEdges`, `hiddenModulesFollowTheVisibleOnesAndCannotMove` | COMPLIANT |
| ST-6 | Move buttons reorder the widget | `theMoveUpIntentMovesTheModuleTowardsTheStart`, `theMoveDownIntentMovesTheModuleTowardsTheEnd` (each with its edge no-op) | COMPLIANT (was PARTIAL in revision 1; chevron→intent binding runtime-confirmed by manual 8.5 — "up is up") |
| ST-7 | Interval change is applied to the sampler | `anIntervalChangeReachesTheRunningSamplerThroughTheCadenceController` | COMPLIANT (manual-passed 8.4) |

#### launch-at-login — LAL-1..LAL-4 (4 requirements, 14 scenarios)

| Requirement | Scenario | Covering test | Result |
|---|---|---|---|
| LAL-1 | Only enabled counts as enabled | `LaunchAtLoginStatus > isEnabledIsTrueOnlyForTheEnabledCase` (over `allCases`) | COMPLIANT |
| LAL-1 | Only requiresApproval needs approval | `needsApprovalIsTrueOnlyForTheRequiresApprovalCase`, `theEnumHasExactlyTheFourSystemCases` | COMPLIANT |
| LAL-2 | Fake reports the scripted status | `LaunchAtLoginService port > theFakeReportsTheScriptedStatusAndCountsEveryRead`, `setStatusRescriptsTheServiceBetweenReads` | COMPLIANT |
| LAL-2 | Fake records and throws on demand | `theFirstEnableThrowsAndTheSecondSucceeds`, `aScriptedDisableFailureLeavesTheStatusUntouched` | COMPLIANT |
| LAL-3 | Status mapping table | `eachSystemStatusMapsToTheDomainCaseOfTheSameName`, `theFourSystemStatusesMapToFourDistinctDomainCases`, `aStatusTheSDKDoesNotDeclareDegradesToNotRegistered` | COMPLIANT |
| LAL-3 | Live status read in the sandbox (`.integration`) | `readingTheStatusTwiceSucceedsAndReturnsOneOfTheFourCases`, `twoAdaptersReportTheSameLiveStatus`, `theReportedStatusIsTheMappedSystemStatus` | COMPLIANT |
| LAL-3 | Nothing persisted | `savingWritesExactlyTheTwoSettingsKeys`, `noPersistedKeyRefersToLaunchAtLogin` | COMPLIANT |
| LAL-4 | Enabled shows a checkmark | `Context menu model > enabledIsCheckedAndTogglesOff` | COMPLIANT (manual-passed 8.6) |
| LAL-4 | Not registered shows no checkmark | `anUnregisteredStatusIsUncheckedWithThePlainTitle` (`.notRegistered` and `.notFound`) | COMPLIANT (manual-passed 8.6) |
| LAL-4 | Approval pending routes to Login Items | `approvalPendingIsAnnotatedAndRoutesToLoginItems`, `approvalPendingOpensLoginItemsInsteadOfToggling` | COMPLIANT (manual-passed 8.6) |
| LAL-4 | Toggle on calls enable once | `togglingFromNotRegisteredCallsEnableExactlyOnce` | COMPLIANT (manual-passed 8.6 — real `SMAppService` registration confirmed, closing W-4) |
| LAL-4 | Toggle off calls disable once | `togglingFromEnabledCallsDisableExactlyOnce` | COMPLIANT (manual-passed 8.6 — real deregistration confirmed, closing W-4) |
| LAL-4 | Enable failure does not crash | `aRefusedEnableIsSurfacedOnceAndLeavesTheItemUnchecked` | COMPLIANT (fake only — not exercised manually, and deliberately so) |
| LAL-4 | Status is re-read on every build | `theLaunchAtLoginItemFollowsTheLiveStatusOnEveryBuild` (`statusReads == 2`) | COMPLIANT (manual-passed 8.6 — "the menu check mark following the live status") |

#### menu-bar-widget — 7 requirements, 19 scenarios

| Requirement | Scenario | Covering test | Result |
|---|---|---|---|
| Context menu | Item titles and order | `theContextMenuHasTheThreeActionItemsInOrder`, `everyStatusYieldsTheSameThreeItemsInOrder`, `theDefaultStatusProducesTheDocumentedTitleList` | COMPLIANT |
| Context menu | Settings item opens the window | `theSettingsItemCallsTheInjectedOpenSettingsClosureOnce`, `theSettingsItemOpensTheRealSettingsWindow` | COMPLIANT (manual-passed 8.3) |
| Context menu | Quit terminates | `theQuitItemIsWiredToTheApplicationTerminateAction` | COMPLIANT |
| Dark popover | Popover appearance | `thePopoverIsPinnedToTheDarkAppearance` (`.darkAqua`) | COMPLIANT (manual-passed 8.6 — dark chrome under a light system appearance) |
| Dark popover | Palette untouched | `thePaletteTokensAreUnchangedByTheDarkPopover` | COMPLIANT |
| Status item lifetime | Deinit removes the item | `releasingTheControllerRemovesItsStatusItem` (two weak refs go `nil`), `releasingTheDelegateRemovesTheStatusItem` | COMPLIANT |
| Panel drives cadence | Open and close are reported | `thePopoverDelegateReportsEachTransitionOnce`, `aPanelTransitionOnTheStatusItemReachesTheSampler` | COMPLIANT (manual-passed 8.4 — real popover open/close pair) |
| Panel drives cadence | No duplicate transitions | `togglingTwiceNeverReportsASecondOpen` | COMPLIANT (was PARTIAL in revision 1; the `performClose` arm is runtime-confirmed by manual 8.4 — "two clicks on the item open then close the panel") |
| Redraw gating | Identical readings compare equal | `contentsBuiltFromIdenticalReadingsCompareEqual`, `readingsBuiltFromTheSameStateCompareEqual` | COMPLIANT |
| Redraw gating | Changed value compares unequal | `contentsDifferingOnlyInTheCPUValueCompareUnequal`, `contentsWithDifferentModuleSetsCompareUnequal`, `moduleLabelsCompareOnTheirWholeReading` | COMPLIANT |
| Data-driven modules | Order preserved | `readingsFollowTheMenuBarOrder` | COMPLIANT (manual-passed 8.5) |
| Data-driven modules | Both modules follow state | `bothModulesFollowTheirOwnState` | COMPLIANT (manual-passed 8.5) |
| Data-driven modules | Hidden module omitted | `aHiddenModuleProducesNoReading`, `anEmptyModuleListProducesNoReadings` | COMPLIANT (manual-passed 8.5) |
| Data-driven modules | Reversed order | `theReadingsFollowTheRequestedOrder` | COMPLIANT (manual-passed 8.5 — MEM before CPU and back) |
| Fixed-width layout | Length stable across updates | `theStatusItemLengthDoesNotChangeWhenTheValueChanges` | COMPLIANT |
| Fixed-width layout | Sizing options disabled | `theHostingViewDoesNotResizeItselfFromItsContent` (`sizingOptions == []`) | COMPLIANT |
| Fixed-width layout | Width budget | `twoModulesAtFullScaleStayUnderTheWidgetBudget`, `theWidgetStaysUnderTheWidthBudgetAtFullScale` (< 230 pt) | COMPLIANT |
| Fixed-width layout | One-module width | `oneModuleAtFullScaleStaysUnderTheOneModuleBudget` (< 130 pt) | COMPLIANT |
| Fixed-width layout | Length changes only when the module set changes | `hidingAModuleReMeasuresTheItemToTheOneModuleWidth`, `neitherNewReadingsNorAnIntervalChangeReMeasureTheItem`, `showingAModuleAgainRestoresTheTwoModuleWidth`, `theStatusItemIsSizedFromTheCurrentModuleSet` | COMPLIANT (manual-passed 8.5) |

#### cpu-metrics — CM-1/CM-2/CM-3 (3 requirements, 13 scenarios)

| Requirement | Scenario | Covering test | Result |
|---|---|---|---|
| CM-2 | Stored while stopped | `anIntervalAppliedWhileStoppedIsUsedByTheNextStart` | COMPLIANT (manual-passed 8.4) |
| CM-2 | One restart while running | `anIntervalAppliedWhileRunningRestartsTheLoopExactlyOnce` | COMPLIANT (manual-passed 8.4) |
| CM-2 | Restart costs one publish-free CPU tick | `aRestartCostsOnePublishFreeCPUTickAndNoMemoryGap` | COMPLIANT (manual-passed 8.4 — "within one tick of the change") |
| CM-2 | Unchanged interval is a no-op | `applyingTheIntervalAlreadyInEffectDoesNotRestartTheLoop` | COMPLIANT |
| CM-3 | Startup under a manual clock | `startSeedsTheDeltaThenPublishesAfterTheStartupGap`, `theInjectedIntervalIsExactlyWhenTheNextSampleLands` | COMPLIANT |
| CM-3 | Stop under a manual clock | `stopUnparksTheLoopAndFreezesEveryCount`, `startIsIdempotentSoOnlyOneLoopEverRuns` | COMPLIANT |
| CM-3 | No wall-clock dependency | `tenIterationsRunWithoutAnyWallClockTime`; grep gate: no `ContinuousClock`, `Task.sleep` or `waitUntil` in `MetricsSamplerTests.swift` | COMPLIANT |
| CM-1 | Throwing provider keeps looping | `aThrowingReadPublishesNothingAndKeepsThePreviousSample`, `aPermanentlyFailingMemoryProviderNeverStopsTheCPU`, `aThrowingCPUReadDoesNotPreventTheMemoryPublish` | COMPLIANT |
| CM-1 | Stop cancels | `stopUnparksTheLoopAndFreezesEveryCount` (`pendingDeadlines == []`) | COMPLIANT |
| CM-1 | Off-main sampling | `everyReadHappensOffTheMainThread` | COMPLIANT |
| CM-1 | Cadence truth table | `aClosedPanelAlwaysSamplesAtTheIdleCadence`, `anOpenPanelSamplesAtTheConfiguredInterval` (3 intervals x open/closed) | COMPLIANT (manual-passed 8.4 — 0.5 s, 5 s open, 2 s closed all observed) |
| CM-1 | Loop keeps running while closed | `theLoopKeepsRunningAtTheIdleCadenceWhileThePanelIsClosed` | COMPLIANT (manual-passed 8.4 — sparkline advances once per 2 s while closed) |
| CM-1 | Opening the panel restarts at the configured rate | `openingThePanelRestartsTheLoopAtTheConfiguredRate`, `openingThePanelRestartsARunningLoopExactlyOnce`, `aSecondOpenDoesNotRestartTheLoopAgain` | COMPLIANT (manual-passed 8.4) |

#### cpu-card (1 requirement, 3 scenarios) and memory-card MC-10 (1 requirement, 2 scenarios)

| Requirement | Scenario | Covering test | Result |
|---|---|---|---|
| Palette and card surface | Token values | `accentTokensMatchTheProductPalette`, `surfaceTokensMatchTheProductPalette`, `textTokensMatchTheProductPalette`, `cardSurfaceUsesTheDocumentedCornerRadius` | COMPLIANT |
| Palette and card surface | Reduce motion yields no animation | `CPUCardTests > reduceMotionRemovesTheGaugeAnimation` | COMPLIANT (manual-passed 8.6 — the ring gauge jumps under Reduce Motion) |
| Palette and card surface | Motion allowed yields the gauge animation | `motionAllowedYieldsTheQuarterSecondEaseOut` (+ the two-answers-differ case) | COMPLIANT |
| MC-10 | Reduce motion | `MemoryCardModelTests > reduceMotionRemovesTheGaugeAnimation` | COMPLIANT (manual-passed 8.6) |
| MC-10 | Motion allowed | equality with `CPUCardModel.gaugeAnimation(reduceMotion: false)` and `.easeOut(0.25)` | COMPLIANT |

**Compliance summary**: 85/85 scenarios COMPLIANT. 0 PARTIAL, 0 UNTESTED, 0 FAILING. 29 of the 85 additionally carry runtime confirmation from the user's manual checks 8.3–8.6, dated 2026-09-06. **0 scenarios remain manual-pending**: task 8.7 gates PRD-10 performance evidence, which appears only in two specs' non-scenario "Manual:" verification notes (`menu-bar-widget/spec.md:167`, `cpu-metrics/spec.md:113`), never in a `#### Scenario:` heading.

### Correctness (Static Evidence)

| Requirement group | Status | Notes |
|---|---|---|
| ST-1..ST-7 | Implemented | `Domain/Models/Settings.swift`, `Domain/Ports/SettingsStore.swift`, `Application/SettingsState.swift`, `Infrastructure/System/UserDefaultsSettingsStore.swift`, `Presentation/Settings/{SettingsView,SettingsWindowController}.swift` |
| LAL-1..LAL-4 | Implemented | `Domain/Models/LaunchAtLoginStatus.swift`, `Domain/Ports/LaunchAtLoginService.swift`, `Infrastructure/System/SMAppServiceLaunchAtLogin.swift`, `Presentation/MenuBar/ContextMenuModel.swift` |
| MBW-1/9/10..14 | Implemented | `Presentation/MenuBar/{StatusItemView,StatusItemController,ContextMenuModel}.swift` |
| CM-1/2/3 | Implemented | `Application/{SamplingCadence,MetricsSampler}.swift`, `system-monitorTests/Support/ManualClock.swift` |
| cpu-card / memory-card | Implemented | `Presentation/Panel/{CPUCard,MemoryCard}.swift` — `gaugeAnimation(reduceMotion:)` on both models |

### Coherence (Design revision 2.1)

| Decision | Followed? | Evidence |
|---|---|---|
| **Explicit window content sizing (Revision 2.1, batch H)** | Yes | `SettingsWindowController.swift:123-128` — `window.setContentSize(CGSize(width: SettingsView.formWidth, height: max(hosting.view.fittingSize.height, SettingsView.formHeight)))` after `layoutSubtreeIfNeeded()` and **before** `center()`, exactly as `design.md:281` now specifies |
| S3 activation fallback not implemented by default | Yes, and now settled | `design.md:281` names its trigger as manual 8.3's "key on first show" failing. 8.3 passed with "normal title bar and traffic lights, no S3 fallback needed", so the trigger did not fire and the fallback correctly stays unimplemented |
| Idle cadence literal is 2 s while closed | Yes | `SamplingCadence.idleInterval: Duration = .seconds(2)`; confirmed at runtime by manual 8.4 |
| `apply(interval:)` restart semantics | Yes | `guard newInterval != interval` → store → `guard isRunning` → `stop(); start()` — unchanged interval never writes |
| `isolated deinit` removes the status item | Yes | `StatusItemController.swift:93`, proven by `releasingTheControllerRemovesItsStatusItem` |
| Launch-at-login status read live per menu build | Yes | `makeContextMenu()` reads `launchAtLogin.status` at build time; `statusReads == 2` across two builds |
| Re-measure only on module-set change | Yes | `settingsDidChange` is `guard settings.menuBarModules != measuredModules else { return }` |
| Popover pinned to `.darkAqua` | Yes | `configurePopover()` sets `popover.appearance` and `popover.delegate` |
| `CommandGroup(replacing: .appSettings)` with Cmd+, | Yes | `system_monitorApp.swift:27-31`, `SwiftUI.Settings` qualification kept at `:12`. Manual 8.3 confirms the replacement takes on macOS 26, so design decision 13's fallback is not needed |
| Composition root construction order | Yes | `AppDelegate.swift:32` one `SettingsState`, `:51` one `SettingsWindowController` |

Batch H's own recorded deviations were reviewed and are all justified by measurement rather than preference. The most consequential — **no `.frame(minHeight:)` was added to `SettingsView`** — is verified independently below.

### Conventions Audit

| Convention | Result | Evidence |
|---|---|---|
| 1. Domain/Infrastructure/port/double types `nonisolated` + `Sendable` | PASS | Every declaration in `system-monitor/Domain` is `nonisolated`; all 5 ports are `nonisolated protocol …: Sendable` |
| `@unchecked Sendable` only on `UserDefaultsSettingsStore` | PASS | Exactly one production occurrence (`UserDefaultsSettingsStore.swift:18`) |
| 2. No `@MainActor` on `@Suite`/test types | PASS | No `@MainActor` precedes any `@Suite` or test struct |
| 3/CM-3. Loop suites free of `Task.sleep` / `ContinuousClock` | PASS | The only remaining `Task.sleep` in the whole test target is `MachIntegrationTests.swift:64` (pre-existing hardware settle, W-5) |
| 5. `.timeLimit(.minutes(1))` is the only time limit | PASS | All 15 occurrences are `.minutes(1)`; no other duration |
| 6/16. `project.pbxproj` never edited | PASS | `git status --short system-monitor.xcodeproj` empty after both verification runs |
| Domain imports Foundation only | PASS | All 16 Domain files import exactly `Foundation` and nothing else |
| `SwiftUI.Settings` qualification present | PASS | `system_monitorApp.swift:12` |
| Exactly one `SettingsState(` / `SettingsWindowController(` in non-preview production code | PASS | `SettingsState(` at `AppDelegate.swift:32`; the two `SettingsView.swift` hits (`:295`, `:306`) are inside the `#Preview` blocks opening at `:293` and `:303`. `SettingsWindowController(` only at `AppDelegate.swift:51` |
| 15. Nothing committed | PASS | `HEAD` still `f41bc05`; 27 intent-to-add entries preserved |
| **New in revision 2: `windowContentSize` is internal and read-only** | PASS | `SettingsWindowController.swift:79-81` — no access modifier (internal, matching the batch E/G precedent set by `windowStyleMask`, `hostedRootViewType`, `boundSettings`), a computed property with a getter only, over the same optional `window`. It has no setter and no `mutating` path; its only two call sites are both in `SettingsWindowControllerTests.swift` (`:125`, `:148`) |
| **New in revision 2: no `.frame(minHeight:)` in `SettingsView`** | PASS | `rg 'minHeight' system-monitor/Presentation/Settings/SettingsView.swift` returns nothing. The only frame modifier is `.frame(width: Self.formWidth)` at `:231`. This is what keeps `SettingsViewTests.theFormGrowsWhenASaveFails` meaningful: a shared minimum height would collapse its strict "failing form is taller than the clean one" inequality into an equality. That suite passes unchanged in the 527 run |

### TDD Compliance

| Check | Result | Details |
|-------|--------|---------|
| TDD Evidence reported | PASS | `TDD Cycle Evidence` tables present for all eight batches A–H |
| All tasks have tests | PASS | 41/42 automated tasks have a covering test; 7.2 is the documented unreachable exception, and it is now runtime-confirmed by manual 8.3 |
| RED confirmed (tests exist) | PASS | Every named test file exists; each batch records a concrete compiler RED. Batch H records a deliberate two-stage RED: stage 1 the compile failure (`no member 'windowContentSize'`, exit 65), stage 2 an inert-declaration run that made the assertion execute and **report the measured `(0.0, 0.0)`** rather than a compile error (exit 65, 525 passed, 1 failing on both expectations) |
| GREEN confirmed (tests pass) | PASS | 527/527 reproduced independently here at exit 0 |
| Triangulation adequate | PASS | Batch H is the model case: `theWindowIsNeverShorterThanTheFormItHosts` exists precisely to kill the "Fake It" implementation that a single hardcoded height would have passed. It measures the hosted form live and compares. This is why the batch produced 527 rather than the anticipated 526 |
| Safety net for modified files | PASS | Each batch records its predecessor count (299 → 359 → 389 → 426 → 483 → 497/501 → 518 → 525 → **527**) |

**TDD compliance**: 6/6 checks passed.

### Test Layer Distribution

| Layer | Tests | Files | Tools |
|-------|-------|-------|-------|
| Unit (pure values, models, application logic) | ~330 cases | 12 | Swift Testing |
| Presentation/AppKit host (real `NSStatusItem`, `NSWindow`, `NSMenu`, `NSHostingView`) | ~182 cases | 5 | Swift Testing + AppKit in the test host |
| `.integration` (live `SMAppService`, real `UserDefaults`, real Mach counters, real graph) | 10+ cases | 2 | Swift Testing `.tags(.integration)` |
| **Total** | **527** | **17 touched** | |
| Manual (user-executed, recorded in `apply-progress.md`) | 4 of 5 checks passed; 1 open | — | Running app on macOS 26 |

### Assertion Quality

Revision 1's full audit stands. Re-audited the two cases batch H added:

- `theFirstShowPresentsTheWholeForm` — calls production (`controller.show()`), then asserts two concrete values against named design constants, not against `nil`-ness. The height assertion carries a diagnostic message quoting the measured size, which is what let the RED report `(0.0, 0.0)` under `-quiet`.
- `theWindowIsNeverShorterThanTheFormItHosts` — calls production twice (`show()`, then renders `SettingsRootView` over `controller.boundSettings` in a real `NSHostingView`) and compares two independently measured runtime numbers. Its `#expect(naturalHeight > 0, "the form measured as empty")` is a guard against a vacuous comparison, not a standalone type-only assertion: if the form measured zero the second expectation would pass trivially, and this line fails first. That is the correct shape for that hazard.

No tautologies, no ghost loops, no `withKnownIssue`, no `.disabled(…)`, no skipped cases anywhere in the change.

**Assertion quality**: all assertions verify real behaviour. 0 CRITICAL, 0 WARNING.

### Quality Metrics

**Compiler (Swift 6 strict concurrency)**: 0 warnings, 0 errors under a forced full recompile of both targets.
**Linter**: not available — no SwiftLint/swift-format configuration in this repository.
**Coverage tool**: not available.

### Documentation

| Item | Status | Evidence |
|---|---|---|
| `PRD.md` 6.1 | Amended | `:166` tree gains `SettingsState.swift`; no "single observable object" wording remains anywhere in the file |
| `PRD.md` 6.4 | Amended | `:225` — "`MetricsState` and `SettingsState` are both `@MainActor @Observable`", non-view consumers register a synchronous observer |
| `PRD.md` 10 | Amended | `:307` points the Instruments numbers at `apply-progress.md` |
| `openspec/config.yaml:24` | Correct | `"26.5 …"` — all 6 `MACOSX_DEPLOYMENT_TARGET` entries are `26.5` |
| `openspec/config.yaml:25` | Correct | `"6.0 …"` — all 6 `SWIFT_VERSION` entries are `6.0` |
| `openspec/config.yaml:90` | Correct | "the repository has commits on `main`" — `git rev-list --count HEAD` = 11 |
| `design.md` Revision 2.1 | Present | `:281` carries the **Revision 2.1 (batch H correction)** marker with the `.standardBounds`/`preferredContentSize` root cause and the explicit `setContentSize` expression |
| `specs/settings/spec.md` ST-5 | Amended | `:159` requirement prose now mandates explicit content sizing; new scenario at `:167` "First show presents the whole form" |

### Issues Found

**CRITICAL**: None.

**Closed by manual check** (revision 1 warnings that the user's runtime observations have now retired — listed for provenance, not as open risk):

- **W-1 — MBW "No duplicate transitions": `performClose` arm never executed headlessly.** CLOSED by manual 8.4: "two clicks on the item open then close the panel". The branch is confirmed on a real popover.
- **W-2 — ST-6 chevron-to-intent binding uncovered by construction.** CLOSED by manual 8.5: "MEM up chevron renders MEM before CPU and the down chevron restores CPU before MEM" — the binding is not transposed. This was revision 1's highest-value manual check.
- **W-3 — Cmd+, unreachable from the unit target.** CLOSED by manual 8.3: "Cmd+, with the app active brings back the same window, never a second or empty one". `CommandGroup(replacing: .appSettings)` takes on macOS 26.
- **W-4 — launch-at-login registration mutations proven only through the fake.** CLOSED by manual 8.6: real `SMAppService` toggle on and off, Login Items entry appearing and disappearing, and the approval path.
- **W-8 — S3 activation fallback deliberately not implemented.** CLOSED by manual 8.3: the window is in front and key on first show with a normal title bar, so the fallback's trigger condition did not fire.

**WARNING** (open):

- **W-5 — `MachIntegrationTests.swift:64` retains a 120 ms `Task.sleep`.** Pre-existing hardware-settle wait outside this change's scope; the CM-3 grep gate covers the sampler loop suites, which are clean. Unchanged from revision 1.
- **W-6 — `AppDelegateCompositionTests` reads `.standard` `UserDefaults`.** Read-only and never mutates a setting, so it cannot disturb the developer's stored preferences. The unconditional identity assertion (`panelVisibilityObserver === cadence`) covers the case where a developer's stored 2 s interval makes two compared cadences coincidentally equal. Unchanged from revision 1.
- **W-7 — `SettingsState.observers` is append-only and never pruned.** Both current registrants capture `[weak self]` and `releasingTheControllerRemovesItsStatusItem` proves it, but any future registrant must do the same. Unchanged from revision 1.
- **W-9 (new) — the settings window is sized once, at creation, and never re-sized.** `setContentSize` runs inside `makeWindow()` (`SettingsWindowController.swift:123`), which `show()` calls only on the first invocation (`:38`, `let window = self.window ?? makeWindow()`). If the hosted form's natural height grows while the window already exists — and `SettingsViewTests.theFormGrowsWhenASaveFails` proves it does grow when a save error footer appears — the content area keeps its first-show height. This is not a defect: a grouped `Form` is a scrolling container, so the extra content scrolls rather than being clipped, and the 280 pt floor already carries 36 pt of headroom over the 244 pt natural height. It is recorded because the batch-H tests assert sizing only on a freshly created window, so a future change that moves sizing responsibility would not be caught. A follow-up would re-apply the same `setContentSize` expression on each `show()`.

On the revision-2 question of whether the window content-size assertion pattern is missing from any other window-hosting test: **confirmed, there is no other.** `NSWindow(` is constructed in exactly one production file (`SettingsWindowController.swift:111`), `SettingsWindowController` is the only window-controller type in the repository, and `SettingsWindowControllerTests.swift` is the only test file that references `NSWindow` at all. The gap batch H closed cannot exist anywhere else in this change. No warning is raised.

**SUGGESTION**:

- Consider pruning `SettingsState.observers` (a token-based `observe`/`cancel` pair) so W-7 stops being a standing note for every future registrant.
- Re-apply the content sizing on every `show()` (W-9), or add a test that grows the hosted form after the first show and asserts the window follows.
- Follow-up G3 remains open by design: if manual 8.7's closed-panel samples show `PanelView` bodies evaluating, build the hosting controller in `popoverWillShow` and drop it on close — as a separate change, not this one.
- `SettingsFormModel.seconds(_:)` duplicates `UserDefaultsSettingsStore.seconds(_:)` for layering reasons. Both are pinned by tests so a drift fails, but a shared Domain helper would remove the duplication.

### Remaining Gate to Archive

**Task 8.7 (`MANUAL`, Instruments) is the single remaining gate.** Time Profiler plus the SwiftUI template, 10 minutes with the panel closed then 10 minutes open; the expectation is < 1% CPU and < 50 MB RSS closed, with the numbers recorded in `apply-progress.md`. It gates PRD 10 performance evidence and the two specs' non-scenario "Manual:" verification notes. It gates **no spec scenario** — all 85 are already covered by tests that passed at runtime — so it is a documentation-and-evidence gate rather than a correctness gate. If its closed-panel samples show `PanelView` bodies evaluating, follow-up G3 is recorded as a separate change, not folded into this one.

### Verdict

**PASS WITH WARNINGS** — 23/23 requirements and 85/85 scenarios are covered by tests that passed at runtime (527/527, exit 0), 29 of them additionally confirmed on a running app by the user's manual checks 8.3–8.6. The zero-warning gate is clean under a forced full recompile of both targets. 46/47 tasks are complete with intact TDD evidence across batches A–H. Correction batch H is verified end to end: the fix is present and minimal, the two new tests are real, the new ST-5 scenario and design revision 2.1 both exist, `windowContentSize` is internal and read-only, and no `.frame(minHeight:)` was introduced. Zero blockers and zero CRITICAL findings. Four of revision 1's eight warnings, plus W-8, are closed by runtime observation; three carry forward unchanged and one new low-severity warning (W-9) is recorded. Task 8.7 is the only remaining gate to archive.
