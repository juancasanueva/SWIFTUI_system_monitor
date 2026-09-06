## Exploration: polish-module (PRD M4 "Polish" — F5, F6, F7; R5.1, R5.4, R6.2, R6.3, R6.4; 7.1; section 10; OQ1, OQ2)

Engram mirror: `sdd/polish-module/explore` (id 8237). Explored on 2026-09-06 by sdd-explore (Fable 5.1). CodeGraph: no `.codegraph/` index; fell back to Read/Grep/Glob.

### Current State

- Baseline: M1–M3 archived (`openspec/changes/archive/2026-09-04-cpu-module`, `2026-09-06-memory-module`); specs of record `cpu-metrics`, `core-topology`, `cpu-card`, `menu-bar-widget`, `memory-metrics`, `memory-card`. Last verify report: 299/299 tests, zero compiler warnings (`openspec/changes/archive/2026-09-06-memory-module/verify-report.md:64,62`). Debt recorded there: wall-clock loop tests W1/W5 (line 258), `NSStatusItem` leak W6 (259), MC-10 reduce-motion inspection-only (252).
- App lifecycle. `system-monitor/App/system_monitorApp.swift:10-12` declares `Settings { EmptyView() }` as the only scene. `system-monitor/App/AppDelegate.swift:14-29` is the composition root: `MetricsState`, `MetricsSampler(... interval: .seconds(1))` (line 21, hard-coded), `StatusItemController(state:)`, then `sampler.start()`; `applicationWillTerminate` stops the sampler (31-33). Repo-wide grep finds no `UserDefaults`, `SMAppService`, `openSettings`, `NSAppearance` or `colorScheme` usage in the app target.
- Status item. `system-monitor/Presentation/MenuBar/StatusItemController.swift:10` is a plain `final class` holding `NSStatusItem`, a `PassthroughHostingView` with `sizingOptions = []` (23) and one `NSPopover` (14). `statusItem.length` is set once from `measuredContentWidth()` (46, 66-72). Button action fires on left and right mouse-up (48-50); `handleClick` (94-100) routes right-click to `showContextMenu()` and left-click to `togglePopover()` (102-109). The popover's `NSHostingController(rootView: PanelView().environment(state))` is created eagerly in `init` (53-58) with no delegate and no explicit `appearance`. The context menu (111-126) is rebuilt on every right-click and contains only "Quit System Monitor" wired to `NSApplication.terminate(_:)` — R6.4 is already satisfied; R1.5's "Settings" and "Launch at Login" items do not exist.
- Sampler. `system-monitor/Application/MetricsSampler.swift:62` stores `private let interval: Duration`; `start()` copies it into a local (104) captured by `Task.detached(priority: .utility)` (108) and applies it as `gap = interval` (142) after every sleep. The interval is read once at task start; a runtime change cannot reach the running loop without a restart or a shared mutable box. `clock: any Clock<Duration>` is already injected (64, 79) but `MetricsSamplerLoopTests` (`system-monitorTests/Application/MetricsSamplerTests.swift:277-435`) still poll `ContinuousClock` and `Task.sleep` (293-305, 372-376, 395-399) — debt W1/W5.
- State. `system-monitor/Application/MetricsState.swift:13-48` is the only `@Observable` object; each `apply` mutates a snapshot plus a history once per tick.
- Widget. `StatusItemReadings.build(...)` maps over the static `MetricModule.menuBarOrder` (`system-monitor/Presentation/MenuBar/StatusItemView.swift:42`; `system-monitor/Domain/Models/MetricModule.swift:22-24`). `StatusItemMetrics.measurementReadings` is a `static let` from `menuBarOrder` (105-111) and sizes the item. `StatusItemView` (134-148) reads all four state properties, so its body re-evaluates every tick. `ModuleLabel` (166-193) wraps `Sparkline` in `.equatable()` (181); `StatusItemContent` (115-128) and `ModuleLabel` are not `Equatable`. `MetricHistory.suffix` (`system-monitor/Domain/Models/MetricHistory.swift:61-64`) materialises `ordered` (52-56) then `suffix` — a handful of small allocations per tick.
- Cards and motion. `CPUCard.swift:128,153` and `MemoryCard.swift:160,231` read `@Environment(\.accessibilityReduceMotion)` and gate `.animation(reduceMotion ? nil : easeOut(0.25), value:)` on the ring gauge only. All Canvas components are `Equatable` with no animation of their own. The environment is not injectable from the unit target, hence MC-10 inspection-only.
- Palette. `system-monitor/Presentation/Theme/Palette.swift:7-56` is a `nonisolated enum` of `Color(.sRGB, …)` literals via `sRGB(_:)` (47-55); its doc comment (4-6) defers the asset catalog. `Assets.xcassets` holds only an empty `AccentColor` and `AppIcon`; `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES` (`project.pbxproj:276,340`). `PaletteTests` (`system-monitorTests/Presentation/StatusItemReadingsTests.swift:28-75`) assert literal `Color` equality; card model tests compare against `Palette` tokens by identity (unaffected if models keep returning `Palette` values).
- Popover appearance today: no `appearance` is set, so the chrome follows the system while `PanelView.swift:23` paints `Palette.panelBackground` unconditionally — light arrow around a dark panel under a light system appearance.
- Build settings (`project.pbxproj:392-425`): `ENABLE_APP_SANDBOX = YES` (401), `ENABLE_HARDENED_RUNTIME = YES` (402), `CODE_SIGN_STYLE = Automatic` + `DEVELOPMENT_TEAM` (397, 400) — dev builds are signed with an Apple Development identity, not unsigned; `INFOPLIST_KEY_LSUIElement = YES` (407); `MACOSX_DEPLOYMENT_TARGET = 26.5` (412), so `SMAppService` (13+), `openSettings` (14+) and `NSApplication.activate()` (14+) are available; `SWIFT_VERSION = 6.0` (422). `openspec/config.yaml` is stale at line 25 (`swift_version "5.0"`), line 24 (`app target 15.0`) and line 90 ("no commits yet").
- Test infrastructure: Mutex-backed `FakeCPUProvider`/`FakeMemoryProvider`, `FakeCoreTopologyProvider`, `TickFixtures`, `MemoryFixtures`, `Tags.integration`, `makeSampler` helpers (`MetricsSamplerTests.swift:17-30, 307-321`), `NSHostingView.fittingSize` helpers (`PanelViewTests.swift:37-49`, `StatusItemReadingsTests.swift:287-298`). `MetricModuleTests.swift:6-8` pins `menuBarOrder == [.cpu, .memory]`.

External facts verified:
- `SMAppService.mainApp` (macOS 13+): `register() throws`, `unregister() throws`, `status` synchronous with `.notRegistered`, `.enabled`, `.requiresApproval`, `.notFound`; `SMAppService.openSystemSettingsLoginItems()`. Works under App Sandbox. Status must be read live, never persisted, because users toggle it in System Settings. Dev builds register the DerivedData path; a moved/deleted build leaves a `.notFound` item. "Operation not permitted" occurs when a conflicting launchd job exists.
- Settings from an LSUIElement app: `showSettingsWindow:` stopped working on macOS 14; `SettingsLink` is unreliable outside a window; `openSettings` needs a live SwiftUI render tree and was reported to fail silently on macOS 26, this project's deployment target; the published workaround requires a hidden `Window` scene before `Settings` plus an activation-policy toggle. On macOS 14+ `activate()` is a request honoured after recent user interaction (a status-item click qualifies in practice; verify manually).

### Affected Areas

Modified:
- `system-monitor/App/AppDelegate.swift` — build store, `SettingsState`, launch-at-login adapter; interval from settings.
- `system-monitor/App/system_monitorApp.swift` — keep one scene; decide whether `Settings` hosts the real view for Cmd+, coherence.
- `system-monitor/Application/MetricsSampler.swift` — `apply(interval:)` / cadence; restart path.
- `system-monitor/Presentation/MenuBar/StatusItemController.swift` — menu items, popover delegate (R5.4), re-measure on module-set change, optional dark `popover.appearance`, `deinit` removing the item (W6).
- `system-monitor/Presentation/MenuBar/StatusItemView.swift` — `build(modules:)`, `measurementReadings(for:)`, `SettingsState` from environment, `Equatable` content.
- `system-monitor/Domain/Models/MetricModule.swift` — `menuBarOrder` becomes the documented default.
- `system-monitor/Presentation/Theme/Palette.swift` — only if light mode ships.
- `CPUCard.swift`, `MemoryCard.swift` — optional model-level `gaugeAnimation(reduceMotion:)` to promote MC-10.
- `MetricHistory.swift` — optional `newest(_:)`.
- Tests: `MetricsSamplerTests`, `StatusItemControllerTests`, `StatusItemReadingsTests`, `MetricModuleTests`.
- Specs: `menu-bar-widget` (MBW-1, fixed-width rule, MBW-8, ADDED context-menu requirement); `cpu-metrics` "Startup double-sample and cadence" (ADDED runtime interval scenario) and "Loop resilience and cancellation" (ADDED idle cadence if R5.4 in scope); `cpu-card`/`memory-card` "Palette" only if light variants ship.

New:
- `Domain/Models/Settings.swift`, `Domain/Models/LaunchAtLoginStatus.swift`; `Domain/Ports/SettingsStore.swift`, `Domain/Ports/LaunchAtLoginService.swift`; `Application/SettingsState.swift` (second `@Observable` object — PRD 6.1 wording deviation to record), `Application/SamplingCadence.swift` (if R5.4); `Infrastructure/System/UserDefaultsSettingsStore.swift`, `Infrastructure/System/SMAppServiceLaunchAtLogin.swift`; `Presentation/Settings/SettingsView.swift`, `Presentation/Settings/SettingsWindowController.swift`.
- Tests: Domain/Application/Infrastructure/Presentation suites listed in the test plan; `Support/FakeSettingsStore`, `Support/FakeLaunchAtLoginService`, `Support/ManualClock`.
- Specs: `settings`, `launch-at-login`, `appearance` (only if F7 in scope).

### Approaches

Settings window presentation

| Option | Pros | Cons | Effort |
|---|---|---|---|
| S1 SwiftUI `Settings` scene + `openSettings` | Already declared; Cmd+, for free | No environment from an AppKit menu item; needs a live render tree; reported silent failure on macOS 26; workaround needs hidden window + `.regular` policy toggle | Medium, fragile |
| S2 Own `NSWindow` + `NSHostingController(SettingsView)` in a `SettingsWindowController`, shown with `NSApp.activate()` + `makeKeyAndOrderFront` | Deterministic from AppKit; single reusable instance; testable in the host; no policy toggle by default | One more controller; Cmd+, coherence must be designed | Low-Medium |
| S3 S2 + temporary `.regular` policy | Guarantees key window if activation is refused | Dock icon flashes; state to restore | Fallback only |

SettingsStore / port shape

| Option | Pros | Cons | Effort |
|---|---|---|---|
| T1 Domain `Settings` value + `SettingsStore` port (`load()`, `save(_:) throws`) + `UserDefaultsSettingsStore(defaults:)` + `@Observable SettingsState` | Mirrors the port pattern; invariants in one `nonisolated` value; trivial fake; adapter tested with `UserDefaults(suiteName:)` | Second observable object | Low |
| T2 Per-key port | Granular | Invariants scattered | Low-Medium |
| T3 `@AppStorage` in views | Least code | Untestable, breaks the hexagonal boundary | Rejected |

Launch-at-login is read from `LaunchAtLoginService.status` when the menu opens; never persisted in `UserDefaults`.

Runtime interval propagation

| Option | Pros | Cons | Effort |
|---|---|---|---|
| P1 Restart: `apply(interval:)` stores; if running, `stop(); start()` | Immediate; loop body untouched; existing tests hold | 100 ms gap and one CPU-seeding tick per change | Low |
| P2 Shared `Mutex<Duration>` read per iteration | No restart, no re-seed | Effective only after the in-flight sleep (up to 5 s) | Low-Medium |
| P3 Race sleep against an `AsyncStream` | Immediate, no re-seed | Task-group plumbing in the hot loop | High |

R5.4 composes with P1 via a pure `SamplingCadence.effective(configured:panelOpen:)` on `popoverWillShow`/`popoverDidClose`; opening the panel yields a fresh value in ~100 ms. Side effect: the sparkline spans 2 min while closed.

Light-mode mechanism

| Option | Pros | Cons | Effort |
|---|---|---|---|
| L1 Asset-catalog colour sets (Any + Dark) via generated `Color.<token>` symbols | PRD 7.1 literal; automatic via `NSAppearance`; `NSApp.appearance` gives the F7 override | `PaletteTests` equality breaks; tests must resolve under an appearance (verify `Color.resolve(in:)` honours `colorScheme` at RED); hex moves to JSON | Medium |
| L2 `Color(nsColor: NSColor(name:dynamicProvider:))` with hex pairs in Swift | Hex stays in code and tests; automatic per appearance | Deviates from PRD 7.1 wording | Low-Medium |
| L3 `PaletteTokens.dark/.light` passed to models via `@Environment(\.colorScheme)` | Pure unit tests | Every model function and `MetricModule.accent` gains a tokens parameter; widest churn | High |

Dark-only quick fix regardless: `popover.appearance = NSAppearance(named: .darkAqua)`.

Status-item redraw gating

| Option | Pros | Cons | Effort |
|---|---|---|---|
| G1 Keep `Equatable` Canvas views; Instruments profile as a manual task | Zero risk; produces PRD 10 evidence | No code change if already under 1% | Low |
| G2 `StatusItemContent`/`ModuleLabel` `Equatable` + `.equatable()` | Skips label/value body when readings are identical | Sparkline shifts every tick, so gain is partial | Low |
| G3 Build the panel hosting controller on `popoverWillShow`, drop on close | Removes the closed panel's tree from the 1 Hz path | Only if the profile shows off-window bodies evaluating | Medium |
| G4 Gate publishing on a ≥1 pt change in `MetricsState` | Literal PRD 10 text | History must still append every sample; couples state to presentation | Rejected |
| G5 `MetricHistory.newest(_:)` | Fewer allocations | Micro | Low |

### Recommendation

S2 + T1 + P1 (+ `SamplingCadence` only if R5.4 is confirmed) + G1/G2, with G3 conditional on the profile. Light mode: if it ships in v1, L1 with `PaletteTests` rewritten as appearance-resolution tests; if it stays P2, ship the one-line dark popover appearance and leave `Palette` untouched. Launch-at-login behind a `LaunchAtLoginService` port wrapping `SMAppService.mainApp`, status read live for the menu checkmark, `.requiresApproval` surfaced with an "Open Login Items…" action. Fold in debt W1/W5 (manual `Clock`), W6 (`deinit`), MC-10 (animation choice in the card models) since the sampler and controller are edited anyway.

### Conventions to inherit

1. Swift 6, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`: every Domain type, port, adapter, formatter, test double and nested type is explicitly `nonisolated` + `Sendable`; only `MetricsState`, `SettingsState`, `MetricsSampler`, views, `StatusItemController`, `SettingsWindowController` are main-actor.
2. Tests are never `@MainActor`; they `await` main-actor members.
3. Sampling loop is `Task.detached(priority: .utility)`; only Sendable values cross.
4. Fakes use `Synchronization.Mutex`; `throwOnCall` zero-based; record `Thread.isMainThread`.
5. `.timeLimit(.minutes(1))` only.
6. New files auto-join via `PBXFileSystemSynchronizedRootGroup`; never edit `project.pbxproj`.
7. Widget budget 230 pt, 221 pt measured; `statusItem.length` may change only when the module set changes, never per tick.
8. App Sandbox on; `SMAppService.mainApp` and `UserDefaults(suiteName:)` work in the container.
9. Locale whitespace hazards; pin `en_US`/`de_DE` (the interval label needs the same care).
10. Strict TDD; unit test command `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`.
11. Page size via `host_page_size()`.
12. (new) Launch-at-login truth is `SMAppService.mainApp.status`, never a persisted Bool.
13. (new) Tests never call `register()`; only `.integration` `status` reads.
14. (new) `UserDefaults` tests use a unique `suiteName` per test and `removePersistentDomain(forName:)` cleanup.
15. (new) Settings mutate on the main actor via `SettingsState`; the store port is `nonisolated` + `Sendable`.
16. (new) Every `NSStatusItem` created in tests is removed.

### Test plan sketch (strict TDD)

- Domain: `Settings` clamps 0.4 s→0.5 s, 6 s→5 s, default 1 s; `menuBarModules` dedupes, keeps order, empty normalises to `menuBarOrder`; `LaunchAtLoginStatus` mapping table.
- Application: `SettingsState` loads on init and persists on mutation; `apply(interval:)` stored while stopped, restarts once while running; `ManualClock` drives the loop deterministically (replaces W1/W5); `SamplingCadence` truth table.
- Infrastructure: store round-trip, defaults on missing/corrupt keys, unknown module raw values ignored; `.integration` `status` read maps without throwing.
- Presentation: `build(modules: [.memory])` one reading; `[.memory, .cpu]` reversed; one-module width `< 130 pt`, both `< 230 pt`; controller re-measures on module-set change and stays constant across values; menu titles `["Settings…", "Launch at Login", "Quit System Monitor"]` with `state == .on` for `.enabled` and annotated for `.requiresApproval`; `SettingsWindowController.show()` single reusable window, title "Settings", `isVisible`; interval labels under `en_US`/`de_DE`; `gaugeAnimation(reduceMotion: true) == nil`; if L1, each token resolves to dark hex under `.darkAqua` and light hex under `.aqua`.
- Manual: Instruments (Time Profiler + SwiftUI, 10 min, panel closed and open, <1% CPU, <50 MB RSS); launch-at-login round trip including `.requiresApproval`; settings window activation from the menu.

### Open questions

1. Does light mode ship in v1 (PRD OQ2 proposed P2)? If not, is the one-line dark popover appearance acceptable here?
2. Is "appearance" a user setting (System/Dark/Light) or does the app follow the system?
3. Is F6 module hiding/reordering in scope, and should the UI refuse to hide the last module (recommended)?
4. Is the R5.4 idle cadence in scope, accepting the 2 min sparkline span while closed?
5. Is the Instruments profile acceptable as a manual, user-executed task with recorded numbers?
6. Should Cmd+, open the same settings window, or is the context-menu entry the only path?
7. Interval control: stepper/slider over 0.5–5 s in 0.5 s steps (recommended) or a fixed list?

### Risks

- `openSettings`/`Settings` scene unreliability on macOS 26 — mitigated by S2; cooperative activation may still refuse `activate()` — fallback S3.
- `SMAppService` on dev builds records the DerivedData path; stale `.notFound` items during manual testing.
- Asset-catalog colours break `PaletteTests` equality; appearance-resolution tests are new territory.
- Second `@Observable` object contradicts PRD 6.1 wording; record a PRD amendment.
- Sampler restart re-seeds CPU (one tick without a CPU publish); spec must state it.
- `statusItem.length` re-measure must not regress "length stable across updates".
- `menu-bar-widget` delta is destructive again; archive must confirm the merge.
- Change spans all five layers plus specs; `single-pr` with size exception already accepted.

### Ready for Proposal

Yes, once OQ1–OQ4 are answered (they decide whether palette, appearance, module-visibility and cadence work exist at all); OQ5–OQ7 can be settled in design. Quit already exists; the sampler needs a restart path because the interval is captured once at task start; the SwiftUI `Settings` scene is not a reliable entry point from an AppKit menu on this deployment target; light mode is the only item that reshapes existing tests.

Sources consulted: [Showing Settings from macOS Menu Bar Items (steipete)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items), [Launch at Login setting (nilcoalescing)](https://nilcoalescing.com/blog/LaunchAtLoginSetting/), [SMAppService notes (theevilbit)](https://theevilbit.github.io/posts/smappservice/), [SMAppService.Status.requiresApproval](https://developer.apple.com/documentation/servicemanagement/smappservice/status-swift.enum/requiresapproval), [SMAppService.Status.notFound](https://developer.apple.com/documentation/servicemanagement/smappservice/status/notfound), [What's new in AppKit — WWDC23](https://developer.apple.com/videos/play/wwdc2023/10054/), [macOS Sonoma: Activate Menubar-Only App (Apple forums)](https://developer.apple.com/forums/thread/739075), [SettingsLink from MenuBarExtra does not activate the app](https://developer.apple.com/forums/thread/731628).
