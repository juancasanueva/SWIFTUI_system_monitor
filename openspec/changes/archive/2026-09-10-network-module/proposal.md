# Proposal: Network Module (PRD M6, "Network")

Engram mirror: topic `sdd/network-module/proposal` (observation 8290). Proposed 2026-09-10.

Serves PRD Draft v4 feature F11 (Network card) and its new section 5.8 (R11.x), R2.2 (fourth card in the CPU, Memory, Disk, Network order), R5.1 (one `MetricsSampler` drives every provider), R5.2 (120-sample histories), R5.3; PRD sections 4.6, 6.1, 6.2, 6.3, 7.1 (`networkAccent`, `networkDownload`, `networkUpload`), 7.3, 8, 9, 10. Milestone M6 Network; GPU moves to M7. Exploration: `exploration.md` (Engram `sdd/network-module/explore`, id 8288). Research: unselected (the SDK header facts are cited in the exploration). Pre-proposal decisions confirmed in Engram `sdd/network-module/pre-proposal` (id 8289) on 2026-09-10.

## Intent

v1 shipped with CPU, Memory and Disk; the panel says nothing about the network link, so users cannot tell whether a slow machine is bandwidth bound or how much traffic has passed since boot. No network type, port, adapter, history or view exists (`MetricsState`, `PanelView`, `Palette` know nothing about network). This change makes Network live end to end: a sandboxed `sysctl NET_RT_IFLIST2` adapter summing 64-bit `if_data64` byte counters over Ethernet-class and cellular interfaces, pure Domain delta-to-rate math with the negative-delta re-seed, a network step inside the existing sampler loop, `MetricsState.network` plus two 120-sample histories, a Network card (globe header, download and upload rates, Total In / Total Out since boot, dual-line history graph) as the fourth card, and a panel that scrolls when the four cards exceed the screen's visible frame. Success: rates move with a large download and upload on the dev machine, Total In / Total Out match Activity Monitor's "Data received / sent" magnitudes, average CPU stays under 1% (PRD 10), and the 561 existing tests stay green.

## Scope

### In Scope
- Domain: `NetworkThroughputCounters` (`bytesIn`, `bytesOut` summed `UInt64`, `interfaceCount`, `timestamp: ContinuousClock.Instant`), `NetworkSnapshot` (`totalIn`, `totalOut` since boot, `downloadBytesPerSecond: Double?`, `uploadBytesPerSecond: Double?`, nil together), `NetworkMetricsProvider` port (`readCounters() throws -> NetworkThroughputCounters`), pure `NetworkThroughputCalculator` (Δ/Δt; nil on no baseline, `interfaceCount == 0`, `Δt <= 0`, any negative delta; caller re-seeds).
- Application: `NetworkSamplingStep` value (`previous` counters) as a `var` in the detached loop and as `inlineNetworkStep` for `sampleOnce()`, exactly like `DiskSamplingStep`; `MetricsSampler` gains `networkProvider:`; the read joins the same iteration as CPU, memory and disk before any publish (R5.1); `MetricsState.network: NetworkSnapshot?`, `networkDownloadHistory`, `networkUploadHistory` (raw bytes/s, appended together only when both rates are non-nil) and `apply(network:)`.
- Infrastructure: `SysctlNetworkProvider` (`Infrastructure/System`) walking the `NET_RT_IFLIST2` buffer (`if_msghdr2`, `RTM_IFINFO2`, `if_data64`), filtering `IFT_ETHER` + `IFT_CELLULAR` and not `IFF_LOOPBACK` (no `IFF_UP`/`IFF_RUNNING` requirement) through a pure, unit-tested `includes(type:flags:)` seam, saturating sums, `ContinuousClock.now` stamp, typed `ReadError`.
- Presentation: `NetworkCard` + `nonisolated enum NetworkCardModel` (ordered `sections`, two `ThroughputLabel` readings at 12 pt with `arrow.down.circle.fill` / `arrow.up.circle.fill` or the design's pair, download green and upload blue, rows Total In / Total Out via `ByteFormatter.capacity`, rates via `ByteFormatter.throughput`, em dash + "unavailable" for nil rates, `graphSeries` normalised by `max(maxDownload, maxUpload, floor)`); `HistoryGraph` multi-series initialiser (`series: [Series]`, existing single-series init kept, CPU/Memory call sites untouched); `Palette.networkAccent` (sampled from the mockup, ~0xA66BFF), `networkDownload = 0x3DD68C`, `networkUpload = 0x4D8DFF`; `PanelView.cards` gains `.network` after `.disk`; panel overflow: the panel scrolls when its fitting height exceeds the presenting screen's `visibleFrame` height (minus a design-owned margin) and stays unscrolled at today's height otherwise; previews.
- App: composition root constructs `SysctlNetworkProvider()` and passes it to the sampler.
- Reference image: `docs/reference/06-panel-network.png` copied from the mockup (apply task; binary copy).
- PRD Draft v4 alignment task: status line; sections 1/2 anti-goal wording; F11 row (F9 menu bar NET module stays Future); 4.6 reference image; new 5.8 R11.x; R5.1/R5.2 wording; 6.1 tree; 6.2 models; 6.3 data-source row; 7.1 three tokens; 7.3 note; section 8 rows; section 9 M6 Network, GPU → M7; section 10 popover-height risk row rewritten and open question 3 answered; section 11 milestone reference. `openspec/config.yaml`: proposal rule widened to F1..F11 / M1..M6 and the `context` PRD line updated to Draft v4.
- Tests per the exploration test plan (Q8): Domain, Application (`sampleOnce()` with scripted instants), Infrastructure filter seam + `.integration` shape suite, Presentation (`en_US`/`de_DE`), `Support/{FakeNetworkProvider,NetworkFixtures}`; strict TDD.
- Specs: two new capability specs `network-metrics` and `network-card`; one delta to `disk-card`.

### Out of Scope
- Network menu bar module, any `MetricModule`, settings or widget change (F9 stays Future; PRD open question 3). Per-interface breakdown, per-process traffic, latency, Wi-Fi signal, VPN accounting (utun stays excluded). Since-app-launch totals. Integer rate variant. Compact card variants. GPU (M7). Making `MetricsSampler` generic over `Clock`. Any `project.pbxproj` edit.

## Capabilities

### New Capabilities
- `network-metrics` (suggested ids `NM-n`): `NetworkMetricsProvider` port and its single read, `NetworkThroughputCounters`/`NetworkSnapshot` invariants (rates nil together), `NetworkThroughputCalculator` (Δbytes/Δt, nil on first sample, `interfaceCount == 0`, `Δt <= 0`, or any negative delta with baseline re-seed), first-tick (totals published, rates nil) and restart semantics, failure isolation (a throw publishes nothing, keeps the last snapshot, drops the baseline), same-iteration read (R5.1), off-main read (R5.3), `MetricsState.network` with two histories appended together only on non-nil rates (R5.2), sysctl adapter shape and the `IFT_ETHER`/`IFT_CELLULAR`/not-`IFF_LOOPBACK` filter.
- `network-card` (suggested ids `NC-n`): layout per 4.6/7.3 (globe header "Network" in `networkAccent`, left column download then upload readings with differing icons and "Download"/"Upload" accessibility labels, right column Total In / Total Out, dual-line graph last), decimal capacity and `/s` throughput formatting under `en_US`/`de_DE`, em dash + "unavailable" for nil rates, nil-snapshot skeleton at the populated height, download green / upload blue for badge and line, shared graph scale with floor and 0...1 clamp, `HistoryGraph` multi-series contract, fourth-card placement, four-card height, panel scroll when taller than the visible frame, reduce-motion rule.

### Modified Capabilities
- `disk-card`: DC-1 "Card order" scenario becomes CPU, Memory, Disk, Network; DC-11 "Panel height" becomes the four-card sum and drops "the popover has no fixed content size" in favour of the visible-frame cap owned by `network-card`. `menu-bar-widget` (MBW-11 appearance, MBW-13 transitions), `settings`, `launch-at-login`, `cpu-*`, `memory-*`, `disk-metrics` hold unchanged.

## Approach

Exploration recommendation confirmed by the handoff (decisions 1–7):
- **Data source: `sysctl NET_RT_IFLIST2`.** 64-bit `if_data64` counters, no entitlement, same source as `netstat -ib`; `getifaddrs` (32-bit wrap), IOKit (no byte counters) and the private NetworkStatistics framework are rejected. Swift import of `if_msghdr2`/`if_data64` through `Darwin` is verified at the first RED compile; the buffer walk uses `loadUnaligned(fromByteOffset:as:)` and `ifm_msglen` strides. The interface filter is a pure `nonisolated static func includes(type:flags:)` so it is unit-testable without a socket.
- **Disk shape cloned.** Single-method port, adapter-stamped `ContinuousClock.Instant`, summed counters, `Δ/Δt` in a pure calculator, negative-delta re-seed with both rates nil for one tick, `NetworkSamplingStep` + `inlineNetworkStep`, one required `networkProvider:` parameter with a defaulted fake at the four test helper sites in the same RED step.
- **Sampling semantics** (spec MUST state each): tick one after `start()` publishes totals with both rates nil; tick two publishes rates. An `apply(interval:)` restart builds a fresh step and costs one rates-unavailable tick. `interfaceCount == 0` publishes totals 0 with nil rates. A `readCounters()` throw publishes nothing, leaves `MetricsState.network` and both histories untouched, and drops the baseline so the next success is a re-seed tick; the loop never stops.
- **Histories in Application, normalisation in Presentation.** `MetricHistory` stays a unit-agnostic single series; `MetricsState` owns two of them and appends both in the same `apply(network:)` only when rates are non-nil, so the x axes stay aligned. `NetworkCardModel.graphSeries` divides both series by `max(maxDownload, maxUpload, floor)` (floor design-owned, about 10 kB/s, so an idle link draws flat lines instead of noise) before `SparklineGeometry` clamps to 0...1. Rejected: a two-series ring buffer in Domain, a separate `DualHistoryGraph`.
- **`HistoryGraph(series:capacity:)`.** One `Canvas` draws N line paths (fill per series design-owned) over the shared baseline; the existing `init(samples:capacity:color:)` becomes a convenience so `CPUCard`/`MemoryCard` do not change. `Equatable` is preserved.
- **Card model.** `NetworkCardModel.sections` ordered array (`header`, `ratesAndTotals`, `graph`) mirroring `DiskCardModel`; `ThroughputLabel` reused at 12 pt for both readings (decision 7); `ByteFormatter.throughput` reused as is (decision 3); `gaugeAnimation` analogue delegates to `CPUCardModel` where an animation exists.
- **Panel overflow.** The presenting screen's `visibleFrame` height (from the status item button's window, resolved at show time) minus a margin caps the panel; above the cap the cards sit inside a `ScrollView`, below it the layout is byte-identical to today so DC-11's lower-bound assertions stay green. Design settles whether the cap is applied by `PanelView` (injected `maxHeight`) or by `configurePopover`, with the pure rule `PanelLayout.height(fitting:visibleFrameHeight:)` unit-tested either way. Compact cards are rejected (they change three shipped cards); clipping is rejected (NSPopover silently clips).
- **Palette.** Three tokens: `networkAccent` sampled from the mockup (estimate 0xA66BFF), `networkDownload` sharing `memFree`/`diskAccent` and `networkUpload` sharing `cpuAccent`/`memCached` ("two tokens, one colour" note as today). The disk ring (green) sits above the network download line (green): accepted as cosmetic.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `Domain/Models/{NetworkThroughputCounters,NetworkSnapshot}.swift` | New | `nonisolated` Sendable values; rates nil together |
| `Domain/Ports/NetworkMetricsProvider.swift` | New | Single-method port |
| `Domain/Services/NetworkThroughputCalculator.swift` | New | Pure Δ/Δt with nil cases |
| `Application/MetricsSampler.swift` | Modified | `networkProvider:`, `NetworkSamplingStep`, `inlineNetworkStep`, same-iteration read, `apply(network:)` publish, doc comment |
| `Application/MetricsState.swift` | Modified | `network`, `networkDownloadHistory`, `networkUploadHistory`, `apply(network:)`; `init(historyCapacity:)` sizes both |
| `Infrastructure/System/SysctlNetworkProvider.swift` | New | `NET_RT_IFLIST2` walk, filter seam, `ReadError` |
| `App/AppDelegate.swift` | Modified | Construct and inject `SysctlNetworkProvider()` |
| `Presentation/Panel/NetworkCard.swift` | New | `NetworkCardModel`, `NetworkCardSection`, thin view |
| `Presentation/Panel/PanelView.swift` | Modified | `PanelCard.network` fourth; overflow cap and `ScrollView`; previews |
| `Presentation/MenuBar/StatusItemController.swift` | Modified (possible) | Pass the presenting screen's visible-frame height if design places the cap here |
| `Presentation/Components/HistoryGraph.swift` | Modified | Multi-series initialiser; single-series convenience kept |
| `Presentation/Theme/Palette.swift` | Modified | `networkAccent`, `networkDownload`, `networkUpload` |
| `PRD.md` | Modified | Draft v4 amendment listed in scope |
| `openspec/config.yaml` | Modified | Rule text F1..F11 / M1..M6; context line Draft v4 |
| `docs/reference/06-panel-network.png` | New | Mockup copy (binary; apply task) |
| `openspec/changes/network-module/specs/{network-metrics,network-card}/spec.md` | New | Capability specs |
| `openspec/changes/network-module/specs/disk-card/spec.md` | New (delta) | DC-1 order, DC-11 height |
| `system-monitorTests/Domain/{NetworkSnapshot,NetworkThroughputCalculator,NetworkMetricsProviderPort}Tests.swift` | New | Pure Domain suites |
| `system-monitorTests/Application/{MetricsSamplerTests,MetricsStateTests,SamplingCadenceTests,SettingsStateTests}.swift` | Modified | Network scenarios; four `MetricsSampler(` call sites get a defaulted network fake |
| `system-monitorTests/Infrastructure/{SysctlNetworkProviderTests,SysctlNetworkIntegrationTests}.swift` | New | Filter seam unit tests; `.integration` shape suite in the sandboxed host |
| `system-monitorTests/Presentation/{NetworkCardModelTests,HistoryGraphSeriesTests,PanelViewTests,StatusItemReadingsTests}.swift` | New/Modified | Strings under `en_US`/`de_DE`, icons, sections, normalisation, four-card height, overflow rule, palette pins |
| `system-monitorTests/App/AppDelegateCompositionTests.swift` | Modified | Publishes `network != nil` |
| `system-monitorTests/Support/{FakeNetworkProvider,NetworkFixtures}.swift` | New | `Mutex<Script>` fake with `throwOnCall`, `readOnMainThread`; instant-based fixtures |

Unchanged: `MetricModule`, `Settings`, `SettingsView`, `StatusItemView`, `MetricHistory`, `SparklineGeometry`, `ThroughputLabel`, `ByteFormatter`, all CPU/memory/disk Domain and Infrastructure, `RingGauge`, `KeyValueRow`, `StackedBar`, `project.pbxproj`.

## Conventions to inherit (from the disk proposal, exploration and handoff; spec/design/tasks MUST carry these)

1. Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`: every Domain type, port, adapter, formatter, test double and nested type is explicitly `nonisolated` + `Sendable`; only `MetricsState`, `SettingsState`, `MetricsSampler`, views and the AppKit controllers are main-actor.
2. Tests are never `@MainActor`; they `await` main-actor members; helper factories may be `@MainActor` functions.
3. Sampling loop is `Task.detached(priority: .utility)`; only Sendable values cross; no `self` capture.
4. Fakes use `Synchronization.Mutex` (no `@unchecked Sendable`); `throwOnCall` zero-based; record `Thread.isMainThread`.
5. `.timeLimit(.minutes(1))` only.
6. New files auto-join via `PBXFileSystemSynchronizedRootGroup`; never edit `project.pbxproj`.
7. Widget budget 230 pt; `statusItem.length` changes only when the module set changes. Network adds no module, so the widget is untouched.
8. App Sandbox on; `.integration` suites run inside the sandboxed test host (`BUNDLE_LOADER`), which is the proof of `PF_ROUTE` sysctl access.
9. Locale whitespace hazards (U+00A0/U+202F); pin `en_US`/`de_DE` and reuse the normaliser from `ByteFormatterTests`.
10. Strict TDD; unit test command `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`.
11. Loop suites stay on `ManualClock`; rate scenarios run through `sampleOnce()` with scripted `ContinuousClock.Instant`s derived from one base, never wall-clock sleeps.
12. (new) `sysctl` constants and struct names (`CTL_NET`, `PF_ROUTE`, `NET_RT_IFLIST2`, `RTM_IFINFO2`, `IFT_ETHER`, `IFT_CELLULAR`, `IFF_LOOPBACK`, `if_msghdr2`, `if_data64`) come from `Darwin` with header citations (`net/if.h:202,213`, `net/if_var.h:189,208-209`, `net/route.h:214` for `RTM_IFINFO2`, `sys/socket.h:541` for `NET_RT_IFLIST2`); any that fail to import at the first RED compile become private literals with the same citations.
13. (new) The sysctl buffer is sized by a first `sysctl` call with a nil buffer, allocated once per read, and walked with `loadUnaligned`; never reinterpret the buffer through a typed pointer cast.
14. (new) `HistoryGraph` series colours are Presentation tokens; `MetricsState` never sees a colour or a unit.

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `if_msghdr2`/`if_data64` do not import cleanly into Swift 6 through `Darwin` | Med | Convention 12 literal fallback with header citations; first RED compile is the check |
| App Sandbox filters the `PF_ROUTE` sysctl | Low | `.integration` shape tests (`interfaceCount >= 1`, `bytesIn > 0`, monotonic across two reads, 50 reads succeed) fail first; em-dash rates and zero totals are the runtime fallback |
| Four cards (about 1050 pt) exceed a 14" display at default scaling (about 945 pt usable) | High (by construction) | Visible-frame cap with `ScrollView` (decision 6); pure `PanelLayout` rule unit-tested; manual check on the 14" dev display |
| Required `networkProvider:` breaks compilation at four test helper sites (`MetricsSamplerTests` x2, `SamplingCadenceTests:98`, `SettingsStateTests:296`) plus `AppDelegate` | High (by construction) | Defaulted `FakeNetworkProvider` in every helper in the same RED step |
| Interface churn (Wi-Fi off/on, VPN, hotspot) resets a per-interface counter and dips the sum | Med | Negative-delta re-seed (both rates nil for one tick); totals dip is accepted and documented in PRD 5.8 |
| VPN/bridge double counting if the filter is loosened | Med | Filter pinned by unit tests on `includes(type:flags:)` (utun, bridge, lo0, gif, stf excluded; en*, awdl0, llw0, cellular included) |
| Shared graph scale hides the smaller series when the other spikes | Med (by design) | Floor keeps idle lines flat; design MAY revisit per-series scaling only if the manual check finds the mockup unreadable |
| Locale whitespace in capacity/throughput strings | Med | Convention 9 normaliser; exact-string pins under `en_US`/`de_DE` |
| SF Symbol names (`globe`, `arrow.down.circle.fill`, `arrow.up.circle.fill`) not machine-verified | Med | Presentation test resolves each name with `NSImage(systemSymbolName:accessibilityDescription:)` and asserts download != upload |
| `networkAccent` estimate 0xA66BFF differs from the mockup | Low | Sample the header glyph at implementation (PRD 7.1); pin the final value in the Presentation palette test |
| Green above green (disk ring, network download line) | Low | Cosmetic, accepted; cards are separated by 12 pt and the card background |
| Single-PR size across five layers plus three spec files (about 2000 lines) | Accepted | `review_budget_lines: unlimited`, same shape as M5; tasks grouped by layer |

## Rollback Plan

The change touches the sampling loop (`MetricsSampler`), so config rule 3 applies. The change is additive: revert to the M5 baseline (commit `de40106`) by restoring `MetricsSampler.swift` (no `networkProvider:`, no network step), `MetricsState.swift`, `AppDelegate.swift`, `PanelView.swift` (drop `.network` and the overflow wrapper), `StatusItemController.swift` if touched, `HistoryGraph.swift` (single-series init only), `Palette.swift`, `PRD.md` and `openspec/config.yaml`; delete the new Domain/Infrastructure/Presentation files, tests, the reference image and the three spec files (`PBXFileSystemSynchronizedRootGroup` picks up removals; no `project.pbxproj` edit); remove the defaulted network fake from the four test helpers. No persisted setting, `UserDefaults` key, login item or `MetricModule` case is introduced, so a partial revert that keeps the Domain and adapter files compiles and changes nothing visible. Reverting only the overflow wrapper restores today's unbounded popover, which still fits three cards.

## Dependencies

- `sdd-spec` and `sdd-design` follow from this proposal and may run in parallel; `sdd-tasks` after both.
- Exploration `sdd/network-module/explore` (8288) and handoff `sdd/network-module/pre-proposal` (8289); specs of record `disk-metrics` (DM-1..15) and `disk-card` (DC-1..11) as the shape precedent; convention `system-monitor/swift6-nonisolated-domain` (Engram).
- macOS APIs: `sysctl` with `NET_RT_IFLIST2` (routing socket, no entitlement), `NSScreen.visibleFrame`, `ByteCountFormatStyle`; deployment target 26.5.
- Delivery: single PR, unlimited review budget; delivery (commit, push, PR) is user-owned; apply never commits. The mockup binary copy is an apply task because the propose phase cannot write binaries.

## Test Strategy (strict TDD)

- Domain: rates nil together; reference rate (5 000 bytes over 1 s → 5 kB/s; 78 000 over 1 s → 78 kB/s), 0.5 s window; `previous == nil`, `interfaceCount == 0`, `Δt <= 0`, negative in delta, negative out delta → both rates nil; re-seed after a negative delta yields rates on the following tick.
- Application (`sampleOnce()` with scripted instants on the fake): first tick publishes totals with nil rates while histories stay empty; second tick publishes rates and appends one sample to each history; throw publishes nothing and leaves both histories untouched; all four providers' call counts advance together; `readOnMainThread` all false in the `ManualClock` loop; `apply(interval:)` restart nils rates for one tick; `apply(network:)` touches no other state.
- Infrastructure: `includes(type:flags:)` truth table; `.integration` (sandboxed host): `readCounters()` succeeds with `interfaceCount >= 1`, `bytesIn > 0`, two reads ≥ 120 ms apart are monotonic with advancing stamps, 50 consecutive reads succeed.
- Presentation: rows `[Total In, Total Out]` with `"3.85 GB"`/`"3,85 GB"`; readings `"5.0 kB/s"`/`"5,0 kB/s"` and `"78.0 kB/s"`/`"78,0 kB/s"`; em dash + "unavailable" for nil rates; icons differ and resolve; `sections == [.header, .ratesAndTotals, .graph]`; `graphSeries` shared scale, floor, clamp, equal lengths; `HistoryGraph` multi-series geometry equals two single-series geometries; palette pins (`networkDownload == memFree`, `networkUpload == cpuAccent` values); `PanelView.cards == [.cpu, .memory, .disk, .network]`; four-card height `>= cpu + memory + disk + network + chrome`; `PanelLayout` rule caps above the visible frame and passes through below it; nil snapshot at the populated height.
- Whitespace normaliser from `ByteFormatterTests` reused for every locale string.

## Success Criteria

- [ ] All existing 561 tests green; zero warnings under Swift 6 strict concurrency; the four sampler test helpers compile with the defaulted network fake.
- [ ] Domain, Application, Infrastructure (`includes` + `.integration`) and Presentation suites above green under the unit test command.
- [ ] Manual (PRD 2): download and upload rates move with a large download and upload on the dev machine; Total In / Total Out are within the same order of magnitude as Activity Monitor's Data received / sent and never decrease across a session without interface churn.
- [ ] Manual (PRD 10): Instruments Time Profiler with the panel closed stays under 1% average CPU with the network step running; number recorded in the verify report.
- [ ] Popover renders four cards in the order CPU, Memory, Disk, Network with 12 pt gaps at width 320 (R2.2); on the 14" dev display at default scaling the panel scrolls to the Network card instead of clipping; on a taller screen no scroll bar appears; no widget or settings change; widget width unchanged.
- [ ] PRD Draft v4 and `openspec/config.yaml` amended as stated; `network-metrics`, `network-card` and the `disk-card` delta drafted; `docs/reference/06-panel-network.png` present.

## Open Questions

None blocking; every exploration question is decided in the handoff. Design-owned: exact `ReadError` cases; the graph floor value and whether each series carries an area fill; the overflow cap host (`PanelView` vs `configurePopover`) and margin; the final `networkAccent` sample; the globe/arrow SF Symbol names; the "Network" sublabel and accessibility labels; whether the nil-snapshot skeleton carries an "Unavailable" caption. Ready for spec and design.
