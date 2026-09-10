# Design: Network Module (PRD M6, "Network")

Proposal: `proposal.md` (Engram `sdd/network-module/proposal`, id 8290). Spec: `specs/network-metrics/spec.md` (NM-1..NM-13) and `specs/network-card/spec.md` (NC-1..NC-13) plus the `disk-card` delta (DC-1, DC-11), Engram `sdd/network-module/spec` (8291); the requirement ids below are the spec's final ids and tasks bind them verbatim. Exploration: `exploration.md` (8288). Pre-proposal: 8289. Engram mirror of this file: `sdd/network-module/design`. Designed 2026-09-10; attempt 2 after the design gate (NC-13 coverage, shared reference fixture, `NET_RT_IFLIST2` citation). Precedent: `archive/2026-09-10-disk-module/design.md` (its numbered decisions apply here by analogy where cited).

## Technical Approach

The disk shape, cloned one layer at a time, confirmed by the handoff (decisions 1–7, not reopened):

- Domain owns `NetworkThroughputCounters`, `NetworkSnapshot`, the single-method `NetworkMetricsProvider` port and the pure `NetworkThroughputCalculator` (Δbytes/Δt, negative-delta re-seed). Every instant is a `ContinuousClock.Instant` stamped by the adapter; Domain imports Foundation only.
- Application adds a `NetworkSamplingStep` value (baseline counters) living as a `var` inside the existing single `Task.detached(priority: .utility)` loop and as `inlineNetworkStep` for `sampleOnce()`, exactly like `DiskSamplingStep`. `MetricsState` gains `network`, `networkDownloadHistory`, `networkUploadHistory` and `apply(network:)`.
- Infrastructure adds `SysctlNetworkProvider` (`Infrastructure/System`): one `NET_RT_IFLIST2` sysctl per tick, walked with `loadUnaligned`, filtered through a pure `includes(type:flags:)` seam, summed saturating, stamped `ContinuousClock.now`.
- Presentation follows the `DiskCardModel`/`DiskCard` split: a `nonisolated enum NetworkCardModel` derives sections, rows, readings and normalised graph series; `NetworkCard` is a thin switch over `NetworkCardModel.sections`; `HistoryGraph` gains a multi-series initialiser; `Palette` gains three tokens; `PanelView` renders the fourth card and accepts an optional `maxHeight` that `StatusItemController` resolves from the presenting screen at show time through the pure `PanelLayout` rule.
- App composition root injects `SysctlNetworkProvider()`.

Isolation rule (convention 1): every type below in Domain, Infrastructure, pure model enums, components' value types and test support is explicitly `nonisolated` and `Sendable`, nested types included (`ReadError`, `Rates`, `Script`, fixtures). Only `MetricsState`, `MetricsSampler`, views and controllers are main-actor.

## Component Diagram

```
App/AppDelegate (composition root, @MainActor)
  ├─ MachCPUProvider, MachMemoryProvider, IOKitDiskProvider, IORegistryCoreTopologyProvider   Infrastructure (nonisolated, Sendable)
  ├─ SysctlNetworkProvider()  ← NEW
  ├─ MetricsState (@MainActor @Observable)  + network, networkDownloadHistory, networkUploadHistory, apply(network:)
  ├─ MetricsSampler(state, cpu, memory, disk, network ← NEW, topology, …) ──► one Task.detached loop
  └─ StatusItemController(state) → NSPopover → PanelRootView(state, maxHeight) ← NEW → PanelView(maxHeight:)
                                        │                 └─ CPUCard, MemoryCard, DiskCard, NetworkCard(snapshot, download, upload) ← NEW
                                        │                              └─ ThroughputLabel×2, KeyValueRow×2, HistoryGraph(series:) ← MODIFIED
                                        └─ PanelLayout.maxHeight(fitting:visibleFrameHeight:) ← NEW (pure)

Port (Domain): NetworkMetricsProvider     Pure rule (Domain/Services): NetworkThroughputCalculator
```

## Interfaces / Contracts

All signatures are normative; tasks implement them verbatim.

### Domain (imports Foundation only) — port defined before any adapter

```swift
nonisolated struct NetworkThroughputCounters: Sendable, Equatable {
    let bytesIn: UInt64              // cumulative since boot, summed over every included interface
    let bytesOut: UInt64
    let interfaceCount: Int          // interfaces that passed the filter; 0 → rates unavailable, totals 0
    let timestamp: ContinuousClock.Instant   // stamped by the adapter; participates in equality
}

nonisolated struct NetworkSnapshot: Sendable, Equatable {
    let totalIn: UInt64, totalOut: UInt64                              // since boot (confirmed)
    let downloadBytesPerSecond: Double?, uploadBytesPerSecond: Double?   // always both nil or both set
}

nonisolated protocol NetworkMetricsProvider: Sendable {
    func readCounters() throws -> NetworkThroughputCounters
}

nonisolated enum NetworkThroughputCalculator {
    /// Both rates or neither: the optional wraps the pair, so "one without the other" is unrepresentable.
    nonisolated struct Rates: Sendable, Equatable { let downloadBytesPerSecond: Double; let uploadBytesPerSecond: Double }
    /// nil when previous == nil, current.interfaceCount == 0, Δt <= 0, or either byte delta is negative.
    /// Δt = previous.timestamp.duration(to: current.timestamp) as Double seconds (attoseconds kept), as the disk rule.
    static func rates(previous: NetworkThroughputCounters?, current: NetworkThroughputCounters) -> Rates?
}
```

### Application (`@MainActor` classes, `nonisolated` step)

```swift
@MainActor @Observable final class MetricsState {
    private(set) var network: NetworkSnapshot?                 // NEW
    private(set) var networkDownloadHistory: MetricHistory     // NEW, raw bytes/s
    private(set) var networkUploadHistory: MetricHistory       // NEW, raw bytes/s
    init(historyCapacity: Int = 120)                           // sizes all four histories
    /// Sets `network`; appends BOTH histories only when both rates are non-nil, so the x axes stay aligned.
    func apply(network snapshot: NetworkSnapshot)
}

/// Stateful counterpart of DiskSamplingStep without the capacity half: only the baseline crosses ticks.
nonisolated struct NetworkSamplingStep: Sendable {
    let provider: any NetworkMetricsProvider
    let previous: NetworkThroughputCounters?
    func advanced() -> (snapshot: NetworkSnapshot?, next: NetworkSamplingStep)
}

@MainActor final class MetricsSampler {
    init(state: MetricsState, cpuProvider: any CPUMetricsProvider, memoryProvider: any MemoryMetricsProvider,
         diskProvider: any DiskMetricsProvider,
         networkProvider: any NetworkMetricsProvider,      // NEW, required, no default; placed after diskProvider
         topologyProvider: any CoreTopologyProvider, interval: Duration = .seconds(1),
         startupGap: Duration = .milliseconds(100), clock: any Clock<Duration> = ContinuousClock())
    private var inlineNetworkStep: NetworkSamplingStep?   // NEW, next to inlineDiskStep
    func sampleOnce()                                     // advances CPU, reads memory, advances disk, advances network, applies all four
}
```

`advanced()` algorithm (normative):

1. `guard let current = try? provider.readCounters() else { return (nil, NetworkSamplingStep(provider: provider, previous: nil)) }` — a throw publishes nothing and drops the baseline (decision 3).
2. `let rates = NetworkThroughputCalculator.rates(previous: previous, current: current)`; `next = NetworkSamplingStep(provider: provider, previous: current)` — the baseline is always re-seeded with `current`.
3. Return `(NetworkSnapshot(totalIn: current.bytesIn, totalOut: current.bytesOut, downloadBytesPerSecond: rates?.downloadBytesPerSecond, uploadBytesPerSecond: rates?.uploadBytesPerSecond), next)` — a successful read always publishes: totals are absolute, so tick one after `start()` shows totals with nil rates and tick two shows rates; `interfaceCount == 0` publishes totals 0 with nil rates.

Loop body per iteration: CPU step, memory read, disk step, then `let (networkSnapshot, nextNetwork) = networkStep.advanced(); networkStep = nextNetwork`, all four reads before any publish; then the four `if let … await state.apply(...)` in the order cpu, memory, disk, network; sleep; `gap = interval`. `var networkStep = NetworkSamplingStep(provider: networkProvider, previous: nil)` is created inside the detached closure, so every `start()` — including the one `apply(interval:)` performs — begins with a fresh step and costs one rates-unavailable tick; an unchanged interval is a no-op before `stop()`/`start()`. `sampleOnce()` mirrors the body with `inlineNetworkStep ?? NetworkSamplingStep(provider: networkProvider, previous: nil)`; like `inlineDiskStep`, it is untouched by `apply(interval:)`.

### Infrastructure (nonisolated, Sendable)

```swift
import Darwin
import Foundation
nonisolated struct SysctlNetworkProvider: NetworkMetricsProvider {   // stateless: init() {}
    nonisolated enum ReadError: Error, Equatable {
        case sizeQuery(errno: Int32)        // the sizing sysctl (nil buffer) returned -1
        case listRead(errno: Int32)         // the filling sysctl returned -1; ENOMEM when the table grew between the two calls
        case malformedMessage(offset: Int)  // ifm_msglen == 0 or a message overruns the buffer
    }
    /// {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0}   — NET_RT_IFLIST2 = 6 (sys/socket.h:541); RTM_IFINFO2 = 0x12 (net/route.h:214)
    private static let mib: [Int32]
    /// Internal (not private) so NM-10 "Sums saturate" is a unit test: addingReportingOverflow, saturating at UInt64.max.
    nonisolated static func saturatingSum(_ lhs: UInt64, _ rhs: UInt64) -> UInt64
    /// Pure filter seam (unit-tested without a socket): (type == IFT_ETHER || type == IFT_CELLULAR) && flags & IFF_LOOPBACK == 0.
    /// IFT_ETHER 0x6, IFT_CELLULAR 0xff (net/if_types.h), IFF_LOOPBACK 0x8 (net/if.h). No IFF_UP/IFF_RUNNING requirement (confirmed).
    nonisolated static func includes(type: UInt8, flags: Int32) -> Bool
    func readCounters() throws -> NetworkThroughputCounters   // stamps ContinuousClock.now after the walk
}
```

Read shape (convention 13): `var length = 0; sysctl(&mib, 6, nil, &length, nil, 0)` → `.sizeQuery(errno)` on failure; `var buffer = [UInt8](repeating: 0, count: length)`; `sysctl(&mib, 6, &buffer, &length, nil, 0)` → `.listRead(errno)` on failure (the kernel may shrink `length`; the walk covers `0..<length`). Walk inside `buffer.withUnsafeBytes`: `offset = 0; while offset + MemoryLayout<if_msghdr>.size <= length { let header = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self); let messageLength = Int(header.ifm_msglen); guard messageLength > 0, offset + messageLength <= length else { throw .malformedMessage(offset: offset) }; if Int32(header.ifm_type) == RTM_IFINFO2 { guard offset + MemoryLayout<if_msghdr2>.size <= length else { throw .malformedMessage(offset: offset) }; let message = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self); if Self.includes(type: message.ifm_data.ifi_type, flags: message.ifm_flags) { bytesIn = saturatingSum(bytesIn, message.ifm_data.ifi_ibytes); bytesOut = …ifi_obytes; interfaceCount += 1 } }; offset += messageLength }`. `if_msghdr` and `if_msghdr2` share the `ifm_msglen`/`ifm_version`/`ifm_type` prefix, so the short header is loaded first and the wide one only for `RTM_IFINFO2` records, and only after the guard above, because `ifm_msglen` could be smaller than the 160-byte `if_msghdr2`. Sums go through `saturatingSum` (`addingReportingOverflow`, `UInt64.max` on overflow; disk precedent). The buffer is never reinterpreted through a typed pointer.

Imports (convention 12): the design gate compiled a Swift probe on this SDK confirming that `if_msghdr2` (160 bytes), `if_data64` (128 bytes, `ifi_ibytes` at offset 64, `ifi_obytes` at 72), `NET_RT_IFLIST2`, `RTM_IFINFO2`, `IFT_ETHER`, `IFT_CELLULAR` and `IFF_LOOPBACK` all import through `Darwin`, so the adapter uses the SDK names directly. Contingency only, should a later SDK drop one of them: read with `loadUnaligned(fromByteOffset:as:)` at private offsets with citations (within `if_msghdr2`, `net/if.h:202`: `ifm_msglen` u_short @0, `ifm_type` u_char @3, `ifm_flags` int @8, `ifm_data` @32; within `if_data64`, `net/if_var.h:189`: `ifi_type` u_char @0, `ifi_ibytes` u_int64 @64, `ifi_obytes` u_int64 @72, `if_var.h:208-209`), and turn a missing constant into a `private static let` literal with the same citation. The `.integration` suite in the sandboxed host (`BUNDLE_LOADER`, convention 8) remains the empirical proof: `interfaceCount >= 1`, `bytesIn > 0`, monotonic across two reads ≥ 120 ms apart with advancing stamps, 50 consecutive reads succeed.

### Presentation

```swift
nonisolated enum Palette {
    static let networkAccent = sRGB(0xA66BFF)     // globe header glyph; sampled from docs/reference/06-panel-network.png (decision 8)
    static let networkDownload = sRGB(0x3DD68C)   // download badge and line; same value as memFree/diskAccent
    static let networkUpload = sRGB(0x4D8DFF)     // upload badge and line; same value as cpuAccent/memCached
}

/// One line of a HistoryGraph. Top-level (not nested in the main-actor view) so it is nonisolated + Sendable; Color is Sendable (CPUCardRow precedent).
nonisolated struct HistoryGraphSeries: Sendable, Equatable {
    let samples: [Double]           // already normalised to 0...1 by the caller
    let color: Color
    let fillOpacity: Double         // 0 → stroke only
    init(samples: [Double], color: Color, fillOpacity: Double = SparklineGeometry.fillOpacity)
}
struct HistoryGraph: View, Equatable {
    let series: [HistoryGraphSeries]; let capacity: Int
    init(series: [HistoryGraphSeries], capacity: Int)
    init(samples: [Double], capacity: Int, color: Color)   // convenience: [HistoryGraphSeries(samples:color:)]; CPUCard/MemoryCard untouched
    /// Pure geometry seam: one point array per series, in draw order (HistoryGraphSeriesTests).
    nonisolated static func points(series: [HistoryGraphSeries], capacity: Int, size: CGSize) -> [[CGPoint]]
}

nonisolated struct NetworkCardRow: Sendable, Equatable, Identifiable { let key: String; let value: String; var id: String { key } }
nonisolated enum NetworkCardSection: Sendable, Equatable, CaseIterable, Identifiable { case header, ratesAndTotals, graph; var id: Self { self } }

nonisolated enum NetworkCardModel {
    static let sections: [NetworkCardSection] = [.header, .ratesAndTotals, .graph]
    static let graphCapacity = 120
    static let title = "Network"                                                       // NC-3; model-owned per NC-1
    static let headerSymbolName = "globe"
    /// NC-13: delegates to CPUCardModel.gaugeAnimation(reduceMotion:) exactly as DiskCardModel.gaugeAnimation does (DiskCard.swift:116-118).
    static func animation(reduceMotion: Bool) -> Animation?
    static let downloadSymbolName = "arrow.down.circle.fill", uploadSymbolName = "arrow.up.circle.fill"
    static let unavailableText = "\u{2014}", unavailableAccessibilityValue = "unavailable"
    static let graphFloorBytesPerSecond: Double = 10_000                              // decision 6
    static func rows(for snapshot: NetworkSnapshot?, locale: Locale = .current) -> [NetworkCardRow]           // Total In, Total Out via ByteFormatter.capacity; "—" each when nil
    static func rateReadings(for snapshot: NetworkSnapshot?, locale: Locale = .current) -> [ThroughputReading]   // download then upload; labels "Download"/"Upload"; ByteFormatter.throughput; "—"/"unavailable" when nil
    static func graphScale(download: [Double], upload: [Double]) -> Double            // max(download.max, upload.max, floor)
    static func normalised(_ samples: [Double], scale: Double) -> [Double]            // samples / scale (scale ≥ max, so every value is in 0...1; SparklineGeometry still clamps)
    static func graphSeries(download: MetricHistory, upload: MetricHistory) -> [HistoryGraphSeries]   // suffix(graphCapacity) both, one shared scale, [download(networkDownload), upload(networkUpload)], fillOpacity 0
}

@MainActor struct NetworkCard: View {     // presentational; ForEach(NetworkCardModel.sections) switch → section view
    let snapshot: NetworkSnapshot?; let downloadHistory: MetricHistory; let uploadHistory: MetricHistory
    @Environment(\.accessibilityReduceMotion) private var reduceMotion   // NC-13; the only environment read, as CPUCard/DiskCard
    nonisolated static let cardPadding: CGFloat = 16, sectionSpacing: CGFloat = 14, rowSpacing: CGFloat = 6,
                           headerSpacing: CGFloat = 6, headerFontSize: CGFloat = 13, graphHeight: CGFloat = 48
}

nonisolated enum PanelLayout {
    static let screenMargin: CGFloat = 24
    /// nil when `fitting <= visibleFrameHeight - margin` (or the cap is not positive): the panel keeps today's tree.
    /// Otherwise the height the scrolling panel is pinned to. What the controller consumes.
    static func maxHeight(fitting: CGFloat, visibleFrameHeight: CGFloat, margin: CGFloat = screenMargin) -> CGFloat?
    /// NC-12's named rule: `maxHeight(...) ?? fitting`, so "shorter" and "exactly at the cap" return the fitting height unchanged.
    static func height(fitting: CGFloat, visibleFrameHeight: CGFloat, margin: CGFloat = screenMargin) -> CGFloat
}
nonisolated enum PanelCard: … { case cpu, memory, disk, network }
@MainActor struct PanelView: View {
    var maxHeight: CGFloat? = nil                      // PanelView() keeps working in previews and tests
    nonisolated static let cards: [PanelCard] = [.cpu, .memory, .disk, .network]
}
/// Root the popover hosts (StatusItemRootView analogue) so the controller can swap the cap without retyping the hosting controller.
@MainActor struct PanelRootView: View { let state: MetricsState; var maxHeight: CGFloat? = nil }   // PanelView(maxHeight:).environment(state)
```

`NetworkCard` sections: `.header` (`Image(systemName: headerSymbolName)` in `networkAccent` + `Text(NetworkCardModel.title)` at `headerFontSize` semibold, `.isHeader`); `.ratesAndTotals` (`HStack(alignment: .top, spacing: sectionSpacing)`: left `VStack(alignment: .leading, spacing: rowSpacing)` of `ThroughputLabel(reading:color:)` for download in `networkDownload` then upload in `networkUpload`; right `VStack(spacing: rowSpacing)` of two `KeyValueRow`s Total In / Total Out; both columns are 12 pt single-line rows, so they align without a fixed height; the `HStack` carries `.animation(NetworkCardModel.animation(reduceMotion: reduceMotion), value: snapshot)`, decision 11); `.graph` (`HistoryGraph(series: NetworkCardModel.graphSeries(download:upload:), capacity: graphCapacity).equatable().frame(height: graphHeight)`). Chrome copies `DiskCard`. Height is identical for nil and populated inputs by construction (same tree, no conditional views); estimated 160–175 pt, pinned at first GREEN.

`PanelView.body`: `if let maxHeight { ScrollView(.vertical) { cardsStack }.scrollBounceBehavior(.basedOnSize).frame(width: 320, height: maxHeight) } else { cardsStack }` where `cardsStack` is today's `VStack` + padding + width + `panelBackground` (the background also wraps the scroll view). With `maxHeight == nil` the tree is byte-identical to today, which is what keeps every existing `PanelViewTests` assertion green.

`StatusItemController`: a new stored `private let hostingController: NSHostingController<PanelRootView>` replaces the inline `popover.contentViewController = NSHostingController(rootView: PanelView().environment(state))` at `StatusItemController.swift:130-132`; `configurePopover()` assigns it as the content view controller; `togglePopover()`'s show branch first calls `updatePanelCap()`: `let visible = (button.window?.screen ?? NSScreen.main)?.visibleFrame.height`, `let fitting = Self.measuredPanelHeight(for: state)` (a throwaway `NSHostingView(rootView: PanelRootView(state: state))` after `layoutSubtreeIfNeeded()`, the `measuredContentWidth` precedent), `hostingController.rootView = PanelRootView(state: state, maxHeight: visible.flatMap { PanelLayout.maxHeight(fitting: fitting, visibleFrameHeight: $0) })`, then `popover.show(...)` exactly as today. Internal `static func panelMaxHeight(for state: MetricsState, visibleFrameHeight: CGFloat) -> CGFloat?` exposes the measurement + rule for a screenless test.

## Architecture Decisions

| # | Decision | Choice | Rejected alternatives | Rationale |
|---|---|---|---|---|
| 1 | Domain shapes and an explicit sibling calculator | `NetworkThroughputCounters`, `NetworkSnapshot`, single-method `NetworkMetricsProvider`, `NetworkThroughputCalculator.rates(previous:current:) -> Rates?` (above); all `nonisolated`, `Sendable`, `Equatable`; `NetworkSnapshot` memberwise only | A generic `ThroughputCalculator<Counters>` over a `CumulativeCounterPair` protocol shared with disk; an overload on `DiskThroughputCalculator`; a `rates:` convenience init on the snapshot | The two rules are ~20 lines each and share only the 4-line `seconds(_:)` helper; a generic would force both Domain values behind abstract `first`/`second` names and lose the vocabulary (`bytesRead` vs `bytesIn`), and would couple two modules' change histories (a disk fix rebuilds network tests). PRD 6.1 promises "adding a module is additive: one adapter, one card"; a sibling keeps that literally true. The optional `Rates` pair makes "one rate without the other" unrepresentable at the rule; the snapshot stays memberwise like `DiskSnapshot` so tests can hand-build edge cases. |
| 2 | Adapter home and `ReadError` vocabulary — **amended 2026-09-10, see the note below the table** | Standalone `SysctlNetworkProvider` in `Infrastructure/System`, stateless; `ReadError { sizeQuery(errno:), listRead(errno:), malformedMessage(offset:) }`; no `noInterfaces` case | Extending `SysctlReader` with a `data(mib:)` method; a shared sysctl error enum; wrapping `errno` as `any Error` | `SysctlReader` is a `sysctlbyname` integer adapter scoped to the CPU module; `NET_RT_IFLIST2` is the MIB-array `sysctl()` with a variable-length buffer, a different call and a different failure shape, and widening the reader would touch `AppDelegate`'s topology wiring for nothing. Each adapter owns its failure vocabulary (`MachCPUProvider`/`IOKitDiskProvider` precedent); `errno` payloads keep the enum `Equatable`. "No interface passed the filter" is a valid reading (`interfaceCount == 0`, totals 0, rates nil), not an error, so the em-dash path never throws. `ENOMEM` from the second call is the interface-churn race; it surfaces as `.listRead` and the step retries next tick. |
| 3 | Baseline on a `readCounters()` throw | Publish nothing, keep `MetricsState.network` and both histories untouched, and drop `previous` so the next success is a re-seed tick (rates nil once) | Keep `previous` and measure a longer window (the disk rule, DM-10) | Confirmed in the proposal. A network read fails realistically only during interface churn (the table grew between the sizing and filling calls), which is exactly when a per-interface counter may have reset; a window spanning the failure is untrustworthy, and one nil-rates tick is the same price DM-4 charges for a negative delta. The loop never stops and the other three steps are unaffected. |
| 4 | Two `MetricHistory` values in Application, appended together | `networkDownloadHistory` and `networkUploadHistory` of raw bytes/s; `apply(network:)` appends both or neither (only when both rates are non-nil) | A two-series ring buffer in Domain; one interleaved history; appending 0 on nil rates | `MetricHistory` stays unit-agnostic and single-series (convention 14); the pair keeps the x axes aligned because both append in one main-actor call. Appending 0 for "unknown" would draw an idle dip that never happened. |
| 5 | `HistoryGraph` multi-series contract | `HistoryGraph(series: [HistoryGraphSeries], capacity:)`; one `Canvas`; baseline drawn once; series drawn in array order (first underneath); per-series `fillOpacity` defaulting to `SparklineGeometry.fillOpacity`; single-series init kept as a convenience; `Equatable` synthesized; `nonisolated static points(series:capacity:size:)` seam | A separate `DualHistoryGraph`; a graph-level fill flag; nesting `Series` inside the view | The convenience init makes the CPU and Memory call sites byte-identical, and equality tests keep passing. Per-series fill lets the network card stroke both lines with no area (the mockup shows two plain lines and overlapping fills would muddy the crossing) while the existing cards keep their 0.35 fill. A top-level `nonisolated` series struct avoids inheriting the view's main-actor isolation. The static seam makes "N-series geometry equals N single-series geometries" an assertion on values. |
| 6 | Graph normalisation, floor, symbols, skeleton | Shared scale `max(maxDownload, maxUpload, 10_000)` over the visible 120 samples; both series divided by it; draw order download then upload; `globe`, `arrow.down.circle.fill`, `arrow.up.circle.fill` (fallback pair `arrow.down.circle`/`arrow.up.circle`); accessibility labels "Download"/"Upload"; nil snapshot renders em dashes with "unavailable" accessibility values and no caption | Floor 1 kB/s or 100 kB/s; per-series scaling; an "Unavailable" caption; `arrow.down`/`arrow.up` | An idle Mac's background chatter (mDNS, keepalives) sits at hundreds of bytes to a few kB/s; without a floor the max of an idle window is tiny and noise renders as full-scale spikes. 10 kB/s is one order above idle chatter and two below any real transfer, so idle draws flat lines and a 1 MB/s download reaches full scale; only the maximum feeds `graphScale`, and the mockup's maximum (the 78 kB/s upload) exceeds the floor, so the mockup renders at its true scale with the 5 kB/s download drawn at about 6 % of the height rather than lifted by the floor. 100 kB/s would draw the mockup's own 78 kB/s upload at 78 % and small transfers flat; 1 kB/s keeps the noise. Per-series scaling would lose the relative amplitude the mockup shows. Filled circles read as badges at 11 pt like the mockup and differ by direction (verified by `NSImage(systemSymbolName:)` in the RED test). No caption: the skeleton must match the populated height (disk decision 4). |
| 7 | Visible-frame scroll cap | Host = `StatusItemController` at show time; pure rule `PanelLayout.maxHeight(fitting:visibleFrameHeight:margin: 24)` returning `nil` when the panel fits, plus NC-12's named `PanelLayout.height(fitting:visibleFrameHeight:)` defined as `maxHeight(...) ?? fitting` so the spec's three scenarios bind literally (1050/945 → 921 and cards scroll; 871/1132 → 871 unchanged; fitting equal to the cap → fitting unchanged, no cap applied); `PanelView(maxHeight:)` switches to `ScrollView` + fixed height only when a cap is supplied; screen = the status button's window screen, else `NSScreen.main`, else no cap | Cap always applied (`ScrollView` + `frame(maxHeight:)` on every show); `PanelView` reading `NSScreen` in `body`; `popover.contentSize`; measuring once in `configurePopover`; exposing only `height(...)` and comparing it against `fitting` in the controller | The CPU card grows after its first snapshot and the display can change between opens, so the height must be measured per show, not at configure time. Returning `nil` below the cap keeps the production tree identical to today's (DC-11 lower bounds stay green) and avoids relying on `ScrollView`'s ideal-size behaviour; above the cap the height is known to overflow, so a fixed frame guarantees scrolling. AppKit stays out of `PanelView`, so the view remains renderable in previews and `NSHostingView` tests with a plain number. 24 pt covers the popover arrow and a breathing gap above the Dock. On a 14" at default scaling (visible ≈ 945 pt) four cards (≈ 1050 pt) pin to 921 pt and scroll; on 16" (visible ≈ 1080 pt) the rule decides from the measured height. `menu-bar-widget` is untouched: MBW-11 keeps `popover.appearance`, MBW-13 keeps one `show`/`performClose` per transition (the root swap happens before `show`). |
| 8 | Palette tokens and "two tokens, one colour" | `networkAccent 0xA66BFF`, `networkDownload 0x3DD68C`, `networkUpload 0x4D8DFF`; palette test pins each value and the two sharings (`networkDownload == diskAccent`, `networkUpload == cpuAccent`) and asserts only `networkDownload != networkUpload` | Reusing `diskAccent`/`cpuAccent` directly in the card; a pairwise-distinct palette test; a new green/blue pair | Tokens name a use, not a colour (`memCached` precedent); the card must not depend on disk or CPU tokens whose values may change independently. The single distinctness assertion is a requirement (badge colours differ); any other pairwise assertion would forbid the sharing the convention exists for. The globe in `06-panel-network.png` reads as a saturated violet consistent with 0xA66BFF; apply samples the glyph's densest pixel with Digital Color Meter and, only if any channel deviates by more than 0x10, replaces the value in `Palette` and the pin in the same commit (PRD 7.1 "estimates, sampled during implementation"). |
| 9 | Restart, `sampleOnce()` and the five compile sites | Fresh `NetworkSamplingStep` inside the detached closure; `inlineNetworkStep` untouched by `apply(interval:)`; `networkProvider: FakeNetworkProvider = FakeNetworkProvider(counters: [])` added as a defaulted parameter to both `makeSampler` helpers in `MetricsSamplerTests.swift` (`:19` and the loop suite's) and inline in `SamplingCadenceTests.swift:98` and `SettingsStateTests.swift:296`, plus `networkProvider: SysctlNetworkProvider()` in `AppDelegate.swift:39-49`, all in the same RED step as the init change | Optional `networkProvider` with a nil branch; a default in Application | Disk decision 13 by analogy: the compile break is by construction; an empty script reads `NetworkFixtures.idle` (`interfaceCount 0`), so every existing scenario keeps its CPU, memory and disk expectations while network publishes totals 0 with nil rates. No production code gains a branch. |
| 10 | Card and panel order seams | `NetworkCardModel.sections` and `PanelView.cards` gains `.network` last | Hard-coded order | Disk decision 11: both orders are array assertions; the bodies are switches. |
| 11 | Reduce motion (NC-13) with no animated element | `NetworkCardModel.animation(reduceMotion:)` delegates to `CPUCardModel.gaugeAnimation(reduceMotion:)` (the `DiskCardModel.gaugeAnimation` pattern); `NetworkCard` reads `\.accessibilityReduceMotion` and applies exactly that result as `.animation(_, value: snapshot)` on the `.ratesAndTotals` `HStack` | Omitting the function because nothing animates; a bespoke animation constant; animating the graph `Canvas` | No element of the Network card animates today: there is no ring gauge, and the history graph is a `Canvas` whose redraw is immediate, exactly as in the CPU and Memory cards. The modifier is therefore observably a no-op in both reduce-motion states (single-line text changes are not animatable), which is precisely what "the view MUST apply exactly that result" reduces to when the result has nothing to act on; it also means a future animatable element in that section inherits the shared rule without a new decision. Delegating keeps the four cards from drifting (NC-13's scenarios pin `nil` and equality with the CPU value). |

### Amendment to decision 2 (2026-09-10, after manual check 7.3)

**The data source in decision 2 and in the "Infrastructure" read shape above was wrong, and the adapter now reads the interface MIB.** `NET_RT_IFLIST2` declares `ifi_ibytes`/`ifi_obytes` as `u_int64_t`, and the design gate's compiled probe confirmed the struct layout — but layout is not behaviour: this platform's driver fills only the low 32 bits, so the counters wrap every 4 GB. Measured on this machine with no download running: `en1` went 4 287 352 832 → 8 851 456 in one 250 ms tick, and a same-moment comparison read 13 563 204 219 through the interface MIB against 678 301 696 through the routing socket. The wrap made the summed delta negative, so NM-4 correctly discarded the tick — the user saw em dashes and totals that appeared to reset.

Amended shape: read the row count from `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT}`, then one `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL}` read per index into a fixed-size `struct ifmibdata` (`net/if_mib.h`), filtering on `ifmd_data.ifi_type` and `Int32(bitPattern: ifmd_flags)`. `ReadError` becomes `{ countQuery(errno:), interfaceRead(index:errno:) }`: there is no sizing call, no allocation, no message walk and no unaligned load, so `sizeQuery`, `listRead` and `malformedMessage` no longer describe anything that can happen. Indices are sparse, so `ENOENT`/`ENXIO`/`EINVAL` on one index is a gap and is skipped through a new pure seam `isMissingInterface(errno:)`, a sibling of `includes(type:flags:)` with its own truth table. `includes` and `saturatingSum` are unchanged, as are their unit tests.

The cost is one `sysctl` per interface per tick — about twenty on this Mac — instead of one variable-length read. That is the price of counters that do not lie, and it removes the entire class of stride and length errors the walk needed guards for.

## Concurrency Design

| Concern | Decision |
|---|---|
| Values crossing into the detached task | `any NetworkMetricsProvider` (Sendable existential) added to the captures; no `self`. `NetworkSnapshot` is the only new value hopping back via `await state.apply(network:)`. |
| `NetworkSamplingStep` | `Sendable` by construction (Sendable existential + `Sendable` value with a stdlib `Instant`). Local `var` in the closure; main-actor stored property for `sampleOnce()`. |
| `SysctlNetworkProvider` | Stateless struct, `Sendable` trivially; the buffer is a local `[UInt8]` per read; `ContinuousClock.now` is read on the utility task inside `readCounters()`; no pointer escapes `withUnsafeBytes`. |
| Presentation values | `HistoryGraphSeries`, `NetworkCardRow`, `NetworkCardSection`, `NetworkCardModel`, `PanelLayout`, `PanelCard` are `nonisolated`; `Color` is `Sendable` (`CPUCardRow` precedent). `PanelRootView`, `NetworkCard`, `PanelView` are main-actor views. |
| Nested types | `SysctlNetworkProvider.ReadError`, `NetworkThroughputCalculator.Rates`, `FakeNetworkProvider.Script`/`ScriptedError` carry explicit `nonisolated`. |
| Errors | `advanced()` swallows the read with `try?`; the loop never exits on a network failure and the other steps are unaffected. `ReadError` exists for the `.integration` suite and direct callers. |
| Tests | Never `@MainActor`; `FakeNetworkProvider` uses `Synchronization.Mutex` (no `@unchecked Sendable`), zero-based `throwOnCall`, records `Thread.isMainThread` into `readOnMainThread`. Loop suites stay on `ManualClock`; rate scenarios run through `sampleOnce()` with scripted instants (convention 11). `.timeLimit(.minutes(1))` only. |

## Data Flow

```
sysctl NET_RT_IFLIST2 ──SysctlNetworkProvider.readCounters()──► NetworkThroughputCounters(stamp) ─► NetworkSamplingStep.advanced() ─► NetworkSnapshot
   (if_msghdr2 walk, includes(type:flags:), saturating sums)           (detached task, same iteration as CPU, memory, disk)     │ await
                                                                                                        MetricsState.apply(network:) ─► network + two histories
                                                                                                                       │ @Observable
                                                     PanelRootView(maxHeight) → PanelView.cards → NetworkCard(snapshot, download, upload) ◄┘
                                                        ▲                       rows / readings via NetworkCardModel + ByteFormatter
StatusItemController.togglePopover() ── measure fitting ── PanelLayout.maxHeight(fitting:visibleFrameHeight:) ─┘   graphSeries: shared scale → HistoryGraph(series:)
```

## File Changes

| File | Action | Description |
|---|---|---|
| `system-monitor/Domain/Models/NetworkThroughputCounters.swift` | Create | Counters value with stamp |
| `system-monitor/Domain/Models/NetworkSnapshot.swift` | Create | Totals since boot + optional rate pair |
| `system-monitor/Domain/Ports/NetworkMetricsProvider.swift` | Create | Single-method port (defined before the adapter) |
| `system-monitor/Domain/Services/NetworkThroughputCalculator.swift` | Create | `Rates?` from consecutive counters |
| `system-monitor/Application/MetricsState.swift` | Modify | `network`, two histories, `apply(network:)`, `init` sizing, doc comment (four metrics) |
| `system-monitor/Application/MetricsSampler.swift` | Modify | `NetworkSamplingStep`, `networkProvider`, loop + `sampleOnce()` + `inlineNetworkStep`, doc comments |
| `system-monitor/Infrastructure/System/SysctlNetworkProvider.swift` | Create | `NET_RT_IFLIST2` walk, `includes(type:flags:)`, `ReadError` |
| `system-monitor/App/AppDelegate.swift` | Modify | `networkProvider: SysctlNetworkProvider()` |
| `system-monitor/Presentation/Theme/Palette.swift` | Modify | Three tokens with the sharing notes |
| `system-monitor/Presentation/Components/HistoryGraph.swift` | Modify | `HistoryGraphSeries`, `series:` init, convenience init, `points(series:capacity:size:)`, preview |
| `system-monitor/Presentation/Panel/NetworkCard.swift` | Create | `NetworkCardRow`, `NetworkCardSection`, `NetworkCardModel`, `NetworkCard`, previews (reference, nil) |
| `system-monitor/Presentation/Panel/PanelLayout.swift` | Create | Pure `maxHeight(fitting:visibleFrameHeight:margin:)` and NC-12's `height(fitting:visibleFrameHeight:margin:)` |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modify | `PanelCard.network`, `cards`, `maxHeight`, scroll branch, `PanelRootView`, live preview applies a network snapshot and histories, doc comment |
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | Modify | New stored `hostingController: NSHostingController<PanelRootView>` replacing the inline assignment at `:130-132`; `updatePanelCap()` before `show`; `panelMaxHeight(for:visibleFrameHeight:)` |
| `docs/reference/06-panel-network.png` | Present | Copied by the orchestrator 2026-09-10; apply verifies presence |
| `PRD.md` | Modify | Draft v4 amendment (below) |
| `openspec/config.yaml` | Modify | Rule text F1..F11 / M1..M6; context line Draft v4 |
| `system-monitorTests/Support/FakeNetworkProvider.swift`, `NetworkFixtures.swift` | Create | Double and instant-based fixtures |
| `system-monitorTests/Domain/{NetworkSnapshotTests,NetworkThroughputCalculatorTests,NetworkMetricsProviderPortTests}.swift` | Create | Domain unit |
| `system-monitorTests/Application/{MetricsStateTests,MetricsSamplerTests}.swift` | Modify | `apply(network:)`; step and loop scenarios; defaulted fake in both helpers |
| `system-monitorTests/Application/{SamplingCadenceTests,SettingsStateTests}.swift` | Modify | Inline network fake (compile fix only) |
| `system-monitorTests/Infrastructure/SysctlNetworkProviderTests.swift` | Create | `includes(type:flags:)` truth table, no `.integration` tag |
| `system-monitorTests/Infrastructure/SysctlNetworkIntegrationTests.swift` | Create | `.integration` shape suite in the sandboxed host |
| `system-monitorTests/App/AppDelegateCompositionTests.swift` | Modify | Real graph publishes `network != nil` then rates; modules and widget length unchanged |
| `system-monitorTests/Presentation/{NetworkCardModelTests,HistoryGraphSeriesTests,PanelLayoutTests}.swift` | Create | Model strings/symbols/normalisation; series geometry and equality; cap rule |
| `system-monitorTests/Presentation/{PanelViewTests,StatusItemReadingsTests,CanvasComponentsTests,StatusItemControllerTests}.swift` | Modify | Four-card order/height, capped height, nil-network stability; palette pins; series equality; `panelMaxHeight` with a number |

Unchanged: `MetricModule`, `Settings`, `SettingsView`, `StatusItemView`, `MetricHistory`, `SparklineGeometry`, `Sparkline`, `ThroughputLabel`, `ByteFormatter`, `KeyValueRow`, `RingGauge`, all CPU/memory/disk Domain and Infrastructure, `CPUCard`, `MemoryCard`, `DiskCard`, `project.pbxproj`, every existing spec of record except the `disk-card` delta.

## Test Doubles and Fixtures

```swift
import Synchronization
nonisolated final class FakeNetworkProvider: NetworkMetricsProvider {   // Sendable: only a `let` Mutex
    nonisolated struct ScriptedError: Error, Equatable {}
    nonisolated private struct Script: Sendable {
        var counters: [NetworkThroughputCounters]; var cursor = 0; var throwOnCall: Set<Int>; var callCount = 0
        var readOnMainThread: [Bool] = []
    }
    init(counters: [NetworkThroughputCounters], throwOnCall: Set<Int> = [])
    func readCounters() throws -> NetworkThroughputCounters   // FakeDiskProvider semantics: throw on zero-based indexes (count advances, cursor does not),
                                                              // repeat the last value when exhausted, empty script → NetworkFixtures.idle
    var callCount: Int; var readOnMainThread: [Bool]
}

nonisolated enum NetworkFixtures {
    static let base = ContinuousClock.now
    static func instant(_ seconds: Double) -> ContinuousClock.Instant
    static func counters(in bytesIn: UInt64, out bytesOut: UInt64, interfaceCount: Int = 1, at seconds: Double) -> NetworkThroughputCounters
    static let idle = counters(in: 0, out: 0, interfaceCount: 0, at: 0)
    /// Shared reference fixture of both specs (network-metrics:7, network-card:7): interfaceCount 2 on both halves.
    static let referencePrevious = counters(in: 3_849_995_000, out: 2_759_922_000, interfaceCount: 2, at: 0)
    static let referenceCurrent  = counters(in: 3_850_000_000, out: 2_760_000_000, interfaceCount: 2, at: 1)   // 5.0 kB/s down, 78.0 kB/s up (mockup figures)
    static let referenceSnapshot = NetworkSnapshot(totalIn: 3_850_000_000, totalOut: 2_760_000_000,
                                                   downloadBytesPerSecond: 5_000, uploadBytesPerSecond: 78_000)   // rows "3.85 GB" / "2.76 GB"; NM-3 asserts totalIn == 3_850_000_000 literally
    /// `steps` counters 1 s apart from referencePrevious growing by 5_000 / 78_000 per step (step 1 == referenceCurrent), for loop suites that must never run dry.
    static func climbing(steps: Int = 400) -> [NetworkThroughputCounters]
}
```

## Testing Strategy (strict TDD; unit command `xcodebuild … -only-testing:system-monitorTests`)

Ids are the final ones from `specs/network-metrics/spec.md` (NM-1..13) and `specs/network-card/spec.md` (NC-1..13); tasks MUST bind these ids and scenario names, not the proposal's earlier suggestions.

| Requirement | Test file | Scenarios (fakes, fixtures) |
|---|---|---|
| NM-1 port | `Domain/NetworkMetricsProviderPortTests.swift` | `FakeNetworkProvider` returns scripted values in order; `throwOnCall: [1]` throws on the second call only; empty script reads `idle` |
| NM-2 counters value | `Domain/NetworkSnapshotTests.swift` | Counters equality includes a 1 ms stamp difference; `referencePrevious != referenceCurrent`; memberwise `Sendable` value |
| NM-3 snapshot value | `Domain/NetworkSnapshotTests.swift` | `referenceSnapshot.totalIn == 3_850_000_000`, `totalOut == 2_760_000_000`; hand-built rate pair; both-nil pair; equality |
| NM-4 rate from counters | `Domain/NetworkThroughputCalculatorTests.swift` | `referencePrevious`/`referenceCurrent` → `Rates(5_000, 78_000)`; 0.5 s window → doubled; nil previous, `interfaceCount 0`, Δt 0 and −1 ms, negative in-delta, negative out-delta → nil; re-seeded baseline recovers on the following tick |
| NM-5 same-iteration read, first tick | `Application/MetricsSamplerTests.swift` (step suite, `sampleOnce()`) | First step: `network != nil`, totals `3_849_995_000` / `2_759_922_000` (the `referencePrevious` counters), both rates nil, histories empty; second step: totals `3_850_000_000` / `2_760_000_000`, rates 5_000/78_000, each history count 1; three steps: all four providers' call counts 3; `idle` script → totals 0, rates nil |
| NM-6 restart | `Application/MetricsSamplerTests.swift` (loop suite, `ManualClock`, `climbing()`) | After rates were published, `apply(interval: .seconds(2))` + one iteration → both rates nil; next iteration → non-nil; unchanged interval → rates stay non-nil |
| NM-7 off-main reads | `Application/MetricsSamplerTests.swift` (loop suite) | `everyReadHappensOffTheMainThread` gains `readOnMainThread` all `false` with count ≥ 2 for the network fake |
| NM-8 failure isolation | `Application/MetricsSamplerTests.swift` (step suite) | Throw on call 1 → `network` still the tick-0 snapshot, histories untouched, `cpu != nil`, `disk != nil`; throw on call 1 then success on call 2 → rates nil on call 2 (re-seed), non-nil on call 3 |
| NM-9 state and paired histories | `Application/MetricsStateTests.swift` | `apply(network:)` with rates appends one sample to each history (values 5_000 / 78_000); with nil rates sets `network` and appends nothing; `cpu`, `memory`, `disk` and their histories untouched; `init(historyCapacity: 3)` bounds both |
| NM-10 sysctl adapter (shape, sums saturate) | `Infrastructure/SysctlNetworkIntegrationTests.swift` (`.integration`); `SysctlNetworkProviderTests.swift` (unit) | `readCounters()` succeeds with `interfaceCount >= 1`, `bytesIn > 0`; two reads ≥ 120 ms apart: `bytesIn`/`bytesOut` non-decreasing, stamp advances; 50 consecutive reads succeed; unit: `saturatingSum(UInt64.max, 1) == UInt64.max`, `saturatingSum(1, 2) == 3`, `saturatingSum(UInt64.max - 1, 1) == UInt64.max` |
| NM-11 interface filter seam | `Infrastructure/SysctlNetworkProviderTests.swift` | Parameterised truth table: (0x6, 0x8863) en0 true; (0x6, 0x0) down Ethernet true; (0x6, 0x8) loopback-flagged false; (0xff, 0x0) cellular true; (0x18, 0x8049) lo0 false; (0x1, 0x8051) utun false; (0xd1, 0x8863) bridge false; (0x37, 0x0) gif false; (0x39, 0x0) stf false |
| NM-12 composition root | `App/AppDelegateCompositionTests.swift` (`.integration`) | Real graph eventually publishes `network != nil` then a snapshot with non-nil rates; `MetricModule.allCases == [.cpu, .memory]`; `statusItemLength` unchanged after `apply(network:)` |
| NM-13 PRD alignment | Verify report (document check) | PRD text matches the amendment list below |
| NC-1 contract and placement | `Presentation/PanelViewTests.swift`, `NetworkCardModelTests.swift` | `PanelView.cards == [.cpu, .memory, .disk, .network]` and `Set == allCases`; `NetworkCard(snapshot: referenceSnapshot, downloadHistory:, uploadHistory:)` builds and measures `> 120` |
| NC-2 section order | `Presentation/NetworkCardModelTests.swift` | `sections == [.header, .ratesAndTotals, .graph]` and `Set == allCases` |
| NC-3 header | `Presentation/NetworkCardModelTests.swift` | `title == "Network"`; `headerSymbolName` resolves via `NSImage(systemSymbolName:accessibilityDescription:)` |
| NC-4 rate readings | `Presentation/NetworkCardModelTests.swift` | Readings `["5.0 kB/s", "78.0 kB/s"]` / `"5,0 kB/s"`, `"78,0 kB/s"` with labels `["Download", "Upload"]`; `downloadSymbolName`/`uploadSymbolName` resolve and differ |
| NC-5 total rows | `Presentation/NetworkCardModelTests.swift` | Rows `[Total In 3.85 GB, Total Out 2.76 GB]` / `3,85` / `2,76` (normaliser from `ByteFormatterTests`) |
| NC-6 unavailable rates | `Presentation/NetworkCardModelTests.swift` | Nil rates → `"—"` with `"unavailable"`, totals still formatted |
| NC-7 nil-snapshot skeleton | `Presentation/NetworkCardModelTests.swift`, `PanelViewTests.swift` | Nil snapshot → rows and readings `"—"`; first `apply(network:)` leaves `fittingSize` unchanged |
| NC-8 shared graph scale | `Presentation/NetworkCardModelTests.swift` | `graphScale([5_000], [78_000]) == 78_000`; `graphScale([500], [800]) == 10_000` (floor); `normalised` divides and every value is in 0...1; `graphSeries` returns two series of equal length, colours `networkDownload` then `networkUpload`, `fillOpacity 0`, suffix of 120 |
| NC-9 multi-series graph | `Presentation/HistoryGraphSeriesTests.swift`, `CanvasComponentsTests.swift` | `points(series: [a, b], …) == [SparklineGeometry.points(a…), SparklineGeometry.points(b…)]`; empty series → `[[]]`; `HistoryGraph(samples:capacity:color:) == HistoryGraph(series: [HistoryGraphSeries(samples:color:)], capacity:)`; two-series graphs with equal data compare equal, differing order differ |
| NC-10 palette and chrome | `Presentation/StatusItemReadingsTests.swift`, `NetworkCardModelTests.swift` | `networkAccent == sRGB(0xA66BFF)`; `networkDownload == sRGB(0x3DD68C) == diskAccent`; `networkUpload == sRGB(0x4D8DFF) == cpuAccent`; `networkDownload != networkUpload`; no other distinctness assertion; `NetworkCard.cardPadding == DiskCard.cardPadding`, `sectionSpacing == 14`, `rowSpacing == 6`, `graphHeight == 48` |
| NC-11 four-card height (DC-1, DC-11 delta) | `Presentation/PanelViewTests.swift` | Four snapshots → `height >= cpu + memory + disk + network + fourCardChrome (60)` and `> three-card height`; comment refreshed to the measured four-card value at first GREEN |
| NC-12 scroll cap | `Presentation/PanelLayoutTests.swift`, `PanelViewTests.swift`, `StatusItemControllerTests.swift` | `height(fitting: 1050, visibleFrameHeight: 945) == 921` and `maxHeight(...) == 921`; `height(871, 1132) == 871` and `maxHeight == nil`; `height(921, 945) == 921` and `maxHeight == nil` (exactly at the cap); `maxHeight(1050, 20) == nil` (non-positive cap); custom margin honoured; `PanelView(maxHeight: 600)` fitting height `== 600` while `PanelView()` is `> 600`; controller `panelMaxHeight(for: fourCardState, visibleFrameHeight: 945)` non-nil and `< 945`, with `2000` → nil |
| NC-13 reduce motion | `Presentation/NetworkCardModelTests.swift` | `animation(reduceMotion: true) == nil`; `animation(reduceMotion: false) != nil` and `== CPUCardModel.gaugeAnimation(reduceMotion: false)` |

Existing suites: no test body changes beyond the four helpers, the `everyReadHappensOffTheMainThread` assertions, the `PanelViewTests` comment and the `CanvasComponentsTests` addition.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. The `sysctl` call is an in-process kernel read with no user-controlled input.

## PRD Alignment (Draft v4, owed by apply)

1. Header: Status "Draft v4 (Network card added on 2026-09-10 as F11 / M6; GPU moved to M7)", Date 2026-09-10.
2. Section 1: add the fourth card sentence (download and upload rates, totals since boot, dual-line history); "v1 shipped CPU, RAM and Disk (M5); M6 adds the Network card".
3. Section 2 anti-goals: split the network bullet into "Network beyond the single card: per-interface breakdown, per-process traffic, latency, Wi-Fi signal, VPN accounting, a NET menu bar module (F9, open question 3)" and "Battery, sensors, fans, temperatures"; success metric adds "Network Total In / Total Out match Activity Monitor's Data received / sent within the same order of magnitude".
4. Section 3: F2 "four stacked cards (CPU, Memory, Disk, Network)"; new row `F11 | Network card: download and upload rates, Total In / Total Out since boot, dual-line history graph (section 5.8) | P0 (M6)`; F9 stays Future.
5. Section 4: new 4.6 `06-panel-network.png` describing the globe header, the two badge rows (`5 KB/s` down, `78 KB/s` up), Total In `3,85 GB` / Total Out `2,76 GB`, and the dual-line graph (blue upload above green download); note that the app renders `5,0 kB/s` (R10.5 vocabulary) and that download = green, upload = blue.
6. 5.2: R2.2 order "CPU, Memory, Disk, Network"; new R2.5 "When the panel's fitting height exceeds the presenting screen's visible frame height minus 24 pt, the panel is pinned to that height and its cards scroll; otherwise it keeps its fitting height and never scrolls".
7. 5.5: R5.1 "(CPU, memory, disk, network)"; R5.2 "Disk keeps no history; Network keeps two (download and upload bytes/s), appended together only when both rates are available".
8. New 5.8 Network card (F11): R11.1 scope and source (`sysctl NET_RT_IFLIST2`, `if_msghdr2.ifm_data` 64-bit `ifi_ibytes`/`ifi_obytes`, no entitlement, same source as `netstat -ib`); R11.2 interface filter (`IFT_ETHER` + `IFT_CELLULAR`, not `IFF_LOOPBACK`, no `IFF_UP` requirement; excludes lo0, utun, bridge, gif, stf); R11.3 totals since boot with the interface-recreation caveat; R11.4 rates Δ/Δt with the negative-delta re-seed (R10.4 analogue); R11.5 first tick totals without rates, restart costs one tick; R11.6 a failed read publishes nothing and drops the baseline; R11.7 two 120-sample histories appended together; R11.8 shared graph scale `max(maxDownload, maxUpload, 10 kB/s)`, stroke-only lines; R11.9 formatting reuse (decimal capacity, `/s` throughput, `ThroughputLabel` at 12 pt); R11.10 unavailable states (em dash + "unavailable", skeleton at populated height); R11.11 palette (download green, upload blue, `networkAccent` header) and no menu bar module (`MetricModule` unchanged).
9. 6.1 tree: `Models/` adds `NetworkSnapshot`; `Ports/` adds `NetworkMetricsProvider`; new `Services/` line listing `CPUUsageCalculator`, `MemoryUsageCalculator`, `DiskThroughputCalculator`, `NetworkThroughputCalculator (M6)`; `System/` adds `SysctlNetworkProvider (M6)`; `Panel/` adds `NetworkCard, PanelLayout (M6)`; `Components/` notes `HistoryGraph (multi-series since M6)`; bullet "The Disk card receives only a snapshot; the Network card receives a snapshot and two histories".
10. 6.2: add `NetworkThroughputCounters` and `NetworkSnapshot` with the port comment (`readCounters()`).
11. 6.3: new row "Network throughput | `sysctl {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0}` → `if_msghdr2` → `if_data64.ifi_ibytes/ifi_obytes` | 64-bit, public headers (`NET_RT_IFLIST2` in `sys/socket.h:541`, `RTM_IFINFO2` in `net/route.h:214`, structs in `net/if.h:202` and `net/if_var.h:189`), no entitlement; works in sandbox (`SysctlNetworkIntegrationTests`)"; closing sentence lists sysctl for network.
12. 7.1: rows `networkAccent #A66BFF`, `networkDownload #3DD68C` (same as `memFree`/`diskAccent`), `networkUpload #4D8DFF` (same as `cpuAccent`/`memCached`).
13. 7.3: note "The Network card replaces the gauge-and-rows block with a two-column rates/totals block and keeps the history graph as two lines".
14. Section 8: Domain adds the network Δ/Δt rule and the interface filter; Application adds the first network tick and the paired histories; Infrastructure adds "filter truth table and saturating sum (unit) and `NET_RT_IFLIST2` shape (integration)"; Presentation adds network strings under `en_US`/`de_DE`, the shared graph scale, and the reduce-motion rule (`NetworkCardModel.animation(reduceMotion:)` delegating to the CPU card's, as the Disk card does).
15. Section 9: `M6 | Network | NetworkMetricsProvider port, sysctl adapter, sampler extension, Network card (5.8), panel scroll cap.`; `M7 | GPU (v2) | Section 11.`
16. Section 10: rewrite the popover row as "Popover grows with a fourth card | Four cards (~1050 pt, measured at M6) exceed a 14" display at default scaling (~945 pt visible) | Visible-frame cap with scrolling (R2.5); manual check on the 14" display"; add "Interface churn resets a per-interface counter | Totals dip, a wrapped delta would spike | Negative-delta re-seed (R11.4); documented caveat (R11.3)"; open question 3 answered "Decided 2026-09-10: no Disk or Network menu bar module in v1; F9 stays Future; revisit both together".
17. Section 11: milestone reference "M7".
18. `openspec/config.yaml`: proposal rule "Reference the PRD feature ID (F1..F11) and milestone (M1..M6)"; context line "Product source of truth: PRD.md (Draft v4: v1 = CPU + RAM + Disk; M6 Network (F11) added 2026-09-10; GPU deferred to v2 as M7)".

## Migration / Rollout

No data migration, no feature flag, single PR (`single-pr`, `review_budget_lines: unlimited`). Rollback per proposal: revert the eight modified source files, `PRD.md` and `openspec/config.yaml` to `de40106`, delete the new Domain/Infrastructure/Presentation files, tests and the three spec files (synchronized groups pick up removals; no `project.pbxproj` edit), and drop the defaulted network fake from the four helpers. No persisted setting, `UserDefaults` key, login item or `MetricModule` case is introduced. Reverting only the `PanelRootView`/`PanelLayout` pair restores today's unbounded popover, which still fits three cards.

## Open Questions

- [x] Whether `if_msghdr2`/`if_data64` import through `Darwin` under Swift 6: confirmed by the design gate's compiled probe on this SDK (160-byte `if_msghdr2`, 128-byte `if_data64`, `ifi_ibytes` @64, `ifi_obytes` @72); the offset fallback is a contingency for a future SDK only.
- [ ] `arrow.down.circle.fill`/`arrow.up.circle.fill` resolution on this SDK: settled by the NC-2 test at first RED; fallback pair in decision 6.
- [ ] Exact `networkAccent` sample from the mockup glyph (tolerance rule in decision 8): settled at the palette test's first RED.
- [ ] Measured network card and four-card heights for the `PanelViewTests` comment and PRD section 10: measured at first GREEN.
- [ ] Whether `NSHostingController.rootView` reassignment before `show` re-measures the popover on the same run-loop turn: verified by the manual 14" check; if the first open after a display change lags one open, apply may move the swap into `popoverWillShow` without changing the rule.
