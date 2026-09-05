# Exploration: memory-module (PRD M3 "Memory end to end" — F4, R4.1–R4.6, R5.1–R5.4, 6.2, 6.3, 7.1, 7.3, 4.3)

Engram mirror: topic `sdd/memory-module/explore` (observation 8216). Explored 2026-09-05.

## Current State

- M1+M2 shipped and archived (`openspec/changes/archive/2026-09-04-cpu-module/`); specs of record `openspec/specs/{cpu-metrics,core-topology,menu-bar-widget,cpu-card}/spec.md` (30 requirements, 61 scenarios); 188 tests green on Apple M4 Pro; zero build warnings under Swift 6 strict concurrency.
- Domain: `MetricModule` already declares `.memory` (label `"MEM"`, second in `menuBarOrder`) at `system-monitor/Domain/Models/MetricModule.swift:9,23`. `MetricHistory` (`Domain/Models/MetricHistory.swift`) is metric-agnostic (O(1) ring buffer, `ordered`, `suffix`). No memory model, port, or calculator exists.
- Application: `MetricsState` (`Application/MetricsState.swift`) holds only `cpu: CPUSnapshot?`, `cpuHistory`, `apply(cpu:)`. `MetricsSampler` (`Application/MetricsSampler.swift`) owns one `Task.detached(priority: .utility)` loop (line 86) driven by the CPU-specific value type `CPUSamplingStep` (line 5), a 100 ms `startupGap` then `interval`, `sampleOnce()` test seam (line 123), `stop()` cancels. Only Sendable values are captured; topology is read once inside the task.
- Infrastructure: `MachCPUProvider` (host_processor_info + `defer vm_deallocate`, cached `mach_host_self()`), `SysctlReader.integer(_:)` (generic sysctlbyname reader), `IORegistryCoreTopologyProvider`. No `Infrastructure/Mach/MachMemoryProvider.swift`.
- Presentation, MEM placeholder wiring: `StatusItemReadings.build(snapshot:history:)` returns `ModuleReading(module: .memory, samples: [], valueText: PercentFormatter.integer(0))` at `Presentation/MenuBar/StatusItemView.swift:43-48`. `ModuleLabel` already renders the 40 pt sparkline and the `"100%"`-sized value frame for MEM; `StatusItemMetrics.measurementReadings` already measures both modules at full scale (221 pt of the 230 pt budget, 9 pt headroom). Making MEM live changes no layout constant and no `StatusItemController` code.
- `Palette` (`Presentation/Theme/Palette.swift`) has `memAccent` (#F5A623) only; `memWired`, `memCompressed`, `memCached`, `memFree` are missing. `MetricModule.accent` (lines 49-56) maps `.memory -> Palette.memAccent` with a "placeholder until M3" comment.
- `PanelView` (`Presentation/Panel/PanelView.swift:19`) renders `CPUCard` then a private `PlaceholderCard(title: "Memory")`.
- Reusable as-is: `RingGauge`, `HistoryGraph`, `KeyValueRow`, `Sparkline`/`SparklineGeometry`, `PercentFormatter`. Card pattern to copy: pure `nonisolated enum CPUCardModel` (rows/gauge/groups derivations, locale-injectable) + thin `CPUCard` view with `.equatable()` Canvas children and reduce-motion gated animation.
- Tests touching MEM: `system-monitorTests/Presentation/StatusItemReadingsTests.swift:156-164` (`theMemoryModuleStaysAPlaceholder` asserts `samples.isEmpty` and `"0%"`; goes RED when MEM becomes live and must be replaced via a spec delta), `PaletteTests` (token values), `PanelViewTests` (height heuristics: `> 260` with the CPU card), `StatusItemControllerTests` (real `NSStatusItem`, width `< 230`). Fakes: `FakeCPUProvider` (`Synchronization.Mutex<Script>`, records `Thread.isMainThread`, `throwOnCall`), `FakeCoreTopologyProvider`, `TickFixtures`, `Tags.integration`.
- Build settings (project.pbxproj): SWIFT_VERSION 6.0, SWIFT_DEFAULT_ACTOR_ISOLATION MainActor, SWIFT_APPROACHABLE_CONCURRENCY YES, ENABLE_APP_SANDBOX YES (no .entitlements file, Xcode synthesizes), MACOSX_DEPLOYMENT_TARGET 26.5, 3 `PBXFileSystemSynchronizedRootGroup` entries (new files auto-join). `openspec/config.yaml` still says `swift_version: "5.0"`; the pbxproj says 6.0 (documentation nit).
- Reference `docs/reference/03-panel-memory.png` (read): header icon + "Memory"; orange ring gauge `69.0%` with sublabel `RAM`; rows `Used 5,52 GB`, `Total 8 GB`, `Wired 1,85 GB`, `Compressed 1,82 GB`; then a stacked horizontal bar; then legend dots `App, Wired, Compressed, Cached, Free`; the history graph is at the BOTTOM. PRD 4.3 agrees (graph bottom); the generic PRD 7.3 skeleton puts the graph before the card-specific footer (OQ4).

## Mach API facts (verified in MacOSX.sdk headers)

- `kern_return_t host_statistics64(host_t host_priv, host_flavor_t flavor, host_info64_t host_info64_out, mach_msg_type_number_t *host_info64_outCnt)` — `mach/mach_host.h:284-290`. Despite the parameter name, the routine lives in `mach_host.defs:244` (unprivileged `mach_host` subsystem), so the plain `mach_host_self()` port suffices — the same port class `MachCPUProvider` already uses successfully inside the sandbox.
- `HOST_VM_INFO64 = 4` (`mach/host_info.h:182`). `HOST_VM_INFO64_COUNT` is a `sizeof` macro (`host_info.h:205`) and is NOT imported into Swift; compute `mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)`.
- `struct vm_statistics64` (`mach/vm_statistics.h:142+`), typedef `vm_statistics64_data_t` (line 213). Fields needed, all `natural_t` (UInt32): `free_count` (143), `wire_count` (146), `purgeable_count` (156), `speculative_count` (163), `compressor_page_count` (170), `external_page_count` (172), `internal_page_count` (173). Header note at 157-162: "speculative pages are already accounted for in free_count".
- Call shape (caller-owned struct, no `vm_deallocate`): `var stats = vm_statistics64_data_t(); var count = <computed>; let status = withUnsafeMutablePointer(to: &stats) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) } }`. The `vm_deallocate` rule in `openspec/config.yaml` applies only to `host_processor_info` buffers.
- Page size hazard: `vm_kernel_page_size` is `extern vm_size_t` at `mach/vm_page_size.h:59` WITHOUT `__swift_nonisolated_unsafe`, whereas `mach_task_self_` carries it (`mach/mach_init.h:80`). Per SE-0412, imported C globals are implicitly `@preconcurrency`, so a reference emits the "reference to var ... is not concurrency-safe because it involves shared mutable state" diagnostic (a warning per the proposal text; reported as an error in several Swift 6 setups). Either way it breaks the project's zero-warning build. Concurrency-safe alternatives: the function `host_page_size(host_t, vm_size_t *)` (`mach/mach_init.h:78`), or `SysctlReader.integer("hw.pagesize")`. On macOS arm64 all three are 16384; on Intel 4096. Design must pick one; the first RED compile settles the exact severity.
- Total: `ProcessInfo.processInfo.physicalMemory` (UInt64, Foundation) — R4.1.
- Sandbox: PRD 6.3 says host_statistics64 works sandboxed; same host-port class as host_processor_info proven by the green `.integration` suite in the sandboxed test host. An `.integration` shape test (`total > 0`, `free_count > 0`, every component `<= total`) is the definitive proof.

## Activity Monitor alignment (evidence, not decided)

- Apple's Activity Monitor guide defines terms only (Memory Used "the amount of RAM being used", App Memory, Wired, Compressed, Cached Files) and gives no formulas.
- Open-source reproductions (zfdang/free-for-macOS `free.c`) use: App = `internal_page_count - purgeable_count`; Cached = `purgeable_count + external_page_count`; Free = `free_count - speculative_count`; Used = `max_mem - (free_count - speculative_count + purgeable_count + external_page_count) * page_size`, i.e. Activity Monitor's "Memory Used" behaves as Total - Free - Cached, not App + Wired + Compressed. Apple forum thread 702498 reports App + Wired + Compressed < Memory Used by about 0.5 GB on M1.
- Consequence for PRD R4.2 (`Used = App + Wired + Compressed`, `Free = free_count`): the MEM percent may miss the PRD section 2 success metric ("memory within 100 MB" of Activity Monitor) on Apple Silicon, and `App + Wired + Compressed + Cached + Free` will not sum to `Total` (speculative and unaccounted pages), so the stacked bar needs a remainder rule (OQ1, OQ3, new OQ7).

## Affected Areas

Modified (existing files):

- `system-monitor/Application/MetricsState.swift` — add `memory: MemorySnapshot?`, `memoryHistory: MetricHistory` (same `historyCapacity`), `apply(memory:)` appending `snapshot.fraction`.
- `system-monitor/Application/MetricsSampler.swift` — inject `memoryProvider: any MemoryMetricsProvider`; read memory in the same loop iteration as CPU (R5.1 single timer); publish via `await state.apply(memory:)`; `sampleOnce()` covers both; `CPUSamplingStep` unchanged.
- `system-monitor/App/AppDelegate.swift` — construct `MachMemoryProvider()` and pass it to the sampler.
- `system-monitor/Presentation/MenuBar/StatusItemView.swift` — `StatusItemReadings.build` gains memory inputs (snapshot + history); `.memory` case becomes `samples: memoryHistory.suffix(60)`, `valueText: PercentFormatter.integer(memory?.fraction ?? 0)`; `StatusItemView` passes `state.memory`/`state.memoryHistory`. `StatusItemMetrics` and `ModuleLabel` unchanged.
- `system-monitor/Presentation/Panel/PanelView.swift` — `MemoryCard(snapshot: state.memory, history: state.memoryHistory)` replaces `PlaceholderCard`; delete `PlaceholderCard`; update the two previews.
- `system-monitor/Presentation/Theme/Palette.swift` — add `memWired` #E5484D, `memCompressed` #F5D90A, `memCached` #4D8DFF, `memFree` #3DD68C; drop the placeholder comment on `.memory` accent. Note `memCached == cpuAccent` and `memFree` equals the v2 `gpuAccent` value: distinct tokens, equal `Color` values (token tests must not assert pairwise distinctness).
- Tests modified: `system-monitorTests/Presentation/StatusItemReadingsTests.swift` (replace `theMemoryModuleStaysAPlaceholder`; add MEM live value/sparkline tests; new palette token tests), `Presentation/PanelViewTests.swift` (memory card presence/live update), `Application/MetricsStateTests.swift`, `Application/MetricsSamplerTests.swift` (`makeSampler` helpers gain a memory fake; new memory scenarios), `Infrastructure/MachIntegrationTests.swift` (or a sibling suite) for memory shape.
- Spec delta: `openspec/specs/menu-bar-widget/spec.md` — MODIFIED "Data-driven module list" (MEM MAY keep placeholder -> MUST bind), MODIFIED "Every module renders a sparkline" scenario "MEM placeholder still has a sparkline", Purpose paragraph. No other main spec changes.

New files:

- `system-monitor/Domain/Models/MemorySnapshot.swift` — PRD 6.2 struct (`total, app, wired, compressed, cached, free: UInt64`, `used`, `fraction`), `nonisolated`, `Sendable`, `Equatable`; guard `total == 0` in `fraction`.
- `system-monitor/Domain/Models/MemoryPageCounts.swift` (or inside the port file) — raw counts value (`free, wired, purgeable, speculative, compressor, external, internal` as UInt64 or UInt32) plus `pageSize` and `totalBytes`.
- `system-monitor/Domain/Ports/MemoryMetricsProvider.swift` — `nonisolated protocol MemoryMetricsProvider: Sendable { func readCounts() throws -> MemoryPageCounts }` (Approach A) or `-> MemorySnapshot` (Approach B).
- `system-monitor/Domain/Services/MemoryUsageCalculator.swift` — pure R4.2/R4.3 math (Approach A).
- `system-monitor/Infrastructure/Mach/MachMemoryProvider.swift` — `host_statistics64` adapter, cached `mach_host_self()`, `ReadError.machCall(kern_return_t)` nested `nonisolated enum`.
- `system-monitor/Presentation/Formatting/ByteFormatter.swift` — `ByteCountFormatStyle(style: .memory, ..., locale:)`; input is `Int64` (`ByteCountFormatStyle.FormatInput`), so convert with `Int64(clamping:)`; macOS 12+ API.
- `system-monitor/Presentation/Components/StackedBar.swift` — `Canvas`, `Equatable`, takes ordered segments (fraction + color); pure geometry enum for unit tests.
- `system-monitor/Presentation/Components/SegmentLegend.swift` — dot + label rows in the R4.5 order.
- `system-monitor/Presentation/Panel/MemoryCard.swift` — `MemoryCardModel` (rows, gauge text, segments, legend, graph samples; locale-injectable) + `MemoryCard(snapshot: MemorySnapshot?, history: MetricHistory)`.
- Tests new: `system-monitorTests/Domain/{MemoryUsageCalculatorTests,MemorySnapshotTests}.swift`, `Infrastructure/MachMemoryIntegrationTests.swift` (`.integration`), `Presentation/{ByteFormatterTests,MemoryCardModelTests,StackedBarGeometryTests}.swift`, `Support/{FakeMemoryProvider,MemoryFixtures}.swift`.
- Specs new: `openspec/changes/memory-module/specs/{memory-metrics,memory-card}/spec.md`.

Unchanged: `MetricHistory`, `Sparkline`, `HistoryGraph`, `RingGauge`, `KeyValueRow`, `CPUCard`, `CoreBar*`, `StatusItemController`, all CPU Domain/Infrastructure, `project.pbxproj`.

## Approaches

| Approach | Pros | Cons | Effort |
|---|---|---|---|
| A. Port returns raw `MemoryPageCounts`; pure Domain `MemoryUsageCalculator` builds `MemorySnapshot` (mirrors CPU: raw ticks + calculator) | R4.2/R4.3 math unit-tested without hardware; fake stays trivial (scripted counts); adapter is a thin marshaller; OQ1/OQ3 formula choices become one-line Domain changes with tests | One more Domain type; PRD 6.4 literally says providers return snapshots | Low-Medium |
| B. Port returns `MemorySnapshot`; math in `MachMemoryProvider` | Fewer types; literal PRD 6.4 | Formula testable only through `.integration` on real hardware; fake must hand-build snapshots; formula changes touch Infrastructure | Low |
| C. Generalise the sampler (`MetricSource` protocol / generic step) before adding memory | Cleaner v2 GPU addition | Refactor of a verified loop for a second metric; higher review load | High |
| Loop: A1 add `memoryProvider` to the existing `Task.detached` iteration (one timer, R5.1) | Single cadence; memory read is one syscall (~microseconds) | Sampler init grows one parameter; tests' `makeSampler` helpers change | Low |
| Loop: A2 second detached loop for memory | Isolation of failures | Violates R5.1 (single sampler, one timer); two cadences to test | Medium |
| State: S1 separate `apply(memory:)` next to `apply(cpu:)` | Memory publishes on iteration 1 (no delta needed); CPU keeps second-sample rule; existing tests untouched | Two main-actor hops per tick (negligible at 1 Hz) | Low |
| State: S2 combined `apply(cpu:memory:)` | One observation transaction per tick | Forces memory to wait for CPU's second sample or to pass optionals; changes existing tests | Low-Medium |

## Recommendation

A + A1 + S1: raw-count port and pure Domain calculator (same shape the CPU module already proved), a single extended loop, and an independent `apply(memory:)` so the MEM widget and card show a real value on the very first iteration (memory is an absolute reading, no delta). Page size via a function call (`host_page_size` or `hw.pagesize` sysctl) rather than the `vm_kernel_page_size` global, unless the first compile proves the global is warning-free. Keep `MemoryCard` presentational with a `MemoryCardModel` enum exactly like `CPUCardModel`. Reuse `RingGauge` (`Palette.memAccent`, subtitle `"RAM"`), `KeyValueRow`, `HistoryGraph`; add only `StackedBar` and `SegmentLegend`.

## Conventions to inherit (MUST appear in proposal/design/tasks)

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

## Test plan sketch (strict TDD)

- Domain: `MemoryUsageCalculator` from scripted counts (page size 16384): App = internal - purgeable; Cached = external + purgeable; Used = App + Wired + Compressed; fraction = Used/Total; `total == 0` -> fraction 0 (no NaN); purgeable > internal clamps at 0 (wrapping guard); `MemorySnapshot.used`/`fraction` computed properties.
- Application: `apply(memory:)` stores snapshot and appends `fraction`; history bounded at 120; `sampleOnce()` publishes memory on the first call while CPU stays nil; throwing memory provider publishes nothing and keeps looping; CPU and memory read in the same iteration (call counts advance together); off-main read recorded by `FakeMemoryProvider`.
- Infrastructure `.integration`: `MachMemoryProvider().readCounts()` `total > 0`, `pageSize` in {4096, 16384}, `total == ProcessInfo.physicalMemory`, `free_count > 0`, each component `* pageSize <= total`, `App + Wired + Compressed <= total`.
- Presentation: `ByteFormatter` `"5.52 GB"` (en_US) / `"5,52 GB"` (de_DE) / `"8 GB"` for exactly 8 GiB; `MemoryCardModel.rows` == `[Used, Total, Wired, Compressed]`; gauge `"69.0%"`; segments in order App/Wired/Compressed/Cached/Free with fractions over Total and the chosen remainder rule; nil snapshot placeholder (`"0.0%"`, rows at 0 bytes, empty bar, empty graph); `StatusItemReadings` MEM value `"59%"` from fraction 0.59 and newest 60 samples; `Palette` four new tokens; `StackedBar` equality; `PanelView` height grows with the memory card.

## Open questions (surface only; the orchestrator owns the decisions)

1. Cached: exactly `external_page_count + purgeable_count` (PRD R4.2) or also fold `speculative_count` (header says speculative pages sit inside `free_count`; `free.c` reports Free = `free_count - speculative_count`, which shifts them out of Free without adding them to Cached).
2. Memory pressure indicator (Activity Monitor shows it; would come from `kern.memorystatus_vm_pressure_level`): out of PRD F4/R4 scope — confirm exclusion.
3. MEM sparkline/percent = Used/Total per R4.2, or an "excluding cached" variant; related: R4.2's Used differs from Activity Monitor's Memory Used (Total - Free - Cached) by up to ~0.5 GB on Apple Silicon, which threatens the "within 100 MB" success metric.
4. Card ordering: rows Used/Total/Wired/Compressed and legend App/Wired/Compressed/Cached/Free as in the reference; history graph at the bottom (PRD 4.3 and image) vs before the footer (PRD 7.3 skeleton).
5. Startup: CPU needs two samples 100 ms apart; memory is absolute, so publish on the first iteration (recommended) or align with CPU's second sample.
6. Page-size source: `host_page_size()` function vs `hw.pagesize` sysctl vs the `vm_kernel_page_size` global (diagnostic risk).
7. Stacked bar remainder: components will not sum to Total; clamp overflow / render Free as the remainder / leave a gap.

## Risks

- `vm_kernel_page_size` global triggers a Swift 6 shared-mutable-state diagnostic (warning or error) and breaks the zero-warning build; mitigated by `host_page_size`/sysctl.
- R4.2 arithmetic vs Activity Monitor on Apple Silicon (success metric within 100 MB) — product decision needed before spec.
- `HOST_VM_INFO64_COUNT` macro not imported; wrong count silently truncates fields (`CountInOut`) — assert `count >= index of internal_page_count` in the adapter and cover with the `.integration` test.
- `ByteCountFormatStyle` locale output may contain U+00A0/U+202F; brittle string tests (same class as the M2 `.percent` finding).
- `menu-bar-widget` spec amendment is a destructive delta on two requirements; archive must confirm the merge.
- 9 pt widget headroom is unaffected by M3 (no layout change) but any new label text in the bar is forbidden.
- Sandbox behaviour of `host_statistics64` is inferred from the same port class as `host_processor_info`; the `.integration` suite is the proof.

## Sources consulted

- zfdang/free-for-macOS `free.c`: https://raw.githubusercontent.com/zfdang/free-for-macOS/master/free.c
- Apple Activity Monitor memory guide: https://support.apple.com/guide/activity-monitor/view-memory-usage-actmntr1004/mac
- Apple Developer Forums thread 702498: https://developer.apple.com/forums/thread/702498
- SE-0412 strict concurrency for global variables: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md
- ByteCountFormatStyle docs: https://sosumi.ai/documentation/foundation/bytecountformatstyle

## Ready for Proposal

Yes, once OQ1, OQ3, OQ5 and OQ7 are answered (they define the Domain formula and the first-publish behaviour); OQ2, OQ4 and OQ6 can be settled in design. The MEM slot and 230 pt budget need no layout work; the whole change is one new port/adapter/calculator, one card with two new components, four palette tokens, and a small sampler/state extension, plus a `menu-bar-widget` spec delta.
