<h1 align="center">System Monitor</h1>

**A lightweight system monitor for the macOS menu bar.** Pure SwiftUI and AppKit, no backend, free.

System Monitor keeps a compact CPU and memory widget in the menu bar, each with a live sparkline and its current percentage. Click it and a dark panel opens with four cards: CPU, Memory, Disk and Network. It reads the same Mach and IOKit counters Activity Monitor reads, and it is built to stay out of the way: under 1% CPU and under 50 MB of memory over a working day is the target.

## Features

- **Menu bar widget.** CPU and MEM side by side on a rounded card, each with a 60-sample sparkline and an integer percentage. The widget has a fixed width, so values changing every second never make the menu bar jitter.
- **CPU card.** Ring gauge of total load, User and System split, Performance-core and Efficiency-core averages, a history graph, and one bar per core grouped into P-cores and E-cores.
- **Memory card.** Ring gauge of used memory, Used, Total, Wired and Compressed values, a stacked bar of App, Wired, Compressed, Cached and Free with a legend, and a history graph. The numbers follow Activity Monitor's formula.
- **Disk card.** Ring gauge of how full the boot volume is, Used, Free and Total, and live read and write throughput.
- **Network card.** Live download and upload rates, bytes received and sent since boot, and a dual-line history graph of both rates.
- **Settings.** Sampling interval from 0.5 s to 5 s, which modules appear in the menu bar, and their order. The sampler drops to a 2 s idle cadence while the panel is closed.
- **Launch at Login.** One toggle in the right-click menu, backed by the system login items service.
- **About.** Version, credits, links and license from the right-click menu.

## Requirements

- macOS 26.5 or later
- Apple Silicon. The app runs on Intel, but the Performance and Efficiency core split is only available on Apple Silicon.
- Xcode 26 with Swift 6 to build from source

## Build and run

Clone the repository and open the project in Xcode:

```sh
git clone git@github.com:juancasanueva/SWIFTUI_system_monitor.git
cd SWIFTUI_system_monitor
open system-monitor.xcodeproj
```

Select the `system-monitor` scheme and run. The app has no Dock icon or main window: it lives in the menu bar. Left-click the widget for the panel, right-click for the menu.

From the command line:

```sh
xcodebuild -scheme system-monitor -destination 'platform=macOS,arch=arm64' build
xcodebuild -scheme system-monitor -destination 'platform=macOS,arch=arm64' test
```

## Architecture

The code follows a hexagonal layout, so each folder under `system-monitor/` names a layer and nothing else:

| Folder | Role |
|---|---|
| `Domain` | Models, ports and pure services. No framework imports beyond Foundation. |
| `Application` | The sampler, the observable metrics and settings state, and the sampling cadence. |
| `Infrastructure` | Adapters over Mach, IOKit, sysctl, UserDefaults and the login items service. |
| `Presentation` | SwiftUI views, the menu bar controller, the panel cards, settings and the About window. |
| `App` | The composition root and the SwiftUI app entry point. |

Every metric is computed in the Domain from raw counters, so the formulas are unit tested without touching the kernel. The menu bar and panel views are plain values driven by observable state, and they compare equal when nothing changed, so SwiftUI skips their redraws.

## Development

The project is developed with strict test-driven development using Swift Testing. Requirements live as specifications under `openspec/specs/`, one folder per capability, and the product document is `PRD.md`. The reference designs the UI follows are under `docs/reference/`.

## Credits

- **Developer** Juan Casanueva
- **Testers** Sebastián Casanueva, Rodrigo Casanueva

## License

MIT. See [LICENSE](LICENSE).
