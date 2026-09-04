# Tasks: CPU Module (PRD M2 — CPU end to end)

Strict TDD: each RED task writes failing tests from the named spec scenarios; the paired GREEN task adds the minimal code and ends with a green `TEST` run.
`TEST` = `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests` (`build` instead of `test` for build checks). Tests are never `@MainActor`; nested types are explicitly `nonisolated`; never edit `project.pbxproj`.

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 2600–3400 (≈30 new files, 4 modified) |
| 400-line budget risk | High |
| Chained PRs recommended | No — user set `review_budget_lines: unlimited` |
| Suggested split | Single PR; units below are apply batches, not PRs |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 (Phase 1) | Domain models, ports, test doubles | PR 1 | `TEST` + `/MetricHistoryTests` | N/A — pure values | delete `Domain/Models`, `Domain/Ports`, `Tests/Support` |
| 2 (Phase 2) | Pure usage math | PR 1 | `TEST` + `/CPUUsageCalculatorTests` | N/A — pure | delete `Domain/Services` |
| 3 (Phase 3) | State + sampler loop | PR 1 | `TEST` + `/MetricsSamplerTests` | N/A — fakes + ContinuousClock | delete `Application/` |
| 4 (Phase 4) | Mach/sysctl/IORegistry adapters | PR 1 | `TEST` + `/MachIntegrationTests` | real host, `.integration` suite | delete `Infrastructure/` |
| 5 (Phase 5) | Palette, formatting, components, card | PR 1 | `TEST` + `/PercentFormatterTests` | Xcode `#Preview` | delete `Presentation/{Theme,Formatting,Components}`, revert `PanelView` |
| 6 (Phase 6) | Menu bar + composition root | PR 1 | `TEST` + `/StatusItemControllerTests` | manual app launch (6.6) | revert `StatusItemView`, `StatusItemController`, `AppDelegate` |

## Phase 1: Domain foundation

- [x] 1.1 RED `system-monitorTests/Domain/MetricHistoryTests.swift` — cpu-metrics "History ring buffer": drop-oldest, suffix, empty, capacity 1
- [x] 1.2 GREEN `system-monitor/Domain/Models/MetricHistory.swift` — O(1) ring buffer, `ordered`, `suffix`; run `TEST`
- [x] 1.3 RED `system-monitorTests/Domain/CoreTopologyTests.swift` — core-topology "Topology model and port": level lookup, out-of-range `.unknown`, `isSplit`, `unknown(coreCount:)`
- [x] 1.4 GREEN `system-monitor/Domain/Models/CoreTopology.swift`, `system-monitor/Domain/Models/CPUTicks.swift` (wrapping `delta(since:)`), `system-monitor/Domain/Models/CPUSnapshot.swift` — design signatures verbatim; run `TEST`
- [x] 1.5 Create ports `system-monitor/Domain/Ports/CPUMetricsProvider.swift`, `system-monitor/Domain/Ports/CoreTopologyProvider.swift`
- [x] 1.6 Create doubles `system-monitorTests/Support/FakeCPUProvider.swift` (`Mutex<Script>`, `callCount`, `readOnMainThread`, scripted throws), `system-monitorTests/Support/FakeCoreTopologyProvider.swift`, `system-monitorTests/Support/TickFixtures.swift`, `system-monitorTests/Support/Tags.swift` (`.integration`); covers cpu-metrics "Fake provider satisfies the port"; run `TEST`

## Phase 2: Pure usage math

- [x] 2.1 RED `system-monitorTests/Domain/CPUUsageCalculatorTests.swift` — cpu-metrics per-core deltas, nice→user, wrap-around, zero delta, summed aggregates, per-level means, nil preconditions; core-topology ordering P/E/unknown (E-first and P-first) and topology-size mismatch → all unknown
- [x] 2.2 GREEN `system-monitor/Domain/Services/CPUUsageCalculator.swift`; run `TEST`

## Phase 3: Application

- [x] 3.1 RED `system-monitorTests/Application/MetricsStateTests.swift` — `apply` sets `cpu` and appends `total`; history bounded at 120
- [x] 3.2 GREEN `system-monitor/Application/MetricsState.swift`; run `TEST`
- [x] 3.3 RED `system-monitorTests/Application/MetricsSamplerTests.swift` — cpu-metrics "publishes only from the second sample": one `sampleOnce()` publishes nothing, two publish one; scripted throw publishes nothing and keeps `previous`
- [x] 3.4 GREEN `system-monitor/Application/MetricsSampler.swift` — `CPUSamplingStep` + `sampleOnce()` with its own stored step; run `TEST`
- [x] 3.5 RED extend `system-monitorTests/Application/MetricsSamplerTests.swift` under `.timeLimit(.seconds(5))` — `start()` at 10 ms publishes within ~200 ms and keeps publishing, `stop()` freezes the count, `start()` idempotent, `readOnMainThread` all `false`. Use a fresh sampler per loop test; never mix `sampleOnce()` and loop state on one instance
- [x] 3.6 GREEN detached `.utility` loop in `system-monitor/Application/MetricsSampler.swift` — startup gap then interval, cancellation via `stop()`; run `TEST`

## Phase 4: Infrastructure

- [x] 4.1 RED `system-monitorTests/Infrastructure/CoreTopologyResolverTests.swift` — core-topology cluster mapping, consistent counts, P-count mismatch, total mismatch, one "M" poisons, duplicate/out-of-range IDs, nil expected counts
- [x] 4.2 GREEN `system-monitor/Infrastructure/System/CoreTopologyResolver.swift`; run `TEST`
- [x] 4.3 Create `system-monitor/Infrastructure/System/SysctlReader.swift` — `hw.logicalcpu`, `hw.nperflevels`, `hw.perflevelN.logicalcpu`
- [x] 4.4 Create `system-monitor/Infrastructure/Mach/MachCPUProvider.swift` — `host_processor_info`, `UInt32(bitPattern:)`, `defer vm_deallocate`
- [x] 4.5 Create `system-monitor/Infrastructure/System/IORegistryCoreTopologyProvider.swift` — degrade to all-`.unknown` on missing root/properties or `nperflevels != 2`
- [x] 4.6 Add `system-monitorTests/Infrastructure/MachIntegrationTests.swift` tagged `.integration` — core-topology "Real-hardware verification": count > 0 and == `hw.logicalcpu`, ticks non-decreasing, per-level counts == sysctl; run `TEST`

## Phase 5: Presentation primitives and card

- [x] 5.1 RED `system-monitorTests/Presentation/PercentFormatterTests.swift` — menu-bar-widget integer formatting; cpu-card one-decimal under `en_US` and `de_DE`
- [x] 5.2 GREEN `system-monitor/Presentation/Formatting/PercentFormatter.swift`; run `TEST`
- [x] 5.3 RED `system-monitorTests/Presentation/StatusItemReadingsTests.swift` — menu-bar-widget "Accent from module": `MetricModule` accent mapping
- [x] 5.4 GREEN `system-monitor/Presentation/Theme/Palette.swift` — 7.1 hex tokens plus the `MetricModule.accent` extension; run `TEST`
- [x] 5.5 Create `system-monitor/Presentation/Components/Sparkline.swift`, `system-monitor/Presentation/Components/HistoryGraph.swift`, `system-monitor/Presentation/Components/RingGauge.swift`, `system-monitor/Presentation/Components/CoreBar.swift`, `system-monitor/Presentation/Components/KeyValueRow.swift` — Equatable `Canvas`, right-aligned partial data, `#Preview`; run build
- [x] 5.6 RED `system-monitorTests/Presentation/CoreBarGridTests.swift` — cpu-card wrapping: 16 → 8+8, 12 → 8+4, 4 → one row
- [x] 5.7 GREEN `system-monitor/Presentation/Components/CoreBarGrid.swift` — static row-chunking helper, `maxPerRow = 8`; run `TEST`
- [x] 5.8 Create `system-monitor/Presentation/Panel/CPUCard.swift` — header, gauge, User/System rows, P/E rows only when non-nil, 120-sample graph, P-Cores/E-Cores groups or single "Cores", nil-snapshot placeholder; `cardBackground`, 12 pt corner radius, no border (carried from the existing `PlaceholderCard`); reduce-motion gate
- [x] 5.9 Modify (M1) `system-monitor/Presentation/Panel/PanelView.swift` — `@Environment(MetricsState.self)`, `CPUCard(snapshot:history:)` replaces the CPU placeholder, Palette tokens; run `TEST`

## Phase 6: Menu bar and composition root

- [x] 6.1 RED extend `system-monitorTests/Presentation/StatusItemReadingsTests.swift` — menu-bar-widget order `[.cpu, .memory]`, nil snapshot → `"0%"`, total 0.42 → `"42%"`, newest 60 of 120, empty history
- [x] 6.2 GREEN modify (M1) `system-monitor/Presentation/MenuBar/StatusItemView.swift` — `ModuleReading`, readings builder, `StatusItemContent`, container `StatusItemView`, `StatusItemRootView`, `StatusItemMetrics` (60 pt sparkline, measured `valueWidth`, `measurementReadings`); run `TEST`
- [x] 6.3 RED `system-monitorTests/Presentation/StatusItemControllerTests.swift` — one suite holding all three menu-bar-widget scenarios: length stable across 0% → 100%, `sizingOptions == []`, fitting width < 200 pt (each instance creates a real `NSStatusItem`)
- [x] 6.4 GREEN modify (M1) `system-monitor/Presentation/MenuBar/StatusItemController.swift` — `init(state:)`, `sizingOptions = []`, length measured once from `measurementReadings`, popover `.environment(state)`, test accessors. `contentFittingWidth` MUST measure with `sizeThatFits(in:)` or a separate default-sizing hosting view, never `hostingView.fittingSize.width` (with `sizingOptions = []` it can report 0); run `TEST`
- [x] 6.5 Modify (M1) `system-monitor/App/AppDelegate.swift` — compose state, providers, sampler, controller; `sampler.start()`; keep strong references
- [x] 6.6 Run the full `TEST` plus the build command, then launch the app manually and confirm a live percentage and sparkline within ~200 ms, stable status-item width, and a live CPU card with the panel open and closed
