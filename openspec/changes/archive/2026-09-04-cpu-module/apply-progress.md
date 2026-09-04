# Apply Progress: cpu-module

**Mode**: Strict TDD (`strict_tdd: true` in `openspec/config.yaml`)
**Work units completed so far**: `apply-phases-1-3-domain-application` (Units 1-3), `apply-phases-4-5-infrastructure-presentation` (Units 4-5), `apply-phase-6-menubar-composition` (Unit 6)
**Delivery**: single PR with `size:exception` (`review_budget_lines: unlimited`)
**Cumulative scope**: tasks 1.1 through 6.6 — the change is fully applied.

`TEST` = `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`

## Task Status

| Task | Status | Notes |
|---|---|---|
| 1.1 RED `MetricHistoryTests` | [x] | 9 cases from cpu-metrics "History ring buffer" |
| 1.2 GREEN `MetricHistory` | [x] | O(1) ring buffer, semantic `Equatable` |
| 1.3 RED `CoreTopologyTests` | [x] | Topology, ticks and snapshot model suites |
| 1.4 GREEN `CoreTopology`, `CPUTicks`, `CPUSnapshot` | [x] | Design signatures verbatim |
| 1.5 Ports | [x] | `CPUMetricsProvider`, `CoreTopologyProvider` |
| 1.6 Doubles and fixtures | [x] | `FakeCPUProvider` (`Mutex<Script>`), `FakeCoreTopologyProvider`, `TickFixtures`, `Tags` |
| 2.1 RED `CPUUsageCalculatorTests` | [x] | 15 cases across cpu-metrics and core-topology |
| 2.2 GREEN `CPUUsageCalculator` | [x] | Summed-delta aggregates, P/E/unknown ordering |
| 3.1 RED `MetricsStateTests` | [x] | apply, history bounded at 120 |
| 3.2 GREEN `MetricsState` | [x] | `@MainActor @Observable` |
| 3.3 RED `MetricsSamplerTests` (steps) | [x] | second-sample publishing, throw keeps `previous` |
| 3.4 GREEN `CPUSamplingStep` + `sampleOnce()` | [x] | Inline step stored separately from the loop |
| 3.5 RED `MetricsSamplerTests` (loop) | [x] | start/stop/idempotence/off-main |
| 3.6 GREEN detached `.utility` loop | [x] | startup gap then interval, cancel via `stop()` |
| 4.1 RED `CoreTopologyResolverTests` | [x] | 22 cases: mapping, cross-checks, duplicate/out-of-range ids, nil counts |
| 4.2 GREEN `CoreTopologyResolver` | [x] | Pure, all-or-nothing resolution + `level(forClusterType:)` |
| 4.3 Create `SysctlReader` | [x] | RED first via the `.integration` suite; width-aware `sysctlbyname` |
| 4.4 Create `MachCPUProvider` | [x] | RED first via the `.integration` suite; cached host port, `defer vm_deallocate` |
| 4.5 Create `IORegistryCoreTopologyProvider` | [x] | RED first via the `.integration` suite; `AppleARMPE` children, degrade path intact |
| 4.6 `.integration` suite | [x] | 11 cases, all green on real hardware inside the App Sandbox |
| 5.1 RED `PercentFormatterTests` | [x] | integer + one-decimal under `en_US` and `de_DE` |
| 5.2 GREEN `PercentFormatter` | [x] | Clamped, NaN-safe, locale-independent integer form |
| 5.3 RED `StatusItemReadingsTests` | [x] | accent mapping + `PaletteTests` token suite |
| 5.4 GREEN `Palette` + `MetricModule.accent` | [x] | 7 PRD 7.1 tokens plus `cardCornerRadius` |
| 5.5 Create Canvas components | [x] | RED first on `SparklineGeometry` and view `Equatable` |
| 5.6 RED `CoreBarGridTests` | [x] | 16 → 8+8, 12 → 8+4, 4 → one row, order preserved |
| 5.7 GREEN `CoreBarGrid` | [x] | `nonisolated static rows(for:)`, `maxPerRow = 8` |
| 5.8 Create `CPUCard` | [x] | RED first on `CPUCardModel`; rows, groups, gauge, graph, nil placeholder |
| 5.9 Modify `PanelView` | [x] | RED via rendered `NSHostingView` size; `@Environment(MetricsState.self)` |
| 6.1 RED menu bar readings | [x] | 12 cases: order, `0%` before the first snapshot, `42%`, newest 60 of 120, partial and empty history, MEM placeholder, metrics constants |
| 6.2 GREEN `StatusItemView` | [x] | `ModuleReading`, `StatusItemReadings.build`, `StatusItemContent`, `StatusItemView`, `StatusItemRootView`, `StatusItemMetrics` |
| 6.3 RED `StatusItemControllerTests` | [x] | 4 cases on a real `NSStatusItem`: stable length, `sizingOptions == []`, width under budget (200 pt then, 230 pt after the corrections), length == measured width |
| 6.4 GREEN `StatusItemController` | [x] | `init(state:)`, `sizingOptions = []`, length measured once, popover `.environment(state)`, three test accessors |
| 6.5 Modify `AppDelegate` | [x] | Composition root; `sampler.start()` on launch, `stop()` on terminate |
| 6.6 Full `TEST` + build + smoke run | [x] | 185/185 tests, clean build, app launched and stayed alive ~21 s at 0.1-0.6% CPU (re-verified after both corrections: 188/188, clean build, clean launch, widget 221.0 pt) |

## Files Created

### Phases 1-3

| File | Layer |
|---|---|
| `system-monitor/Domain/Models/MetricHistory.swift` | Domain |
| `system-monitor/Domain/Models/CPUTicks.swift` | Domain |
| `system-monitor/Domain/Models/CoreTopology.swift` | Domain |
| `system-monitor/Domain/Models/CPUSnapshot.swift` | Domain |
| `system-monitor/Domain/Ports/CPUMetricsProvider.swift` | Domain |
| `system-monitor/Domain/Ports/CoreTopologyProvider.swift` | Domain |
| `system-monitor/Domain/Services/CPUUsageCalculator.swift` | Domain |
| `system-monitor/Application/MetricsState.swift` | Application |
| `system-monitor/Application/MetricsSampler.swift` | Application |
| `system-monitorTests/Domain/MetricHistoryTests.swift` | Test |
| `system-monitorTests/Domain/CoreTopologyTests.swift` | Test |
| `system-monitorTests/Domain/CPUMetricsProviderPortTests.swift` | Test |
| `system-monitorTests/Domain/CPUUsageCalculatorTests.swift` | Test |
| `system-monitorTests/Application/MetricsStateTests.swift` | Test |
| `system-monitorTests/Application/MetricsSamplerTests.swift` | Test |
| `system-monitorTests/Support/FakeCPUProvider.swift` | Test support |
| `system-monitorTests/Support/FakeCoreTopologyProvider.swift` | Test support |
| `system-monitorTests/Support/TickFixtures.swift` | Test support |
| `system-monitorTests/Support/Tags.swift` | Test support |

### Phases 4-5

| File | Layer | Lines |
|---|---|---|
| `system-monitor/Infrastructure/System/CoreTopologyResolver.swift` | Infrastructure | 85 |
| `system-monitor/Infrastructure/System/SysctlReader.swift` | Infrastructure | 52 |
| `system-monitor/Infrastructure/System/IORegistryCoreTopologyProvider.swift` | Infrastructure | 129 |
| `system-monitor/Infrastructure/Mach/MachCPUProvider.swift` | Infrastructure | 69 |
| `system-monitor/Presentation/Formatting/PercentFormatter.swift` | Presentation | 37 |
| `system-monitor/Presentation/Theme/Palette.swift` | Presentation | 56 |
| `system-monitor/Presentation/Components/Sparkline.swift` | Presentation | 119 |
| `system-monitor/Presentation/Components/HistoryGraph.swift` | Presentation | 67 |
| `system-monitor/Presentation/Components/RingGauge.swift` | Presentation | 83 |
| `system-monitor/Presentation/Components/CoreBar.swift` | Presentation | 66 |
| `system-monitor/Presentation/Components/CoreBarGrid.swift` | Presentation | 77 |
| `system-monitor/Presentation/Components/KeyValueRow.swift` | Presentation | 36 |
| `system-monitor/Presentation/Panel/CPUCard.swift` | Presentation | 242 |
| `system-monitorTests/Infrastructure/CoreTopologyResolverTests.swift` | Test | 216 |
| `system-monitorTests/Infrastructure/MachIntegrationTests.swift` | Test (`.integration`) | 118 |
| `system-monitorTests/Presentation/PercentFormatterTests.swift` | Test | 75 |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Test | 61 |
| `system-monitorTests/Presentation/CanvasComponentsTests.swift` | Test | 141 |
| `system-monitorTests/Presentation/CoreBarGridTests.swift` | Test | 67 |
| `system-monitorTests/Presentation/CPUCardTests.swift` | Test | 173 |
| `system-monitorTests/Presentation/PanelViewTests.swift` | Test | 73 |

### Phase 6

| File | Layer | Lines |
|---|---|---|
| `system-monitorTests/Presentation/StatusItemControllerTests.swift` | Test | 71 |

## Files Modified

| File | Change |
|---|---|
| `system-monitor/Presentation/Panel/PanelView.swift` | Container view reading `@Environment(MetricsState.self)`; `CPUCard(snapshot:history:)` replaces the CPU placeholder; local colour constants replaced by `Palette`; the Memory `PlaceholderCard` stays |
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | Rewritten (30 → 198 lines): `ModuleReading`, pure `StatusItemReadings.build(snapshot:history:)`, `StatusItemMetrics`, presentational `StatusItemContent`, container `StatusItemView`, `StatusItemRootView`, accent-coloured label and 60 pt sparkline, fixed-width value frame, two `#Preview`s |
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | `init(state:)`; `hostingView.sizingOptions = []`; `statusItem.length` measured once from `StatusItemMetrics.measurementReadings` on a throwaway default-sizing `NSHostingView`; popover root `PanelView().environment(state)`; `statusItemLength` / `hostingSizingOptions` / `contentFittingWidth` accessors. `PassthroughHostingView` hit-test passthrough and the right-click Quit menu are unchanged |
| `system-monitor/App/AppDelegate.swift` | Composition root: `MetricsState`, `MachCPUProvider`, `IORegistryCoreTopologyProvider(sysctl: SysctlReader())`, `MetricsSampler(interval: .seconds(1))`, `StatusItemController(state:)`; `sampler.start()` in `applicationDidFinishLaunching`, `sampler.stop()` in `applicationWillTerminate`; strong references kept |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Extended (61 → 219 lines) with the `MenuBarReadingsTests` and `StatusItemMetricsTests` suites; `import AppKit` added for the font measurement helper |

`project.pbxproj` was never touched; new files and folders are picked up by the synchronized root group.

## TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 1.1/1.2 | `Domain/MetricHistoryTests.swift` | Unit | 4/4 baseline | Written, `cannot find 'MetricHistory' in scope` | 12/12 | 9 cases | None needed |
| 1.3/1.4 | `Domain/CoreTopologyTests.swift` | Unit | 12/12 | Written, `cannot find 'CoreTopology' in scope` | 26/26 | 14 cases across 3 suites | None needed |
| 1.5/1.6 | `Domain/CPUMetricsProviderPortTests.swift` | Unit | 26/26 | Written, `cannot find 'FakeCPUProvider' in scope` | 32/32 | 6 cases | None needed |
| 2.1/2.2 | `Domain/CPUUsageCalculatorTests.swift` | Unit | 32/32 | Written, `cannot find 'CPUUsageCalculator' in scope` | 47/47 | 15 cases | None needed |
| 3.1/3.2 | `Application/MetricsStateTests.swift` | Unit | 47/47 | Written, `cannot find 'MetricsState' in scope` | 52/52 | 5 cases | None needed |
| 3.3/3.4 | `Application/MetricsSamplerTests.swift` | Unit | 52/52 | Written, `cannot find type 'MetricsSampler' in scope` | 59/59 | 7 cases | None needed |
| 3.5/3.6 | `Application/MetricsSamplerTests.swift` | Unit (concurrency) | 59/59 | Written, `no member 'start'/'stop'/'isRunning'` | 64/64 | 5 cases | None needed |
| 4.1/4.2 | `Infrastructure/CoreTopologyResolverTests.swift` | Unit | 64/64 | Written, `cannot find type 'CoreTopologyResolver' in scope` | 86/86 | 22 cases | None needed |
| 4.3 | `Infrastructure/MachIntegrationTests.swift` | Integration | 86/86 | Written, `cannot find 'SysctlReader' in scope` | 91/91 | 5 cases | None needed |
| 4.4 | `Infrastructure/MachIntegrationTests.swift` | Integration | 91/91 | Written, `cannot find 'MachCPUProvider' in scope` | 93/93 | 2 cases | None needed |
| 4.5/4.6 | `Infrastructure/MachIntegrationTests.swift` | Integration | 93/93 | Written, `cannot find 'IORegistryCoreTopologyProvider' in scope` | 97/97 | 4 cases | None needed |
| 5.1/5.2 | `Presentation/PercentFormatterTests.swift` | Unit | 97/97 | Written, `cannot find 'PercentFormatter' in scope` | 116/116 | 19 cases | None needed |
| 5.3/5.4 | `Presentation/StatusItemReadingsTests.swift` | Unit | 116/116 | Written, `cannot find 'Palette' in scope`, `no member 'accent'` | 123/123 | 7 cases | None needed |
| 5.5 | `Presentation/CanvasComponentsTests.swift` | Unit | 123/123 | Written, `cannot find 'SparklineGeometry' in scope` | 136/136 + clean build | 13 cases | None needed |
| 5.6/5.7 | `Presentation/CoreBarGridTests.swift` | Unit | 136/136 | Written, `cannot find 'CoreBarGrid' in scope` | 145/145 | 8 cases | Replaced the last-row `Spacer`/`layoutPriority` hack with explicit `Color.clear` fillers; 145/145 after |
| 5.8 | `Presentation/CPUCardTests.swift` | Unit | 145/145 | Written, `cannot find 'CPUCardModel' in scope` | 161/161 | 16 cases | None needed |
| 5.9 | `Presentation/PanelViewTests.swift` | Integration (rendered `NSHostingView`) | 161/161 | Written; 2 behavioural failures (`thePanelRendersTheCPUCardRatherThanAPlaceholder`, `applyingASnapshotWithCoresGrowsThePanelWithBarGroups`) | 165/165 | 4 cases | None needed |
| 6.1/6.2 | `Presentation/StatusItemReadingsTests.swift` | Unit | 165/165 | Written, `cannot find type 'ModuleReading' in scope` (exit 65) | Compiled; suite verified green with 6.4 (the test host could not launch until the status item root view had its environment) | 16 cases | None needed |
| 6.3/6.4 | `Presentation/StatusItemControllerTests.swift` | Integration (real `NSStatusItem` + `NSHostingView`) | 165/165 | Written, `argument passed to call that takes no arguments` ×4 (exit 65) | 185/185 | 4 cases | None needed |
| 6.5 | `Presentation/StatusItemControllerTests.swift` (indirect) | Integration (app launch) | 165/165 | The test host crashed on launch — `Early unexpected exit ... test runner crashed before establishing connection` — because the composition root did not exist | 185/185 plus a clean launch of the built app | Smoke run (6.6) | None needed |

**Note on the 6.2 RED→GREEN gap**: `StatusItemView` became an `@Environment(MetricsState.self)` container in 6.2, so the app — which is also the unit-test host — trapped at launch until `StatusItemController` injected the state (6.4) and `AppDelegate` built it (6.5). This is exactly the pre-recorded Phase 5 issue #1. The 6.1 tests were written first and failed to compile (RED); they were proven green in the first run in which the host could boot again.

### Test Summary

- Total tests written in Phases 4-5: 101 (64 → 165)
- Total tests written in Phase 6: 20 (165 → 185)
- Total tests passing: 188, 0 failing (185 at the end of Phase 6, +2 from the 40 pt sparkline correction, +1 from the 230 pt budget correction)
- Layers used: Unit (166), Integration (19: 11 real-hardware `.integration`, 4 rendered-panel, 4 real `NSStatusItem`)
- Pure functions created in Phase 6: `StatusItemReadings.build(snapshot:history:)`, `StatusItemMetrics.showsSparkline(_:)`
- Approval tests: none — `PanelView` was rewritten against new behavioural tests, not refactored in place
- Pure functions created in Phases 4-5: `CoreTopologyResolver.resolve`/`level(forClusterType:)`, `SysctlReader.integer`, `PercentFormatter.integer`/`oneDecimal`, `SparklineGeometry.points`/`areaPath`/`linePath`, `CoreBarGrid.rows(for:)`, `CPUCardModel.rows`/`groups`/`gaugeText`/`gaugeFraction`/`barLabel`/`graphSamples`

## Work Unit Evidence (Phases 4-5)

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` — exit 0, 165 passed, 0 failed |
| Runtime harness command/scenario and exact result | `xcodebuild ... -quiet build` — exit 0, zero errors, zero warnings. Real-hardware harness: the `.integration` suite (11 cases) reads Mach `host_processor_info`, `sysctlbyname` and the `AppleARMPE` IORegistry tree from inside the sandboxed test host on an Apple M4 Pro (12 logical cores, 8 P + 4 E) — all green, with the topology fully resolved (no `.unknown`), confirming both design open questions about IOKit under the App Sandbox and `logical-cpu-id` matching the Mach index |
| Rollback boundary | Delete `system-monitor/Infrastructure/`, `system-monitor/Presentation/{Theme,Formatting,Components}`, `system-monitor/Presentation/Panel/CPUCard.swift`, `system-monitorTests/Infrastructure/`, `system-monitorTests/Presentation/`, and revert `system-monitor/Presentation/Panel/PanelView.swift` to its M1 two-placeholder form. Domain, Application and the menu bar files are untouched |

## Work Unit Evidence (Phase 6)

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` — exit 0, 185 passed, 0 failed (was 165 before the phase). Focused slice: `-only-testing:system-monitorTests/StatusItemControllerTests` — 4 cases, all passing on a real `NSStatusItem` created inside the test host |
| Runtime harness command/scenario and exact result | `xcodebuild ... -quiet build` — exit 0, zero errors, zero warnings. Manual smoke run: `open .../Build/Products/Debug/system-monitor.app`, `pgrep -x system-monitor` → alive after 4 s and again after ~12 s (0.6% then 0.1% CPU, 89 MB RSS, 21 s elapsed), then `pkill -x system-monitor` → terminated cleanly with no crash report. The app ran the real 1 Hz Mach sampling loop with the live status item and the environment-backed popover |
| Rollback boundary | Revert `system-monitor/Presentation/MenuBar/StatusItemView.swift`, `system-monitor/Presentation/MenuBar/StatusItemController.swift` and `system-monitor/App/AppDelegate.swift` to their M1 form, delete `system-monitorTests/Presentation/StatusItemControllerTests.swift` and the two appended suites in `StatusItemReadingsTests.swift`. Nothing in Domain, Application, Infrastructure or the panel changes |

## Deviations from Design

### Phases 1-3

1. **`.timeLimit(.minutes(1))` instead of `.timeLimit(.seconds(5))`** in `MetricsSamplerLoopTests`. Swift Testing rejects sub-minute time limits: `error: 'seconds' is unavailable: Time limit must be specified in minutes`. Per-test polling deadlines (200 ms / 1500 ms) keep every loop case under 0.35 s, so the intent of the task is preserved.
2. **Extra test file `system-monitorTests/Domain/CPUMetricsProviderPortTests.swift`** (additive). Tasks 1.5/1.6 name the ports and doubles but no test file, while cpu-metrics "Fake provider satisfies the port" is a scenario that needs assertions.
3. **`CPUTicks` and `CPUSnapshot` coverage lives in `CoreTopologyTests.swift`** as two extra suites. Task 1.4 creates all three model files in one GREEN step and 1.3 is its only paired RED task.
4. **`MetricHistory` has a custom `==`** comparing `capacity` and `ordered` rather than the synthesized memberwise one, so two histories showing the same values compare equal regardless of the internal write cursor.

### Phases 4-5

5. **`PercentFormatter.oneDecimal` builds its string from `.number` plus a literal `%`, not from `FormatStyle.percent`.** The design says "via FormatStyle `.percent`", but measured output for `de_DE` is `"40,2 %"` with a U+00A0 before the sign, while the cpu-card scenario "Locale decimal separator" requires exactly `"40,2%"`. The spec is the acceptance criterion, so the formatter scales the value, formats it with `.number.precision(.fractionLength(1)).grouping(.never).locale(locale)` and appends `%`. The locale decimal separator — the point of the scenario — is preserved.
6. **`IORegistryCoreTopologyProvider` walks `IOServiceMatching("AppleARMPE")` children instead of `IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus")`.** This follows the explicit apply instruction and the exploration's Q1 note. Verified on this host: the platform expert exposes `cpu0`…`cpu7`, `cpu10`…`cpu13` (names are not contiguous and are *not* the logical id) plus a `cpus` sibling that the `cpu` + digits name filter correctly excludes. `logical-cpu-id` is published as a `CFNumber` here, not the `OSData` the design assumed, so the reader accepts both shapes.
7. **Additive pure helpers so Strict TDD had a RED gate for view tasks**: `CoreTopologyResolver.level(forClusterType:)`, `SparklineGeometry` (in `Sparkline.swift`), `CoreBarGrid.rows(for:)`/`maxPerRow`, and `CPUCardModel` + `CPUCardRow`/`CPUCardGroup` (in `CPUCard.swift`). No design signature changed: `CoreTopologyResolver.resolve`, `SysctlReader`, `MachCPUProvider`, `IORegistryCoreTopologyProvider`, `PercentFormatter`, `Palette`, `Sparkline`, `HistoryGraph`, `RingGauge`, `CoreBar`, `CoreBarGrid`, `KeyValueRow`, `CPUCard` and `PanelView` all match the design verbatim. The design's file list is unchanged — every helper lives in a file the design already names.
8. **`Palette.cardCornerRadius`** added alongside the 7 colour tokens, so the "12 pt corner radius" requirement is one asserted constant shared by `CPUCard` and `PlaceholderCard` instead of a repeated literal.
9. **Additive test files** `CanvasComponentsTests.swift`, `CPUCardTests.swift`, `PanelViewTests.swift` (tasks 5.5, 5.8 and 5.9 name no test file but Strict TDD requires a failing test first), and a second `PaletteTests` suite inside the task-named `StatusItemReadingsTests.swift` for the cpu-card "Token values" scenario.
10. **Menu-bar-widget scenarios covered in Phase 5 are only "Accent from module" and "Equal data compares equal".** The readings builder, `StatusItemContent`, `StatusItemMetrics` and the controller scenarios stay in Phase 6 exactly as `tasks.md` schedules them.

### Phase 6

11. ~~**MEM renders no sparkline in M2.**~~ **SUPERSEDED** by the product correction below (2026-09-04): both modules now render a 40 pt sparkline. Kept for the audit trail. Original text: The menu-bar-widget "Width budget" scenario measures the widget with `"100%"` in both modules and requires less than 200 pt, and that budget cannot hold two 60 pt sparklines: the fixed content alone would be 2 × 60 pt sparkline + 50.4 pt labels ("CPU" 23.8, "MEM" 26.6 at 11 pt semibold) + 2 × 32 pt value frames = 234.4 pt before any spacing or padding. With one sparkline the same measurement is 197.0 pt. `StatusItemMetrics.sparklineModules` makes the decision structural (`[.cpu]`), never data-driven, so an empty CPU history at launch cannot change the layout. MEM keeps its accent-coloured label and its `"0%"` placeholder value in a full-width value frame, so M3 can turn it live without resizing the item.
12. **Widget spacing tightened from the M1 values.** `moduleSpacing` is 6 pt (was 8) and `horizontalPadding` is 2 pt (was 6); the intra-module `elementSpacing` stays at the design's 4 pt. Measured: 6 pt / 8 pt gives 207.0 pt — over budget — while the shipped 2 pt / 6 pt gives 197.0 pt, 3 pt under. All four numbers were measured with `NSHostingView.fittingSize` on the same layout.
13. **`contentFittingWidth` measures a throwaway default-sizing `NSHostingView` over `StatusItemMetrics.measurementReadings`**, not `hostingView.fittingSize.width` as the design's accessor list says. The live hosting view has `sizingOptions = []` and reports a zero fitting size, so the design accessor would have measured nothing. `tasks.md` 6.4 mandates this substitution. `statusItem.length` comes from the same private `measuredContentWidth()`, and a fourth controller test asserts `statusItemLength == contentFittingWidth`, which keeps the accessor honest instead of tautological.
14. **`ModuleReading` gained an `Identifiable` conformance** (`id: String { module.id }`) so `ForEach` binds without an explicit key path. The three stored properties are exactly the design's.
15. **Additive pure surface in `StatusItemView.swift`**: `StatusItemReadings` (the readings builder named by task 6.2) and `StatusItemMetrics.showsSparkline(_:)` / `sparklineModules` / `elementSpacing` / `moduleSpacing` / `horizontalPadding` / `labelFont` / `valueFont` / `sparklineHeight`. `sparklineWidth`, `valueWidth` and `measurementReadings` match the design verbatim. `valueWidth` is measured at runtime from `"100%"` with `NSFont.monospacedDigitSystemFont(ofSize: 11)` (32.0 pt here) rather than hardcoded.
16. **`AppDelegate` also implements `applicationWillTerminate`** to call `sampler.stop()`. The design only requires `start()`; stopping the detached loop on quit costs one line and makes the lifecycle symmetric.

## Correction: sparklines 40 pt on both modules (2026-09-04)

**Decision**: the user rescoped the widget — every module in `menuBarOrder` keeps a sparkline, each 40 pt wide, replacing the CPU-only 60 pt sparkline. The updated `openspec/changes/cpu-module/specs/menu-bar-widget/spec.md` adds the requirement "Every module renders a sparkline" with the scenario "MEM placeholder still has a sparkline", and keeps the sub-200 pt width budget. This supersedes Phase 6 deviation 11. Applied under Strict TDD in work unit `apply-correction-sparklines-40pt-both-modules`; `tasks.md` checkboxes are unchanged.

### TDD cycle

| Step | Evidence |
|---|---|
| Safety net | 185/185 before the correction |
| RED | `theSparklineKeepsItsFortyPointWidth` (expected 40, got 60) and the parameterized `everyModuleReservesItsSparklineArea` (MEM content measured ~63 pt against a 72 pt floor) both failed — exit 65, 2 failing cases |
| GREEN | 187/187, exit 0 |
| Triangulate | `everyModuleReservesItsSparklineArea` runs over `MetricModule.menuBarOrder`, so CPU and MEM are separate cases with an upper bound that also rejects a doubled sparkline; `theSparklineStillHoldsSixtySamples` pins the 60-sample capacity that the narrower frame must keep |
| Refactor | `sparklineModules` / `showsSparkline(_:)` deleted — with every module drawing a sparkline the set carried no information |

### Changes

| File | Change |
|---|---|
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | `sparklineWidth` 60 → 40 (single source of truth); `ModuleLabel` renders `Sparkline` unconditionally, so MEM shows an empty 40 pt area; `sparklineModules` and `showsSparkline(_:)` removed; `elementSpacing` 4 → 0, `moduleSpacing` 6 → 2, `horizontalPadding` 2 → 0 |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | `theSparklineKeepsItsSixtyPointWidth` → `theSparklineKeepsItsFortyPointWidth`; `onlyTheCPUModuleDrawsASparkline` → parameterized `everyModuleReservesItsSparklineArea` measuring rendered `StatusItemContent`; added `theSparklineStillHoldsSixtySamples`; `measurementReadings` now also asserted to carry a full sample set per module |
| `system-monitorTests/Presentation/StatusItemControllerTests.swift` | Unchanged — the width budget still asserts `< 200` |
| `system-monitor/Presentation/Components/Sparkline.swift` | Untouched. `SparklineGeometry` scales x by `width / (capacity - 1)`, so 60 samples across 40 pt needed no geometry change |

### Measured widths

Two 40 pt sparklines cost 20 pt more than the single 60 pt one, and the budget absorbed it only by spending the layout's spacing. All numbers are `NSHostingView.fittingSize.width` on the shipped layout:

| Layout (element / module / padding) | Width |
|---|---|
| 4 / 6 / 2 — spacing as shipped in Phase 6 | 221 pt |
| 3 / 4 / 2 | 215 pt |
| 2 / 2 / 0 | 205 pt |
| 1 / 1 / 0 | 200 pt — fails `< 200` |
| **0 / 2 / 0 — shipped** | **197 pt** |
| 0 / 0 / 0 — absolute floor | 195 pt |

Fixed content is 195 pt of the 200 pt budget: two 40 pt sparklines, `"CPU"` 23.8 pt and `"MEM"` 26.6 pt at 11 pt semibold, and two 32 pt `"100%"` frames. Only ~5 pt remains for all five gaps, so the widget spends it between the two modules and keeps none inside a module. The value frame is wider than every value except `"100%"`, so in normal operation there is still a visible gap between the sparkline and the digits; at exactly `100%` they touch.

### Verification

- `TEST` — exit 0, **187 passed, 0 failed** (185 before; +2 net: one case removed, three added)
- `xcodebuild ... -quiet build` — exit 0, zero errors, zero warnings
- Smoke run — `open .../Debug/system-monitor.app`, `pgrep -x system-monitor` → pid alive after 4 s (0.5% CPU, 92 MB RSS), `pkill -x system-monitor` → terminated cleanly
- Changed lines: ~70 authored (≈25 in `StatusItemView.swift`, ≈45 in `StatusItemReadingsTests.swift`), well under the 500-line ceiling

### Risk carried forward

~~The 200 pt budget is now saturated to within 3 pt and the layout has no spacing left to give.~~ **Resolved** by the next correction: the budget was raised to 230 pt and the spacing restored.

## Correction: width budget 230 pt, spacing restored (2026-09-04)

**Decision**: the user raised the widget width budget from 200 pt to 230 pt (PRD R1.7). `openspec/changes/cpu-module/specs/menu-bar-widget/spec.md` now requires "under 230 pt" in both the "Fixed-width, jitter-free layout" requirement and the "Every module renders a sparkline" scenario. This supersedes the zero-spacing layout of the previous correction, which only existed because two 40 pt sparklines left ~5 pt inside the old budget. Applied under Strict TDD in work unit `apply-correction-widget-budget-230pt-spacing`; `tasks.md` checkboxes unchanged.

### TDD cycle

| Step | Evidence |
|---|---|
| Safety net | 187/187 before the correction |
| RED | `theLayoutKeepsItsReadableSpacing` failed — the constants were 0 / 2 / 0 against the expected 4 / 6 / 2 — exit 65, 1 failing case. Raising the controller assertion to `< 230` on its own is not RED: 197 pt already satisfied it, which is exactly why the spacing needed its own pinned test |
| GREEN | 188/188, exit 0 |
| Triangulate | The new case asserts all three constants independently, and the controller's width case still measures the rendered widget, so a change to either the constants or the resulting geometry fails a test |
| Refactor | None needed |

### Changes

| File | Change |
|---|---|
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | `elementSpacing` 0 → 4, `moduleSpacing` 2 → 6, `horizontalPadding` 0 → 2; the constants' doc comment now cites the 230 pt budget and the 221 pt measurement |
| `system-monitorTests/Presentation/StatusItemControllerTests.swift` | `widthBudget` 200 → 230 |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Added `theLayoutKeepsItsReadableSpacing`, pinning `elementSpacing == 4`, `moduleSpacing == 6`, `horizontalPadding == 2` so a future width squeeze cannot silently collapse the gaps again |

### Measured width

**221.0 pt** (probed exactly: the budget assertion fails at `< 221`, passes at `< 222`), 9 pt under the new 230 pt budget. Composition: 195 pt of fixed content — two 40 pt sparklines, `"CPU"` 23.8 pt and `"MEM"` 26.6 pt at 11 pt semibold, two 32 pt `"100%"` frames — plus 26 pt of spacing (four 4 pt element gaps, one 6 pt module gap, two 2 pt insets). This is the same layout the widget had at the end of Phase 6, now with a sparkline in both modules instead of one.

### Verification

- `TEST` — exit 0, **188 passed, 0 failed** (187 before; +1 new case)
- `xcodebuild ... -quiet build` — exit 0, zero errors, zero warnings
- Smoke run — `open .../Debug/system-monitor.app`, `pgrep -x system-monitor` → pid alive after 4 s (0.5% CPU, 89 MB RSS), `pkill -x system-monitor` → terminated cleanly
- Changed lines: ~25 authored (≈8 in `StatusItemView.swift`, ≈16 in `StatusItemReadingsTests.swift`, 1 in `StatusItemControllerTests.swift`), far under the 200-line ceiling

### Headroom

9 pt remain under the 230 pt budget — roughly one more percentage-point digit or a slightly wider label, not a third module. A third module at the current layout would need about 110 pt more.

## Issues Found

1. **The app cannot render its popover until task 6.4 lands.** `PanelView` now requires `@Environment(MetricsState.self)`, but `StatusItemController.swift:41` still builds `NSHostingController(rootView: PanelView())` with no environment, which traps at render time. Task 6.4 adds `.environment(state)` to the popover and 6.5 composes the state in `AppDelegate`. This run was explicitly scoped away from those three files, so the intermediate state is expected; the app must not be launched manually between Phase 5 and Phase 6. Everything is verified by tests, and the full `TEST` plus `build` are both green.
2. **`#expect` cannot wrap a `rethrows` call directly.** `#expect(text.allSatisfy(\.isASCII))` fails to compile with `call can throw, but it is not marked with 'try'` because the macro expansion loses the rethrows inference. Assign the result to a local `Bool` first.
3. No degradation path was weakened to make hardware tests pass. The resolver's all-or-nothing rule and the provider's fallbacks are intact and independently unit tested; the `.integration` suite passed on the first run.
4. **Resolved in Phase 6**: issue 1 above. `StatusItemController` now injects the state into both the status item root view and the popover, and `AppDelegate` builds it. The app launches and runs.
5. **The unit-test host is the app itself.** Between tasks 6.2 and 6.4 the whole suite could not run at all — `Early unexpected exit, operation never finished bootstrapping ... test runner crashed before establishing connection` — because `applicationDidFinishLaunching` rendered an `@Environment(MetricsState.self)` view with no environment. The failure surfaces as a bootstrap crash, not as a test failure, so it reads as infrastructure breakage rather than RED. Any future change that makes a view launched by `AppDelegate` require a new environment value must land its composition-root wiring in the same batch.
6. **Width budget (RESOLVED by the two 2026-09-04 corrections).** Originally: 200 pt budget, 197.0 pt measured with a 60 pt CPU-only sparkline. Now: both modules render 40 pt sparklines, the budget is 230 pt (PRD R1.7), spacing is 4/6/2 and the widget measures 221.0 pt with 9 pt of headroom. M3 makes the MEM sparkline live with no layout change; a third module would need roughly 110 pt more.
7. **Each `StatusItemControllerTests` case creates a real `NSStatusItem`** in the test host and never removes it, so a run leaves four short-lived status items behind until the host exits. Creating them headlessly worked without any special entitlement or window server workaround; no case had to be skipped.

## Workload / PR Boundary

- Mode: single PR with accepted `size:exception`
- Phases 1-3: 1538 authored lines across 19 new files
- Phases 4-5: 2117 authored lines across 21 new files (13 production, 8 test) plus 43 replaced lines in `PanelView.swift`
- Phase 6: ~600 authored lines — 1 new test file (71), `StatusItemView.swift` rewritten (30 → 198), `StatusItemController.swift` reworked (85 → 134), `AppDelegate.swift` (10 → 33), `StatusItemReadingsTests.swift` extended (61 → 219)
- Cumulative: ~4300 changed lines, well past the 400-line budget, as the tasks forecast predicted (`400-line budget risk: High`, `Chained PRs recommended: No`)
- Boundary: the change now runs end to end — Mach ticks through the sampler and state into a live menu bar widget and CPU card. Phase 6 alone can be rolled back by reverting the three M1 files and deleting the two Phase 6 test additions

## Status

35/35 tasks complete (Phases 1-6) plus two product corrections — 40 pt sparklines on both modules, then a 230 pt width budget with normal spacing restored. 188 tests passing, widget measured at 221.0 pt. Ready for `sdd-verify`.
