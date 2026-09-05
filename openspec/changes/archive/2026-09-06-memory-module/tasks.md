# Tasks: Memory Module (PRD M3 — Memory end to end)

Strict TDD: each RED task writes failing tests for the named spec scenarios; the paired GREEN task adds the minimal code and ends with a green `TEST` run.
`TEST` = `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests` (`build` instead of `test` for build checks). `.integration` tests run inside the same command. Tests are never `@MainActor`; every new Domain/Infrastructure/formatting/model/nested type is explicitly `nonisolated` and `Sendable`; never edit `project.pbxproj`.
Traceability: 51 scenarios — memory-metrics MM-1..MM-10 (23), memory-card MC-1..MC-10 (20), menu-bar-widget delta MBW-1/7/8 (8).

## Review Workload Forecast

| Field | Value |
|-------|-------|
| Estimated changed lines | 1700–2300 (≈19 new files, 12 modified) |
| 400-line budget risk | High |
| Chained PRs recommended | No — `review_budget_lines: unlimited` |
| Suggested split | Single PR; units below are apply/commit batches, not PRs |
| Delivery strategy | single-pr |
| Chain strategy | size-exception |

Decision needed before apply: No
Chained PRs recommended: No
Chain strategy: size-exception
400-line budget risk: High

### Suggested Work Units (also the proposed work-unit commit boundaries)

| Unit | Goal | Likely PR | Focused test command | Runtime harness | Rollback boundary |
|---|---|---|---|---|---|
| 1 (Phase 1) | Memory domain values, port, saturating formula, fixtures | PR 1 | `TEST` + `/MemoryUsageCalculatorTests` | N/A — pure values | delete `Domain/{Models,Ports,Services}/Memory*`, `Tests/Support/Memory*` |
| 2 (Phase 2) | State + sampler same-iteration memory read | PR 1 | `TEST` + `/MetricsSamplerTests` | N/A — fakes + `sampleOnce()` | revert `MetricsState.swift`, `MetricsSampler.swift` |
| 3 (Phase 3) | `MachMemoryProvider` adapter | PR 1 | `TEST` + `/MachMemoryProviderTests` | real host, `.integration` suite | delete `Infrastructure/Mach/MachMemoryProvider.swift` |
| 4 (Phase 4) | Palette, byte formatting, bar/legend, card model | PR 1 | `TEST` + `/MemoryCardModelTests` | Xcode `#Preview` | delete `Presentation/{Formatting/ByteFormatter,Components/StackedBar,Components/SegmentLegend,Panel/MemoryCard}.swift`, revert `Palette.swift` |
| 5 (Phase 5) | Memory card in the panel | PR 1 | `TEST` + `/PanelViewTests` | open popover manually | revert `PanelView.swift`, restore `PlaceholderCard` |
| 6 (Phase 6) | Live MEM widget + composition root | PR 1 | `TEST` + `/StatusItemReadingsTests` | manual app launch (7.3) | revert `StatusItemView.swift`, `AppDelegate.swift` |
| 7 (Phase 7) | PRD amendment + verification | PR 1 | `TEST` (full) | manual Activity Monitor check | revert `PRD.md` |

## Phase 1: Domain foundation (MM-1, MM-2, MM-3)

- [x] 1.1 RED `system-monitorTests/Domain/MemorySnapshotTests.swift` — MM-3 "Fraction" (0.7711 ± 0.0001) and "Zero total" (exactly 0, no NaN); plus `fraction` clamped to 1 for a hand-built `used > total` and `Equatable`/memberwise init (design decision 1)
- [x] 1.2 GREEN `system-monitor/Domain/Models/MemoryPageCounts.swift`, `system-monitor/Domain/Models/MemorySnapshot.swift` (stored `used`, computed `fraction`, `unattributedUsed`), `system-monitor/Domain/Ports/MemoryMetricsProvider.swift` (port before any adapter) — design signatures verbatim; run `TEST`
- [x] 1.3 RED `system-monitorTests/Domain/MemoryUsageCalculatorTests.swift` + `system-monitorTests/Support/MemoryFixtures.swift` — MM-2 five scenarios via the design fixtures `reference`, `eightGiB`, `zero`, `purgeableExceedsInternal`, `speculativeExceedsFree`, `freePlusCachedExceedTotal`, `uint32MaxWired`, `overflowingCounts`; parameterize over the two full fixtures and assert every byte field, `used == total − free − cached`, `unattributedUsed`
- [x] 1.4 GREEN `system-monitor/Domain/Services/MemoryUsageCalculator.swift` — saturating `UInt64` formula, widen before multiply; run `TEST`
- [x] 1.5 RED `system-monitorTests/Domain/MemoryMetricsProviderPortTests.swift` + `system-monitorTests/Support/FakeMemoryProvider.swift` — MM-1 "Fake provider satisfies the port" (two scripted counts in order) and "Scripted failure" (`throwOnCall: [0]`, zero-based; second call returns); `Mutex<Script>`, `callCount`, `readOnMainThread`; run `TEST`

## Phase 2: Application (MM-4 – MM-8)

- [x] 2.1 RED extend `system-monitorTests/Application/MetricsStateTests.swift` — MM-4 "Apply stores and appends" (`memoryHistory.ordered == [0.5]`), "History bounded" (130 applies → 120), "CPU state untouched"
- [x] 2.2 GREEN modify `system-monitor/Application/MetricsState.swift` — `memory`, `memoryHistory` (capacity 120), `apply(memory:)`; run `TEST`
- [x] 2.3 RED extend `system-monitorTests/Application/MetricsSamplerTests.swift` — MM-5 (first `sampleOnce()` → `memory != nil`, `cpu == nil`; second → both), MM-6 "Call counts advance together" (3 steps → 3/3), MM-7 all three scenarios (memory throws on 0 and 1 then recovers; memory always throws; CPU `throwOnCall: [0]` still publishes memory with `cpuHistory.count == 0`); add `memoryProvider: FakeMemoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])` to both `makeSampler` helpers so no existing body changes. No new wall-clock tests
- [x] 2.4 GREEN modify `system-monitor/Application/MetricsSampler.swift` — `nonisolated struct MemorySamplingStep` with `read()` (`try?`), required `memoryProvider` init parameter (design decision 5), `sampleOnce()` reads memory inline and applies both; run `TEST`
- [x] 2.5 RED extend the existing `everyReadHappensOffTheMainThread` loop test only — MM-8: memory fake `readOnMainThread` all `false`, count ≥ 2 (never asserted against `sampleOnce()`)
- [x] 2.6 GREEN add the memory read to the detached `.utility` loop body in `system-monitor/Application/MetricsSampler.swift` — CPU read, memory read, then publish CPU then memory in one iteration; run `TEST`

## Phase 3: Infrastructure (MM-9)

- [x] 3.1 RED `system-monitorTests/Infrastructure/MachMemoryProviderTests.swift` — MM-9 "Truncated response rejected": `requiredFieldCount == offset(of: \.internal_page_count)/stride(integer_t) + 1` and ≤ the full struct count; `validate(returnedCount:)` accepts `requiredFieldCount` and the full count, throws `.truncatedStatistics(n)` for `requiredFieldCount − 1` and `0`. Plain unit suite, no Mach call, no `.integration` tag
- [x] 3.2 GREEN `system-monitor/Infrastructure/Mach/MachMemoryProvider.swift` — `host_statistics64(HOST_VM_INFO64)` into a caller-owned struct (no `vm_deallocate`), `host_page_size` and `ProcessInfo.physicalMemory` cached in `init`, `ReadError.{machCall,truncatedStatistics,invalidPageSize}`, widen the seven `natural_t` fields; never reference `vm_kernel_page_size`/`vm_page_size`; run `TEST`
- [x] 3.3 Add `system-monitorTests/Infrastructure/MachMemoryIntegrationTests.swift` tagged `.integration` — MM-9 "Sandboxed shape" (`total > 0`, `total == physicalMemory == UInt64(hw.memsize)`, `pageSize ∈ {4096, 16384}`, `freeCount > 0`, every component ≤ total, `app + wired + compressed ≤ used ≤ total`, `fraction ∈ 0...1`) and "Repeated reads" (two reads succeed and agree on `pageSize`/`totalBytes`); run `TEST`

## Phase 4: Presentation primitives (MC-2 – MC-9)

- [x] 4.1 RED extend `system-monitorTests/Presentation/StatusItemReadingsTests.swift` — MC-9 "Token values": `memAccent #F5A623`, `memWired #E5484D`, `memCompressed #F5D90A`, `memCached #4D8DFF`, `memFree #3DD68C`; never assert pairwise distinctness
- [x] 4.2 GREEN modify `system-monitor/Presentation/Theme/Palette.swift` — four tokens, `memAccent` doc "gauge, graph, App segment", drop the M3 placeholder comment in `MetricModule.accent`; run `TEST`
- [x] 4.3 RED `system-monitorTests/Presentation/ByteFormatterTests.swift` — MC-2 four scenarios: `"5.52 GB"` (en_US), `"5,52 GB"` (de_DE), `"8 GB"`, zero starts with `"0"` and `UInt64.max` does not trap; pin the exact ICU zero string and map U+00A0/U+202F to U+0020 before comparing (convention 9)
- [x] 4.4 GREEN `system-monitor/Presentation/Formatting/ByteFormatter.swift` — `ByteCountFormatStyle(style: .memory, allowedUnits: .all, spellsOutZero: false, includesActualByteCount: false, locale:)` over `Int64(clamping:)`; run `TEST`
- [x] 4.5 RED `system-monitorTests/Presentation/StackedBarGeometryTests.swift` — MC-5 geometry: cumulative left-to-right rects, cumulative x clamped at `size.width`, zero-fraction → zero-width rect, NaN → 0, degenerate size → `[]`
- [x] 4.6 GREEN `system-monitor/Presentation/Components/StackedBar.swift` (`StackedBarGeometry`, `Equatable` `Canvas` `StackedBar`, `nonisolated struct Segment`, empty track `textSecondary.opacity(0.18)`, Capsule clip) and `system-monitor/Presentation/Components/SegmentLegend.swift` (`LegendEntry`, 8 pt dot + 11 pt label) with `#Preview`; run `TEST`
- [x] 4.7 RED `system-monitorTests/Presentation/MemoryCardModelTests.swift` — MC-3 gauge `"69.0%"`/`"100.0%"`/`"69,0%"` (de_DE); MC-4 rows `[Used 5.52 GB, Total 8 GB, Wired 1.85 GB, Compressed 1.82 GB]` from `eightGiB`; MC-5 six segments `[.app, .unattributed, .wired, .compressed, .cached, .free]` on `reference` with bytes summing to total, fractions to 1 ± 1e-9, memAccent width == `(used − wired − compressed)/total`, remainder 0 when components exceed used, `[]` when nil; MC-6 legend `[App, Wired, Compressed, Cached, Free]` with the MC-5 colours, present when nil; MC-7 `sections == [.header, .gaugeAndRows, .stackedBar, .legend, .graph]`, `sections.last == .graph`, `Set(sections) == Set(allCases)`, graph samples for 120/3/0 values; MC-8 nil → `"0.0%"`, every row value starts with `"0"`, empty segments and samples
- [x] 4.8 GREEN the model half of `system-monitor/Presentation/Panel/MemoryCard.swift` — `MemoryCardRow`, `MemorySegmentKind`, `MemorySegment`, `MemoryCardSection`, `MemoryCardModel` (`sections`, `rows`, `gaugeText`, `gaugeFraction`, `segments`, `legend`, `color(for:)`, `graphSamples`); run `TEST`

## Phase 5: Memory card and panel (MC-1, MC-10)

- [x] 5.1 RED extend `system-monitorTests/Presentation/PanelViewTests.swift` — MC-1 "Panel grows with the memory card" (fitting height exceeds the CPU-only height, threshold pinned at the first GREEN; no placeholder titled "Memory") and "Live update while open" (`apply(memory:)` with fraction 0.69 → gauge text `"69.0%"`)
- [x] 5.2 GREEN the view half of `system-monitor/Presentation/Panel/MemoryCard.swift` — `ForEach(MemoryCardModel.sections)` switch rendering header (`memorychip` + "Memory"), `RingGauge(...).equatable()` with sublabel "RAM" + four `KeyValueRow`s, `StackedBar(...).equatable().frame(height: 8)`, `SegmentLegend`, `HistoryGraph(capacity: 120).frame(height: 48)`; MC-10 `cardBackground`, 12 pt radius, no border, `accessibilityReduceMotion` gate copied from `CPUCard`; `#Preview` for the `eightGiB` fixture and for nil
- [x] 5.3 GREEN modify `system-monitor/Presentation/Panel/PanelView.swift` — `MemoryCard(snapshot: state.memory, history: state.memoryHistory)` replaces the Memory placeholder, delete `PlaceholderCard`, live preview applies a memory snapshot, update the doc comment; run `TEST`

## Phase 6: Menu bar and composition root (MBW-1, MBW-7, MBW-8, MM-6)

- [x] 6.1 RED extend `system-monitorTests/Presentation/StatusItemReadingsTests.swift` — delete `theMemoryModuleStaysAPlaceholder`; add MBW-7 (fraction 0.59 → `"59%"`; newest 60 of 120 oldest-first; nil → `"0%"` with empty samples; MEM accent == `Palette.memAccent`), MBW-1 ("Order preserved" CPU then MEM; "Both modules follow state" `"42%"`/`"59%"`), MBW-8 ("MEM live sparkline" with 30 values; "MEM empty history still has a sparkline" plus total width at `"100%"` under 230 pt). Use `build(cpu:cpuHistory:memory:memoryHistory:)` and update the `reading` helper
- [x] 6.2 GREEN modify `system-monitor/Presentation/MenuBar/StatusItemView.swift` — `StatusItemReadings.build(cpu:cpuHistory:memory:memoryHistory:)` (design decision 9), MEM bound to `memory`/`memoryHistory` with `PercentFormatter.integer` and `suffix(sampleCount)`, `StatusItemView` passes four values, doc comments; no layout constant changes; run `TEST`
- [x] 6.3 Modify `system-monitor/App/AppDelegate.swift` — construct `MachMemoryProvider()` and inject it into `MetricsSampler` (MM-6 composition root); run `TEST` and the `build` command

## Phase 7: Documentation and verification (MM-10)

- [x] 7.1 Modify `PRD.md` — MM-10: R4.2 replacement text from the proposal, R4.3 note that the page size comes from `host_page_size()`, 6.2 `let used` = Total − Free − Cached with the carve-out note; no `Used = App + Wired + Compressed` or `Free = free_count` left
- [x] 7.2 Run the full `TEST` (all suites including `.integration`) and the `build` command; confirm zero warnings under Swift 6 strict concurrency and that the 188 pre-existing tests are still green
- [x] 7.3 [RESULT 2026-09-06: rebuilt app vs Activity Monitor — Used 17.32 GB vs 17.38 GB (Δ 60 MB, within 100 MB), Total 24 GB = 24.00 GB, Compressed 2.57 = 2.57, Wired 3.36 vs 3.47 (sampling offset), legend wraps by entry] Manual verification on the dev machine (Apple M4 Pro): card Total vs Activity Monitor "Physical Memory" and card Used vs "Memory Used" at the same moment, |Δ| ≤ 100 MB (apply the `hw.memsize_usable` fallback from design decision 3 if Totals match but Used does not); launch the app and confirm the live MEM percentage, sparkline and memory card; widget fitting width < 230 pt via `system-monitorTests/Presentation/StatusItemControllerTests.swift`
  - **Result (2026-09-06, user)**: Total matched Activity Monitor "Physical Memory". Wired, Compressed and App (= internal − purgeable) matched exactly. Used was **0.27–0.42 GB below** Activity Monitor's "Memory Used" across simultaneous screenshots, over the 100 MB target. A three-minute `vm_stat` window traced the gap to the handling of speculative and purgeable pages: Activity Monitor's own unattributed remainder (Used − App − Wired − Compressed) reached 0.95 GB, which the shipped formula could not produce. Because the Totals matched, the `hw.memsize_usable` fallback was **not** applied; the formula was corrected instead (Phase 8, design decision 14). The widget fitting width stays confirmed under 230 pt by `StatusItemControllerTests.theWidgetStaysUnderTheWidthBudgetAtFullScale`. A final visual re-check of the running app by the user is still outstanding and is tracked in the apply-progress open items, not as a task.

## Phase 8: Post-verify correction (user decision 2026-09-06)

Bounded correction after `sdd-verify`, work unit `apply-correction-used-formula-activity-monitor-match`. The card must show what Activity Monitor shows: only free and file-backed pages leave Used.

- [x] 8.1 RED update the expectations first — `system-monitorTests/Support/MemoryFixtures.swift` (`eightGiB.freeCount` 107_588 → 112_588 so the card keeps its reference numbers; doc comments for `reference`, `eightGiB`, `purgeableExceedsInternal`, `speculativeExceedsFree`, `freePlusCachedExceedTotal`), `MemoryUsageCalculatorTests.swift` (reference cached 983_040_000 / used 6_787_694_592 / unattributed 397_934_592 / fraction 0.7902; eightGiB cached 901_120_000 / free 1_762_721_792; new parameterized case pinning `cached == (external + speculative) × pageSize`, `used + cached + free == total` and `unattributedUsed >= purgeable × pageSize`; purgeable/speculative saturation cases re-derived), `MemoryCardModelTests.swift` (reference segment bytes), `MetricsSamplerTests.swift` and `MemoryMetricsProviderPortTests.swift` (reference `used`); run `TEST` → RED
- [x] 8.2 GREEN `system-monitor/Domain/Services/MemoryUsageCalculator.swift` — `cached = external + speculative` (saturating), `used` unchanged as `total ⊖ free ⊖ cached` which is now `Total − (free + external) × pageSize`, doc comment rewritten; align the two hand-built `#Preview` snapshots in `MemoryCard.swift` and `PanelView.swift`; run `TEST` → GREEN
- [x] 8.3 Legend wrapping defect (MC-6): `system-monitorTests/Presentation/SegmentLegendTests.swift` RED, then `system-monitor/Presentation/Components/SegmentLegend.swift` — single-line `fixedSize` labels inside `ViewThatFits`, one row while it fits and two rows otherwise, layout constants exposed as `nonisolated static let`; run `TEST` → GREEN
- [x] 8.4 Artifacts — `specs/memory-metrics/spec.md` MM-2, `specs/memory-card/spec.md` MC-5 remainder, `design.md` (revision 3: decisions 1, 2, 14, 15, calculator block, fixture table, testing strategy, rationale, open questions), `PRD.md` 5.4 R4.2 and 6.2, this file, `apply-progress.md` batch D, and the matching Engram topics
