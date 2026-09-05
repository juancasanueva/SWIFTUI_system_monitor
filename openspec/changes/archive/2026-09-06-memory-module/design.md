# Design: Memory Module (PRD M3, "Memory end to end")

Proposal: `proposal.md` (Engram `sdd/memory-module/proposal`, id 8220). Exploration: `exploration.md` (8216). Research: `research.md` rev 2 (8219). Engram mirror of this file: `sdd/memory-module/design`. Revision 2: amended after gate feedback (fixtures `reference`, `freePlusCachedExceedTotal`, `uint32MaxWired`; `MachMemoryProvider.validate(returnedCount:)` seam; `MemoryCardSection` order seam; MM-7 third scenario; citation and call-site nits). Revision 3 (2026-09-06, post-verify correction): `Cached = external + speculative` and `Used = Total − free × pageSize − external × pageSize` after the manual Activity Monitor check (decision 14 and the rationale below), plus the legend wrapping fix (decision 15). Specs `memory-metrics` (MM-*) and `memory-card` (MC-*) were written in parallel; scenario IDs below refer to them.

## Technical Approach

Same hexagonal shape the CPU module proved (`openspec/changes/archive/2026-09-04-cpu-module/design.md`), approach A + A1 + S1 from the proposal:

- Domain owns `MemoryPageCounts` (raw Mach counters widened to `UInt64`), the `MemoryMetricsProvider` port, the pure `MemoryUsageCalculator` and the `MemorySnapshot` value. The Activity Monitor formula lives in exactly one place (the calculator) and is unit-tested from scripted counts.
- Infrastructure adds one thin adapter, `MachMemoryProvider`, that marshals `host_statistics64(HOST_VM_INFO64)` into `MemoryPageCounts`; no arithmetic beyond widening.
- Application extends the existing single `Task.detached(priority: .utility)` loop: one iteration reads CPU then memory, publishes CPU (when a delta exists) then memory (always) through two independent `apply` calls. Memory publishes on iteration 1.
- Presentation follows the `CPUCardModel`/`CPUCard` split: a `nonisolated enum MemoryCardModel` derives every rendered value, including the section order; `MemoryCard` is a thin layout reusing `RingGauge`, `KeyValueRow`, `HistoryGraph` and adding `StackedBar` + `SegmentLegend`. The MEM widget slot binds to `MetricsState.memory`/`memoryHistory` with no layout-constant change.

Isolation rule (convention 1): every type below in Domain, Infrastructure, `Presentation/Formatting`, pure model enums and test support is explicitly `nonisolated` and `Sendable`, including nested types. Only `MetricsState`, `MetricsSampler`, views and `StatusItemController` are main-actor.

## Component Diagram

```
App/AppDelegate (composition root, @MainActor)
  ├─ MachCPUProvider, IORegistryCoreTopologyProvider            Infrastructure (nonisolated, Sendable)
  ├─ MachMemoryProvider  ← NEW (host_statistics64 + host_page_size + physicalMemory)
  ├─ MetricsState (@MainActor @Observable)  + memory, memoryHistory, apply(memory:)
  ├─ MetricsSampler(state, cpuProvider, memoryProvider, topologyProvider, …) ──► one Task.detached loop
  └─ StatusItemController(state)
        ├─ StatusItemView → StatusItemReadings.build(cpu:cpuHistory:memory:memoryHistory:) → ModuleLabel ×2
        └─ NSPopover → PanelView → CPUCard, MemoryCard(snapshot, history)  ← replaces PlaceholderCard
                                        └─ RingGauge, KeyValueRow×4, StackedBar, SegmentLegend, HistoryGraph

Port (Domain): MemoryMetricsProvider      Pure math (Domain/Services): MemoryUsageCalculator
```

## Interfaces / Contracts

All signatures are normative; tasks implement them verbatim.

### Domain (imports Foundation only) — port defined before any adapter

```swift
/// Raw vm_statistics64 counters (pages) plus the two facts needed to turn them into bytes.
/// Field names mirror the Mach struct; values are natural_t (UInt32) widened at the adapter so
/// every subtraction in the calculator happens in 64 bits (research R5).
nonisolated struct MemoryPageCounts: Sendable, Equatable {
    let freeCount: UInt64            // includes speculative pages (vm_statistics.h:157-162)
    let wireCount: UInt64
    let purgeableCount: UInt64
    let speculativeCount: UInt64
    let compressorPageCount: UInt64
    let externalPageCount: UInt64
    let internalPageCount: UInt64
    let pageSize: UInt64             // bytes per page, from host_page_size()
    let totalBytes: UInt64           // physical memory, from ProcessInfo.physicalMemory
}

nonisolated protocol MemoryMetricsProvider: Sendable {
    func readCounts() throws -> MemoryPageCounts
}

/// PRD 6.2 (amended): `used` is STORED, not derived from app + wired + compressed.
nonisolated struct MemorySnapshot: Sendable, Equatable {
    let total: UInt64
    let app: UInt64, wired: UInt64, compressed: UInt64, cached: UInt64, free: UInt64
    let used: UInt64                                   // Total - Free - Cached (saturating), set by the calculator
                                                       // = Total - (free + external) * pageSize; purgeable pages are inside it
    var fraction: Double                               // total == 0 ? 0 : min(Double(used) / Double(total), 1)
    var unattributedUsed: UInt64                       // used - min(used, app + wired + compressed) (saturating)
}

nonisolated enum MemoryUsageCalculator {
    /// Activity Monitor formula (corrected 2026-09-06 by the manual check, revision 3):
    /// App = internal - purgeable; Wired = wire; Compressed = compressor;
    /// Cached = external + speculative; Free = free - speculative;
    /// Used = Total - free * pageSize - external * pageSize, i.e. Total - Free - Cached, since Free
    /// and Cached share the speculative pages. Purgeable pages leave App but stay inside Used.
    /// Every subtraction saturates at 0, every addition/multiplication saturates at UInt64.max.
    static func snapshot(from counts: MemoryPageCounts) -> MemorySnapshot
}
```

### Application (`@MainActor` classes, `nonisolated` step)

```swift
@MainActor @Observable final class MetricsState {
    private(set) var cpu: CPUSnapshot?;        private(set) var cpuHistory: MetricHistory      // unchanged
    private(set) var memory: MemorySnapshot?;  private(set) var memoryHistory: MetricHistory   // NEW, same historyCapacity (120)
    init(historyCapacity: Int = 120)
    func apply(cpu snapshot: CPUSnapshot)      // unchanged
    func apply(memory snapshot: MemorySnapshot) // sets memory, appends snapshot.fraction
}

/// Stateless counterpart of CPUSamplingStep: memory is an absolute reading, so there is no `previous`.
nonisolated struct MemorySamplingStep: Sendable {
    let provider: any MemoryMetricsProvider
    /// try? provider.readCounts() → MemoryUsageCalculator.snapshot; nil on a throwing read.
    func read() -> MemorySnapshot?
}

@MainActor final class MetricsSampler {
    init(state: MetricsState,
         cpuProvider: any CPUMetricsProvider,
         memoryProvider: any MemoryMetricsProvider,      // NEW, required, no default
         topologyProvider: any CoreTopologyProvider,
         interval: Duration = .seconds(1),
         startupGap: Duration = .milliseconds(100),
         clock: any Clock<Duration> = ContinuousClock())
    func start(); func stop(); var isRunning: Bool     // unchanged contracts
    func sampleOnce()                                   // advances the CPU step AND reads memory inline, applies both
}
```

Loop body per iteration (detached task): `let (cpuSnapshot, next) = step.advanced(); step = next; let memorySnapshot = memoryStep.read(); if let cpuSnapshot { await state.apply(cpu:) }; if let memorySnapshot { await state.apply(memory:) }; sleep(gap); gap = interval`. Both reads happen off-main before either publish, so the two readings belong to the same tick. A memory throw yields `nil`, publishes nothing and never touches the CPU step or the loop; a CPU throw yields `(nil, self)` and never prevents the memory publish (MM-7).

### Infrastructure (nonisolated, Sendable; imports Darwin + Foundation)

```swift
nonisolated struct MachMemoryProvider: MemoryMetricsProvider {
    nonisolated enum ReadError: Error, Equatable {
        case machCall(kern_return_t)                     // host_statistics64 != KERN_SUCCESS
        case truncatedStatistics(mach_msg_type_number_t) // returned count does not cover internal_page_count
        case invalidPageSize                             // host_page_size failed or returned 0 at init
    }
    /// Smallest `integer_t` count that still covers `internal_page_count` (MM-9 seam, unit-testable without Mach):
    /// MemoryLayout<vm_statistics64_data_t>.offset(of: \.internal_page_count)! / MemoryLayout<integer_t>.stride + 1
    nonisolated static let requiredFieldCount: mach_msg_type_number_t
    /// Throws `.truncatedStatistics(returnedCount)` when `returnedCount < requiredFieldCount`; called from `readCounts()`.
    nonisolated static func validate(returnedCount: mach_msg_type_number_t) throws(ReadError)
    private let host: host_t          // mach_host_self() once (UInt32, Sendable)
    private let pageSize: UInt64      // host_page_size(host, &size) once at init; 0 when the call failed
    private let totalBytes: UInt64    // ProcessInfo.processInfo.physicalMemory once at init
    init()
    func readCounts() throws -> MemoryPageCounts
}
```

Call shape: `var stats = vm_statistics64_data_t(); var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride); let status = withUnsafeMutablePointer(to: &stats) { $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, host_flavor_t(HOST_VM_INFO64), $0, &count) } }`. Then `guard pageSize > 0 else { throw ReadError.invalidPageSize }`, `guard status == KERN_SUCCESS else { throw ReadError.machCall(status) }`, `try Self.validate(returnedCount: count)`, then widen the seven `natural_t` fields with `UInt64(_:)`. Caller-owned struct, no `vm_deallocate` (convention 8). Never reference `vm_kernel_page_size`/`vm_page_size` (research X3).

### Presentation

```swift
nonisolated enum Palette { /* existing */ static let memWired = sRGB(0xE5484D), memCompressed = sRGB(0xF5D90A),
                                           memCached = sRGB(0x4D8DFF), memFree = sRGB(0x3DD68C) }
// memCached == cpuAccent and memFree == the v2 gpuAccent value: distinct tokens, equal Colors. Tests assert values, never pairwise distinctness.

nonisolated enum ByteFormatter {
    /// ByteCountFormatStyle(style: .memory, allowedUnits: .all, spellsOutZero: false, includesActualByteCount: false, locale:)
    /// applied to Int64(clamping: bytes). 5_926_092_800 → "5.52 GB" (en_US) / "5,52 GB" (de_DE); 8_589_934_592 → "8 GB".
    static func memory(_ bytes: UInt64, locale: Locale = .current) -> String
}

nonisolated struct MemoryCardRow: Sendable, Equatable, Identifiable { let key: String; let value: String; var id: String { key } }
nonisolated enum MemorySegmentKind: Sendable, Hashable, CaseIterable { case app, unattributed, wired, compressed, cached, free }
nonisolated struct MemorySegment: Sendable, Equatable, Identifiable {
    let kind: MemorySegmentKind; let bytes: UInt64; let fraction: Double; let color: Color; var id: MemorySegmentKind { kind }
}
nonisolated struct LegendEntry: Sendable, Equatable, Identifiable { let label: String; let color: Color; var id: String { label } }
/// Vertical order of the card (MC-7 seam): the view derives its VStack from `MemoryCardModel.sections`.
nonisolated enum MemoryCardSection: Sendable, Equatable, CaseIterable { case header, gaugeAndRows, stackedBar, legend, graph }

nonisolated enum MemoryCardModel {
    static let graphCapacity = 120
    static let sections: [MemoryCardSection] = [.header, .gaugeAndRows, .stackedBar, .legend, .graph]   // graph last (confirmed)
    static func rows(for snapshot: MemorySnapshot?, locale: Locale = .current) -> [MemoryCardRow]   // Used, Total, Wired, Compressed; numeric zero when nil
    static func gaugeText(for snapshot: MemorySnapshot?, locale: Locale = .current) -> String       // PercentFormatter.oneDecimal(fraction), "0.0%" when nil
    static func gaugeFraction(for snapshot: MemorySnapshot?) -> Double
    /// [] when nil or total == 0; otherwise six segments in order app, unattributed, wired, compressed, cached, free.
    /// bytes sum to total by construction; fraction = Double(bytes) / Double(total).
    static func segments(for snapshot: MemorySnapshot?) -> [MemorySegment]
    static let legend: [LegendEntry]                                    // App, Wired, Compressed, Cached, Free (no entry for .unattributed)
    static func color(for kind: MemorySegmentKind) -> Color             // app/unattributed → memAccent, wired → memWired, …
    static func graphSamples(for history: MetricHistory) -> [Double]    // history.suffix(graphCapacity)
}

/// Pure geometry so the bar is unit-tested without rendering.
nonisolated enum StackedBarGeometry {
    /// Left-to-right rects; cumulative x clamped to size.width; zero-fraction segments yield zero-width rects; NaN → 0.
    static func rects(fractions: [Double], in size: CGSize) -> [CGRect]
}
@MainActor struct StackedBar: View, Equatable {
    nonisolated struct Segment: Sendable, Equatable { let fraction: Double; let color: Color }
    let segments: [Segment]         // Canvas; track in Palette.textSecondary.opacity(0.18) when empty; clipped to a Capsule; height set by the caller (8 pt)
}
@MainActor struct SegmentLegend: View { let entries: [LegendEntry] }   // rows of 8 pt dot + 11 pt single-line label in textSecondary,
// entrySpacing 10 / rowSpacing 6 as nonisolated static constants; ViewThatFits picks one row, else two (decision 15)
@MainActor struct MemoryCard: View { let snapshot: MemorySnapshot?; let history: MetricHistory }  // presentational; ForEach(MemoryCardModel.sections) switch → section view

nonisolated enum StatusItemReadings {
    static let sampleCount = 60
    static func build(cpu: CPUSnapshot?, cpuHistory: MetricHistory,
                      memory: MemorySnapshot?, memoryHistory: MetricHistory) -> [ModuleReading]
    // .memory → samples: memoryHistory.suffix(sampleCount), valueText: PercentFormatter.integer(memory?.fraction ?? 0)
}
```

`MemoryCard` renders `MemoryCardModel.sections` in order inside its `VStack` (a `switch` per section, `MemoryCardSection` is `Identifiable` via `self` for the `ForEach`): `.header` (`memorychip` icon in `Palette.memAccent` + "Memory"); `.gaugeAndRows` (`HStack`: `RingGauge(fraction, color: memAccent, valueText, subtitle: "RAM").equatable()` with reduce-motion gated animation + `VStack` of the four `KeyValueRow`s); `.stackedBar` (`StackedBar(segments).equatable().frame(height: 8)`); `.legend` (`SegmentLegend(entries: MemoryCardModel.legend)`); `.graph` (`HistoryGraph(samples, capacity: 120, color: memAccent).equatable().frame(height: 48)`). Nil snapshot: gauge `0.0%`, rows at `ByteFormatter.memory(0)`, empty bar (track only), full legend, empty graph. Padding, spacing, corner radius and header font copy `CPUCard`'s constants.

## Architecture Decisions

| # | Decision | Choice | Rejected alternatives | Rationale |
|---|---|---|---|---|
| 1 | `MemorySnapshot.used` | Stored `let`, set only by the calculator | Computed `total - free - cached` in the model | `used` is a first-class observation, not a sum of the other fields: it carries the purgeable, speculative-backed and kernel pages that App, Wired and Compressed do not name (revision 3 widened that set, it did not change the shape). Computing it would duplicate the saturating formula in two places and make the PRD 6.2 amendment misleading. Stored keeps `Equatable` trivial and lets fixtures build arbitrary snapshots for presentation tests (for example a large unattributed remainder). Cost: a snapshot can be internally inconsistent when hand-built; production has exactly one constructor path. |
| 2 | Stacked-bar remainder | Sixth segment `.unattributed`, App colour, placed right after App, no legend entry | (b) Fold the remainder into the App segment; (c) new colour + "Other" legend entry | (b) violates R4.5 literally (the App segment would no longer be proportional to App) and lies to any future legend value. (c) adds a token PRD 7.1 does not define and a legend entry the reference does not show. (a) keeps every labelled segment truthful, the bar reads as Used (App + unattributed + Wired + Compressed) then Cached then Free, and the six byte values sum to Total exactly whenever `used` did not saturate. The remainder is where the purgeable pages live after revision 3, which is why it grew from 14 288 to 24 288 pages on the `reference` fixture. When `free + cached > total` (`used == 0`), geometry clamps and the bar simply fills. |
| 3 | Total source | `ProcessInfo.processInfo.physicalMemory`, read once in the adapter `init` | `hw.memsize` via `SysctlReader`; `hw.memsize_usable` | R4.1 names `physicalMemory`. Research C7 documents that `hw.memsize` is actual physical memory while `hw.memsize_usable` subtracts carve-outs, and G4 leaves open which quantity `physicalMemory`/`host_basic_info.max_mem` expose; the equivalence `physicalMemory == hw.memsize` is therefore established empirically by the `.integration` assertion, not assumed from the sources. Because Used = Total - Free - Cached, Total must include the carve-outs for Used to match Activity Monitor's Memory Used (research S4/S5 gap); `hw.memsize_usable` would under-report. Validation: the `.integration` test asserts `totalBytes == physicalMemory == UInt64(try #require(SysctlReader().integer("hw.memsize")))`; the manual check on the M4 Pro compares the card's Total to Activity Monitor "Physical Memory" and the card's Used to "Memory Used" at the same moment, target |Δ| ≤ 100 MB. Recorded fallback if the manual check fails with matching Totals: swap the one `totalBytes` line to `hw.memsize_usable` and re-run; no other code moves. |
| 4 | Page size | `host_page_size(host, &size)` once in `init`, cached as `UInt64` next to `host`; never the C globals | `vm_kernel_page_size` global; `SysctlReader.integer("hw.pagesize")` | The global is a mutable `vm_size_t` and trips the Swift 6 shared-mutable-state diagnostic (X3, zero-warning build). `hw.pagesize` is the task map page size, not the kernel page size the counters use (research C11, R2). `host_page_size` returns exactly `vm_kernel_page_size` without a Mach round trip (C9) and needs no new sysctl key. |
| 5 | Sampler injection | Required `memoryProvider` init parameter, no default; `AppDelegate` passes `MachMemoryProvider()` | Default `= MachMemoryProvider()` in Application; optional `any MemoryMetricsProvider? = nil` | A default would make Application import an Infrastructure type (hexagonal boundary). An optional creates a nil branch production never takes. Test churn is limited to the two `makeSampler` helpers, which gain `memoryProvider: FakeMemoryProvider = FakeMemoryProvider(counts: [MemoryFixtures.eightGiB])` as a defaulted parameter, so no existing test body changes. |
| 6 | Loop placement | Same iteration, CPU read then memory read, then publish CPU then memory (two `await`s) | Second detached loop (A2); combined `apply(cpu:memory:)` (S2) | R5.1 single timer; two hops at 1 Hz are negligible; S1 lets memory publish on iteration 1 while CPU keeps its second-sample rule, leaving the 188 tests untouched. Reading both before publishing keeps the two readings in one tick. |
| 7 | `MemorySamplingStep` | A `nonisolated struct` with `read()`, mirroring `CPUSamplingStep` | Inline `try?` in the loop closure; a free function | Symmetry with the existing step makes one iteration testable inline and keeps `sampleOnce()` a two-line extension. |
| 8 | Observation granularity | Two properties (`memory`, `memoryHistory`) next to the CPU pair; no combined struct | Single `MemoryFeed` struct; per-metric sub-objects | `@Observable` tracks per property. `StatusItemView` already reads both CPU properties and re-evaluates once per `apply`; adding two more reads doubles body evaluations to two per tick, which the `.equatable()` `Sparkline`/`HistoryGraph` children absorb. Matches the existing shape. |
| 9 | `StatusItemReadings.build` | Symmetric `build(cpu:cpuHistory:memory:memoryHistory:)` | Append `memory:memoryHistory:` to the old `snapshot:history:` labels | The test file is edited anyway for the spec delta; symmetric labels remove the ambiguity of an unqualified `snapshot`. Four call sites change (`StatusItemView.swift:130`; `StatusItemReadingsTests.swift:99`, `:171`, `:172`) plus the `reading` helper at `StatusItemReadingsTests.swift:93`. |
| 10 | `ReadError` shape | Nested `nonisolated enum` with `machCall`, `truncatedStatistics`, `invalidPageSize`; count validation exposed as `static validate(returnedCount:)` | Reuse `MachCPUProvider.ReadError`; a shared `Infrastructure/Mach/MachError`; validation inlined in `readCounts()` | Each adapter owns its failure vocabulary (existing pattern); `truncatedStatistics` is memory-specific (the `CountInOut` hazard); sharing would couple two adapters for one case. The static seam makes MM-9 a plain unit test instead of an untestable branch behind a real Mach call. |
| 11 | Bar/legend component scope | Generic `StackedBar.Segment(fraction, color)` + `LegendEntry(label, color)` in `Components/`; memory-specific `MemorySegment` in the card model maps into them | `StackedBar` taking `[MemorySegment]` | Components stay metric-agnostic (a v2 GPU card can reuse them); the model owns the memory vocabulary. |
| 12 | Zero formatting | `spellsOutZero: false` | `true` ("Zero kB") | The nil placeholder rows read a numeric zero (expected `0 bytes` in en_US; exact string pinned at the first RED because it is ICU output), consistent with a numeric table. |
| 13 | Card section order | `MemoryCardModel.sections` drives the `VStack` | Hard-coded order in `body` | MC-7 ("graph at the bottom") becomes an assertion on a pure array instead of a rendering inspection; the view cannot drift from the model. |
| 14 | Which pages leave Used (revision 3) | `Cached = external + speculative`, `Used = Total − free × pageSize − external × pageSize` | Keep `Cached = external + purgeable` and `Used = Total − (free − speculative) − (external + purgeable)` | See the rationale below: the manual check of 2026-09-06 measured the shipped formula 0.27–0.42 GB under Activity Monitor's "Memory Used" and a 3-minute `vm_stat` window proved Activity Monitor keeps both speculative and purgeable pages inside Used. The invariant `Used + Cached + Free == Total` still holds by construction, because Free and Cached share exactly the speculative pages. |
| 15 | Legend wrapping | Labels are single fixed-size lines; `ViewThatFits` keeps one row while it fits and falls back to two | Let the `HStack` compress the labels; a `LazyVGrid` with an adaptive minimum | The shipped `HStack` squeezed the labels and SwiftUI broke them inside the word ("Compre / ssed", "Cache / d"). `lineLimit(1)` plus `fixedSize(horizontal:)` makes a break impossible, so the only remaining question is where the legend wraps, and `ViewThatFits` answers it without a magic minimum column width that has to be re-tuned whenever a label changes. Entry order (MC-6) is identical in both layouts. |

## Rationale: the 2026-09-06 formula correction (revision 3)

The manual verification in task 7.3, run on the development Apple M4 Pro against simultaneous Activity Monitor screenshots, found the card's Used between 0.27 GB and 0.42 GB below Activity Monitor's "Memory Used", while Wired, Compressed and App (= internal − purgeable) matched exactly. A three-minute `vm_stat` window then showed Activity Monitor's own unattributed remainder — Used − App − Wired − Compressed — reaching 0.95 GB, which the shipped formula cannot produce: it had already removed the purgeable and speculative pages from Used.

The conclusion is that Activity Monitor deducts only the free and file-backed pages from physical memory. Speculative pages are read-ahead cache, so they leave Free and land in Cached; purgeable pages are reclaimable but still resident, so they leave App and stay inside Used. App, Wired and Compressed are unchanged, and the stacked bar still sums to Total because Free and Cached share exactly the speculative pages. Only two lines of the calculator moved (`cached`, and the comment on `used`); every fixture expectation was re-derived from the new formula before the production change (batch D RED).

## Concurrency Design

| Concern | Decision |
|---|---|
| Values crossing into the detached task | `any MemoryMetricsProvider` (Sendable protocol) in addition to the existing captures; no `self` capture. `MemorySnapshot` is the only new value hopping back to the main actor. |
| Adapter state | `MachMemoryProvider` stores three `let`s (`host_t`, `UInt64`, `UInt64`); struct is `Sendable` by construction. `host_page_size` and `physicalMemory` are read once in `init` on whatever thread constructs it (the composition root); `readCounts()` runs on the utility task. `requiredFieldCount` is an immutable `static let` of a `Sendable` integer, so it satisfies SE-0412 without isolation. |
| Nested types | `MachMemoryProvider.ReadError`, `StackedBar.Segment`, `FakeMemoryProvider.Script`/`ScriptedError` all carry explicit `nonisolated` (default isolation would otherwise make them main-actor). |
| `Color` in Sendable structs | `SwiftUI.Color` is `Sendable`; `CPUCardRow` already relies on this. |
| Errors | `MemorySamplingStep.read()` swallows via `try?`; the loop never exits on a memory failure and the CPU step is unaffected. `ReadError` exists for the `.integration` test, the `validate` unit test and direct adapter callers. |
| Tests | Never `@MainActor`; they `await` `MetricsState`/`MetricsSampler` members. `FakeMemoryProvider` uses `Synchronization.Mutex`, records `Thread.isMainThread`, `throwOnCall` zero-based. |

## Data Flow

```
host_statistics64 ──MachMemoryProvider.readCounts()──► MemoryPageCounts ─► MemoryUsageCalculator.snapshot ─► MemorySnapshot
(host_page_size, physicalMemory cached at init)        (detached task, same iteration as the CPU step)          │ await
                                                                                       MetricsState.apply(memory:) ─► memory, memoryHistory(120, fraction)
                                                                                                    │ @Observable
                     StatusItemView ◄───────────────────────────────────────────────────────────────┴──► PanelView → MemoryCard
                     suffix(60) + integer % of fraction                                     rows/gauge/segments/legend/graph via MemoryCardModel
```

## File Changes

| File | Action | Description |
|---|---|---|
| `system-monitor/Domain/Models/MemoryPageCounts.swift` | Create | Raw counts value |
| `system-monitor/Domain/Models/MemorySnapshot.swift` | Create | Snapshot with stored `used`, `fraction`, `unattributedUsed` |
| `system-monitor/Domain/Ports/MemoryMetricsProvider.swift` | Create | Port (defined before the adapter) |
| `system-monitor/Domain/Services/MemoryUsageCalculator.swift` | Create | Saturating formula |
| `system-monitor/Infrastructure/Mach/MachMemoryProvider.swift` | Create | Adapter + `ReadError` + `requiredFieldCount`/`validate(returnedCount:)` |
| `system-monitor/Application/MetricsState.swift` | Modify | `memory`, `memoryHistory`, `apply(memory:)` |
| `system-monitor/Application/MetricsSampler.swift` | Modify | `MemorySamplingStep`, `memoryProvider`, loop + `sampleOnce()` |
| `system-monitor/App/AppDelegate.swift` | Modify | Pass `MachMemoryProvider()` |
| `system-monitor/Presentation/Theme/Palette.swift` | Modify | Four tokens; `memAccent` doc "gauge, graph, App segment"; drop the M3 placeholder comment in `MetricModule.accent` |
| `system-monitor/Presentation/Formatting/ByteFormatter.swift` | Create | `.memory` style |
| `system-monitor/Presentation/Components/StackedBar.swift` | Create | `StackedBarGeometry`, `StackedBar`, `Segment` |
| `system-monitor/Presentation/Components/SegmentLegend.swift` | Create | `LegendEntry`, `SegmentLegend` |
| `system-monitor/Presentation/Panel/MemoryCard.swift` | Create | Model types, `MemoryCardSection`, `MemoryCardModel`, `MemoryCard`, previews (8 GiB fixture, nil) |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modify | `MemoryCard(snapshot: state.memory, history: state.memoryHistory)`; delete `PlaceholderCard`; live preview applies memory too; doc comment |
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | Modify | `build(cpu:cpuHistory:memory:memoryHistory:)`, MEM bound; `StatusItemView` passes four values; doc comments |
| `PRD.md` | Modify | R4.2 replacement text (proposal), R4.3 "via `host_page_size()`", 6.2 `let used` + note |
| `openspec/specs/menu-bar-widget/spec.md` | Delta (in change) | MODIFIED "Data-driven module list" (MEM MUST bind), MODIFIED "Every module renders a sparkline" scenario, Purpose |
| `system-monitorTests/Support/FakeMemoryProvider.swift`, `MemoryFixtures.swift` | Create | Doubles and fixtures |
| `system-monitorTests/Domain/{MemoryUsageCalculatorTests,MemorySnapshotTests}.swift` | Create | Domain unit |
| `system-monitorTests/Application/{MetricsStateTests,MetricsSamplerTests}.swift` | Modify | `apply(memory:)`; memory scenarios via `sampleOnce()`; `makeSampler` defaulted fake |
| `system-monitorTests/Infrastructure/MachMemoryProviderTests.swift` | Create | Plain unit suite for `requiredFieldCount`/`validate(returnedCount:)` (MM-9), no Mach call |
| `system-monitorTests/Infrastructure/MachMemoryIntegrationTests.swift` | Create | `.integration` shape suite |
| `system-monitorTests/Presentation/{ByteFormatterTests,MemoryCardModelTests,StackedBarGeometryTests}.swift` | Create | Presentation unit |
| `system-monitorTests/Presentation/{StatusItemReadingsTests,PanelViewTests}.swift` | Modify | Replace `theMemoryModuleStaysAPlaceholder`; MEM live cases; palette tokens; panel height |
| `system-monitorTests/Presentation/SegmentLegendTests.swift` | Create (revision 3) | Rendered legend geometry: two single-line rows at the card content width, one row when the entries fit |

Unchanged: `MetricHistory`, `Sparkline`, `HistoryGraph`, `RingGauge`, `KeyValueRow`, `CPUCard`, `CoreBar*`, `StatusItemController`, `StatusItemMetrics`, all CPU Domain/Infrastructure, `project.pbxproj`.

## Test Doubles and Fixtures

```swift
import Synchronization
nonisolated final class FakeMemoryProvider: MemoryMetricsProvider {          // Sendable: only a `let` Mutex
    nonisolated struct ScriptedError: Error, Equatable {}
    nonisolated private struct Script: Sendable {
        var counts: [MemoryPageCounts]; var cursor = 0; var throwOnCall: Set<Int>; var callCount = 0; var readOnMainThread: [Bool] = []
    }
    private let script: Mutex<Script>
    init(counts: [MemoryPageCounts], throwOnCall: Set<Int> = [])
    func readCounts() throws -> MemoryPageCounts   // same semantics as FakeCPUProvider: records Thread.isMainThread, throws on scripted zero-based indexes
                                                   // (advancing callCount, not cursor), repeats the last value when exhausted, returns MemoryFixtures.zero when the script is empty
    var callCount: Int; var readOnMainThread: [Bool]
}

nonisolated enum MemoryFixtures {
    static let pageSize: UInt64 = 16_384

    /// Spec MM-2 counts on an 8 GiB machine.
    static let reference = MemoryPageCounts(freeCount: 60_000, wireCount: 120_000, purgeableCount: 20_000, speculativeCount: 10_000,
                                            compressorPageCount: 90_000, externalPageCount: 50_000, internalPageCount: 200_000,
                                            pageSize: 16_384, totalBytes: 8_589_934_592)
    // MM-2 expected bytes: app 2_949_120_000, wired 1_966_080_000, compressed 1_474_560_000, cached 983_040_000, free 819_200_000,
    // used 6_787_694_592 (fraction 0.79019…), unattributedUsed 397_934_592 (24_288 pages); the six segments sum to 8_589_934_592.

    /// 8 GiB machine reproducing the reference card (MC-4): Used 5.52 GB / 69.0%, Wired 1.85 GB, Compressed 1.82 GB.
    static let eightGiB = MemoryPageCounts(freeCount: 112_588, wireCount: 121_250, purgeableCount: 10_000, speculativeCount: 5_000,
                                           compressorPageCount: 119_280, externalPageCount: 50_000, internalPageCount: 99_170,
                                           pageSize: 16_384, totalBytes: 8_589_934_592)
    // Derived bytes: app 1_460_961_280, wired 1_986_560_000, compressed 1_954_283_520, cached 901_120_000, free 1_762_721_792,
    // used 5_926_092_800 (fraction 0.68989…), unattributedUsed 524_288_000; the six segments sum to 8_589_934_592.
    // `freeCount` moved 107_588 → 112_588 in revision 3 so the card keeps its reference numbers under the corrected formula.

    static let zero: MemoryPageCounts                       // every field 0 except pageSize 16_384; total 0 → fraction 0
    static let purgeableExceedsInternal: MemoryPageCounts   // internal 10, purgeable 20 → app 0
    static let speculativeExceedsFree: MemoryPageCounts     // free 10, speculative 20 → free 0
    /// MM-2 saturation ("free plus file-backed pages exceed Total"): total 1_000, pageSize 16, freeCount 60, externalPageCount 40,
    /// everything else 0 → Free 960 + Cached 640 > 1_000 → used 0, fraction 0.
    static let freePlusCachedExceedTotal: MemoryPageCounts
    /// MM-2 widening: wireCount == UInt64(UInt32.max), pageSize 16_384 → wired == 70_368_744_161_280 exactly (no saturation, no trap).
    static let uint32MaxWired: MemoryPageCounts
    /// Extra triangulation with a different assertion: UInt64.max counts → every byte field saturates at UInt64.max instead of trapping.
    static let overflowingCounts: MemoryPageCounts
    static func snapshot(from counts: MemoryPageCounts) -> MemorySnapshot   // MemoryUsageCalculator.snapshot(from:)
}
```

## Testing Strategy (strict TDD; unit command `xcodebuild … -only-testing:system-monitorTests`)

| Layer | What to Test | Approach |
|---|---|---|
| Domain unit | Calculator on `reference` (MM-2): app 2_949_120_000, wired 1_966_080_000, compressed 1_474_560_000, cached 983_040_000, free 819_200_000, used 6_787_694_592, `unattributedUsed` 397_934_592, fraction ≈ 0.7902. Calculator on `eightGiB` (MC-4): each byte field, `used == total - free - cached`, fraction ≈ 0.6899, `unattributedUsed == 524_288_000`. Both fixtures also pin `cached == (external + speculative) × pageSize`, `used + cached + free == total` and `unattributedUsed >= purgeable × pageSize` (purgeable pages stay inside Used). `zero` → fraction 0, no NaN; `purgeableExceedsInternal` → app 0 and cached 0; `speculativeExceedsFree` → free 0 with the speculative pages in cached; `freePlusCachedExceedTotal` → used 0, fraction 0; `uint32MaxWired` → wired == 70_368_744_161_280 exactly; `overflowingCounts` → saturates at UInt64.max, no trap; `fraction` clamps to 1 when hand-built `used > total`; `MemorySnapshot` equality and memberwise init | Swift Testing, parameterized over the two full fixtures and over the saturation cases |
| Infrastructure unit (MM-9) | `MachMemoryProvider.requiredFieldCount` equals `offset(of: \.internal_page_count) / stride(integer_t) + 1` and is ≤ the full struct count; `validate(returnedCount: requiredFieldCount)` and `validate(returnedCount: fullCount)` do not throw; `validate(returnedCount: requiredFieldCount - 1)` and `validate(returnedCount: 0)` throw `.truncatedStatistics(n)` with the passed count | Plain unit suite `MachMemoryProviderTests`, no `.integration` tag, no Mach call |
| Application | `apply(memory:)` sets `memory` and appends `fraction`; `memoryHistory` capped at 120 after 130 applies; `sampleOnce()` once → `memory != nil` while `cpu == nil` (MM-7 first publish); `sampleOnce()` twice → both non-nil, CPU and memory `callCount == 2` each (same-iteration); memory fake `throwOnCall: [0]` → `memory == nil`, CPU step unaffected, next `sampleOnce()` publishes memory; **MM-7 third scenario**: CPU fake `throwOnCall: [0]` and a healthy memory fake → after one `sampleOnce()` `memory != nil`, `memoryHistory.count == 1`, `cpu == nil`, `cpuHistory.count == 0`; a throwing memory fake never changes `cpuHistory` | Fakes + `sampleOnce()`; **no new wall-clock tests**. MM-8 (off-main read) is asserted only inside the existing `everyReadHappensOffTheMainThread` loop test, which gains assertions on the memory fake's `readOnMainThread` (all `false`, count ≥ 2); it is never asserted against `sampleOnce()`, which runs inline on the main actor by design. |
| Infrastructure `.integration` | `MachMemoryProvider().readCounts()` succeeds; `pageSize ∈ {4096, 16384}`; `totalBytes == ProcessInfo.processInfo.physicalMemory` and `totalBytes == UInt64(try #require(SysctlReader().integer("hw.memsize")))` (`integer(_:)` returns `Int?`); `freeCount > 0`; each component `× pageSize <= totalBytes`; derived snapshot `fraction ∈ 0...1`, `used <= total`, and `app + wired + compressed <= used` (empirical Apple Silicon behaviour, rests on research C6/C7/U1); two reads agree on `pageSize`/`totalBytes` | New suite tagged `.integration`; runs in the sandboxed test host (proves `host_statistics64` under App Sandbox) |
| Presentation unit | `ByteFormatter`: `"5.52 GB"` (en_US), `"5,52 GB"` (de_DE), `"8 GB"`, zero string pinned; compare after mapping U+00A0/U+202F to U+0020 (convention 9). `MemoryCardModel`: rows `[Used, Total, Wired, Compressed]` with the `eightGiB` strings; gauge `"69.0%"`; six segments in order `[.app, .unattributed, .wired, .compressed, .cached, .free]` with `bytes` summing to `total` and `fraction`s summing to 1 ± 1e-9; `legend` labels/colours in R4.5 order without `.unattributed`; **MC-7**: `MemoryCardModel.sections == [.header, .gaugeAndRows, .stackedBar, .legend, .graph]`, `sections.last == .graph`, and `Set(sections) == Set(MemoryCardSection.allCases)`; nil → `"0.0%"`, zero rows, `[]` segments, full legend, empty graph. `StackedBarGeometry`: cumulative rects, clamp at width, zero/NaN fractions, degenerate size → `[]`. `SegmentLegend` (revision 3): the five entries cannot share one row at the 264 pt card content width, the rendered legend is exactly two single-line rows there, and a two-entry legend stays on one row. `StatusItemReadings`: MEM `"59%"` from fraction 0.59, `"0%"` for nil, newest 60 of 120, equal inputs compare equal. `PaletteTests`: four token values. `PanelViewTests`: height grows with the memory card (threshold pinned at first GREEN). | Pure helpers; `@MainActor` view measurement awaited from nonisolated tests; views covered by `#Preview` |

Spec-delta impact: `StatusItemReadingsTests.theMemoryModuleStaysAPlaceholder` is deleted and replaced by `theMemoryValueFollowsTheSnapshotFraction`, `theMemoryValueReadsZeroPercentBeforeTheFirstSnapshot` and `theMemorySparklineUsesTheNewestSixtySamples`; `everyModuleReservesItsSparklineArea` stays (structural width, unchanged).

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## Migration / Rollout

No data migration. Single PR (delivery strategy `single-pr`). Rollback per proposal: revert the six modified source files and `PRD.md` to `60cca91`, delete the new Domain/Infrastructure/Presentation files and tests (synchronized groups pick up removals), drop the unmerged `menu-bar-widget` delta; MEM returns to the `0%` placeholder and `PlaceholderCard`. Archive must warn before merging the destructive `menu-bar-widget` delta (config rule).

## Open Questions

- [ ] Exact ICU strings for `ByteFormatter.memory(0)` in en_US/de_DE and the whitespace character between number and unit: pinned at the first RED, not assumed.
- [x] Manual validation on the Apple M4 Pro: card Total vs Activity Monitor "Physical Memory" and card Used vs "Memory Used" within 100 MB. Run on 2026-09-06. Totals matched; Used was 0.27–0.42 GB low. The cause was the formula, not `Total`, so the `hw.memsize_usable` fallback (decision 3) was NOT applied and `ProcessInfo.physicalMemory` stays. Corrected per decision 14; a final visual re-check by the user is still outstanding.
- [ ] Severity of the `vm_kernel_page_size` diagnostic is moot for this design (never referenced); the first compile of `host_page_size(host, &size)` confirms it is warning-free.
