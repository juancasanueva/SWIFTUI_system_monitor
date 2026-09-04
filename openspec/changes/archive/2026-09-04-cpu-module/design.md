# Design: CPU Module (PRD M2, "CPU end to end")

Proposal: `proposal.md` (Engram `sdd/cpu-module/proposal`, id 8199). Exploration: `exploration.md` (id 8196). Engram mirror of this file: `sdd/cpu-module/design`.

## Technical Approach

Hexagonal, four layers, one direction of dependency. Domain owns raw-tick models, ports and the pure `CPUUsageCalculator`. Application owns the single `MetricsSampler` (a `@MainActor` class that launches one `Task.detached` loop) and the `@MainActor @Observable MetricsState`. Infrastructure adapts Mach, sysctl and IORegistry behind the ports. Presentation is container/presentational: `StatusItemView` and `PanelView` read `MetricsState` from the environment and hand plain values (`[Double]`, `MetricHistory`, `CPUSnapshot?`) to Equatable `Canvas` components.

Every Domain type, port, Infrastructure adapter, formatter and test double is `nonisolated` + `Sendable` (convention `system-monitor/swift6-nonisolated-domain`). Only `MetricsState`, `MetricsSampler`, views and `StatusItemController` live on the main actor. Nothing non-Sendable crosses into the detached task; the compiler enforces it.

## Component Diagram

```
App/AppDelegate (composition root, @MainActor)
  ├─ MachCPUProvider ──────────┐            Infrastructure (nonisolated, Sendable)
  ├─ IORegistryCoreTopologyProvider(SysctlReader) ─┤
  ├─ MetricsState (@MainActor @Observable)
  ├─ MetricsSampler(state, providers, clock, interval) ──► Task.detached loop
  └─ StatusItemController(state)
        ├─ PassthroughHostingView<StatusItemRootView>  → StatusItemView (@Environment MetricsState)
        │       └─ StatusItemContent(readings) → ModuleLabel → Sparkline (40 pt) + value
        └─ NSPopover → PanelView.environment(state) → CPUCard(snapshot, history)
                 └─ RingGauge, KeyValueRow×4, HistoryGraph, CoreBarGrid → CoreBar

Ports (Domain): CPUMetricsProvider, CoreTopologyProvider
Pure math (Domain/Services): CPUUsageCalculator
```

## Interfaces / Contracts

All signatures are normative; tasks implement them verbatim.

### Domain (imports Foundation only)

```swift
nonisolated struct CPUTicks: Sendable, Hashable {
    let user: UInt32, system: UInt32, idle: UInt32, nice: UInt32
    var total: UInt64 { UInt64(user) + UInt64(system) + UInt64(idle) + UInt64(nice) }
    /// Wrapping subtraction (&-) per field; used by the calculator.
    func delta(since previous: CPUTicks) -> CPUTicks
}

nonisolated struct CPUTickSample: Sendable, Equatable {
    let cores: [CPUTicks]            // indexed by Mach processor index
    var coreCount: Int { cores.count }
}

nonisolated enum PerformanceLevel: Sendable, Hashable, CaseIterable { case performance, efficiency, unknown }

nonisolated struct CoreTopology: Sendable, Equatable {
    let levels: [PerformanceLevel]   // indexed by Mach processor index
    var coreCount: Int { levels.count }
    var isSplit: Bool                 // true when at least one core is .performance or .efficiency
    func level(of index: Int) -> PerformanceLevel   // .unknown when out of range
    static func unknown(coreCount: Int) -> CoreTopology
}

nonisolated struct CoreUsage: Sendable, Equatable, Identifiable {
    let index: Int; let usage: Double /* 0...1 */; let level: PerformanceLevel
    var id: Int { index }
}

nonisolated struct CPUSnapshot: Sendable, Equatable {
    let total: Double, user: Double, system: Double      // 0...1
    let performanceAverage: Double?                        // nil when no .performance cores
    let efficiencyAverage: Double?                         // nil when no .efficiency cores
    let cores: [CoreUsage]                                 // stable order: P, then E, then unknown; index order within a group
    var hasPerformanceLevels: Bool { performanceAverage != nil || efficiencyAverage != nil }
}

nonisolated struct MetricHistory: Sendable, Equatable {
    let capacity: Int                                      // precondition > 0
    init(capacity: Int)
    private(set) var count: Int
    var isEmpty: Bool
    var last: Double?
    mutating func append(_ value: Double)                  // O(1), drops oldest when full
    var ordered: [Double]                                  // oldest → newest
    func suffix(_ maxLength: Int) -> [Double]              // newest maxLength values, oldest → newest
}

nonisolated protocol CPUMetricsProvider: Sendable { func readTicks() throws -> CPUTickSample }
nonisolated protocol CoreTopologyProvider: Sendable { func topology() -> CoreTopology }

nonisolated enum CPUUsageCalculator {
    /// nil when previous is nil or core counts differ. Topology whose coreCount differs from the sample is treated as all-.unknown.
    static func snapshot(previous: CPUTickSample?, current: CPUTickSample, topology: CoreTopology) -> CPUSnapshot?
}
```

Calculator rules: per core `d = current.delta(since: previous)`; if `d.total == 0` usage is 0, else `usage = 1 - idle/total`. Aggregates use summed deltas across cores: `total = 1 - Σidle/Σtotal`, `user = (Σuser + Σnice)/Σtotal`, `system = Σsystem/Σtotal`, all 0 when `Σtotal == 0`. Level averages are the arithmetic mean of per-core `usage` per level, nil for an empty level.

### Application (`@MainActor`)

```swift
@MainActor @Observable final class MetricsState {
    private(set) var cpu: CPUSnapshot?
    private(set) var cpuHistory: MetricHistory
    init(historyCapacity: Int = 120)
    func apply(cpu snapshot: CPUSnapshot)      // sets cpu, appends snapshot.total
}

/// One sampling step; a pure value so it can be advanced inside the detached task or inline in tests.
nonisolated struct CPUSamplingStep: Sendable {
    let provider: any CPUMetricsProvider
    let topology: CoreTopology
    let previous: CPUTickSample?
    /// try? provider.readTicks(); on failure returns (nil, self) so previous survives; on success computes the snapshot.
    func advanced() -> (snapshot: CPUSnapshot?, next: CPUSamplingStep)
}

@MainActor final class MetricsSampler {
    init(state: MetricsState,
         cpuProvider: any CPUMetricsProvider,
         topologyProvider: any CoreTopologyProvider,
         interval: Duration = .seconds(1),
         startupGap: Duration = .milliseconds(100),
         clock: any Clock<Duration> = ContinuousClock())
    var isRunning: Bool
    func start()            // idempotent; launches the detached loop
    func stop()             // cancels the task; idempotent
    func sampleOnce()       // test seam: advances one step inline on the main actor and applies the snapshot
}
```

### Infrastructure (nonisolated, Sendable)

```swift
nonisolated struct MachCPUProvider: CPUMetricsProvider {
    nonisolated enum ReadError: Error, Equatable { case machCall(kern_return_t) }
    init()                                   // caches mach_host_self() once (host_t = UInt32, Sendable)
    func readTicks() throws -> CPUTickSample // host_processor_info(PROCESSOR_CPU_LOAD_INFO); ticks via UInt32(bitPattern:); defer vm_deallocate
}

nonisolated struct SysctlReader: Sendable {
    func integer(_ name: String) -> Int?     // sysctlbyname into an 8-byte buffer, interpreted by returned length; nil on error/absent
    var logicalCPUCount: Int?                // hw.logicalcpu
    var performanceLevelCount: Int?          // hw.nperflevels
    func logicalCPUCount(perfLevel: Int) -> Int?   // hw.perflevel{N}.logicalcpu
}

/// Pure, unit-testable resolution of IORegistry data plus sysctl counts into a topology.
nonisolated enum CoreTopologyResolver {
    nonisolated struct Entry: Sendable, Equatable { let logicalID: Int; let clusterType: String }  // "P", "E", "M", ...
    /// "P" → .performance, "E" → .efficiency, anything else → .unknown. The result is either fully resolved or fully unknown:
    /// returns all-.unknown(coreCount: expectedTotal) when any of: entries.count != expectedTotal, duplicate/out-of-range IDs,
    /// P count != expectedPerformance, E count != expectedEfficiency, an expected count is nil, or ANY entry resolves to .unknown
    /// (e.g. sysctl 8/4, expectedTotal 13, entries 8P + 4E + 1M → all unknown). expectedTotal is fed hw.logicalcpu by the provider;
    /// the Mach-count cross-check is enforced downstream by the calculator's core-count mismatch rule (topology size != sample size → all unknown).
    static func resolve(entries: [Entry], expectedPerformance: Int?, expectedEfficiency: Int?, expectedTotal: Int) -> CoreTopology
}

nonisolated struct IORegistryCoreTopologyProvider: CoreTopologyProvider {
    init(sysctl: SysctlReader = SysctlReader())
    func topology() -> CoreTopology
    // IOServiceMatching("AppleARMPE") → child iterator (kIOServicePlane) → per child named "cpu<digits>" (names not contiguous and not the logical id on M4 Pro; sibling "cpus" node excluded by the name filter):
    // cluster-type (OSData, first byte as ASCII) and logical-cpu-id (CFNumber on this host; OSData little-endian UInt32 also accepted). Missing root, missing
    // properties, or nperflevels != 2 → CoreTopology.unknown(coreCount: sysctl.logicalCPUCount ?? 0). Otherwise CoreTopologyResolver.resolve.
}
```

### Presentation

```swift
nonisolated enum Palette { static let panelBackground, cardBackground, textPrimary, textSecondary, cpuAccent, cpuEfficiency, memAccent: Color }  // PRD 7.1 hex
nonisolated extension MetricModule { var accent: Color }   // Presentation-layer mapping: .cpu → Palette.cpuAccent, .memory → Palette.memAccent (placeholder until M3); lives in Palette.swift
nonisolated enum PercentFormatter {
    static func integer(_ fraction: Double) -> String                         // clamps 0...1, rounds, locale-independent "26%"
    static func oneDecimal(_ fraction: Double, locale: Locale = .current) -> String  // "40.2%" via .number.precision(.fractionLength(1)) + literal "%" (FormatStyle.percent inserts U+00A0 before the sign in de_DE, violating the "40,2%" scenario)
}
nonisolated struct ModuleReading: Sendable, Equatable { let module: MetricModule; let samples: [Double]; let valueText: String }

@MainActor struct Sparkline: View, Equatable   { let samples: [Double]; let capacity: Int; let color: Color }   // filled area; x-scale fixed by capacity
@MainActor struct HistoryGraph: View, Equatable { let samples: [Double]; let capacity: Int; let color: Color }
@MainActor struct RingGauge: View, Equatable    { let fraction: Double; let color: Color; let valueText: String; let subtitle: String }
@MainActor struct CoreBar: View, Equatable      { let usage: Double; let color: Color; let label: String }
@MainActor struct CoreBarGrid: View             { let title: String; let cores: [CoreUsage]; let color: Color; static let maxPerRow = 8 }
@MainActor struct KeyValueRow: View             { let key: String; let value: String; var valueColor: Color = Palette.textPrimary }
@MainActor struct CPUCard: View                 { let snapshot: CPUSnapshot?; let history: MetricHistory }   // presentational, no environment; calls history.ordered
@MainActor struct StatusItemContent: View       { let readings: [ModuleReading] }                       // presentational
@MainActor struct StatusItemView: View          { @Environment(MetricsState.self) private var state }   // container → StatusItemContent
@MainActor struct StatusItemRootView: View      { let state: MetricsState; body: StatusItemView().environment(state) }
@MainActor enum StatusItemMetrics { static let sparklineWidth: CGFloat = 60; static let valueWidth: CGFloat /* measured from "100%" at 11 pt monospaced digits */; static let measurementReadings: [ModuleReading] /* 100%, full history */ }
```

## Concurrency Design

| Concern | Decision |
|---|---|
| Loop host | `MetricsSampler.start()` creates `Task.detached(priority: .utility)`. A plain `Task {}` would inherit MainActor under default isolation. The closure is `@Sendable`, so it is nonisolated. |
| Values crossing into the task | `any CPUMetricsProvider`, `any CoreTopologyProvider` (both `Sendable` protocols), `any Clock<Duration>` (`Clock: Sendable`), `Duration` ×2, and `MetricsState` (global-actor-isolated class, implicitly `Sendable`). No `self` capture. |
| Topology | Read once inside the task at loop start (`topologyProvider.topology()`), keeping IOKit off the main thread. |
| Loop shape | `var step = CPUSamplingStep(provider:topology:previous: nil); var gap = startupGap; while !Task.isCancelled { let (snap, next) = step.advanced(); step = next; if let snap { await state.apply(cpu: snap) }; do { try await clock.sleep(for: gap) } catch { break }; gap = interval }`. First iteration yields no snapshot; the second, ~100 ms later, publishes; then 1 Hz. |
| Errors | `advanced()` uses `try?`; a throwing read returns `(nil, self)` so the previous sample survives and the next success computes over the longer window. The loop never exits on provider errors. |
| Cancellation | `stop()` calls `task?.cancel()`; `clock.sleep` throws `CancellationError`, the loop breaks. `while !Task.isCancelled` also covers cancellation during `apply`. |
| Publishing | Only `CPUSnapshot` (Sendable value) hops to the main actor via `await state.apply(cpu:)`. `MetricsState` appends `total` to the 120-capacity ring buffer; `@Observable` drives view updates. |
| Deterministic tests | `sampleOnce()` keeps a `CPUSamplingStep?` stored on the sampler, advances it inline (main actor, synchronous fakes) and applies. Two calls publish exactly one snapshot; a scripted throw publishes nothing and keeps `previous`. |
| Clock | Existential `any Clock<Duration>` injected, default `ContinuousClock()`. Loop tests use `ContinuousClock` with `interval: .milliseconds(10)` and a bounded polling wait under `.timeLimit`; no custom test clock in M2. Where the spec mentions a "test clock", read it as this injected `ContinuousClock` with a short interval. |
| Nested types | Nested types do not inherit the outer declaration's isolation; under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` an un-annotated nested type becomes main-actor-isolated even inside a `nonisolated` outer type. Every nested type in Domain, Infrastructure and test support is declared `nonisolated` explicitly (`MachCPUProvider.ReadError`, `CoreTopologyResolver.Entry`, `FakeCPUProvider.ScriptedError`, `FakeCPUProvider.Script`, and any added later). |

## Composition Root and Status Item

`AppDelegate.applicationDidFinishLaunching`: build `MetricsState()`, `MachCPUProvider()`, `IORegistryCoreTopologyProvider()`, `MetricsSampler(state:cpuProvider:topologyProvider:)`, `StatusItemController(state:)`; call `sampler.start()`. Keep strong references to sampler and controller.

`StatusItemController(state:)`:
1. `hostingView = PassthroughHostingView(rootView: StatusItemRootView(state: state))`; `hostingView.sizingOptions = []` so 1 Hz content updates do not rewrite Auto Layout constraints.
2. `statusItem.length = NSHostingView(rootView: StatusItemContent(readings: StatusItemMetrics.measurementReadings)).fittingSize.width` computed once (max-value sample). Because every sub-width is constant (label intrinsic, 40 pt sparkline, `valueWidth` frame), the live view can never exceed it.
3. `popover.contentViewController = NSHostingController(rootView: PanelView().environment(state))`.
4. Test-visible accessors (`@MainActor`, read-only, `internal` so `@testable import` reaches them) for the three status-item scenarios: `var statusItemLength: CGFloat { statusItem.length }` (length stable across `state.apply` calls), `var hostingSizingOptions: NSHostingSizingOptions { hostingView.sizingOptions }` (equals `[]`), and `var contentFittingWidth: CGFloat` measured on a separate default-sizing `NSHostingView` over `StatusItemMetrics.measurementReadings` (the live hosting view has `sizingOptions = []` and reports a zero `fittingSize`); under 230 pt, R1.7, measured 221 pt. Tests `await` these from a nonisolated context.

## Rendering

- Widget `ModuleLabel`: `HStack(spacing: 4)`: label (11 pt semibold, `foregroundStyle(module.accent)`), `Sparkline(samples: history.suffix(60), capacity: 60, color: module.accent).frame(width: 40, height: 14).equatable()`, value `Text(...).font(.system(size: 11).monospacedDigit()).frame(width: StatusItemMetrics.valueWidth, alignment: .trailing)` in the system label color (`.primary`) so it stays legible on dark and light menu bars (menu-bar-widget spec "Legibility"). Label and sparkline use the module accent; the value uses the system label color. CPU reads live state; MEM keeps `samples: []`, `"0%"` (placeholder until M3) but still renders its 40 pt sparkline area; every module renders a sparkline. No animation in the bar.
- `Sparkline`/`HistoryGraph`: `Canvas` filled path from oldest (left) to newest (right); x step = width / (capacity - 1); right-aligned when fewer than `capacity` samples; fill `color.opacity(0.35)` plus 1 pt stroke. Wrap in `.equatable()` so identical arrays skip redraw.
- `CPUCard` (PRD 7.3): header icon `cpu` + "CPU"; `HStack`: `RingGauge(fraction: total, valueText: PercentFormatter.oneDecimal(total), subtitle: "CPU")` with 22 pt bold rounded value, and a `VStack` of `KeyValueRow`s: User, System, then P-Cores (`Palette.cpuAccent`) and E-Cores (`Palette.cpuEfficiency`) only when the respective average is non-nil; `HistoryGraph(samples: history, capacity: 120)` full width, ~48 pt tall; footer `CoreBarGrid`s.
- Footer: when `snapshot.hasPerformanceLevels`, two grids titled "P-Cores" (cores with `.performance`, accent) and "E-Cores" (`.efficiency`, efficiency color); otherwise one grid titled "Cores" with all cores in accent color (R3.6). `CoreBarGrid` chunks cores into rows of at most 8, each row an `HStack` where bars share width equally; 16 P-cores become two rows of 8, 12 unknown cores become 8 + 4. Each `CoreBar` is a vertical bar with `PercentFormatter.integer(usage)` below (9 pt).
- Nil snapshot (cpu-card spec "No-snapshot placeholder"): header, gauge at 0 with `0.0%`, rows User `0.0%` and System `0.0%` (no P/E rows), empty history graph, and no bar groups; no crash before the first publish.
- Panel animations (gauge only) gated by `accessibilityReduceMotion`.

## Architecture Decisions

| Decision | Choice | Rejected alternatives | Rationale |
|---|---|---|---|
| Core-level mapping | IORegistry `cluster-type` + sysctl cross-check, all-`.unknown` on mismatch | B: assume E-first from perflevel counts; C: load-correlation heuristic | B is wrong on M5-class chips and violates R3.4; C is slow and unreliable. A is definitive and degrades safely. |
| Status item host | `NSStatusItem` + `NSHostingView` (kept from M1) | `MenuBarExtra` | `MenuBarExtra` flattens custom labels and re-renders poorly at 1 Hz (R1.1). |
| Sparkline/graph rendering | `Canvas` + `Equatable` | Swift Charts | Charts is too heavy for 1 Hz menu bar redraws (PRD 6.5); Canvas gives exact 40 pt sizing. |
| Loop scheduling | `Task.detached` + `Clock.sleep` | `Timer` on the main run loop; `DispatchSourceTimer` | Timer runs Mach reads on the main thread (violates R5.3) and is not cancellable via structured concurrency. |
| Sampler shape | `@MainActor` class owning the task + pure `CPUSamplingStep` | `actor MetricsSampler`; loop as `@concurrent` function | Class keeps `start/stop` synchronous for AppKit; the pure step makes one iteration testable inline. |
| Clock injection | `any Clock<Duration>` | Generic `MetricsSampler<C: Clock>`; custom `TestClock` | Existential keeps the composition root and fakes simple; a manual clock is deferred until a test needs it. |
| Topology resolution | Pure `CoreTopologyResolver` separated from IOKit reads | Resolve inside the provider | Mismatch and "M" rules get unit tests without hardware. |
| Aggregate math | Sum of deltas; nice folded into user | Mean of per-core totals | Matches Activity Monitor and R3.1/R3.2; fixed decision. |
| Status item root | `StatusItemRootView` wrapper applying `.environment` | `AnyView` root; passing `state` as a stored property | Keeps a concrete generic for `PassthroughHostingView` and the environment injection convention. |
| Palette | Swift constants in `Palette.swift` | Asset catalog now | Light variants are F7 (P2, M4); constants unblock M2. |

## Data Flow

```
Mach ticks ──MachCPUProvider.readTicks()──► CPUTickSample ─┐
IORegistry+sysctl ──topology()──► CoreTopology ────────────┼─► CPUSamplingStep.advanced() ─► CPUSnapshot?
                                (detached task, 1 Hz)      ┘              │ await (main actor)
                                                     MetricsState.apply(cpu:) ─► cpu, cpuHistory(120)
                                                              │ @Observable
                      StatusItemView ◄────────────────────────┴──────────────► PanelView → CPUCard
                      suffix(60) + integer %                                   snapshot + MetricHistory (.ordered)
```

## File Changes

| File | Action | Description |
|---|---|---|
| `system-monitor/Domain/Models/CPUTicks.swift` | Create | `CPUTicks`, `CPUTickSample` |
| `system-monitor/Domain/Models/CoreTopology.swift` | Create | `PerformanceLevel`, `CoreTopology` |
| `system-monitor/Domain/Models/CPUSnapshot.swift` | Create | `CoreUsage`, `CPUSnapshot` |
| `system-monitor/Domain/Models/MetricHistory.swift` | Create | Ring buffer |
| `system-monitor/Domain/Ports/CPUMetricsProvider.swift`, `CoreTopologyProvider.swift` | Create | Ports |
| `system-monitor/Domain/Services/CPUUsageCalculator.swift` | Create | Pure delta math |
| `system-monitor/Application/MetricsState.swift`, `MetricsSampler.swift` | Create | State; sampler + `CPUSamplingStep` |
| `system-monitor/Infrastructure/Mach/MachCPUProvider.swift` | Create | `host_processor_info` adapter |
| `system-monitor/Infrastructure/System/SysctlReader.swift`, `CoreTopologyResolver.swift`, `IORegistryCoreTopologyProvider.swift` | Create | sysctl, pure resolver, IOKit adapter |
| `system-monitor/Presentation/Theme/Palette.swift`, `Presentation/Formatting/PercentFormatter.swift` | Create | Palette + `MetricModule.accent` extension, formatting |
| `system-monitor/Presentation/Components/{Sparkline,HistoryGraph,RingGauge,CoreBar,CoreBarGrid,KeyValueRow}.swift` | Create | Canvas components |
| `system-monitor/Presentation/Panel/CPUCard.swift` | Create | Card |
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | Modify | `StatusItemRootView`, container/content split, `ModuleReading`, `StatusItemMetrics` |
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | Modify | `init(state:)`, `sizingOptions = []`, measured length, environment on popover, test-visible accessors |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modify | `@Environment(MetricsState.self)`; `CPUCard(snapshot: state.cpu, history: state.cpuHistory)` replaces the CPU placeholder; use `Palette` |
| `system-monitor/App/AppDelegate.swift` | Modify | Composition root, `sampler.start()` |
| `system-monitorTests/Support/{FakeCPUProvider,FakeCoreTopologyProvider,TickFixtures,Tags}.swift` | Create | Doubles, fixtures, `.integration` tag |
| `system-monitorTests/Domain/{CPUUsageCalculatorTests,CoreTopologyTests,MetricHistoryTests}.swift` | Create | Domain unit |
| `system-monitorTests/Application/{MetricsSamplerTests,MetricsStateTests}.swift` | Create | Application unit |
| `system-monitorTests/Infrastructure/{CoreTopologyResolverTests,MachIntegrationTests}.swift` | Create | Pure resolver unit; `.integration` suite |
| `system-monitorTests/Presentation/{PercentFormatterTests,StatusItemReadingsTests}.swift` | Create | Formatting; readings mapping |

## Test Doubles

```swift
import Synchronization
nonisolated final class FakeCPUProvider: CPUMetricsProvider {   // Sendable: only `let` of Mutex<Script>
    nonisolated struct ScriptedError: Error, Equatable {}
    nonisolated private struct Script: Sendable {
        var samples: [CPUTickSample]; var cursor = 0; var throwOnCall: Set<Int>; var callCount = 0
        var readOnMainThread: [Bool] = []          // Thread.isMainThread recorded at each readTicks() call
    }
    private let script: Mutex<Script>
    init(samples: [CPUTickSample], throwOnCall: Set<Int> = [])
    func readTicks() throws -> CPUTickSample   // records Thread.isMainThread, increments callCount; throws on scripted indexes (0-based); repeats last sample when exhausted
    var callCount: Int
    var readOnMainThread: [Bool]               // "Off-main sampling" scenario: after start(), every recorded value is false
}
nonisolated struct FakeCoreTopologyProvider: CoreTopologyProvider { let result: CoreTopology; func topology() -> CoreTopology { result } }
```

`Mutex` (macOS 15+) gives `Sendable` without `@unchecked`. Fixtures: `TickFixtures.sample(coreCount:user:system:idle:nice:)`, E-first and P-first topologies, near-`UInt32.max` ticks for wrap tests. Tests are never `@MainActor`; they `await` `MetricsState`/`MetricsSampler` members.

## Testing Strategy

| Layer | What to Test | Approach |
|---|---|---|
| Domain unit | Calculator: nil on first sample / count mismatch; wrap-around; zero delta → 0; nice folded into user (asserted through the aggregate `user` on single-core samples, because `CoreUsage` only carries `usage`); summed-delta aggregates; P/E means; ordering P, E, unknown for E-first and P-first topologies; topology size mismatch → all unknown. `MetricHistory`: order, drop-oldest, `suffix`, capacity 1. `CoreTopology.isSplit`, out-of-range level. | Swift Testing, parameterized where variations repeat |
| Infrastructure unit | `CoreTopologyResolver`: P-first, E-first, any "M"/unknown entry → all unknown (8P + 4E + 1M with 8/4/13), duplicate IDs, count mismatches, nil expected counts | Pure, no IOKit |
| Application | `sampleOnce` ×2 publishes one snapshot; throw on call 1 keeps loop alive and `previous`; history bounded at 120; `start()` with 10 ms interval publishes within ~200 ms (startup gap) and continues; `stop()` halts growth; `start()` idempotent; off-main sampling: `FakeCPUProvider.readOnMainThread` is all `false` after `start()` | Fakes + `ContinuousClock` (10 ms interval, no custom test clock), `.timeLimit(.seconds(5))`, polling wait |
| Infrastructure `.integration` | `MachCPUProvider` core count > 0 and == `hw.logicalcpu`; ticks non-decreasing across two reads; `IORegistryCoreTopologyProvider` count == core count and per-level counts == sysctl on Apple Silicon | Single suite tagged `.integration`; runs in the sandboxed test host |
| Presentation | `PercentFormatter` under fixed locales; `ModuleReading` mapping from state (CPU live, MEM placeholder); `MetricModule.accent` mapping; `CoreBarGrid` chunking helper (16 → 8+8, 12 → 8+4); `StatusItemController` accessors: `statusItemLength` unchanged after applying 0% and 100% snapshots, `hostingSizingOptions == []`, `contentFittingWidth < 230` | Pure helpers and `@MainActor` accessors awaited from nonisolated tests; views covered by `#Preview` |

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No migration required. Rollback per proposal: revert the four modified files and delete the new folders.

## Open Questions

- [ ] `logical-cpu-id` == Mach processor index is assumed; the `.integration` topology test on real hardware is the validation. If it fails, the resolver's mismatch path keeps the app functional.
- [ ] `sizingOptions = []` plus a pinned hosting view: verify visually that the button height still matches the menu bar (fallback: keep `.intrinsicContentSize` only).
