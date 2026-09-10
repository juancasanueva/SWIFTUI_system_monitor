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
- **Updates.** Signed in-app updates from the project's own feed. Automatic checking is off until you turn it on; **Check for Updates…** in the right-click menu is always there.

## Requirements

- macOS 15 (Sequoia) or later
- Apple Silicon
- Xcode 26 with Swift 6 to build from source

## Install

With Homebrew:

```sh
brew tap juancasanueva/system-monitor
brew trust juancasanueva/system-monitor
brew install --cask system-monitor
```

That installs `/Applications/System-Monitor.app`, the same notarized build the
releases page serves. Homebrew 6 refuses to load a cask from a third-party tap
until the tap is trusted, which is what the middle line does; it grants nothing
beyond this tap. The unambiguous form is
`brew install --cask juancasanueva/system-monitor/system-monitor`.

**Already have `System-Monitor.app` in `/Applications`?** Homebrew refuses to
overwrite an app it did not place (`It seems there is already an App at
'/Applications/System-Monitor.app'`). Let it adopt the existing copy instead:

```sh
brew install --cask --adopt system-monitor
```

Adoption keeps the bundle and its data where they are and simply records it as
brew-managed. Because the cask declares `auto_updates`, brew does not compare
versions before adopting: the copy you have, whatever Sparkle has updated it to,
is the one it takes over.

Or download the latest `System-Monitor-<version>.zip` from
[Releases](../../releases), unzip it, and drag `System-Monitor.app` to
`/Applications`.

The build is notarized and stapled, so the first launch is a single ordinary
"Open" confirmation — no right-click workaround, and no network access needed to
get past Gatekeeper. Apple Silicon and macOS 15 or later only.

To remove a cask install, `brew uninstall --cask --zap system-monitor` also
deletes System Monitor's preferences and caches. System Monitor creates no
Keychain items, so nothing of its own is left behind there.

## Build from source

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

## Updates

System Monitor updates itself with [Sparkle](https://sparkle-project.org), from an
EdDSA-signed appcast published alongside each release. The feed URL and the
public verification key are compiled into the app, so an update is only ever
installed if its signature matches the key the running copy already carries.

**Automatic checking is off by default.** A check is a network request, and
System Monitor asks before making one: turn it on in **Settings → Updates**, or
leave it off and use **right-click → Check for Updates…** whenever you want. The
Settings section also shows when the last check actually happened, and says so
plainly when there has never been one.

Prereleases are never offered.

## Releasing

Pushing a `v*` tag is the only thing that publishes a release. CI builds an
arm64, Developer ID-signed, notarized and stapled `System-Monitor-<version>.zip`
and attaches it to a GitHub Release; every gate runs before publication, so a
failed run publishes nothing.

The same job publishes the Sparkle appcast to GitHub Pages on a stable tag; a
prerelease tag publishes a release and no feed entry.

The runbook, prerequisites, version policy and entitlements rationale live in
[`RELEASING.md`](RELEASING.md). Third-party attributions live in
[`THIRD-PARTY.md`](THIRD-PARTY.md).

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
