# PRD: System Monitor for macOS

| Field | Value |
|---|---|
| Status | Draft v4 (Network card added on 2026-09-10 as F11 / M6; GPU moved to M7) |
| Date | 2026-09-10 |
| Platform | macOS 15+ (Xcode project deployment target), Apple Silicon first |
| Stack | Swift 6, SwiftUI, AppKit (NSStatusItem / NSPopover), Mach APIs for metrics |
| Reference images | `docs/reference/` (see section 4) |

---

## 1. Summary

A lightweight, always-visible system monitor that lives in the macOS menu bar. It shows a compact widget with a live sparkline and current value for **CPU** and **RAM**. Clicking the widget opens a detail panel with a ring gauge, a breakdown of the metric, a longer history graph and, for CPU, per-core bars split into Performance and Efficiency cores. A third card shows how full the boot volume is and the live read and write throughput of the disk. A fourth card shows the live download and upload rates, the bytes received and sent since boot, and a dual-line history graph of both rates.

The goal is a native, low-overhead replacement for tools like iStat Menus or Stats, focused only on the metrics that matter day to day, with a modern dark UI.

**v1 shipped CPU, RAM and Disk (M5); M6 adds the Network card.** The Disk card was added on 2026-09-06 after M4 shipped (section 5.7, milestone M5) and the Network card on 2026-09-10 (section 5.8, milestone M6). GPU is designed and specified in section 11 and ships in v2 as M7. The architecture is built so that adding it is additive: one provider adapter, one card, one widget module.

---

## 2. Problem and Users

**Who is this for.** A developer or power user on an Apple Silicon Mac who wants to see at a glance whether the machine is under load, without opening Activity Monitor.

**Pain today.**
- Activity Monitor is a full window and gives no at-a-glance history.
- Existing menu bar monitors are either heavy, paid, cluttered with dozens of modules, or visually dated.

**Why now.** P-core versus E-core scheduling on Apple Silicon is a real signal of what kind of work the machine is doing, and it is invisible in the menu bar today. Memory pressure on unified-memory machines matters more than on discrete-GPU machines.

**Anti-goals (explicitly out of scope for v1).**
- GPU (deferred to v2, see section 11).
- Network beyond the single card: per-interface breakdown, per-process traffic, latency, Wi-Fi signal, VPN accounting, a NET menu bar module (F9, open question 3).
- Battery, sensors, fans, temperatures.
- Disk beyond the single card: per-volume breakdown, external drives as separate cards, per-process I/O, SMART health, a disk menu bar module (open question 3).
- Process list or per-process usage.
- Notifications or alerts on thresholds.
- Intel Macs as a first-class target (must not crash, but P/E split will be absent).
- Mac App Store distribution (not needed for v1; revisit with GPU since IOKit access under sandbox is unverified).

**Success metric.** The app runs for a full working day with under 1% average CPU and under 50 MB RSS, and the menu bar values match Activity Monitor within a reasonable margin (CPU ±3 pts, memory within 100 MB). Disk Total and Free match Finder's figures for the boot volume within 100 MB. Network Total In and Total Out match Activity Monitor's Data received and Data sent within the same order of magnitude.

---

## 3. Feature Overview

| ID | Feature | Priority |
|---|---|---|
| F1 | Menu bar widget: CPU and MEM, each with sparkline + percentage | P0 |
| F2 | Detail panel opened on click, four stacked cards (CPU, Memory, Disk, Network) | P0 |
| F3 | CPU card: ring gauge, User/System/P-Cores/E-Cores values, history graph, per-core bars | P0 |
| F4 | Memory card: ring gauge, Used/Total/Wired/Compressed values, stacked legend, history graph | P0 |
| F5 | Launch at login toggle | P1 |
| F6 | Settings: sampling interval, which modules show in the menu bar, widget order | P1 |
| F7 | Light mode support (dark is the default and reference design) | P2 |
| F8 | GPU module: widget slot + GPU card (section 11) | v2 |
| F9 | Network module (as in the original reference bar) | Future |
| F10 | Disk card: ring gauge, Used/Free/Total values, read and write throughput (section 5.7) | P0 |
| F11 | Network card: download and upload rates, Total In / Total Out since boot, dual-line history graph (section 5.8) | P0 (M6) |

---

## 4. Reference Designs

All images live in `docs/reference/`.

### 4.1 `01-menubar-widget-reference.jpeg` — Menu bar widget
A Linux status bar (the source of the visual idea). Layout, left to right:

```
CPU [sparkline] 26%   MEM [sparkline] 59%   NET [sparkline] ↓207B ↑232B
```

- Each module: **label** (small caps, cyan/teal on dark), **sparkline** (filled area, ~60 px wide), **value** (percentage).
- The whole group sits inside a rounded pill with a subtle border.
- v1 ships the first two modules only. NET is a future module; GPU takes the third slot in v2.

### 4.2 `02-panel-cpu.png` — CPU card
- Header: CPU chip icon + "CPU".
- Left: ring gauge, big value `40.2%`, sublabel `CPU`. Gauge color blue.
- Right, key/value rows: `User 30.6%`, `System 9.6%`, `P-Cores 70.6%` (blue), `E-Cores 9.8%` (teal).
- Middle: history area graph, blue fill, ~2 minutes of data.
- Bottom: two rows of per-core bars, `P-Cores` and `E-Cores`, each bar with its percentage below.

### 4.3 `03-panel-memory.png` — Memory card
- Header: memory icon + "Memory".
- Left: ring gauge `69.0%`, sublabel `RAM`. Gauge color orange.
- Right: `Used 5,52 GB`, `Total 8 GB`, `Wired 1,85 GB`, `Compressed 1,82 GB`.
- Stacked horizontal bar with legend: **App** (orange), **Wired** (red), **Compressed** (yellow), **Cached** (blue), **Free** (green).
- Bottom: history area graph, orange fill.
- Note the locale-aware decimal separator (`5,52 GB`). Formatting must use the system locale.

### 4.4 `04-panel-gpu.png` — GPU card (v2 reference)
Kept for v2. Described in section 11.

### 4.5 `05-panel-disk.png` — Disk card
- Header: internal drive icon + "Disk".
- Left: ring gauge `87.4%`, sublabel `Disk`. The ring is green; in the reference it fades from amber at the start of the arc to green at the end.
- Right: `Used 432,07 GB`, `Free 62,29 GB`, `Total 494,35 GB`. Used + Free equals Total, so Used is derived, not measured.
- Footer: two throughput values side by side, `27,1 MB/s` (read) and `2,2 MB/s` (write), each preceded by a small green document icon.
- No history graph and no stacked bar. This is the only card without a graph.
- `494,35 GB` is the decimal capacity Finder reports for a 512 GB Apple SSD, so capacity uses decimal units (1 GB = 10⁹ bytes), unlike the Memory card. Locale-aware decimal separator as in 4.3.

### 4.6 `06-panel-network.png` — Network card
- Header: globe icon + "Network".
- Left: two badge rows, a downward arrow with `5 KB/s` and an upward arrow with `78 KB/s`. These are rates, not totals, so there is no ring gauge; the card replaces the gauge with the rate pair.
- Right: `Total In 3,85 GB` and `Total Out 2,76 GB`, the bytes received and sent since boot.
- Bottom: history area graph with **two** lines on one shared vertical scale — upload in blue above download in green.
- Download is green and upload is blue throughout the card, matching the two arrows and the two graph lines (7.1).
- The mockup writes the rates as `5 KB/s`; the app renders `5,0 kB/s`, because throughput reuses the decimal bytes-per-second vocabulary already fixed by R10.5 (one fraction digit, decimal units, locale-aware separator as in 4.3).

---

## 5. Functional Requirements

### 5.1 Menu bar widget (F1)
- R1.1 The widget is an `NSStatusItem` with a custom SwiftUI view hosted via `NSHostingView`. Rationale: `MenuBarExtra` flattens custom labels to a static image and re-renders poorly at 1 Hz; `NSStatusItem` gives full control over width and redraw.
- R1.2 Two modules in order CPU, MEM. The module list is data-driven so a third module can be appended in v2 without layout changes.
- R1.3 Sparkline shows the last 60 samples. At a 1 s interval that is one minute of history.
- R1.4 Value is an integer percentage (`26%`). Width is fixed-digit so the bar does not jitter as values change.
- R1.5 Left click toggles the detail panel. Right click opens a context menu with Settings, Launch at Login, Quit.
- R1.6 The widget must render legibly on both dark and light menu bars. Sparkline uses the module accent color; text uses the system label color.
- R1.7 Total widget width target: under 230 pt for two modules (raised from 200 pt on 2026-09-04: two 40 pt sparklines plus labels and a "100%" value frame need 221 pt with normal spacing) so it fits alongside other status items on a 14" display.

### 5.2 Detail panel (F2)
- R2.1 Presented as an `NSPopover` anchored to the status item, transient behavior (closes on outside click or Esc).
- R2.2 Fixed width around 320 pt. Height fits content; the cards stack vertically with 12 pt gaps, in the order CPU, Memory, Disk, Network.
- R2.3 Dark card background (see 7.1), 12 pt corner radius, no visible borders.
- R2.4 The panel keeps updating live while open, at the same sampling interval.
- R2.5 When the panel's fitting height exceeds the presenting screen's visible frame height minus 24 pt, the panel is pinned to that height and its cards scroll; otherwise it keeps its fitting height and never scrolls.

### 5.3 CPU card (F3)
- R3.1 Total usage = 100 − idle, computed from the delta of Mach tick counters between two samples, never from a single instantaneous read.
- R3.2 User and System are the corresponding tick deltas over the total delta. `nice` ticks are folded into User.
- R3.3 P-Cores and E-Cores averages are computed over the cores belonging to each performance level. Core count per level comes from `hw.perflevel0.logicalcpu` (P) and `hw.perflevel1.logicalcpu` (E).
- R3.4 The mapping from Mach core index to performance level must be verified per chip at startup and covered by a test with a fake provider; do not hardcode "E-cores first".
- R3.5 Per-core bars: one bar per logical core, grouped P then E, each with its percentage label. The development machine has 8 P + 4 E, so the layout must handle up to 16 P-cores gracefully (wrap to two rows if needed).
- R3.6 On machines with no perflevel split (Intel), hide the P/E rows and label the bars "Cores".
- R3.7 History graph shows the last 120 samples of total usage.

### 5.4 Memory card (F4)
- R4.1 Source: `host_statistics64` with `HOST_VM_INFO64` (`vm_statistics64`), plus `ProcessInfo.processInfo.physicalMemory` for Total.
- R4.2 Definitions, aligned with Activity Monitor:
  - App = `internal_page_count − purgeable_count`
  - Wired = `wire_count`
  - Compressed = `compressor_page_count`
  - Cached = `external_page_count + speculative_count`
  - Free = `free_count − speculative_count` (speculative pages are counted inside `free_count`)
  - Used = Total − `free_count` − `external_page_count` (equivalently Total − Free − Cached, since Free and Cached share the speculative pages)
  - Percentage = Used / Total
  - Note: only free and file-backed pages leave Used. Purgeable pages count as Used but not as App, matching Activity Monitor, and speculative pages count as Cached rather than Free.
  - Note: Used includes memory not visible in App, Wired or Compressed (purgeable, kernel-managed and boot-time carve-out pages), so App + Wired + Compressed is less than Used by roughly 0.5 GB on Apple Silicon.
- R4.3 All page counts are multiplied by the kernel page size, read once from `host_page_size()`.
- R4.4 Values are formatted with `ByteCountFormatStyle` so the decimal separator follows the user locale.
- R4.5 Stacked bar segments are proportional to App, Wired, Compressed, Cached, Free against Total, with the legend colors from 7.1.
- R4.6 History graph shows the last 120 samples of the Used percentage.

### 5.5 Sampling and history
- R5.1 A single `MetricsSampler` drives every provider (CPU, memory, disk, network) on one timer. Default interval 1 s, configurable 0.5–5 s.
- R5.2 History is a fixed-capacity ring buffer per metric (capacity 120). No unbounded arrays. Disk keeps no history (R10.8); Network keeps two, one for download and one for upload bytes per second, appended together only when both rates are available (R11.7).
- R5.3 Sampling runs off the main thread. Only the published snapshot crosses to the main actor.
- R5.4 When the panel is closed, the widget still samples at the configured rate (it needs the sparkline). A P1 optimization may lower the rate to 2 s while the panel is closed.

### 5.6 App behavior
- R6.1 `LSUIElement = YES`: no Dock icon, no main window.
- R6.2 Launch at Login via `SMAppService.mainApp` (F5).
- R6.3 Settings stored in `UserDefaults` via a small `SettingsStore` (F6).
- R6.4 Quit from the context menu.

### 5.7 Disk card (F10)
- R10.1 Scope: capacity is reported for the boot volume (`/`) only, aligned with Finder. Throughput is the sum over every block storage device present, aligned with Activity Monitor's Disk tab.
- R10.2 Capacity source: `URL(fileURLWithPath: "/").resourceValues(forKeys:)` with `.volumeTotalCapacityKey` and `.volumeAvailableCapacityForImportantUsageKey`. Definitions:
  - Total = `volumeTotalCapacity`
  - Free = `volumeAvailableCapacityForImportantUsage` (includes purgeable space; this is the figure Finder shows as Available)
  - Used = Total − Free
  - Percentage = Used / Total
- R10.3 Throughput source: IOKit. Iterate `IOServiceMatching("IOBlockStorageDriver")`, read each driver's `Statistics` dictionary, take `Bytes (Read)` and `Bytes (Write)` (`kIOBlockStorageDriverStatisticsBytesReadKey` and `kIOBlockStorageDriverStatisticsBytesWrittenKey`, declared in `IOKit/storage/IOBlockStorageDriver.h`; the same counters `iostat` reads). Counters are cumulative: the rate is the delta between two samples divided by the elapsed wall time, never a single read (same rule as R3.1). The first sample after start publishes capacity with throughput unavailable.
- R10.4 Counter resets: if a summed delta is negative (drive ejected or mounted, counter wrapped), that tick reports throughput as unavailable and re-seeds the baseline. The next tick reports normally.
- R10.5 Formatting: capacity uses `ByteCountFormatStyle(style: .decimal)` (decimal units, so a 512 GB SSD reads `494,35 GB` as in Finder). Throughput is formatted as decimal bytes per second with one fraction digit and a `/s` suffix (`27,1 MB/s`). Separators follow the system locale as in R4.4.
- R10.6 Layout per 4.5: header, ring gauge with `Disk` sublabel, three key/value rows Used, Free, Total, and a footer row with read then write throughput. Read and write icons must differ (the reference uses the same icon for both; that is a legibility defect, not a requirement) and each carries an accessibility label of "Read" or "Write".
- R10.7 Cadence: throughput is sampled on every tick. Capacity is refreshed at most every 10 s and the last values are reused in between; the important-usage query can cost more than a plain `statfs` and the value changes slowly.
- R10.8 No history graph and no ring buffer for disk in v1. `MetricsState` holds only the latest `DiskSnapshot`.
- R10.9 Unavailable states, mirroring G5: if no `IOBlockStorageDriver` statistics are readable, the footer shows an em dash for both rates with an accessibility label of "unavailable" while capacity keeps rendering. If the capacity query throws, the card shows an "Unavailable" state instead of a fake 0%.
- R10.10 Gauge and icons use `diskAccent` (7.1). The amber-to-green gradient seen in the reference is P2 polish, not a v1 requirement.
- R10.11 Disk has no menu bar module in v1 (open question 3). `MetricModule` and the settings module list are unchanged.

### 5.8 Network card (F11)
- R11.1 Scope: one machine-wide reading, the sum over the admitted interfaces. Source: the interface MIB (`net/if_mib.h`) — the row count from `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT}`, then one `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL}` read per index into a `struct ifmibdata`, taking `ifi_ibytes` and `ifi_obytes` from its `ifmd_data`. No entitlement is required; these are the counters `netstat -ib` reports. The routing-socket MIB `NET_RT_IFLIST2` is **not** used: it declares the same fields as 64-bit but this platform's driver fills only the low 32 bits, so they wrap every 4 GB (corrected 2026-09-10, see 6.3).
- R11.2 Interface filter: a record is admitted when its type is `IFT_ETHER` or `IFT_CELLULAR` and it does not carry `IFF_LOOPBACK`. Being up is not required, so an interface that carried traffic and then went down still contributes its bytes. The filter excludes `lo0`, `utun` tunnels, bridges, `gif` and `stf`.
- R11.3 Total In and Total Out are the since-boot byte totals of the admitted interfaces, reported absolutely rather than accumulated by the app. Caveat: an interface destroyed and recreated by the system resets its own kernel counter, so the totals can dip below a previously shown figure; they track the kernel, not a private ledger.
- R11.4 Rates are the byte delta divided by the elapsed time between two consecutive readings, never a single instantaneous read (the rule of R3.1 and R10.3). If a delta is negative — an interface disappeared or a counter wrapped — that tick reports no rates and re-seeds the baseline, exactly as R10.4 does for disk. The next tick reports normally. A reading covering no interface (R11.2) is likewise never one end of a window, as baseline or as current: it carries zero totals, so measuring from it would report the whole since-boot total as one window of traffic, and the first populated tick after such a reading costs one rate-free tick instead.
- R11.5 The first tick after a start publishes the totals with the rates unavailable, because a rate needs two readings. A restart of the loop costs one tick of rates and no totals.
- R11.6 A failed counter read publishes nothing for network — the previous reading stays on screen — and drops the baseline, so the tick after the failure is a first tick again (R11.5). Every other metric keeps sampling.
- R11.7 History is two fixed-capacity ring buffers of 120 samples, download bytes per second and upload bytes per second. They are appended together and only when both rates are available, so the two series always carry the same sample count and the same time base.
- R11.8 The history graph draws both series against one shared vertical scale, `max(maxDownload, maxUpload, 10 kB/s)`, so the two lines stay comparable and an idle card does not magnify noise. Both series are stroked lines with no fill, unlike the single filled area of the CPU and Memory cards.
- R11.9 Formatting reuses the vocabulary already fixed for disk: decimal units for the totals (`ByteCountFormatStyle(style: .decimal)`, R10.5), decimal bytes per second with one fraction digit and a `/s` suffix for the rates, rendered by the same 12 pt `ThroughputLabel` the Disk card's footer uses. Separators follow the system locale as in R4.4.
- R11.10 Unavailable states, mirroring R10.9: when no rates are available the card shows an em dash for each rate with an accessibility label of "unavailable" rather than a misleading `0 B/s`, while the totals keep rendering. Before the first reading the card shows a skeleton at its populated height, so the panel does not resize on the first tick.
- R11.11 Palette: download green, upload blue, and a distinct `networkAccent` for the header (7.1). Network has no menu bar module in v1 (F9, open question 3): `MetricModule`, the settings module list and the status item width are unchanged.

---

## 6. Technical Design

### 6.1 Architecture (Hexagonal / Screaming)

```
system-monitor/
├── App/                      # @main, AppDelegate, status item setup, DI composition root
├── Domain/
│   ├── Models/               # CPUSnapshot, MemorySnapshot, DiskSnapshot, NetworkSnapshot, MetricHistory
│   ├── Ports/                # CPUMetricsProvider, MemoryMetricsProvider, DiskMetricsProvider, NetworkMetricsProvider (protocols)
│   └── Services/             # CPUUsageCalculator, MemoryUsageCalculator, DiskThroughputCalculator, NetworkThroughputCalculator (M6)
├── Application/
│   ├── MetricsSampler.swift  # timer loop, calls ports, publishes MetricsState
│   ├── MetricsState.swift    # @Observable, main-actor, holds snapshots + histories
│   ├── SettingsState.swift   # @Observable, main-actor, holds the user's Settings (M4)
│   └── SamplingCadence.swift # pure cadence rule + the panel-visibility controller (M4)
├── Infrastructure/
│   ├── Mach/                 # MachCPUProvider (host_processor_info), MachMemoryProvider (host_statistics64)
│   ├── IOKit/                # IOKitDiskProvider (IOBlockStorageDriver statistics + VolumeCapacityReader) (M5)
│   └── System/               # SysctlReader (perflevel core counts), VolumeCapacityReader (URLResourceValues, M5), SysctlNetworkProvider (interface MIB, M6), UserDefaultsSettingsStore, SMAppServiceLaunchAtLogin
└── Presentation/
    ├── MenuBar/              # StatusItemView, ModuleLabel, Sparkline, ContextMenuModel
    ├── Panel/                # PanelView, CPUCard, MemoryCard, DiskCard (M5), NetworkCard, PanelLayout (M6)
    ├── Settings/             # SettingsView, SettingsWindowController (M4)
    └── Components/           # RingGauge, HistoryGraph (multi-series since M6), CoreBar, StackedBar, KeyValueRow, ThroughputLabel (M5)
```

- **Domain** has no imports beyond Foundation. Snapshots are plain `Sendable` structs.
- **Ports** are protocols. Each has one real adapter in Infrastructure and one fake in the test target.
- **Application** holds the only timer and every `@Observable` state object. Since M4 there are two: `MetricsState` (samples and histories, written by the sampler) and `SettingsState` (the user's `Settings`, loaded once through the `SettingsStore` port and persisted on every accepted mutation). Views never touch Mach, IOKit or `UserDefaults`.
- **Presentation** follows container/presentational: cards receive a snapshot and a history, nothing else. The Disk card receives only a snapshot (R10.8); the Network card receives a snapshot and two histories (R11.7).
- v2 adds `Infrastructure/Metal`, a second reader in `Infrastructure/IOKit` (created for Disk in M5), a `GPUMetricsProvider` port and a `GPUCard`. No existing file should need more than a one-line change (registering the new module).

### 6.2 Key domain models

```swift
struct CPUSnapshot: Sendable {
    let total: Double          // 0...1
    let user: Double
    let system: Double
    let cores: [CoreUsage]     // ordered P first, then E
}

struct CoreUsage: Sendable {
    let index: Int
    let usage: Double
    let level: PerformanceLevel  // .performance, .efficiency, .unknown
}

struct MemorySnapshot: Sendable {
    let total: UInt64
    let app, wired, compressed, cached, free: UInt64
    let used: UInt64           // Total − Free − Cached, i.e. Total minus the
                               // free and file-backed pages; carries the
                               // purgeable, kernel and carve-out pages that
                               // App, Wired and Compressed do not account for
    var fraction: Double { Double(used) / Double(total) }
}

// The DiskMetricsProvider port reads the two halves separately, because
// throughput and capacity come from different facilities on different cadences
// (R10.7) and either may fail without affecting the other:
//     func readThroughput() throws -> DiskThroughputCounters
//     func readCapacity()   throws -> VolumeCapacity

struct DiskThroughputCounters: Sendable {  // returned by readThroughput()
    let bytesRead: UInt64                // cumulative, summed over all block storage drivers
    let bytesWritten: UInt64             // cumulative, summed over the same drivers
    let driverCount: Int                 // drivers actually read; 0 is a valid reading
                                         // that carries no data, so no rate follows from it
    let timestamp: ContinuousClock.Instant  // stamped by the adapter at read time, never
                                            // by the Domain, which reads no clock
}

struct VolumeCapacity: Sendable {        // returned by readCapacity()
    let total: UInt64                    // boot volume capacity, bytes
    let free: UInt64                     // available for important usage, bytes
}

struct DiskSnapshot: Sendable {
    let total: UInt64
    let free: UInt64
    let used: UInt64                     // total − free, saturating at 0, so a free figure
                                         // larger than total cannot wrap around
    let readBytesPerSecond: Double?      // both rates are nil together: on the first sample,
    let writeBytesPerSecond: Double?     // after a counter reset, and when driverCount is 0
    var fraction: Double {               // 0 when total is 0, and never above 1
        total > 0 ? min(Double(used) / Double(total), 1) : 0
    }
}

// The NetworkMetricsProvider port reads both directions in one call, because
// they come from the same sysctl walk and splitting them would read the
// interface list twice per tick (R11.1):
//     func readCounters() throws -> NetworkThroughputCounters

struct NetworkThroughputCounters: Sendable {  // returned by readCounters()
    let bytesIn: UInt64                  // cumulative, summed over the admitted interfaces
    let bytesOut: UInt64                 // cumulative, summed over the same interfaces
    let interfaceCount: Int              // interfaces that passed the filter; 0 is a valid
                                         // reading that carries no data (R11.2)
    let timestamp: ContinuousClock.Instant  // stamped by the adapter at read time, as for disk
}

struct NetworkSnapshot: Sendable {
    let totalIn: UInt64                  // bytes received since boot (R11.3)
    let totalOut: UInt64                 // bytes sent since boot
    let downloadBytesPerSecond: Double?  // both rates are nil together: on the first tick,
    let uploadBytesPerSecond: Double?    // after a negative delta, and after a failed read
}
```

### 6.3 Data sources and known constraints

| Metric | API | Notes |
|---|---|---|
| CPU ticks | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Must `vm_deallocate` the returned buffer. Works in sandbox. |
| P/E core counts | `sysctl hw.perflevel0.logicalcpu`, `hw.perflevel1.logicalcpu` | perflevel0 is the higher-performance level on Apple Silicon. Absent on Intel. |
| Memory | `host_statistics64(HOST_VM_INFO64)` | Works in sandbox. |
| Disk capacity | `URLResourceValues` `.volumeTotalCapacityKey`, `.volumeAvailableCapacityForImportantUsageKey` on `/` | Public Foundation API. The important-usage figure includes purgeable space and matches Finder's Available. Works in sandbox (`VolumeCapacityIntegrationTests`). |
| Disk throughput | IOKit `IOBlockStorageDriver` → `Statistics` → `Bytes (Read)`, `Bytes (Write)` | Keys are public constants in `IOKit/storage/IOBlockStorageDriver.h`; same source as `iostat`. Cumulative per device, delta per tick. Works in sandbox: the app target sets `ENABLE_APP_SANDBOX = YES` (`project.pbxproj:401,435`) and the `.integration` suite `IOKitDiskIntegrationTests` proves statistics access inside the sandboxed test host. |
| Network throughput | `sysctl {CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, <index>, IFDATA_GENERAL}` → `ifmibdata` → `ifmd_data.ifi_ibytes` / `ifi_obytes`, with the index count from `IFMIB_SYSTEM`/`IFMIB_IFCOUNT` | Genuinely 64-bit counters from public headers (`net/if_mib.h`: `IFMIB_SYSTEM` :79, `IFMIB_IFDATA` :80, `IFDATA_GENERAL` :86, `IFMIB_IFCOUNT` :94, `NETLINK_GENERIC` :100), no entitlement. Cumulative per interface, delta per tick; indices are sparse, so `ENOENT`/`ENXIO`/`EINVAL` on one index is a gap, not a failure. Works in sandbox: the `.integration` suite `SysctlNetworkIntegrationTests` proves the reads inside the sandboxed test host. **Corrected 2026-09-10**: the first implementation used the routing socket (`NET_RT_IFLIST2` → `if_msghdr2` → `if_data64`), whose fields are declared `u_int64_t` but filled by this driver with only the low 32 bits. Measured: `en1` at 13 563 204 219 via this MIB against 678 301 696 via the routing socket at the same moment — the low 32 bits exactly. The wrap every 4 GB made the summed delta negative, so R11.4 discarded the tick and the totals appeared to reset. |

All v1 data sources are public APIs: Mach for CPU and memory, Foundation and IOKit block storage statistics for disk, and sysctl for network.

### 6.4 Concurrency
- Swift 6 strict concurrency, default MainActor isolation for the module.
- `MetricsSampler` runs its loop in a detached `Task` with `Task.sleep` at the interval, not a `Timer` on the main run loop.
- Providers are `nonisolated` and `Sendable`; they return value-type snapshots.
- `MetricsState` and `SettingsState` are both `@MainActor @Observable`. Views read them via `@Environment`; non-view consumers of `SettingsState` (the sampling cadence controller, the status-item re-measure) register a synchronous observer instead.

### 6.5 Rendering
- Sparkline, history graph, ring gauge and core bars are `Canvas`-based custom views. Swift Charts is acceptable for the panel history graphs but is too heavy for the 1 Hz menu bar sparkline.
- The status item view must be sized deterministically; measure once with `fixedSize()` and set `statusItem.length` explicitly.
- All animations respect `accessibilityReduceMotion`.

---

## 7. Visual Design

### 7.1 Palette (dark, from the reference images)

| Token | Hex (approx.) | Use |
|---|---|---|
| `panelBackground` | `#0F1522` | Popover background |
| `cardBackground` | `#1A2131` | Card surface |
| `textPrimary` | `#F2F4F8` | Values |
| `textSecondary` | `#8A93A6` | Labels |
| `cpuAccent` | `#4D8DFF` | CPU gauge, graph, P-core values |
| `cpuEfficiency` | `#3FC1C9` | E-core values and bars |
| `memAccent` | `#F5A623` | Memory gauge, graph, App segment |
| `memWired` | `#E5484D` | Wired segment |
| `memCompressed` | `#F5D90A` | Compressed segment |
| `memCached` | `#4D8DFF` | Cached segment |
| `memFree` | `#3DD68C` | Free segment |
| `diskAccent` | `#3DD68C` | Disk gauge and throughput icons (same green as `memFree`; the reference's amber start of the arc is P2, R10.10) |
| `networkAccent` | `#C659E4` | Network header glyph (sampled from the globe in `06-panel-network.png`) |
| `networkDownload` | `#3DD68C` | Download rate and its graph line (same green as `memFree` and `diskAccent`) |
| `networkUpload` | `#4D8DFF` | Upload rate and its graph line (same blue as `cpuAccent` and `memCached`) |
| `gpuAccent` | `#3DD68C` | GPU gauge and graph (v2) |

Colors live in an asset catalog with light variants (F7). Hex values are estimates from the screenshots and should be sampled precisely during implementation; `networkAccent` was sampled that way on 2026-09-10, which is why it is not the `#A66BFF` the design first estimated by eye.

### 7.2 Typography
- System font. Big gauge values: 22 pt bold, rounded design. Labels: 11 pt. Key/value rows: 12 pt with values in medium weight.
- Menu bar: 11 pt monospaced digits for the percentage.

### 7.3 Card layout (both cards share the skeleton)

```
┌─────────────────────────────────────────┐
│ [icon] Title                             │
│  ╭───╮      key ............... value    │
│  │40%│      key ............... value    │
│  ╰───╯      key ............... value    │
│  [history area graph, full width]        │
│  [card-specific footer: core bars /      │
│   stacked bar + legend]                  │
└─────────────────────────────────────────┘
```

The Disk card omits the history graph row; its footer is the read/write throughput row (4.5). The Network card replaces the gauge-and-rows block with a two-column rates/totals block and keeps the history graph row, drawn as two lines instead of one filled area (4.6, R11.8).

---

## 8. Testing Strategy (Strict TDD)

- Framework: Swift Testing (`@Test`, `#expect`).
- **Domain**: pure functions. Tick-delta to percentage, memory breakdown math, disk used/fraction math, cumulative byte counters to bytes per second including the negative-delta reset, the network Δ/Δt rule with its own re-seed (R11.4) and the interface filter truth table (R11.2), ring buffer behavior, P/E grouping. Written first, no mocks needed.
- **Application**: `MetricsSampler` tested with fake providers injected through the ports. Assert that snapshots are published, history capacity holds, a throwing provider does not stop the loop, the first tick publishes disk capacity without throughput and network totals without rates (R11.5), capacity is refreshed on the 10 s cadence (R10.7), and the two network histories are appended together (R11.7).
- **Infrastructure**: thin integration tests that only assert shape (core count > 0, total memory > 0, boot volume total > 0, at least one block storage driver found, the interface MIB returns at least one admitted interface whose counters are not truncated to 32 bits). The filter truth table and the saturating sum are unit-tested; the sysctl shape is integration. These are the only tests that hit real system APIs and are tagged `.tags(.integration)`.
- **Presentation**: snapshot-free. Cards are given fixed snapshots in Previews; a couple of unit tests cover formatting helpers (percentage strings, byte formatting under a fixed locale, decimal capacity and `MB/s` throughput strings, the network strings under `en_US` and `de_DE`), the shared graph scale (R11.8) and the reduce-motion rule — `NetworkCardModel.animation(reduceMotion:)` delegates to the CPU card's, as the Disk card does.
- Target: 80%+ on Domain and Application. Infrastructure is exempt from coverage goals.

---

## 9. Milestones

| # | Milestone | Deliverable |
|---|---|---|
| M1 | Skeleton | Status item shows static "CPU 0%" text, popover opens and closes, `LSUIElement` set. |
| M2 | CPU end to end | Mach provider, sampler, sparkline in the bar, CPU card with gauge and per-core bars. |
| M3 | Memory | vm_statistics provider, Memory card with stacked bar and legend. |
| M4 | Polish | Launch at login, settings, light mode, animation and performance pass. |
| M5 | Disk | `DiskMetricsProvider` port, IOKit throughput + volume capacity adapter, sampler extension, Disk card (section 5.7). Ship v1. |
| M6 | Network | `NetworkMetricsProvider` port, sysctl adapter, sampler extension, Network card (section 5.8), panel scroll cap. |
| M7 | GPU (v2) | Section 11. |

---

## 10. Risks and Open Questions

| Risk | Impact | Mitigation |
|---|---|---|
| Mach core index to P/E level mapping differs across chips | Wrong per-core grouping | Verify at startup, cover with tests, never hardcode (R3.4). |
| `MenuBarExtra` limitations tempt a simpler implementation | Laggy or blank sparklines | Decision made: `NSStatusItem` + `NSHostingView` (R1.1). |
| Per-second redraw of the status item costs CPU | Violates the under-1% goal | Redraw only when a value changed by ≥1 pt or the sparkline shifted; profile with Instruments in M4. |
| Wide menu bar on small displays | Widget gets hidden by macOS | Keep under 230 pt (R1.7); allow hiding modules (F6). |
| `IOBlockStorageDriver` counters are per device and cumulative | Wrong rate after an eject or mount, or on multi-disk Macs | Sum over the drivers present on each tick, re-seed on a negative delta (R10.4), cover with a fake provider. |
| Important-usage capacity query at 1 Hz | Sampling CPU creeps toward the 1% budget | Refresh capacity at most every 10 s (R10.7); profile in M5. |
| Popover grows with a third card | Panel taller than short displays allow | Measured in M5: 678 pt with two cards → 871 pt with three (the Disk card adds 175 pt, the shortest of the three since it has no graph). Height still fits content (R2.2) and still fits a 14" display. |
| Popover grows with a fourth card | Four cards no longer fit a 14" display | Measured in M6: 1049 pt with four (370 CPU + 278 Memory + 175 Disk + 166 Network + 60 chrome), against roughly 945 pt of visible frame on a 14" display at default scaling. Mitigation: the visible-frame cap with scrolling (R2.5), which pins the panel at 921 pt there; manual check on the 14" display. |
| Interface churn resets a per-interface counter | Totals dip, and a wrapped delta would spike the rate | Negative-delta re-seed (R11.4) and the documented totals caveat (R11.3). |

Profiling note: the Instruments pass named in the third row (Time Profiler + SwiftUI template, panel closed then open) is a manual M4 task, not an automated one. Its measured CPU and RSS numbers are recorded in `openspec/changes/polish-module/apply-progress.md` alongside the rest of the M4 manual checklist.

**Open questions**
1. Should NET be reserved as a slot in the settings UI now, or left entirely to a future version? Proposed: leave it out of v1 entirely.
2. Is light mode a v1 requirement or acceptable as P2? Proposed: P2.
3. Should Disk get a menu bar module (throughput sparkline or a percentage)? Proposed: no, panel card only in v1; revisit together with NET. **Decided 2026-09-10: no Disk or Network menu bar module in v1. F9 stays Future; revisit both together.**

---

## 11. v2: GPU Module (deferred)

Kept here so the design is not lost. Nothing in this section is built in v1; it ships as milestone M7 (section 9).

### 11.1 Reference: `04-panel-gpu.png`
- Header: GPU icon + "GPU".
- Left: ring gauge `22.0%`, sublabel `GPU`. Gauge color green.
- Right: `Device Apple M2`, `Memory 6,8 MB / 5,33 GB`.
- Bottom: history area graph, green fill.
- `5,33 GB` on an 8 GB M2 matches Metal's `recommendedMaxWorkingSetSize` (≈ 2/3 of unified memory). `6,8 MB` is the sampling process's own Metal allocation, which is not useful to the user.

### 11.2 Requirements
- G1 Third widget module `GPU` after MEM, sparkline + percentage, same layout as the others.
- G2 Device name from `MTLCreateSystemDefaultDevice()?.name`.
- G3 Utilization from IOKit: iterate `IOServiceMatching("IOAccelerator")`, read the `PerformanceStatistics` dictionary, use `Device Utilization %`. Fall back to `Renderer Utilization %` if the device key is missing.
- G4 GPU memory: show **system-wide** `In use system memory` from the same dictionary as "used", and `recommendedMaxWorkingSetSize` as the max. If unavailable, show only the max.
- G5 If no IOAccelerator statistics are readable, the card shows the device name and a "Utilization unavailable" state instead of a fake 0%.
- G6 History graph shows the last 120 samples of utilization.

### 11.3 Domain model

```swift
struct GPUSnapshot: Sendable {
    let deviceName: String
    let utilization: Double?     // nil when unavailable
    let memoryUsed: UInt64?
    let memoryMax: UInt64
}
```

### 11.4 Data sources

| Metric | API | Notes |
|---|---|---|
| GPU utilization | IOKit `IOAccelerator` → `PerformanceStatistics` | Undocumented dictionary keys, may change across macOS versions. Unverified under App Sandbox. |
| GPU device | Metal `MTLDevice.name`, `recommendedMaxWorkingSetSize` | Public API. |

### 11.5 Risks
- `PerformanceStatistics` keys are undocumented and may be empty under sandbox. Mitigation: graceful unavailable state (G5), no sandbox, re-verify on each macOS beta.
- This is the main reason GPU was deferred: v1 ships on public APIs only. Disk's IOKit keys are public header constants (R10.3), unlike `PerformanceStatistics`.

### 11.6 Open question
- System-wide GPU memory (proposed) versus per-process as in the reference screenshot.
