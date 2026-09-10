Mirror of Engram observation 8288 (topic `sdd/network-module/explore`), written by the propose phase on 2026-09-10 because the explore phase could not write project files. Body verbatim below.

## Exploration: Network card (fourth panel card) — change `network-module`

Explored 2026-09-10. Precedent: disk-module (archived 2026-09-10; specs of record `openspec/specs/disk-metrics/spec.md` DM-1..15, `openspec/specs/disk-card/spec.md` DC-1..11). Mockup: globe header "Network"; left column two rate rows (down badge + `5 KB/s`, up badge + `78 KB/s`); right column `Total In 3,85 GB`, `Total Out 2,76 GB`; bottom dual-line history graph. Fourth card after Disk.

### Current State
- Hexagonal layout `system-monitor/{App,Domain,Application,Infrastructure,Presentation}`; Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency; App Sandbox ON (`project.pbxproj:401,435`), tests run in the sandboxed host (`BUNDLE_LOADER = $(TEST_HOST)`, `:463,484`).
- Disk shape to clone: `DiskThroughputCounters` (bytesRead/bytesWritten/driverCount/`ContinuousClock.Instant` stamp) → port `DiskMetricsProvider` → pure `DiskThroughputCalculator.rates(previous:current:) -> Rates?` (nil when no baseline, driverCount 0, Δt <= 0, any negative delta; caller re-seeds) → `DiskSamplingStep` value inside the single `Task.detached(priority: .utility)` loop + `inlineDiskStep` for `sampleOnce()` → `MetricsState.apply(disk:)` → `DiskCard` over `DiskCardModel.sections` → `PanelView.cards`.
- `MetricHistory` is a single-series ring buffer of `Double` (capacity 120). `HistoryGraph(samples:capacity:color)` draws ONE series; `SparklineGeometry.points` clamps values to 0...1, so anything unnormalised must be scaled before it reaches the graph.
- `ByteFormatter.throughput` emits decimal `kB/MB/GB/TB` with exactly one fraction digit at kB and above (`5.0 kB/s`, `78.0 kB/s`), lowercase `kB`.
- `Palette` tokens: cpuAccent 0x4D8DFF (blue), memFree/diskAccent 0x3DD68C (green), memCached shares cpuAccent. No purple.
- `PanelViewTests` pins three-card height 871 pt = 370 (CPU) + 278 (memory) + 175 (disk) + 48 chrome.
- Required-init compile trap: adding a required provider to `MetricsSampler.init` breaks four test helper sites (`MetricsSamplerTests` x2, `SamplingCadenceTests:98`, `SettingsStateTests:296`) plus `AppDelegate.swift:39-49`.

### Q1 Data source (verified against the macOS 26 SDK headers)
| Source | Counter width | Entitlement | Verdict |
|---|---|---|---|
| `getifaddrs()` → `ifa_data` = `struct if_data` | `u_int32_t ifi_ibytes/ifi_obytes` (`net/if_var.h:170-171`) → wraps at 4 GiB; Apple forum reports resets and doubled values | none | Reject: totals since boot are wrong within minutes on a busy link |
| `sysctl {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0}` → walk `if_msghdr2` (`net/if.h:202`, `ifm_msglen`, `ifm_type == RTM_IFINFO2` `route.h:214`) → `ifm_data: if_data64` (`net/if.h:213`, `if_var.h:189`) | `u_int64_t ifi_ibytes/ifi_obytes` (`if_var.h:208-209`) | none (routing-socket sysctl, no `network.client`; same source as `netstat -ib`) | RECOMMENDED |
| IOKit `IONetworkInterface` statistics | `IONetworkStats` has only UInt32 packets/errors/collisions (`IONetworkStats.h:46-50`), no bytes; virtual ifs absent | — | Not viable |
| Private NetworkStatistics framework (Activity Monitor) | — | private | Reject |
> **Correction (2026-09-10, after manual check 7.3).** The `NET_RT_IFLIST2` row above is **wrong on this platform**, and the table's whole "counter width" column was reasoning from header declarations rather than from measurement. The routing-socket export declares `ifi_ibytes` as `u_int64_t`, but this machine's driver fills only the low 32 bits, so it wraps at 4 GB exactly like the `getifaddrs()` row that was rejected for that reason. Measured with no traffic beyond background chatter: `en1` went 4 287 352 832 → 8 851 456 in one 250 ms tick, and a same-moment comparison read 13 563 204 219 through the interface MIB against 678 301 696 through the routing socket.
>
> **The source actually used is the interface MIB** (`net/if_mib.h`): `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, <index>, IFDATA_GENERAL}` into `struct ifmibdata`, whose `ifmd_data` is a genuinely-filled `if_data64`, with the index count from `IFMIB_SYSTEM`/`IFMIB_IFCOUNT`. Same entitlement story (none), same `netstat -ib` figures, no message walk. The lesson for the next exploration: a declared field width is a claim about the struct, not about the driver, and only a reading above 2^32 settles it.

`net/if.h:73` includes `net/if_var.h`, so `if_msghdr2`/`if_data64` should import through `Darwin` (verify at first RED compile; use `loadUnaligned(fromByteOffset:as:)` while walking the buffer). Interface filter: include `ifi_type ∈ {IFT_ETHER 0x6, IFT_CELLULAR 0xff}` and not `IFF_LOOPBACK 0x8`; this keeps en*, awdl0, llw0 (real radio traffic) and excludes lo0 (IFT_LOOP), utun* (IFT_OTHER + IFF_POINTOPOINT, would double count VPN bytes), bridge* (IFT_BRIDGE), gif/stf. Do not require IFF_UP so totals of a down interface stay in the sum. Sandbox: unverified in this repo, expected to work; `.integration` test is the proof (disk precedent).

### Q2 Totals: since boot (raw 64-bit sum), matches mockup magnitudes (3,85 GB / 2,76 GB) and Activity Monitor "Data received/sent"; since-app-launch would show 0 B at first open. Caveat: an interface recreated after boot resets its own counter.

### Q3 History: two `MetricHistory` in `MetricsState` (`networkDownloadHistory`, `networkUploadHistory`) storing raw bytes/s, appended together only when rates are non-nil (shared x axis). Presentation normalises: `NetworkCardModel.graphSeries` divides both by `max(maxDown, maxUp, floor)` (floor design-owned, ~10 kB/s) before the graph. Graph: extend `HistoryGraph` with a `series: [Series(samples,color)]` initialiser and keep the single-series init as a convenience (CPU/Memory call sites untouched). Rejected: a 2-series ring buffer in Domain (Domain stays unit-agnostic), a separate `DualHistoryGraph` (duplicates canvas code).

### Q4 Rate formatting: reuse `ByteFormatter.throughput` as is (`5,0 kB/s`) for cross-card consistency; product decision because the mockup shows `5 KB/s` (no fraction, capital K).

### Q5 Menu bar: panel card only; `MetricModule`, settings, widget untouched (R10.11 analogue); PRD open question 3 answered "revisit NET module later, F9 stays Future".

### Q6 Palette: `networkAccent ≈ 0xA66BFF` (purple, estimate from mockup, sample precisely at implementation per PRD 7.1), `networkDownload = 0x3DD68C` (shares diskAccent/memFree), `networkUpload = 0x4D8DFF` (shares cpuAccent). Colour-mapping finding: the mockup badges say download=green, upload=blue, and the graph's tall blue line matches the larger rate (upload 78 KB/s) while the flat green line matches download 5 KB/s — so the mockup is internally consistent with download=green/upload=blue; recommend that mapping for badge AND line. Product decision.

### Q7 Height: network card ≈ 165–175 pt (32 padding + header 16 + 14 + two rows ~40 + 14 + graph 48). Four cards ≈ 871 + 12 + ~170 ≈ 1050 pt. 14" MacBook Pro default scaling is 1512×982 pt with a ~37 pt menu bar → ~945 pt usable: the four-card popover does NOT fit at default scaling (it fits at "More Space" 1800×1169 and on 16"). NSPopover clips oversized content. Product decision: scroll the panel when taller than the screen's visibleFrame vs compact cards vs accept.

### Q8 Test plan (Strict TDD, Swift Testing): Domain `NetworkThroughputCounters`/`NetworkSnapshot` values, `NetworkThroughputCalculator` (reference rate, 0.5 s window, nil cases, negative delta both directions, re-seed), port conformance via `FakeNetworkProvider`; Application `MetricsState.apply(network:)` (two histories append together, nil rates append nothing), `NetworkSamplingStep` via `sampleOnce()` (first tick totals with nil rates, second tick rates, throw isolation, restart re-seed under `ManualClock`, off-main reads); Infrastructure pure seam `includes(type:flags:)` unit tests + `.integration` `SysctlNetworkIntegrationTests` (`interfaceCount >= 1`, `bytesIn > 0`, monotonic across two reads, 50 reads succeed) in the sandboxed host; Presentation `NetworkCardModel` (sections, rows Total In/Out under en_US/de_DE, readings/badges symbols resolve and differ, em dash + "unavailable", graph normalisation shared scale + floor + clamp), `HistoryGraph` multi-series geometry, Palette tokens, `PanelView.cards == [.cpu,.memory,.disk,.network]`, four-card height and nil-snapshot stability; `AppDelegateCompositionTests` publishes `network != nil`.

### Affected files
New: Domain/Models/{NetworkThroughputCounters,NetworkSnapshot}.swift, Domain/Ports/NetworkMetricsProvider.swift, Domain/Services/NetworkThroughputCalculator.swift, Infrastructure/System/SysctlNetworkProvider.swift, Presentation/Panel/NetworkCard.swift, docs/reference/06-panel-network.png, specs network-metrics + network-card, tests Support/{FakeNetworkProvider,NetworkFixtures}.swift, Domain/{NetworkSnapshotTests,NetworkThroughputCalculatorTests,NetworkMetricsProviderPortTests}.swift, Infrastructure/{SysctlNetworkProviderTests,SysctlNetworkIntegrationTests}.swift, Presentation/{NetworkCardModelTests,HistoryGraphSeriesTests}.swift.
Modified: Application/{MetricsSampler,MetricsState}.swift, App/AppDelegate.swift, Presentation/Panel/PanelView.swift, Presentation/Components/HistoryGraph.swift, Presentation/Theme/Palette.swift, PRD.md, openspec/config.yaml (rule text F1..F10/M1..M5 → F11/M6), tests MetricsSamplerTests, MetricsStateTests, SamplingCadenceTests, SettingsStateTests, PanelViewTests, StatusItemReadingsTests (palette pins), AppDelegateCompositionTests.

### PRD amendment (Draft v4): status line; section 1/2 (anti-goal split: network beyond the single card); F11 row "Network card (5.8)" keeping F9 menu bar module Future; 4.6 reference image; new 5.8 R11.x (source NET_RT_IFLIST2/if_data64, interface filter, since-boot totals, Δ/Δt with negative-delta re-seed, two 120-sample histories, shared graph scale with floor, formatting reuse, unavailable states, palette, no menu bar module); R5.1/R5.2 wording; 6.1 tree; 6.2 models; 6.3 row; 7.1 three tokens; 7.3 note; 8 rows; 9 M6 Network, GPU → M7; 10 popover-height risk row rewritten (four cards exceed 14" default scaling) + open question 3 answered; section 11 milestone reference.

### Product decisions needing confirmation
1. Colour mapping: download=green / upload=blue (recommended, consistent with mockup badges and amplitude evidence) vs download=blue / upload=green.
2. Totals semantics: since boot (recommended) vs since app launch.
3. Rate fraction digits: reuse `5,0 kB/s` (recommended) vs integer `5 KB/s` variant.
4. Interface filter: Ethernet-class + cellular, excluding loopback/utun/bridge/gif/stf (recommended) vs everything except loopback.
5. PRD amendment scope: F11 + M6 (GPU → M7) + section 5.8 (recommended) vs re-scoping F9.
6. Popover height: how to handle the four-card panel exceeding a 14" display at default scaling (scroll when taller than visibleFrame recommended).
7. Rate text size: mockup's larger rate text vs reuse of `ThroughputLabel` 12 pt.

### Risks
Swift import of `if_msghdr2`/`if_data64` (Med, verify at first compile); sandbox filtering of PF_ROUTE sysctl (Low, `.integration` proof); popover no longer fits 14" default scaling (High, by construction); required `networkProvider:` compile trap at four helper sites (High by construction, same-RED fix); VPN/bridge double counting if the filter is loosened (Med); locale whitespace in strings (Med, existing normaliser); adjacent green (disk ring above network upload line) (Low, cosmetic); single-PR size ~2000 lines (accepted, `review_budget_lines: unlimited`).

Recommendation: clone the disk shape (single-method port, adapter-stamped instants, summed counters, negative-delta re-seed), sysctl NET_RT_IFLIST2 adapter, two histories + multi-series HistoryGraph, reuse ByteFormatter.throughput, three palette tokens, panel card only. Ready for proposal after the seven product decisions are confirmed.
