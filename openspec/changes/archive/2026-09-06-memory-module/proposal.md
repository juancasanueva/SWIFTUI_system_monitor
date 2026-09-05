# Proposal: Memory Module (PRD M3, "Memory end to end")

Serves PRD feature F4 (Memory card) and R4.1-R4.6, R5.1-R5.4. Milestone M3. Exploration: `exploration.md` (Engram `sdd/memory-module/explore`, id 8216). Research: `research.md` rev 2 (Engram `sdd/memory-module/research`, id 8219). Product decisions confirmed in `state.yaml` (Engram 8218).

## Intent

After M2 the MEM slot in the menu bar shows a static `0%` with an empty sparkline and the panel renders `PlaceholderCard("Memory")`. Users get no memory signal. This change makes memory live end to end: a sandboxed `host_statistics64` adapter, pure Domain math that reproduces Activity Monitor's "Memory Used", a live MEM sparkline and percentage, and a Memory card (ring gauge, Used/Total/Wired/Compressed rows, stacked bar, legend, history graph). Success: the MEM value matches Activity Monitor within 100 MB on the dev machine (PRD 2) and the 188 existing tests stay green.

## Scope

### In Scope
- Domain: `MemoryPageCounts` (raw counts + page size + total), `MemoryMetricsProvider` port, pure `MemoryUsageCalculator`, `MemorySnapshot` (PRD 6.2, `used` stored or derived as Total - Free - Cached).
- Infrastructure: `MachMemoryProvider` (`host_statistics64(HOST_VM_INFO64)`, `host_page_size()`, `ProcessInfo.physicalMemory`).
- Application: `MetricsSampler` reads memory in the same loop iteration as CPU (R5.1); `MetricsState.apply(memory:)` + `memoryHistory` (capacity 120); memory publishes on the first iteration.
- Presentation: MEM widget slot bound to live state; `MemoryCard` + `MemoryCardModel`; new `StackedBar`, `SegmentLegend`, `ByteFormatter`; `Palette.memWired/memCompressed/memCached/memFree` (PRD 7.1).
- PRD amendment (implementation task): replace R4.2 with the text below; align 6.2 `MemorySnapshot.used`; note in R4.3 that the kernel page size is read via `host_page_size()`.
- Tests: Domain, Application, Presentation unit tests; one `.integration` shape suite; strict TDD.

### Out of Scope
- Memory pressure indicator (`kern.memorystatus_vm_pressure_level`), swap. GPU (PRD 11, v2). Settings, launch at login, light mode, asset-catalog palette (M4). Sampler generalisation (`MetricSource`). Any change to cpu-* specs, `StatusItemController`, layout constants or `project.pbxproj`.

## PRD R4.2 replacement text

> R4.2 Definitions, aligned with Activity Monitor (sources: Apple Activity Monitor guide S1, XNU `vm_statistics.h` S2, free-for-macOS `free.c` S3, Apple forum 702498 S4, XNU `kern_mib.c` S5):
> - App = `internal_page_count - purgeable_count`
> - Wired = `wire_count`
> - Compressed = `compressor_page_count`
> - Cached = `external_page_count + purgeable_count`
> - Free = `free_count - speculative_count` (speculative pages are counted inside `free_count`)
> - Used = Total - Free - Cached
> - Percentage = Used / Total
> - Note: Used includes memory not visible in App, Wired or Compressed (kernel-managed pages and boot-time carve-outs), so App + Wired + Compressed is less than Used by roughly 0.5 GB on Apple Silicon.

## Capabilities

### New Capabilities
- `memory-metrics`: `MemoryMetricsProvider` port returning raw counts, `MemoryUsageCalculator` (formula above, 64-bit saturating arithmetic, `total == 0` guard), `MemorySnapshot`, sampler/state extension, first-iteration publish.
- `memory-card`: card layout (header, ring gauge with `Palette.memAccent` and sublabel `RAM`, rows Used/Total/Wired/Compressed, stacked bar App/Wired/Compressed/Cached/Free summing to Total, legend, history graph at the bottom), `ByteCountFormatStyle(.memory)` formatting, nil-snapshot placeholder, reduce-motion.

### Modified Capabilities
- `menu-bar-widget`: "Data-driven module list" (MEM MAY keep placeholder -> MUST bind to `MetricsState.memory`/`memoryHistory`); "Every module renders a sparkline" scenario "MEM placeholder still has a sparkline" replaced by a live-MEM scenario; Purpose paragraph. Destructive delta on two requirements; archive must confirm the merge. No changes to `cpu-metrics`, `core-topology`, `cpu-card`.

## Approach

Exploration recommendation A + A1 + S1:
- **A (raw-count port + Domain calculator)** mirrors the proven CPU shape (`CPUTickSample` -> `CPUUsageCalculator`): the formula is unit-tested from scripted counts without hardware, the fake stays trivial, and the adapter is a thin marshaller.
- **A1 (single extended loop)** keeps R5.1's one sampler and one timer; memory is one syscall per tick.
- **S1 (separate `apply(memory:)`)** lets memory publish on iteration 1 (absolute reading) while CPU keeps its second-sample rule; existing tests untouched.
- Page size via `host_page_size()` (research C9/C12/C23), never the `vm_kernel_page_size`/`vm_page_size` globals (X3). Total from `ProcessInfo.physicalMemory` (R4.1); design records the `hw.memsize` vs `hw.memsize_usable` choice (G4) and the `.integration` test compares against Activity Monitor on the dev machine.
- Stacked bar: segments App, Wired, Compressed, Cached, Free sum to Total by construction; the "other used" remainder (Used - App - Wired - Compressed) is not a legend entry; design decides whether it is folded into App or drawn unlabeled.
- `MemoryCard` presentational with a `nonisolated enum MemoryCardModel` (locale-injectable), exactly like `CPUCardModel`; reuse `RingGauge`, `KeyValueRow`, `HistoryGraph`.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `Domain/Models/{MemorySnapshot,MemoryPageCounts}.swift` | New | Sendable value types |
| `Domain/Ports/MemoryMetricsProvider.swift` | New | Port protocol |
| `Domain/Services/MemoryUsageCalculator.swift` | New | Pure formula |
| `Infrastructure/Mach/MachMemoryProvider.swift` | New | `host_statistics64` adapter, `ReadError` |
| `Presentation/Formatting/ByteFormatter.swift` | New | `.memory` style, `Int64(clamping:)` |
| `Presentation/Components/{StackedBar,SegmentLegend}.swift` | New | Canvas bar (Equatable) + legend |
| `Presentation/Panel/MemoryCard.swift` | New | `MemoryCardModel` + view |
| `Application/{MetricsState,MetricsSampler}.swift` | Modified | `apply(memory:)`, `memoryProvider`, same-iteration read |
| `App/AppDelegate.swift` | Modified | Construct `MachMemoryProvider` |
| `Presentation/MenuBar/StatusItemView.swift` | Modified | `StatusItemReadings.build` binds MEM |
| `Presentation/Panel/PanelView.swift` | Modified | `MemoryCard` replaces `PlaceholderCard` (deleted) |
| `Presentation/Theme/Palette.swift` | Modified | Four tokens; drop placeholder comment |
| `PRD.md` | Modified | R4.2, R4.3 note, 6.2 `used` |
| `openspec/specs/menu-bar-widget/spec.md` | Modified | Delta above |
| `system-monitorTests/{Domain,Application,Infrastructure,Presentation,Support}/` | New/Modified | Tests, `FakeMemoryProvider`, `MemoryFixtures`; replace `theMemoryModuleStaysAPlaceholder` |

## Conventions to inherit (from exploration; spec/design/tasks MUST carry these)

1. Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`: every Domain type, port, Infrastructure adapter, formatter, test double and every NESTED type (`ReadError`, `Script`, fixtures) is explicitly `nonisolated` and `Sendable`; only `MetricsState`, `MetricsSampler`, views and `StatusItemController` are main-actor.
2. Tests are never `@MainActor`; they `await` main-actor members; helper factories may be `@MainActor` functions.
3. Sampling loop is `Task.detached(priority: .utility)`; a plain `Task {}` inherits MainActor. Only Sendable values cross; no `self` capture.
4. Fakes use `Synchronization.Mutex` (no `@unchecked Sendable`); record `Thread.isMainThread` for the off-main scenario; `throwOnCall` zero-based.
5. Swift Testing `.timeLimit` accepts minutes only (`.minutes(1)`); `.seconds` does not compile.
6. New Swift files auto-join targets via `PBXFileSystemSynchronizedRootGroup`; never edit `project.pbxproj`.
7. Widget budget 230 pt, measured 221 pt, 9 pt headroom; both sparklines 40 pt (`StatusItemMetrics.sparklineWidth`), 60 samples (`StatusItemReadings.sampleCount`); spacing 4/6/2 pinned by tests.
8. App Sandbox on; `host_statistics64` fills a caller-owned struct (no `vm_deallocate`); `vm_deallocate` applies only to `host_processor_info`.
9. `PercentFormatter.oneDecimal` uses `.number` + literal `%` because `.percent` inserts U+00A0 under `de_DE`; expect the same class of whitespace surprises from `ByteCountFormatStyle` (a non-breaking space between number and unit is possible per locale) and pin tests to exact strings under `en_US`/`de_DE` with Unicode-aware comparison.
10. Strict TDD: safety net, real RED, GREEN, triangulation; test command `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`.
11. Known debt carried from M2: wall-clock loop tests (W1/W5) should migrate to the already-injected `clock: any Clock<Duration>`; `StatusItemControllerTests` leak `NSStatusItem`s (W6). Memory tests should not add new wall-clock cases; prefer `sampleOnce()`.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `vm_kernel_page_size` global emits a Swift 6 shared-mutable-state diagnostic (X3) | High | Call `host_page_size(mach_host_self(), &size)`; never reference the global |
| `HOST_VM_INFO64_COUNT` macro not imported; wrong count truncates fields | Med | Compute `stride(vm_statistics64_data_t) / stride(integer_t)`; assert count covers `internal_page_count`; `.integration` test |
| `natural_t` 32-bit wraparound in `internal - purgeable`, `free - speculative` (R5) | Med | Widen to `UInt64` and saturate in the calculator; unit test purgeable > internal |
| `ByteCountFormatStyle` locale whitespace (U+00A0/U+202F) breaks string tests | Med | Fixed-locale tests, Unicode-aware comparison (convention 9) |
| Total source differs from Activity Monitor's Physical Memory by carve-out size (R1, G4) | Med | Design records `physicalMemory` vs `hw.memsize_usable`; manual comparison on dev machine |
| `host_statistics64` blocked by App Sandbox | Low | Same host-port class as `host_processor_info`; `.integration` shape test is the proof |
| Destructive `menu-bar-widget` delta merged incorrectly | Low | Archive rule: warn before merging destructive deltas |

## Rollback Plan

The change touches the sampling loop (`MetricsSampler`). Revert to the M2 baseline (commit `60cca91`, code at `a424487`): restore the six modified source files and `PRD.md`, delete the new Domain/Infrastructure/Presentation files and tests (`PBXFileSystemSynchronizedRootGroup` picks up removals; no `project.pbxproj` edit), and drop the unmerged `menu-bar-widget` delta. The MEM slot falls back to the `0%` placeholder and `PlaceholderCard`. No persisted state or settings exist.

## Dependencies

- `sdd-spec` and `sdd-design` follow from this proposal and may run in parallel.
- Convention `system-monitor/swift6-nonisolated-domain` (Engram); exploration and research artifacts above.
- macOS 12+ `ByteCountFormatStyle` (deployment target 26.5).

## Success Criteria

- [ ] All existing 188 tests still green; zero build warnings under Swift 6 strict concurrency.
- [ ] New Domain tests: formula from scripted counts (page size 16384), `total == 0` -> fraction 0, saturating guards; Application tests: `apply(memory:)`, history capped at 120, first-call publish with CPU still nil, throwing provider keeps the loop, off-main read, same-iteration call counts.
- [ ] `.integration` shape test: `total > 0`, `pageSize` in {4096, 16384}, `free_count > 0`, each component `<= total`.
- [ ] Presentation tests: `"5.52 GB"` (en_US) / `"5,52 GB"` (de_DE) / `"8 GB"`; rows, gauge `"69.0%"`, segments in R4.5 order summing to Total, nil placeholder, MEM widget value and newest 60 samples, four palette tokens.
- [ ] MEM value within 100 MB of Activity Monitor on the dev machine (Apple M4 Pro, 12 cores), verified manually.
- [ ] Widget fitting width still under 230 pt; no layout constant changed.
- [ ] PRD R4.2/6.2 amended as stated above; `menu-bar-widget` delta drafted.

## Open Questions

None blocking. Product decisions (Used formula, card layout with graph at the bottom, first-iteration publish) are confirmed. Design-owned: stacked-bar remainder rendering, Total source record, exact `ReadError` shape.
