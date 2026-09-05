# PRD: System Monitor for macOS

| Field | Value |
|---|---|
| Status | Draft v2 (GPU deferred to v2 release) |
| Date | 2026-09-04 |
| Platform | macOS 26.5+ (Xcode project deployment target), Apple Silicon first |
| Stack | Swift 6, SwiftUI, AppKit (NSStatusItem / NSPopover), Mach APIs for metrics |
| Reference images | `docs/reference/` (see section 4) |

---

## 1. Summary

A lightweight, always-visible system monitor that lives in the macOS menu bar. It shows a compact widget with a live sparkline and current value for **CPU** and **RAM**. Clicking the widget opens a detail panel with a ring gauge, a breakdown of the metric, a longer history graph and, for CPU, per-core bars split into Performance and Efficiency cores.

The goal is a native, low-overhead replacement for tools like iStat Menus or Stats, focused only on the metrics that matter day to day, with a modern dark UI.

**v1 scope is CPU and RAM only.** GPU is designed and specified in section 11 and ships in v2. The architecture is built so that adding it is additive: one provider adapter, one card, one widget module.

---

## 2. Problem and Users

**Who is this for.** A developer or power user on an Apple Silicon Mac who wants to see at a glance whether the machine is under load, without opening Activity Monitor.

**Pain today.**
- Activity Monitor is a full window and gives no at-a-glance history.
- Existing menu bar monitors are either heavy, paid, cluttered with dozens of modules, or visually dated.

**Why now.** P-core versus E-core scheduling on Apple Silicon is a real signal of what kind of work the machine is doing, and it is invisible in the menu bar today. Memory pressure on unified-memory machines matters more than on discrete-GPU machines.

**Anti-goals (explicitly out of scope for v1).**
- GPU (deferred to v2, see section 11).
- Network, disk, battery, sensors, fans, temperatures.
- Process list or per-process usage.
- Notifications or alerts on thresholds.
- Intel Macs as a first-class target (must not crash, but P/E split will be absent).
- Mac App Store distribution (not needed for v1; revisit with GPU since IOKit access under sandbox is unverified).

**Success metric.** The app runs for a full working day with under 1% average CPU and under 50 MB RSS, and the menu bar values match Activity Monitor within a reasonable margin (CPU ±3 pts, memory within 100 MB).

---

## 3. Feature Overview

| ID | Feature | Priority |
|---|---|---|
| F1 | Menu bar widget: CPU and MEM, each with sparkline + percentage | P0 |
| F2 | Detail panel opened on click, two stacked cards (CPU, Memory) | P0 |
| F3 | CPU card: ring gauge, User/System/P-Cores/E-Cores values, history graph, per-core bars | P0 |
| F4 | Memory card: ring gauge, Used/Total/Wired/Compressed values, stacked legend, history graph | P0 |
| F5 | Launch at login toggle | P1 |
| F6 | Settings: sampling interval, which modules show in the menu bar, widget order | P1 |
| F7 | Light mode support (dark is the default and reference design) | P2 |
| F8 | GPU module: widget slot + GPU card (section 11) | v2 |
| F9 | Network module (as in the original reference bar) | Future |

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
- R2.2 Fixed width around 320 pt. Height fits content; the cards stack vertically with 12 pt gaps.
- R2.3 Dark card background (see 7.1), 12 pt corner radius, no visible borders.
- R2.4 The panel keeps updating live while open, at the same sampling interval.

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
- R5.1 A single `MetricsSampler` drives both providers on one timer. Default interval 1 s, configurable 0.5–5 s.
- R5.2 History is a fixed-capacity ring buffer per metric (capacity 120). No unbounded arrays.
- R5.3 Sampling runs off the main thread. Only the published snapshot crosses to the main actor.
- R5.4 When the panel is closed, the widget still samples at the configured rate (it needs the sparkline). A P1 optimization may lower the rate to 2 s while the panel is closed.

### 5.6 App behavior
- R6.1 `LSUIElement = YES`: no Dock icon, no main window.
- R6.2 Launch at Login via `SMAppService.mainApp` (F5).
- R6.3 Settings stored in `UserDefaults` via a small `SettingsStore` (F6).
- R6.4 Quit from the context menu.

---

## 6. Technical Design

### 6.1 Architecture (Hexagonal / Screaming)

```
system-monitor/
├── App/                      # @main, AppDelegate, status item setup, DI composition root
├── Domain/
│   ├── Models/               # CPUSnapshot, MemorySnapshot, MetricHistory
│   └── Ports/                # CPUMetricsProvider, MemoryMetricsProvider (protocols)
├── Application/
│   ├── MetricsSampler.swift  # timer loop, calls ports, publishes MetricsState
│   └── MetricsState.swift    # @Observable, main-actor, holds snapshots + histories
├── Infrastructure/
│   ├── Mach/                 # MachCPUProvider (host_processor_info), MachMemoryProvider (host_statistics64)
│   └── System/               # SysctlReader (perflevel core counts), LaunchAtLogin
└── Presentation/
    ├── MenuBar/              # StatusItemView, ModuleLabel, Sparkline
    ├── Panel/                # PanelView, CPUCard, MemoryCard
    └── Components/           # RingGauge, HistoryGraph, CoreBar, StackedBar, KeyValueRow
```

- **Domain** has no imports beyond Foundation. Snapshots are plain `Sendable` structs.
- **Ports** are protocols. Each has one real adapter in Infrastructure and one fake in the test target.
- **Application** holds the only timer and the only `@Observable` state object. Views never touch Mach or IOKit.
- **Presentation** follows container/presentational: cards receive a snapshot and a history, nothing else.
- v2 adds `Infrastructure/IOKit`, `Infrastructure/Metal`, a `GPUMetricsProvider` port and a `GPUCard`. No existing file should need more than a one-line change (registering the new module).

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
```

### 6.3 Data sources and known constraints

| Metric | API | Notes |
|---|---|---|
| CPU ticks | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Must `vm_deallocate` the returned buffer. Works in sandbox. |
| P/E core counts | `sysctl hw.perflevel0.logicalcpu`, `hw.perflevel1.logicalcpu` | perflevel0 is the higher-performance level on Apple Silicon. Absent on Intel. |
| Memory | `host_statistics64(HOST_VM_INFO64)` | Works in sandbox. |

All v1 data sources are public, documented Mach APIs.

### 6.4 Concurrency
- Swift 6 strict concurrency, default MainActor isolation for the module.
- `MetricsSampler` runs its loop in a detached `Task` with `Task.sleep` at the interval, not a `Timer` on the main run loop.
- Providers are `nonisolated` and `Sendable`; they return value-type snapshots.
- `MetricsState` is `@MainActor @Observable`. Views read it via `@Environment`.

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
| `gpuAccent` | `#3DD68C` | GPU gauge and graph (v2) |

Colors live in an asset catalog with light variants (F7). Hex values are estimates from the screenshots and should be sampled precisely during implementation.

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

---

## 8. Testing Strategy (Strict TDD)

- Framework: Swift Testing (`@Test`, `#expect`).
- **Domain**: pure functions. Tick-delta to percentage, memory breakdown math, ring buffer behavior, P/E grouping. Written first, no mocks needed.
- **Application**: `MetricsSampler` tested with fake providers injected through the ports. Assert that snapshots are published, history capacity holds, and a throwing provider does not stop the loop.
- **Infrastructure**: thin integration tests that only assert shape (core count > 0, total memory > 0). These are the only tests that hit real system APIs and are tagged `.tags(.integration)`.
- **Presentation**: snapshot-free. Cards are given fixed snapshots in Previews; a couple of unit tests cover formatting helpers (percentage strings, byte formatting under a fixed locale).
- Target: 80%+ on Domain and Application. Infrastructure is exempt from coverage goals.

---

## 9. Milestones

| # | Milestone | Deliverable |
|---|---|---|
| M1 | Skeleton | Status item shows static "CPU 0%" text, popover opens and closes, `LSUIElement` set. |
| M2 | CPU end to end | Mach provider, sampler, sparkline in the bar, CPU card with gauge and per-core bars. |
| M3 | Memory | vm_statistics provider, Memory card with stacked bar and legend. |
| M4 | Polish | Launch at login, settings, light mode, animation and performance pass. Ship v1. |
| M5 | GPU (v2) | Section 11. |

---

## 10. Risks and Open Questions

| Risk | Impact | Mitigation |
|---|---|---|
| Mach core index to P/E level mapping differs across chips | Wrong per-core grouping | Verify at startup, cover with tests, never hardcode (R3.4). |
| `MenuBarExtra` limitations tempt a simpler implementation | Laggy or blank sparklines | Decision made: `NSStatusItem` + `NSHostingView` (R1.1). |
| Per-second redraw of the status item costs CPU | Violates the under-1% goal | Redraw only when a value changed by ≥1 pt or the sparkline shifted; profile with Instruments in M4. |
| Wide menu bar on small displays | Widget gets hidden by macOS | Keep under 230 pt (R1.7); allow hiding modules (F6). |

**Open questions**
1. Should NET be reserved as a slot in the settings UI now, or left entirely to a future version? Proposed: leave it out of v1 entirely.
2. Is light mode a v1 requirement or acceptable as P2? Proposed: P2.

---

## 11. v2: GPU Module (deferred)

Kept here so the design is not lost. Nothing in this section is built in v1.

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
- This is the main reason GPU was deferred: v1 ships on public APIs only.

### 11.6 Open question
- System-wide GPU memory (proposed) versus per-process as in the reference screenshot.
