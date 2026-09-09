# Design: Disk Module (PRD M5, "Disk — ship v1")

Proposal: `proposal.md` (Engram `sdd/disk-module/proposal`, id 8268). Spec: `specs/disk-metrics/spec.md` (DM-1..DM-15) and `specs/disk-card/spec.md` (DC-1..DC-11), Engram `sdd/disk-module/spec` (8269). Exploration: `exploration.md` (8266). Pre-proposal: 8267. Engram mirror of this file: `sdd/disk-module/design`. Designed 2026-09-09. Precedents: `archive/2026-09-04-cpu-module/design.md`, `archive/2026-09-06-memory-module/design.md`.

## Technical Approach

Same hexagonal shape as the CPU and Memory modules, approach P1 + T1 + D1 + F1 + S1 (confirmed, not reopened):

- Domain owns `DiskThroughputCounters`, `VolumeCapacity`, `DiskSnapshot`, the two-method `DiskMetricsProvider` port, the pure `DiskThroughputCalculator` (Δbytes/Δt, negative-delta re-seed) and the pure `DiskCapacityCadence` rule. Every instant is a `ContinuousClock.Instant` stamped by the adapter (T1); Domain imports Foundation only (stdlib `Instant` is `Sendable, Hashable, Comparable`).
- Application adds a `DiskSamplingStep` value with cross-tick state (baseline counters, cached capacity, last capacity instant) that lives as a `var` inside the existing single `Task.detached(priority: .utility)` loop and as `inlineDiskStep` for `sampleOnce()`, exactly like `CPUSamplingStep`. `MetricsState` gains `disk: DiskSnapshot?` and `apply(disk:)`, no history.
- Infrastructure adds `IOKitDiskProvider` (`IOBlockStorageDriver` iterator, sums `Statistics` counters, stamps `ContinuousClock.now`) composing `VolumeCapacityReader` (`URLResourceValues` on `/`).
- Presentation follows the `MemoryCardModel`/`MemoryCard` split: a `nonisolated enum DiskCardModel` derives sections, rows, gauge, footer readings and animation; `DiskCard` is a thin switch over `DiskCardModel.sections`; a metric-agnostic `ThroughputLabel` component; `ByteFormatter.capacity`/`throughput`; `Palette.diskAccent`; `PanelView` renders the third card from a pure `cards` array.
- App composition root injects `IOKitDiskProvider(capacity: VolumeCapacityReader())`.

Isolation rule (convention 1): every type below in Domain, Infrastructure, `Presentation/Formatting`, pure model enums, components' constants and test support is explicitly `nonisolated` and `Sendable`, nested types included (`ReadError`, `Rates`, `Script`, fixtures). Only `MetricsState`, `MetricsSampler`, views and controllers are main-actor.

## Component Diagram

```
App/AppDelegate (composition root, @MainActor)
  ├─ MachCPUProvider, MachMemoryProvider, IORegistryCoreTopologyProvider       Infrastructure (nonisolated, Sendable)
  ├─ IOKitDiskProvider(capacity: VolumeCapacityReader())  ← NEW
  ├─ MetricsState (@MainActor @Observable)  + disk, apply(disk:)
  ├─ MetricsSampler(state, cpu, memory, disk ← NEW, topology, …) ──► one Task.detached loop
  └─ StatusItemController(state) → NSPopover → PanelView → CPUCard, MemoryCard, DiskCard(snapshot) ← NEW
                                                                └─ RingGauge, KeyValueRow×3, ThroughputLabel×2 ← NEW

Port (Domain): DiskMetricsProvider     Pure rules (Domain/Services): DiskThroughputCalculator, DiskCapacityCadence
```

## Interfaces / Contracts

All signatures are normative; tasks implement them verbatim.

### Domain (imports Foundation only) — port defined before any adapter

```swift
nonisolated struct DiskThroughputCounters: Sendable, Equatable {
    let bytesRead: UInt64            // cumulative, summed over every IOBlockStorageDriver
    let bytesWritten: UInt64
    let driverCount: Int             // drivers whose Statistics were read; 0 → rates unavailable
    let timestamp: ContinuousClock.Instant   // stamped by the adapter (T1); participates in equality (DM-2)
}

nonisolated struct VolumeCapacity: Sendable, Equatable { let total: UInt64; let free: UInt64 }

nonisolated struct DiskSnapshot: Sendable, Equatable {
    let total: UInt64, free: UInt64
    let used: UInt64                                   // stored; init computes total − free saturating at 0
    let readBytesPerSecond: Double?, writeBytesPerSecond: Double?   // always both nil or both set
    var fraction: Double { total == 0 ? 0 : min(Double(used) / Double(total), 1) }
    init(total: UInt64, free: UInt64, readBytesPerSecond: Double?, writeBytesPerSecond: Double?)
}

nonisolated protocol DiskMetricsProvider: Sendable {
    func readThroughput() throws -> DiskThroughputCounters
    func readCapacity() throws -> VolumeCapacity
}

nonisolated enum DiskThroughputCalculator {
    /// Both rates or neither (DM-4): the optional wraps the pair, so "one without the other" is unrepresentable.
    nonisolated struct Rates: Sendable, Equatable { let readBytesPerSecond: Double; let writeBytesPerSecond: Double }
    /// nil when previous == nil, current.driverCount == 0, Δt <= 0, or either byte delta is negative.
    /// Δt = previous.timestamp.duration(to: current.timestamp) converted to seconds
    /// (Double(components.seconds) + Double(components.attoseconds) / 1e18).
    static func rates(previous: DiskThroughputCounters?, current: DiskThroughputCounters) -> Rates?
}

nonisolated enum DiskCapacityCadence {
    static let minimumInterval: Duration = .seconds(10)
    /// true when lastReadAt == nil or lastReadAt.duration(to: now) >= minimum (DM-5).
    static func shouldRefresh(lastReadAt: ContinuousClock.Instant?, now: ContinuousClock.Instant,
                              minimum: Duration = minimumInterval) -> Bool
}
```

### Application (`@MainActor` classes, `nonisolated` step)

```swift
@MainActor @Observable final class MetricsState {
    private(set) var disk: DiskSnapshot?      // NEW; no history (DM-11)
    func apply(disk snapshot: DiskSnapshot)   // sets disk only
}

/// Stateful counterpart of CPUSamplingStep: baseline counters, cached capacity, instant of the last successful capacity read.
nonisolated struct DiskSamplingStep: Sendable {
    let provider: any DiskMetricsProvider
    let previous: DiskThroughputCounters?
    let capacity: VolumeCapacity?
    let capacityReadAt: ContinuousClock.Instant?
    init(provider: any DiskMetricsProvider)   // fresh step: previous, capacity, capacityReadAt all nil
    func advanced() -> (snapshot: DiskSnapshot?, next: DiskSamplingStep)
}

@MainActor final class MetricsSampler {
    init(state: MetricsState, cpuProvider: any CPUMetricsProvider, memoryProvider: any MemoryMetricsProvider,
         diskProvider: any DiskMetricsProvider,          // NEW, required, no default (decision 5 of the memory design)
         topologyProvider: any CoreTopologyProvider, interval: Duration = .seconds(1),
         startupGap: Duration = .milliseconds(100), clock: any Clock<Duration> = ContinuousClock())
    private var inlineDiskStep: DiskSamplingStep?       // NEW, next to inlineStep
    func sampleOnce()                                   // advances CPU, reads memory, advances disk, applies all three
}
```

`advanced()` algorithm (normative):

1. `guard let current = try? provider.readThroughput()` — on a throw there is no stamp: skip the cadence check and keep `previous`. If `capacity == nil`, attempt `readCapacity()` once; on success return `(snapshot with nil rates, step with capacity set and capacityReadAt still nil)`. Otherwise return `(capacity.map { snapshot with nil rates }, self)` — nothing is published when nothing was ever cached.
2. `var capacity = self.capacity; var readAt = capacityReadAt`. If `DiskCapacityCadence.shouldRefresh(lastReadAt: readAt, now: current.timestamp)`, `try? provider.readCapacity()`; on success set both `capacity` and `readAt = current.timestamp`; on a throw change neither (retry on the next tick, cached values survive).
3. `let rates = DiskThroughputCalculator.rates(previous: previous, current: current)`; `next = DiskSamplingStep(provider, previous: current, capacity, readAt)` — the baseline is always re-seeded with `current` (DM-4).
4. `guard let capacity else { return (nil, next) }`; else `(DiskSnapshot(total: capacity.total, free: capacity.free, readBytesPerSecond: rates?.readBytesPerSecond, writeBytesPerSecond: rates?.writeBytesPerSecond), next)`.

Loop body per iteration: `let (cpuSnapshot, next) = step.advanced(); step = next; let memorySnapshot = memoryStep.read(); let (diskSnapshot, nextDisk) = diskStep.advanced(); diskStep = nextDisk;` then the three `if let … await state.apply(...)` in the order cpu, memory, disk; sleep; `gap = interval`. `var diskStep = DiskSamplingStep(provider: diskProvider)` is created inside the detached closure, so every `start()` — including the one `apply(interval:)` performs — begins with a fresh step: the first tick re-reads capacity (`capacityReadAt == nil`) and re-seeds the baseline, costing one throughput-unavailable tick (DM-8, CM-2 analogue). An unchanged interval is a no-op before `stop()`/`start()`, so the step survives. `sampleOnce()` mirrors the body with `inlineDiskStep ?? DiskSamplingStep(provider: diskProvider)`; like `inlineStep`, it is untouched by `apply(interval:)`.

### Infrastructure (nonisolated, Sendable)

```swift
import IOKit   // class/key names are private literals with header citations (convention 18)
nonisolated struct IOKitDiskProvider: DiskMetricsProvider {
    nonisolated enum ReadError: Error, Equatable {
        case matchingUnavailable            // IOServiceMatching("IOBlockStorageDriver") returned nil
        case ioKitCall(kern_return_t)       // IOServiceGetMatchingServices != KERN_SUCCESS
    }
    private static let driverClass = "IOBlockStorageDriver"      // IOKit/storage/IOBlockStorageDriver.h:41
    private static let statisticsKey = "Statistics"              // :54
    private static let bytesReadKey = "Bytes (Read)"             // :68
    private static let bytesWrittenKey = "Bytes (Write)"         // :82
    private let capacity: VolumeCapacityReader
    init(capacity: VolumeCapacityReader = VolumeCapacityReader())
    func readThroughput() throws -> DiskThroughputCounters   // stamps ContinuousClock.now after the sum
    func readCapacity() throws -> VolumeCapacity             // try capacity.read(); rethrows VolumeCapacityReader.ReadError
}

nonisolated struct VolumeCapacityReader: Sendable {
    nonisolated enum ReadError: Error, Equatable {
        case resourceValues(domain: String, code: Int)   // URL.resourceValues(forKeys:) threw (NSError domain/code, Equatable)
        case missingKey(URLResourceKey)                  // the key was absent from URLResourceValues
        case negativeValue(URLResourceKey)               // Int/Int64 below 0
    }
    private let volumeURL: URL                           // URL(fileURLWithPath: "/") by default
    init(volumeURL: URL = URL(fileURLWithPath: "/"))
    /// Pure conversion seam (DM-13 "Missing or negative value rejected"), unit-tested without touching the file system.
    nonisolated static func capacity(total: Int?, free: Int64?) throws(ReadError) -> VolumeCapacity
    func read() throws -> VolumeCapacity                 // resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) → Self.capacity(total:free:)
}
```

Throughput call shape (from the exploration, same as `IORegistryCoreTopologyProvider`): `IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)` consumes `matching` (never released by the caller); `defer { IOObjectRelease(iterator) }`; `while case let driver = IOIteratorNext(iterator), driver != IO_OBJECT_NULL { defer { IOObjectRelease(driver) } … }`; `IORegistryEntryCreateCFProperty(driver, statisticsKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any]`; a driver without a readable dictionary is skipped and not counted; counters via `(dictionary[key] as? NSNumber)?.uint64Value ?? 0`; sums use `addingReportingOverflow` saturating at `UInt64.max`; `driverCount == 0` returns normally. A NULL iterator with `KERN_SUCCESS` means no match and yields `driverCount == 0`.

### Presentation

```swift
nonisolated enum Palette { static let diskAccent = sRGB(0x3DD68C) }   // same value as memFree; "two tokens, one colour" note as memCached

nonisolated enum ByteFormatter {
    /// ByteCountFormatStyle(style: .decimal, allowedUnits: .all, spellsOutZero: false, includesActualByteCount: false).locale(locale)
    /// on Int64(clamping:). 432_068_000_000 → "432.07 GB" / "432,07 GB"; 512_000_000_000 → "512 GB".
    static func capacity(_ bytes: UInt64, locale: Locale = .current) -> String
    /// Decimal per-second string, see decision 3. 27_100_000 → "27.1 MB/s" / "27,1 MB/s"; 0 → "0 B/s"; 512 → "512 B/s".
    static func throughput(_ bytesPerSecond: Double, locale: Locale = .current) -> String
}

nonisolated struct DiskCardRow: Sendable, Equatable, Identifiable { let key: String; let value: String; var id: String { key } }
nonisolated enum DiskCardSection: Sendable, Equatable, CaseIterable, Identifiable { case header, gaugeAndRows, throughput; var id: Self { self } }
/// Metric-agnostic footer item (Components/ThroughputLabel.swift), like LegendEntry.
nonisolated struct ThroughputReading: Sendable, Equatable, Identifiable {
    let symbolName: String; let accessibilityLabel: String; let text: String; let accessibilityValue: String
    var id: String { accessibilityLabel }
}

nonisolated enum DiskCardModel {
    static let sections: [DiskCardSection] = [.header, .gaugeAndRows, .throughput]
    static let headerSymbolName = "internaldrive"
    static let readSymbolName = "arrow.down.doc", writeSymbolName = "arrow.up.doc"
    static let unavailableText = "\u{2014}", unavailableAccessibilityValue = "unavailable"
    static func rows(for snapshot: DiskSnapshot?, locale: Locale = .current) -> [DiskCardRow]       // Used, Free, Total; "—" each when nil
    static func gaugeText(for snapshot: DiskSnapshot?, locale: Locale = .current) -> String         // PercentFormatter.oneDecimal(fraction); "—" when nil
    static func gaugeFraction(for snapshot: DiskSnapshot?) -> Double                                // fraction, 0 when nil
    static func gaugeAccessibilityValue(for snapshot: DiskSnapshot?, locale: Locale = .current) -> String   // gaugeText, "unavailable" when nil
    static func throughputReadings(for snapshot: DiskSnapshot?, locale: Locale = .current) -> [ThroughputReading]   // read then write
    static func gaugeAnimation(reduceMotion: Bool) -> Animation?                                    // CPUCardModel.gaugeAnimation
}

@MainActor struct ThroughputLabel: View {   // Image(systemName:) in `color` + Text(text).monospacedDigit(), one line, fixedSize horizontal
    let reading: ThroughputReading; let color: Color
    nonisolated static let iconSpacing: CGFloat = 4, iconFontSize: CGFloat = 11, valueFontSize: CGFloat = 12
    // .accessibilityElement(children: .ignore).accessibilityLabel(reading.accessibilityLabel).accessibilityValue(reading.accessibilityValue)
}
@MainActor struct DiskCard: View {           // presentational; ForEach(DiskCardModel.sections) switch → section view
    let snapshot: DiskSnapshot?
    nonisolated static let cardPadding: CGFloat = 16, sectionSpacing: CGFloat = 14, rowSpacing: CGFloat = 6,
                           headerSpacing: CGFloat = 6, headerFontSize: CGFloat = 13, footerSpacing: CGFloat = 16
}

/// Panel card order as a pure array (DC-1 "Card order"), the PanelView analogue of the sections seam.
nonisolated enum PanelCard: Sendable, Equatable, CaseIterable, Identifiable { case cpu, memory, disk; var id: Self { self } }
@MainActor struct PanelView: View { nonisolated static let cards: [PanelCard] = [.cpu, .memory, .disk] }   // body: ForEach(Self.cards) switch
```

`DiskCard` sections: `.header` (`Image(systemName: DiskCardModel.headerSymbolName)` in `diskAccent` + "Disk", `.isHeader`); `.gaugeAndRows` (`HStack`: `RingGauge(fraction, color: diskAccent, valueText: gaugeText, subtitle: "Disk").equatable().accessibilityValue(gaugeAccessibilityValue).animation(gaugeAnimation, value: snapshot?.fraction)` + `VStack(spacing: rowSpacing)` of three `KeyValueRow`s and `Spacer(minLength: 0)`); `.throughput` (`HStack(spacing: footerSpacing)` of `ThroughputLabel(reading:color: diskAccent)` for each reading, then `Spacer`). Chrome copies `MemoryCard` (`padding 16`, `cardBackground` in `RoundedRectangle(cornerRadius: Palette.cardCornerRadius)`). Height is identical for nil and populated snapshots by construction: the same view tree, single-line texts of the same font size, no conditional views.

## Architecture Decisions

| # | Decision | Choice | Rejected alternatives | Rationale |
|---|---|---|---|---|
| 1 | `ReadError` vocabularies | `IOKitDiskProvider.ReadError { matchingUnavailable, ioKitCall(kern_return_t) }`; `VolumeCapacityReader.ReadError { resourceValues(domain:code:), missingKey(URLResourceKey), negativeValue(URLResourceKey) }`; `readCapacity()` rethrows the reader's error unchanged | One shared disk error enum; a `noDrivers` case; wrapping the Foundation error as `any Error` | Each adapter owns its failure vocabulary (`MachCPUProvider`/`MachMemoryProvider` precedent). "No drivers" is a valid reading (`driverCount == 0`, DM-12), not an error, so R10.9's em-dash path never throws. `Equatable` needs value payloads, hence NSError `domain`/`code` instead of the error object. Wrapping the reader error in the IOKit enum would couple the two adapters for nothing: the port is untyped `throws` and the step only distinguishes success from failure. |
| 2 | Cadence on a `readThroughput()` throw | No stamp, so the tick skips the cadence check, keeps `previous`, and publishes the cached capacity with nil rates. If nothing was ever cached it attempts one capacity read and leaves `capacityReadAt == nil` | Read capacity every throwing tick; stamp with `ContinuousClock.now` inside the step; never read capacity without a stamp | DM-10's SHOULDs become MUSTs. A clock call inside the step would make `sampleOnce()` scenarios nondeterministic (convention 19). Reading on every throwing tick violates R10.7. Never reading would leave the card a skeleton for as long as IOKit matching fails, contradicting R10.9 ("capacity keeps rendering"). Cost: under a permanent throw, capacity is read once and refreshed only when throughput recovers (the next stamped tick sees `capacityReadAt == nil` and reads again — one extra read, once). Accepted because the realistic degraded case, sandbox-filtered `Statistics`, yields `driverCount == 0` with a valid stamp and refreshes normally. |
| 3 | Throughput vocabulary and zero | Units `B`, `kB`, `MB`, `GB`, `TB` by 1000-steps with `/s`; the unit is the smallest one whose scaled value rounded to one fraction digit stays below 1000 (999_949 → `999.9 kB/s`, 999_950 → `1.0 MB/s`); `kB` and above carry exactly one fraction digit via `.number.precision(.fractionLength(1)).grouping(.never).locale(locale)`; below 1 kB the integer byte count with no fraction digit (`512 B/s`); zero, negative and NaN input all render `0 B/s`; number, U+0020, unit, `/s` | `Measurement<UnitInformationStorage>`; `ByteCountFormatStyle` output plus `/s`; `0.0 kB/s` for zero | `ByteCountFormatStyle` picks its own fraction digits and has no `/s`. `Measurement` has no per-second unit and would still need the suffix. Lowercase `kB` matches the capacity strings ICU emits next to it. A fractional byte is meaningless and `0 B/s` reads as idle, which is what the value means. The separator is a plain space, so `en_US` and `de_DE` differ only in the decimal separator. |
| 4 | Nil-snapshot "Unavailable" caption | None. The skeleton carries em dashes; the gauge exposes `accessibilityValue` "unavailable" through `DiskCardModel.gaugeAccessibilityValue` and each footer reading "unavailable" per DC-7 | Extra caption text under the gauge; overlaying "Unavailable" on the ring | A caption is a new element whose presence changes height or needs an overlay hack; DC-8 demands height parity. The em dash is already the app's unavailable glyph and R10.9's "Unavailable state" is satisfied for assistive technology by the accessibility values, which VoiceOver reads instead of "em dash". |
| 5 | `ThroughputLabel` geometry | `iconSpacing 4`, `iconFontSize 11`, `valueFontSize 12` (monospaced digits, `lineLimit(1)`, `fixedSize(horizontal: true)`); `DiskCard.footerSpacing 16`; constants `nonisolated static` internal | Reuse `KeyValueRow`; a fixed value width | `KeyValueRow` is key-left/value-right, the footer is icon-then-value left-aligned. The icon size follows `SegmentLegend.labelFontSize` (11) and the value follows `KeyValueRow.fontSize` (12), so the footer reads as the rows' sibling. No fixed width: the popover does not jitter because nothing to its right depends on the label width. Internal statics let DC-9 pin chrome parity as values. |
| 6 | SF Symbols | Header `internaldrive`; read `arrow.down.doc`, write `arrow.up.doc`; fallback pair `arrow.down.circle`/`arrow.up.circle` if the first RED resolution test fails | Same document glyph twice (reference); `arrow.down`/`arrow.up` | The document glyphs echo the reference while the arrow direction fixes the R10.6 legibility defect; read = data leaving the disk (down, like a download), write = data entering it. Resolution is machine-verified by `NSImage(systemSymbolName:accessibilityDescription:)` in DC-3/DC-7 tests, never assumed. |
| 7 | Disk step state | `DiskSamplingStep` value (`previous`, `capacity`, `capacityReadAt`) created inside the detached closure and as `inlineDiskStep`; `advanced()` returns `(snapshot, next)` | State stored on the sampler and shared with the loop; a Domain "step" | Same two homes as `CPUSamplingStep` (exploration); values crossing into the task stay `Sendable` and the restart semantics of DM-8 fall out of "a new task builds a new step" without extra code in `apply(interval:)`. The step is Application, not Domain: it orchestrates two port calls and holds cross-tick state. |
| 8 | Capacity failure after success | Keep cached values; `capacityReadAt` unchanged, so the read is retried on the next tick | Stamp on failure (back off 10 s) | R10.7 exists for the cost of successful important-usage queries; a failing Foundation call on `/` is not expected in practice, and retrying restores freshness sooner. One rule for both the never-succeeded and the cached case keeps `advanced()` simple. |
| 9 | Where the pure rules live | `Domain/Services/DiskThroughputCalculator.swift` returning `Rates?`; `Domain/Services/DiskCapacityCadence.swift` with `shouldRefresh(lastReadAt:now:minimum:)` | Two optionals on the calculator; the cadence as a static on the step | The optional pair makes DM-4's "never one without the other" a type guarantee. Both rules are Domain because they are pure over Domain values (PRD 8 asks for unit tests without hardware); the step only sequences them. |
| 10 | `used` and `fraction` on `DiskSnapshot` | `used` stored, computed once in `init` saturating; `fraction` computed with the `total == 0` guard and the cap at 1 | Computed `used` | Matches `MemorySnapshot` (stored `used`) and keeps `Equatable` memberwise; the saturating subtraction lives in one initialiser instead of every read. |
| 11 | Card and panel order seams | `DiskCardModel.sections` (S1, confirmed) and a new `PanelView.cards: [PanelCard]` | Hard-coded order in `PanelView.body` | DC-1 "Card order" becomes an array assertion, the same mechanism MC-7 uses; the body is a switch, so it cannot drift. |
| 12 | Composition of the capacity reader | `IOKitDiskProvider` composes a `VolumeCapacityReader` (default argument in Infrastructure) | Sampler reads capacity through a second port | P1 (confirmed): one init parameter, one fake. A default argument inside Infrastructure does not cross the hexagonal boundary. |
| 13 | Fake defaults in the four helpers | `diskProvider: FakeDiskProvider = FakeDiskProvider(throughput: [], capacities: [DiskFixtures.referenceCapacity])` added as a defaulted parameter to both `makeSampler` helpers in `MetricsSamplerTests.swift` (`:19`, `:307`) and inline in `SamplingCadenceTests.swift:98` and `SettingsStateTests.swift:296` in the same RED step as the init change | Optional `diskProvider` with a nil branch; a default in Application | The compile break is by construction; an empty throughput script reads `DiskFixtures.idle` (`driverCount 0`), so every existing scenario keeps its CPU and memory expectations while disk publishes capacity with nil rates. No production code gains a branch. |

## Concurrency Design

| Concern | Decision |
|---|---|
| Values crossing into the detached task | `any DiskMetricsProvider` (Sendable protocol) added to the captures; no `self`. `DiskSnapshot` is the only new value hopping back to the main actor via `await state.apply(disk:)`. |
| `DiskSamplingStep` | `Sendable` by construction: an existential of a `Sendable` protocol plus `Sendable` values (`ContinuousClock.Instant` is stdlib `Sendable`). Lives as a local `var` in the closure and as a main-actor stored property for `sampleOnce()`. |
| Adapters | `IOKitDiskProvider` stores one `let` struct; `VolumeCapacityReader` stores one `let URL`; both structs are `Sendable`. `ContinuousClock.now` is read on the utility task inside `readThroughput()`. IOKit handles never escape the call (convention 17). |
| Nested types | `IOKitDiskProvider.ReadError`, `VolumeCapacityReader.ReadError`, `DiskThroughputCalculator.Rates`, `FakeDiskProvider.Script`/`ScriptedError` all carry explicit `nonisolated`. |
| Errors | `advanced()` swallows both reads with `try?`; the loop never exits on a disk failure and the CPU and memory steps are unaffected (DM-10). `ReadError`s exist for the `.integration` suites, the pure `capacity(total:free:)` seam and direct callers. |
| Tests | Never `@MainActor`; `FakeDiskProvider` uses `Synchronization.Mutex`, zero-based `throwThroughputOnCall`/`throwCapacityOnCall`, records `Thread.isMainThread` for both reads into one `readOnMainThread` list. Loop suites stay on `ManualClock`; rate and cadence scenarios run through `sampleOnce()` with scripted instants (convention 19). |

## Data Flow

```
IOBlockStorageDriver ──IOKitDiskProvider.readThroughput()──► DiskThroughputCounters(stamp) ─┐
URLResourceValues("/") ──VolumeCapacityReader.read()──► VolumeCapacity (≤ every 10 s) ──────┼─► DiskSamplingStep.advanced() ─► DiskSnapshot?
                                                                    (detached task, same iteration as CPU and memory)      │ await
                                                                                                        MetricsState.apply(disk:) ─► disk (no history)
                                                                                                                       │ @Observable
                                                                                            PanelView.cards → DiskCard ◄┘
                                                                                     rows / gauge / readings via DiskCardModel + ByteFormatter
```

## File Changes

| File | Action | Description |
|---|---|---|
| `system-monitor/Domain/Models/DiskThroughputCounters.swift` | Create | Counters value with stamp |
| `system-monitor/Domain/Models/VolumeCapacity.swift` | Create | Capacity value |
| `system-monitor/Domain/Models/DiskSnapshot.swift` | Create | Snapshot with stored saturating `used`, guarded `fraction` |
| `system-monitor/Domain/Ports/DiskMetricsProvider.swift` | Create | Two-method port (defined before the adapter) |
| `system-monitor/Domain/Services/DiskThroughputCalculator.swift` | Create | `Rates?` from consecutive counters |
| `system-monitor/Domain/Services/DiskCapacityCadence.swift` | Create | `shouldRefresh` rule, 10 s default |
| `system-monitor/Application/MetricsState.swift` | Modify | `disk`, `apply(disk:)`, doc comment |
| `system-monitor/Application/MetricsSampler.swift` | Modify | `DiskSamplingStep`, `diskProvider`, loop + `sampleOnce()` + `inlineDiskStep`, doc comments (three providers, restart note) |
| `system-monitor/Infrastructure/IOKit/IOKitDiskProvider.swift` | Create | Iterator adapter + `ReadError`, composes the reader |
| `system-monitor/Infrastructure/System/VolumeCapacityReader.swift` | Create | Reader + `ReadError` + static `capacity(total:free:)` seam |
| `system-monitor/App/AppDelegate.swift` | Modify | `diskProvider: IOKitDiskProvider(capacity: VolumeCapacityReader())` |
| `system-monitor/Presentation/Theme/Palette.swift` | Modify | `diskAccent` with the "two tokens, one colour" note |
| `system-monitor/Presentation/Formatting/ByteFormatter.swift` | Modify | `capacity(_:locale:)`, `throughput(_:locale:)`; doc comment widened beyond memory |
| `system-monitor/Presentation/Components/ThroughputLabel.swift` | Create | `ThroughputReading`, `ThroughputLabel`, preview |
| `system-monitor/Presentation/Panel/DiskCard.swift` | Create | `DiskCardRow`, `DiskCardSection`, `DiskCardModel`, `DiskCard`, previews (reference, nil) |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modify | `PanelCard`, `cards`, switch body, `DiskCard(snapshot: state.disk)`; live preview applies a disk snapshot |
| `PRD.md` | Modify | See PRD alignment |
| `system-monitorTests/Support/FakeDiskProvider.swift`, `DiskFixtures.swift` | Create | Double and instant-based fixtures |
| `system-monitorTests/Domain/{DiskSnapshotTests,DiskThroughputCalculatorTests,DiskCapacityCadenceTests,DiskMetricsProviderPortTests}.swift` | Create | Domain unit |
| `system-monitorTests/Application/{MetricsStateTests,MetricsSamplerTests}.swift` | Modify | `apply(disk:)`; disk step and loop scenarios; defaulted fake in both helpers |
| `system-monitorTests/Application/{SamplingCadenceTests,SettingsStateTests}.swift` | Modify | Inline disk fake in `makeSampler` (compile fix only) |
| `system-monitorTests/Infrastructure/VolumeCapacityReaderTests.swift` | Create | Pure `capacity(total:free:)` seam, no `.integration` tag |
| `system-monitorTests/Infrastructure/{IOKitDiskIntegrationTests,VolumeCapacityIntegrationTests}.swift` | Create | `.integration` shape suites in the sandboxed host |
| `system-monitorTests/App/AppDelegateCompositionTests.swift` | Modify | DM-14 disk publish and unchanged modules/widget length |
| `system-monitorTests/Presentation/{DiskCardModelTests,ThroughputFormatterTests}.swift` | Create | Model, symbols, formatting under `en_US`/`de_DE` |
| `system-monitorTests/Presentation/{ByteFormatterTests,PanelViewTests,StatusItemReadingsTests}.swift` | Modify | Capacity strings; three-card height, nil-disk stability, `cards` order, refreshed 678 pt comment; `diskAccent` token value next to the other palette pins |

Unchanged: `MetricModule`, `Settings`, `SettingsView`, `StatusItemView/Controller`, `MetricHistory`, all CPU/memory Domain and Infrastructure, `RingGauge`, `KeyValueRow`, `HistoryGraph`, `StackedBar`, `SegmentLegend`, `project.pbxproj`, every existing spec of record.

## Test Doubles and Fixtures

```swift
import Synchronization
nonisolated final class FakeDiskProvider: DiskMetricsProvider {          // Sendable: only a `let` Mutex
    nonisolated struct ScriptedError: Error, Equatable {}
    nonisolated private struct Script: Sendable {
        var throughput: [DiskThroughputCounters]; var throughputCursor = 0; var throwThroughputOnCall: Set<Int>; var throughputCallCount = 0
        var capacities: [VolumeCapacity]; var capacityCursor = 0; var throwCapacityOnCall: Set<Int>; var capacityCallCount = 0
        var readOnMainThread: [Bool] = []       // Thread.isMainThread at every read of either kind
    }
    init(throughput: [DiskThroughputCounters], capacities: [VolumeCapacity],
         throwThroughputOnCall: Set<Int> = [], throwCapacityOnCall: Set<Int> = [])
    func readThroughput() throws -> DiskThroughputCounters   // FakeMemoryProvider semantics per kind: throw on zero-based indexes (count advances,
    func readCapacity() throws -> VolumeCapacity             // cursor does not), repeat the last value when exhausted, empty script → DiskFixtures.idle / .referenceCapacity
    var throughputCallCount: Int; var capacityCallCount: Int; var readOnMainThread: [Bool]
}

nonisolated enum DiskFixtures {
    static let base = ContinuousClock.now                                    // every stamp derives from one base; only differences matter
    static func instant(_ seconds: Double) -> ContinuousClock.Instant         // base.advanced(by: .seconds(seconds))
    static func counters(read: UInt64, written: UInt64, driverCount: Int = 1, at seconds: Double) -> DiskThroughputCounters
    static let idle = counters(read: 0, written: 0, driverCount: 0, at: 0)  // empty-script value: rates nil, no driver
    static let referenceCapacity = VolumeCapacity(total: 494_354_000_000, free: 62_286_000_000)   // used 432_068_000_000, fraction 0.87401…
    static let referencePrevious = counters(read: 1_000_000_000, written: 500_000_000, at: 0)
    static let referenceCurrent  = counters(read: 1_027_100_000, written: 502_200_000, at: 1)     // 27.1 MB/s read, 2.2 MB/s write
    static let referenceSnapshot = DiskSnapshot(total: 494_354_000_000, free: 62_286_000_000,
                                                readBytesPerSecond: 27_100_000, writeBytesPerSecond: 2_200_000)
    /// `steps` counters 1 s apart growing by 27_100_000 / 2_200_000 per step, for loop suites that must never run dry.
    static func climbing(steps: Int = 400) -> [DiskThroughputCounters]
}
```

## Testing Strategy (strict TDD; unit command `xcodebuild … -only-testing:system-monitorTests`)

| Requirement | Test file | Scenarios (fakes, fixtures) |
|---|---|---|
| DM-1 | `Domain/DiskMetricsProviderPortTests.swift` | `FakeDiskProvider` returns scripted values per kind in order; `throwThroughputOnCall: [0]`, `throwCapacityOnCall: [1]` fail independently |
| DM-2, DM-3 | `Domain/DiskSnapshotTests.swift` | Counters equality includes a 1 ms stamp difference; `referenceCapacity` → `used 432_068_000_000`, `fraction ≈ 0.874`; free > total → `used 0`; total 0 → `fraction 0` (no NaN); free 0 → `fraction 1`; hand-built `used > total` caps at 1 |
| DM-4 | `Domain/DiskThroughputCalculatorTests.swift` | `referencePrevious`/`referenceCurrent` → `Rates(27_100_000, 2_200_000)`; 0.5 s → 54_200_000; nil previous, `driverCount 0`, Δt 0 and −1 ms, negative read, negative write → nil; re-seeded baseline recovers (+1_000 over 1 s → 1_000) |
| DM-5 | `Domain/DiskCapacityCadenceTests.swift` | nil → true; 9.999 s and 0 s → false; 10 s → true; custom `minimum` honoured |
| DM-6, DM-7, DM-10 | `Application/MetricsSamplerTests.swift` (step suite, `sampleOnce()`) | First step: `disk != nil`, both rates nil, `memory != nil`, `cpu == nil`; second step with `referenceCurrent`: `readBytesPerSecond == 27_100_000`, `cpu != nil`; 3 steps: all three call counts 3; stamps 0/1/2/9.999 → `capacityCallCount 1`, then 10/11 with a second capacity → 2 and the last two snapshots carry it; throughput throw on call 1 → tick-0 capacity with nil rates, `cpu != nil`; throughput throw on the 10 s tick → capacity count unchanged, grows on the next; capacity throws on 0 and 1 → `disk == nil`, `memory != nil`; capacity succeeds on 0, throws on 1 with stamps 0/10 → second snapshot keeps call-0 capacity with non-nil rates; CPU throw on 0 → `disk != nil`; design extra (decision 2): throughput throws on call 0 with nothing cached → `capacityCallCount 1`, `disk` carries capacity with nil rates, and the next successful tick reads capacity again and stamps |
| DM-8, DM-9 | `Application/MetricsSamplerTests.swift` (loop suite, `ManualClock`, `climbing()` script, two capacities) | Restart: after rates were published, `apply(interval: .seconds(2))` + one iteration → both rates nil and `capacityCallCount` +1; next iteration → non-nil rates (mirrors `aRestartCostsOnePublishFreeCPUTickAndNoMemoryGap`); unchanged interval → rates non-nil, capacity count unchanged; `everyReadHappensOffTheMainThread` gains `readOnMainThread` all `false` with count ≥ 2 for the disk fake |
| DM-11 | `Application/MetricsStateTests.swift` | Two applies keep the second; `cpu`, `memory`, both histories untouched; no disk history member exists (compile-level) |
| DM-12 | `Infrastructure/IOKitDiskIntegrationTests.swift` (`.integration`) | `driverCount >= 1`, `bytesRead > 0`; two reads ≥ 120 ms apart monotonic with advancing stamps; 50 consecutive reads succeed |
| DM-13 | `Infrastructure/VolumeCapacityReaderTests.swift` (unit) and `VolumeCapacityIntegrationTests.swift` (`.integration`) | `capacity(total: nil, free: 1)` → `.missingKey(.volumeTotalCapacityKey)`, `capacity(total: 1, free: nil)` → `.missingKey(.volumeAvailableCapacityForImportantUsageKey)`, negative either → `.negativeValue`; real read: `total > 0`, `0 < free <= total`, `free >= volumeAvailableCapacity`; `IOKitDiskProvider(capacity:).readCapacity().total == reader.read().total` |
| DM-14 | `App/AppDelegateCompositionTests.swift` (`.integration`) | Real graph eventually publishes `disk != nil`; `MetricModule.allCases == [.cpu, .memory]`; `statusItemLength` unchanged |
| DM-15 | Verify report (manual document check) | PRD text matches the alignment list below |
| DC-1 | `Presentation/PanelViewTests.swift`, `DiskCardModelTests.swift` | `PanelView.cards == [.cpu, .memory, .disk]`; `DiskCard(snapshot: referenceSnapshot)` builds; `apply(disk:)` with fraction 0.874 → gauge text `"87.4%"` |
| DC-2, DC-3, DC-4, DC-7, DC-8 (model), DC-10 | `Presentation/DiskCardModelTests.swift` | `sections == [.header, .gaugeAndRows, .throughput]` and `Set == allCases`; `"87.4%"`, `"100.0%"`, `"87,4%"`; `headerSymbolName`, `readSymbolName`, `writeSymbolName` resolve via `NSImage(systemSymbolName:accessibilityDescription:)` and read != write; rows `[Used 432.07 GB, Free 62.29 GB, Total 494.35 GB]` / `432,07`, `62,29`, `494,35`; readings `["27.1 MB/s", "2.2 MB/s"]` with labels `["Read", "Write"]`; nil rates → `"—"` with `"unavailable"`; nil snapshot → gauge `"—"`, fraction 0, `gaugeAccessibilityValue == "unavailable"`, rows `"—"`, readings `"—"`; `gaugeAnimation(true) == nil`, `gaugeAnimation(false) == CPUCardModel.gaugeAnimation(reduceMotion: false)` |
| DC-5 | `Presentation/ByteFormatterTests.swift` | `capacity`: `"432.07 GB"`, `"432,07 GB"`, `"512 GB"`, `"62.29 GB"`, zero starts with `"0"`, `UInt64.max` formats; normaliser reused |
| DC-6 | `Presentation/ThroughputFormatterTests.swift` | `"27.1 MB/s"`, `"2.2 MB/s"`, `"27,1 MB/s"`, `"1.0 GB/s"`, `"1,0 GB/s"`, `"0 B/s"` (both locales), `"512 B/s"`, `"999.9 kB/s"`, `"1.0 MB/s"` for 999_950, `"1.0 TB/s"`, negative and NaN → `"0 B/s"` |
| DC-8 (height), DC-11 | `Presentation/PanelViewTests.swift` | CPU + memory applied, `disk == nil` → first `apply(disk:)` leaves `fittingSize` unchanged; three snapshots → `height >= cpu + memory + disk + chrome`, `> 620`, greater than the two-card height; disk card height `> 120`; comment refreshed to the measured three-card value at first GREEN |
| DC-9 | `Presentation/StatusItemReadingsTests.swift` (token pins), `DiskCardModelTests.swift` | `Palette.diskAccent == sRGB(0x3DD68C)` and `== Palette.memFree`; `DiskCard.cardPadding == 16`, `sectionSpacing == 14`, `rowSpacing == 6` |
| `ThroughputLabel` | `Presentation/DiskCardModelTests.swift` | Constants `iconSpacing 4`, `iconFontSize 11`, `valueFontSize 12`; views covered by `#Preview` |

Existing suites: no test body changes beyond the four helpers, the `everyReadHappensOffTheMainThread` assertions and the `PanelViewTests` comment.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary.

## PRD Alignment (owed by apply, DM-15)

1. Section 6.2: replace `DiskCounters` with `DiskThroughputCounters` (`bytesRead`, `bytesWritten`, `driverCount`, `timestamp`) and `VolumeCapacity` (`total`, `free`) behind `readThroughput()`/`readCapacity()`; `DiskSnapshot` gains the saturating `used` note and the `total == 0` guard on `fraction`.
2. R10.5: `ByteCountFormatStyle(style: .file)` becomes `.decimal` (same output today; the header reserves the right to change `.file`).
3. Section 6.3, Disk throughput row: replace "Unverified under App Sandbox (v1 is not sandboxed)" with "Works in sandbox: the app target sets `ENABLE_APP_SANDBOX = YES` (`project.pbxproj:401,435`) and the `.integration` suite `IOKitDiskIntegrationTests` proves statistics access inside the sandboxed test host"; the capacity row gains "Works in sandbox (`VolumeCapacityIntegrationTests`)".
4. Section 10, "Popover grows with a third card" row: record the measured heights (two cards 678 pt; three cards ≈ 850–870 pt, pinned at first GREEN) and that the popover still fits a 14" display.

## Migration / Rollout

No data migration, no feature flag, single PR (`single-pr`). Rollback per proposal: revert the seven modified source files and `PRD.md` to `9e77e42`, delete the new Domain/Infrastructure/Presentation files, tests and the two capability specs (synchronized groups pick up removals; no `project.pbxproj` edit), and drop the defaulted disk fake from the four helpers. No persisted setting, `UserDefaults` key, login item or `MetricModule` case is introduced.

## Open Questions

- [ ] Exact ICU string for `ByteFormatter.capacity(0)` under `en_US`/`de_DE`: pinned at the first RED (memory precedent), not assumed.
- [ ] `arrow.down.doc`/`arrow.up.doc` resolution on this SDK: settled by the DC-7 test at the first RED; fallback pair in decision 6.
- [ ] Whether `import IOKit.storage` compiles under Swift 6 (would let the four literals become SDK constants): settled at the adapter's first compile; literals stay the default (convention 18).
- [ ] Three-card measured height for the `PanelViewTests` comment and the PRD section 10 note: measured at first GREEN.
