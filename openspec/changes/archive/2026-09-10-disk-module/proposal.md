# Proposal: Disk Module (PRD M5, "Disk — ship v1")

Engram mirror: topic `sdd/disk-module/proposal` (observation 8268). Proposed 2026-09-06.

Serves PRD feature F10 (Disk card) and R10.1–R10.11, R2.2 (third card in the CPU, Memory, Disk order), R5.1 (one `MetricsSampler` drives every provider), R5.3; PRD sections 4.5, 6.1, 6.2, 6.3, 7.1 (`diskAccent`), 7.3, 8, 10. Milestone M5, ships v1. Exploration: `exploration.md` (Engram `sdd/disk-module/explore`, id 8266). Research: unselected (the IOKit, Foundation and sandbox facts are header-verified in the exploration). Pre-proposal decisions confirmed in Engram `sdd/disk-module/pre-proposal` (id 8267) on 2026-09-06; product decisions rest on the approved PRD Draft v3 section 5.7.

## Intent

After M4 the panel shows CPU and Memory only; PRD Draft v3 made Disk the third and last v1 card (F10, M5) and no disk type, port, adapter or view exists (`MetricModule`, `MetricsState`, `PanelView` know nothing about disk). Users cannot see whether the boot volume is filling up or whether the machine is I/O bound. This change makes Disk live end to end: a sandboxed IOKit adapter summing `IOBlockStorageDriver` byte counters, a Foundation adapter reading the boot volume's Finder-aligned capacity, pure Domain math for used/fraction and delta-to-rate with the negative-delta re-seed, a disk step inside the existing sampler loop (throughput every tick, capacity at most every 10 s), `MetricsState.disk`, and a Disk card (ring gauge, Used/Free/Total rows, read/write throughput footer, no graph). Success: Total and Free match Finder within 100 MB on the dev machine (PRD 2), average CPU stays under 1% (PRD 10), and the 527 existing tests stay green.

## Scope

### In Scope
- Domain: `DiskThroughputCounters` (`bytesRead`, `bytesWritten` summed `UInt64`, `driverCount`, `timestamp: ContinuousClock.Instant`), `VolumeCapacity` (`total`, `free`), `DiskSnapshot` (PRD 6.2: `total`, `free`, `used = total − free` saturating, `readBytesPerSecond: Double?`, `writeBytesPerSecond: Double?`, `fraction` 0 for `total == 0` and capped at 1), `DiskMetricsProvider` port (`readThroughput() throws -> DiskThroughputCounters`, `readCapacity() throws -> VolumeCapacity`), pure `DiskThroughputCalculator`, pure capacity cadence rule (`shouldRefresh(lastReadAt:now:minimum: .seconds(10))`).
- Application: `DiskSamplingStep` value (`previous` counters, cached `capacity`, `capacityReadAt`) kept as a `var` in the detached loop and as `inlineDiskStep` for `sampleOnce()`, exactly like `CPUSamplingStep`; `MetricsSampler` gains `diskProvider:`; disk is read in the same iteration as CPU and memory before any publish (R5.1); `MetricsState.disk: DiskSnapshot?` + `apply(disk:)`, no history (R10.8, R5.2).
- Infrastructure: `IOKitDiskProvider` (`Infrastructure/IOKit`) iterating `IOServiceMatching("IOBlockStorageDriver")`, summing `Statistics` → `Bytes (Read)` / `Bytes (Write)` across drivers and stamping `ContinuousClock.now`, typed `ReadError`; `VolumeCapacityReader` (`Infrastructure/System`) over `URLResourceValues` on `/` with `.volumeTotalCapacityKey` and `.volumeAvailableCapacityForImportantUsageKey`, typed error for a missing key or negative value; `IOKitDiskProvider` composes the reader for `readCapacity()`.
- Presentation: `DiskCard` + `nonisolated enum DiskCardModel` (ordered `sections`, rows Used/Free/Total, gauge text and fraction, read/write texts with em dash and "unavailable" accessibility label, distinct read/write symbol names, `gaugeAnimation` delegating to `CPUCardModel`); `ThroughputLabel` component (icon + value, `accessibilityLabel` "Read"/"Write"); `Palette.diskAccent = sRGB(0x3DD68C)`; `ByteFormatter.capacity(_:locale:)` on `.decimal` and `ByteFormatter.throughput(_:locale:)` (one fraction digit, `/s`); `PanelView` renders `DiskCard(snapshot: state.disk)` after `MemoryCard` (R2.2); previews.
- App: composition root constructs `IOKitDiskProvider(capacity: VolumeCapacityReader())` and passes it to the sampler.
- PRD alignment task (like MM-10): 6.2 `DiskCounters` becomes `DiskThroughputCounters` + `VolumeCapacity` with the two-method port; R10.5 `.file` becomes `.decimal`; 6.3 "Unverified under App Sandbox (v1 is not sandboxed)" is corrected once the `.integration` suite proves access (the app target has `ENABLE_APP_SANDBOX = YES`); section 10 notes the popover height growth.
- Tests per the exploration test plan: Domain, Application (`sampleOnce()` with scripted instants), Infrastructure `.integration` shape suites, Presentation (`en_US`/`de_DE`), `Support/{FakeDiskProvider,DiskFixtures}`; strict TDD.
- Specs: two new capability specs `disk-metrics` and `disk-card`.

### Out of Scope
- Disk menu bar module, any `MetricModule` or settings change (R10.11, PRD open question 3). History graph or ring buffer for disk (R10.8). Amber-to-green gradient ring (P2, R10.10). GPU (PRD 11, v2). Per-volume breakdown, external drives as cards, per-process I/O, SMART (PRD 2 anti-goals). Making `MetricsSampler` generic over `Clock` (T3). Deltas to any existing spec of record. Any `project.pbxproj` edit.

## Capabilities

### New Capabilities
- `disk-metrics` (suggested ids `DM-n`): `DiskMetricsProvider` port and its two reads, `DiskThroughputCounters`/`VolumeCapacity`/`DiskSnapshot` invariants, `DiskThroughputCalculator` (Δbytes/Δt, nil on first sample, `driverCount == 0`, `Δt <= 0`, or any negative delta with baseline re-seed, R10.3/R10.4), 10 s capacity cadence owned by the sampler step (R10.7), first-tick and restart semantics, failure isolation (R10.9), same-iteration read (R5.1), off-main read (R5.3), `MetricsState.disk` with no history (R10.8), IOKit and Foundation adapter shape.
- `disk-card` (suggested ids `DC-n`): layout per 4.5/7.3 (header with internal-drive glyph, ring gauge with sublabel `Disk`, rows Used/Free/Total, throughput footer read then write with differing icons and "Read"/"Write" labels, no graph), decimal capacity and `MB/s` formatting under `en_US`/`de_DE`, em dash + "unavailable" for nil rates, nil-snapshot skeleton at the populated height, `diskAccent`, reduce-motion animation rule.

### Modified Capabilities
- None. `menu-bar-widget`, `settings`, `launch-at-login` are untouched (R10.11); `cpu-metrics`/`memory-metrics` loop requirements hold unchanged because the disk read joins the iteration without altering CPU or memory publish rules.

## Approach

Exploration recommendation P1 + T1 + D1 + F1 + S1, confirmed by the pre-proposal handoff:
- **P1 one port, two methods.** `readThroughput()` and `readCapacity()` on one `DiskMetricsProvider`, adapter composing `VolumeCapacityReader`. The sampler owns the 10 s cadence (PRD 8 asks for an Application test of it), each half fails independently (R10.9), there is one init parameter and one fake scripting both halves. P2 (two ports) would add two init parameters and helpers; P3 (PRD-literal single `DiskCounters`) forces the cadence into an untestable adapter cache or violates R10.7.
- **T1 adapter-stamped `ContinuousClock.Instant`.** The throughput adapter stamps every read; the Domain rate is Δbytes/Δt between consecutive stamps and the cadence compares the stamp with `capacityReadAt`. No restructuring of the existential `any Clock<Duration>` loop; fakes script instants derived from one `ContinuousClock.now` base (only differences matter), so tests never sleep. `Instant` is stdlib `Sendable, Hashable, Comparable`, so the Domain "Foundation only" rule holds.
- **D1 sum over every `IOBlockStorageDriver`** (R10.1/R10.3, Activity Monitor Disk tab, same counters as `iostat`). Disk images and external drives count; eject/mount produces a negative delta handled by R10.4. D2 (boot disk only) needs the APFS container-to-physical-store walk and is not worth it.
- **F1 `.decimal` capacity.** Same output as `.file` today (swift-foundation maps both to decimal) without the header's "may change" caveat; one-word PRD amendment. Throughput: decimal units `kB`/`MB`/`GB`/`TB`, one fraction digit, `/s` suffix; below 1 kB `B/s` with no fraction digit. Design may refine the vocabulary and the zero string but MUST pin `en_US` and `de_DE`.
- **S1 `DiskCardModel.sections`** ordered array (`header`, `gaugeAndRows`, `throughput`) mirroring `MemoryCardModel`, so vertical order is a pure-array assertion and the view stays a switch; `gaugeAnimation` delegates to `CPUCardModel` (MC-10 precedent).
- **Sampling semantics** (spec MUST state each): tick one after `start()` publishes capacity with both rates nil (R10.3 last sentence; MM-5 first-iteration precedent applies to capacity). An `apply(interval:)` restart builds a fresh `DiskSamplingStep`: the first tick of the new loop re-reads capacity and re-seeds the throughput baseline, costing one throughput-unavailable tick (the analogue of CM-2's publish-free CPU tick). A negative read or write delta makes both rates nil for that tick and re-seeds the baseline with the current counters (R10.4). The capacity read happens when `capacityReadAt == nil` or the current stamp is at least 10 s later; the cached `VolumeCapacity` is reused otherwise (R10.7).
- **Failure isolation** (MM-7 analogue): a `readThroughput()` throw publishes the cached capacity with nil rates (em dash footer, R10.9). A `readCapacity()` throw before any success publishes nothing, so the card shows the unavailable skeleton; a throw after a prior success keeps the last cached values (at most 10 s stale, capacity changes slowly). Neither throw stops the loop.
- **Unavailable card state.** A nil snapshot renders the full skeleton at the populated height with em dashes and no `0%` (memory-card "Nil snapshot" precedent); design settles whether a distinct "Unavailable" caption is added.
- **IOKit adapter.** Same call shape as `IORegistryCoreTopologyProvider`: `IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)` consumes the matching dictionary; iterator and every driver handle released in `defer`; `IORegistryEntryCreateCFProperty(...)?.takeRetainedValue() as? [String: Any]`; counters via `NSNumber.uint64Value`, saturating sum. Class and key names are Swift literals with header citations unless the first RED compile proves `import IOKit.storage` exposes them (convention 18).

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `Domain/Models/{DiskThroughputCounters,VolumeCapacity,DiskSnapshot}.swift` | New | `nonisolated` Sendable values; saturating `used`, guarded `fraction` |
| `Domain/Ports/DiskMetricsProvider.swift` | New | Two-method port |
| `Domain/Services/{DiskThroughputCalculator,DiskCapacityCadence}.swift` | New | Pure rate and cadence rules |
| `Application/MetricsSampler.swift` | Modified | `diskProvider:`, `DiskSamplingStep`, `inlineDiskStep`, same-iteration read, `apply(disk:)` publish, doc comment |
| `Application/MetricsState.swift` | Modified | `disk: DiskSnapshot?`, `apply(disk:)`; no history |
| `Infrastructure/IOKit/IOKitDiskProvider.swift` | New | `IOBlockStorageDriver` iterator, `ReadError`, composes the capacity reader |
| `Infrastructure/System/VolumeCapacityReader.swift` | New | `URLResourceValues` on `/`, typed error |
| `App/AppDelegate.swift` | Modified | Construct and inject `IOKitDiskProvider(capacity: VolumeCapacityReader())` |
| `Presentation/Panel/DiskCard.swift` | New | `DiskCardModel`, `DiskCardRow`, `DiskCardSection`, thin view |
| `Presentation/Panel/PanelView.swift` | Modified | Third card after `MemoryCard`; previews |
| `Presentation/Components/ThroughputLabel.swift` | New | Icon + value pair, `nonisolated static` layout constants |
| `Presentation/Formatting/ByteFormatter.swift` | Modified | `capacity(_:locale:)` (`.decimal`), `throughput(_:locale:)` |
| `Presentation/Theme/Palette.swift` | Modified | `diskAccent` with the "two tokens, one colour" note (as `memCached`) |
| `PRD.md` | Modified | 6.2 two-value port, R10.5 `.decimal`, 6.3 sandbox note, section 10 height note |
| `openspec/changes/disk-module/specs/{disk-metrics,disk-card}/spec.md` | New | Capability specs |
| `system-monitorTests/Domain/{DiskSnapshot,DiskThroughputCalculator,DiskCapacityCadence,DiskMetricsProviderPort}Tests.swift` | New | Pure Domain suites |
| `system-monitorTests/Application/{MetricsSamplerTests,MetricsStateTests,SamplingCadenceTests,SettingsStateTests}.swift` | Modified | Disk scenarios; four `MetricsSampler(` call sites get a defaulted disk fake |
| `system-monitorTests/Infrastructure/{IOKitDiskIntegrationTests,VolumeCapacityIntegrationTests}.swift` | New | `.integration` shape suites inside the sandboxed host |
| `system-monitorTests/Presentation/{DiskCardModelTests,ThroughputFormatterTests,PanelViewTests}.swift` | New/Modified | Strings under `en_US`/`de_DE`, icons, sections, three-card height |
| `system-monitorTests/Support/{FakeDiskProvider,DiskFixtures}.swift` | New | `Mutex<Script>` fake with `throwThroughputOnCall`/`throwCapacityOnCall`, `readOnMainThread`; instant-based fixtures |

Unchanged: `MetricModule`, `Settings`, `SettingsView`, `StatusItemView/Controller`, `MetricHistory`, all CPU/memory Domain and Infrastructure, `RingGauge`, `KeyValueRow`, `HistoryGraph`, `StackedBar`, `project.pbxproj`.

## Conventions to inherit (from exploration and handoff; spec/design/tasks MUST carry these)

1. Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`: every Domain type, port, adapter, formatter, test double and nested type (`ReadError`, `Script`, fixtures) is explicitly `nonisolated` + `Sendable`; only `MetricsState`, `SettingsState`, `MetricsSampler`, views, `StatusItemController`, `SettingsWindowController` are main-actor.
2. Tests are never `@MainActor`; they `await` main-actor members; helper factories may be `@MainActor` functions.
3. Sampling loop is `Task.detached(priority: .utility)`; only Sendable values cross; no `self` capture.
4. Fakes use `Synchronization.Mutex` (no `@unchecked Sendable`); `throwOnCall` zero-based; record `Thread.isMainThread`.
5. `.timeLimit(.minutes(1))` only.
6. New files auto-join via `PBXFileSystemSynchronizedRootGroup`; never edit `project.pbxproj`.
7. Widget budget 230 pt, 221 pt measured; `statusItem.length` changes only when the module set changes. Disk adds no module, so the widget is untouched.
8. App Sandbox on; `.integration` suites run inside the sandboxed test host (`BUNDLE_LOADER`), which is the proof of IOKit and capacity access.
9. Locale whitespace hazards (U+00A0/U+202F from `.number`/`ByteCountFormatStyle`); pin `en_US`/`de_DE` and reuse the normaliser from `ByteFormatterTests`.
10. Strict TDD; unit test command `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`.
11. Page size via `host_page_size()`.
12. Launch-at-login truth is `SMAppService.mainApp.status`, never a persisted Bool.
13. Tests never call `register()`; only `.integration` `status` reads.
14. `UserDefaults` tests use a unique `suiteName` per test and `removePersistentDomain(forName:)` cleanup.
15. Settings mutate on the main actor via `SettingsState`; the store port is `nonisolated` + `Sendable`.
16. Every `NSStatusItem` created in tests is removed.
17. (new) Every IOKit object handle (`io_iterator_t`, each `io_object_t` from `IOIteratorNext`) is released in a `defer`; a matching dictionary handed to `IOServiceGetMatchingServices` is consumed and never released by the caller.
18. (new) IOKit class and property names (`"IOBlockStorageDriver"`, `"Statistics"`, `"Bytes (Read)"`, `"Bytes (Write)"`) are private Swift literals with a header citation (`IOKit/storage/IOBlockStorageDriver.h:41,54,68,82`), unless the first RED compile proves `import IOKit.storage` exposes the constants.
19. (new) Loop suites stay on `ManualClock`; cadence and rate scenarios run through `sampleOnce()` with scripted `ContinuousClock.Instant`s derived from one base, never wall-clock sleeps.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| App Sandbox filters `IOBlockStorageDriver` `Statistics` (no document allows `iokit-get-properties`; evidence is the green sandboxed topology test on another class) | Low-Med | `.integration` shape tests (`driverCount >= 1`, `bytesRead > 0`, counters monotonic) fail first in Infrastructure; R10.9 em-dash footer is the runtime fallback; capacity keeps rendering |
| Required `diskProvider:` breaks compilation at four test sites (`MetricsSamplerTests.swift:25,314`, `SamplingCadenceTests.swift:98`, `SettingsStateTests.swift:296`) | High (by construction) | Defaulted `FakeDiskProvider` in every helper in the same RED step; the RED is the failing scenario, not a broken target |
| `import IOKit.storage` does not import cleanly into Swift 6 | Med | Literals with header citations (convention 18); the submodule import is an optional refactor after the first green |
| Counter resets on eject/mount, disk images and Time Machine volumes inflate or dip the sum | Med | R10.4 negative-delta re-seed (both rates nil for one tick); D1 accepted as PRD scope |
| `ContinuousClock.Instant` cannot be built from a literal in fixtures | High (by design) | Fixtures derive every stamp from one `ContinuousClock.now` base with `advanced(by:)`; assertions use differences only |
| Locale whitespace in capacity/throughput strings | Med | Convention 9 normaliser; exact-string pins under `en_US`/`de_DE` |
| Popover height grows from 678 pt to roughly 850–870 pt (disk card ≈ 176 pt) | High (by design) | Lower-bound height assertions stay green; refresh the `PanelViewTests` comment; PRD 10 notes the growth; still fits a 14" display |
| `volumeAvailableCapacityForImportantUsage` differs from Finder on unusual volumes (external boot, Fusion) | Low | Manual success-metric check on the dev machine (PRD 2); `.integration` asserts `free >= volumeAvailableCapacity` |
| SF Symbol names (`internaldrive`, read/write arrows) not machine-verified | Med | Presentation test resolves each name with `NSImage(systemSymbolName:accessibilityDescription:)` and asserts read != write |
| Throughput throw leaves the tick without a stamp for the cadence check | Low | Design-owned: skip the refresh check that tick and reuse cached capacity (worst case 10 s plus one tick stale) |
| Single-PR size across five layers plus two specs | Accepted | `review_budget_lines: unlimited`, same shape as M3/M4; tasks grouped by layer |

## Rollback Plan

The change touches the sampling loop (`MetricsSampler`), so config rule 3 applies. The change is additive: revert to the M4 baseline (commit `9e77e42`) by restoring `MetricsSampler.swift` (no `diskProvider:`, no disk step), `MetricsState.swift`, `AppDelegate.swift`, `PanelView.swift` (drop the `DiskCard` line), `Palette.swift`, `ByteFormatter.swift` and `PRD.md`; delete the new Domain/Infrastructure/Presentation files, tests and the two capability specs (`PBXFileSystemSynchronizedRootGroup` picks up removals; no `project.pbxproj` edit); remove the defaulted disk fake from the four test helpers. No persisted settings, `UserDefaults` key, login item or `MetricModule` case is introduced, so a partial revert that keeps the Domain and adapter files compiles and changes nothing visible.

## Dependencies

- `sdd-spec` and `sdd-design` follow from this proposal and may run in parallel; `sdd-tasks` after both.
- Exploration `sdd/disk-module/explore` (8266) and handoff `sdd/disk-module/pre-proposal` (8267); convention `system-monitor/swift6-nonisolated-domain` (Engram).
- macOS APIs: `kIOMainPortDefault` (12+), `URLResourceValues.volumeAvailableCapacityForImportantUsage` (10.13+), `ByteCountFormatStyle` (12+); deployment target 26.5.
- Delivery: single PR, unlimited review budget, delivery (commit, push, PR) is user-owned; apply never commits.

## Test Strategy (strict TDD)

- Domain: `used` saturating, `fraction` 0 for `total == 0` and capped at 1; rate = Δ/Δt with reference numbers (27 100 000 bytes over 1 s → 27.1 MB/s); `previous == nil`, `driverCount == 0`, `Δt <= 0`, negative read delta, negative write delta → both rates nil; cadence refresh at 0 s, not at 9.999 s, at 10 s, and when `lastReadAt == nil`.
- Application (`sampleOnce()` with scripted instants on the fake): first tick publishes capacity with nil rates while CPU stays nil; second tick publishes rates; throughput throw keeps capacity with nil rates; capacity throw on tick one publishes nothing, on a later tick keeps cached values; capacity read count 1 under 10 s and 2 once crossed; all three providers' call counts advance together; `readOnMainThread` all false in the `ManualClock` loop; `apply(interval:)` restart re-reads capacity and nils rates for one tick; `apply(disk:)` touches no other state.
- Infrastructure `.integration` (sandboxed host): `readThroughput()` succeeds with `driverCount >= 1`, `bytesRead > 0`; two reads ≥ 120 ms apart are monotonic with advancing stamps; `VolumeCapacityReader().read()` gives `total > 0`, `0 < free <= total`, `free >= volumeAvailableCapacity`.
- Presentation: rows `[Used, Free, Total]` with `"432.07 GB"`/`"432,07 GB"`; gauge `"87.4%"`; `"27.1 MB/s"`/`"27,1 MB/s"`, `"2.2 MB/s"`, sub-kB and zero strings per design; em dash + "unavailable" for nil rates; icons differ and resolve; `sections == [.header, .gaugeAndRows, .throughput]`; reduce-motion animation nil; nil snapshot at the populated height; `PanelView` height ≥ cpu + memory + disk + chrome; `diskAccent == memFree` value.
- Whitespace normaliser from `ByteFormatterTests` reused for every locale string.

## Success Criteria

- [ ] All existing 527 tests green; zero warnings under Swift 6 strict concurrency; the four sampler test helpers compile with the defaulted disk fake.
- [ ] Domain, Application, Infrastructure `.integration` and Presentation suites above green under the unit test command.
- [ ] Manual (PRD 2): Total and Free on the card match Finder's boot-volume figures within 100 MB; read/write rates move with a large file copy and fall back to em dashes on no drivers.
- [ ] Manual (PRD 10): Instruments Time Profiler with the panel closed stays under 1% average CPU with the disk step running (capacity at 10 s cadence); number recorded in the verify report.
- [ ] Popover renders three cards in the order CPU, Memory, Disk with 12 pt gaps at width 320 (R2.2); no widget or settings change (R10.11); widget width unchanged.
- [ ] PRD 6.2, R10.5, 6.3 and section 10 amended as stated; `disk-metrics` and `disk-card` specs drafted.

## Open Questions

None blocking; every exploration question is decided in the handoff. Design-owned: exact `ReadError` cases and the cadence behaviour on a throughput throw (recommended: reuse cached capacity that tick); throughput unit vocabulary below 1 kB and the zero string; whether the nil-snapshot skeleton carries an "Unavailable" caption; `ThroughputLabel` geometry constants; the read/write SF Symbol pair. Ready for spec and design.
