# Proposal: Polish Module (PRD M4, "Polish — ship v1")

Serves PRD features F5 (launch at login) and F6 (settings: interval, module visibility, widget order) and requirements R1.5, R5.1, R5.4, R6.2, R6.3; PRD 6.5 (reduce motion) and section 10 (redraw cost, Instruments evidence). Milestone M4. Exploration: `exploration.md` (Engram `sdd/polish-module/explore`, id 8237). Research: unselected (exploration verified the external facts). Product decisions confirmed in `state.yaml` on 2026-09-06.

## Intent

After M3 the app is functionally complete for CPU and RAM but not shippable: the sampling interval is hard-coded to 1 s in `AppDelegate`, the context menu offers only Quit (R1.5 promises Settings and Launch at Login), nothing persists, the loop samples at full rate with the panel closed, the popover chrome follows the system appearance around a dark panel, and there is no PRD 10 performance evidence. This change adds a settings window, a `UserDefaults`-backed `SettingsStore`, module visibility and order, a runtime-configurable interval with a 2 s idle cadence, launch at login over `SMAppService`, a dark-pinned popover, and a redraw-gating pass. It also retires debt recorded in the M3 verify report (W1/W5 wall-clock loop tests, W6 status-item leak, MC-10 reduce-motion inspection-only). Success: v1 ships with all 299 existing tests green, new suites for every layer, and a recorded Instruments profile under 1% CPU.

## Scope

### In Scope
- Domain: `Settings` value (interval clamped 0.5–5 s, default 1 s; ordered, non-empty, de-duplicated `menuBarModules`, default `MetricModule.menuBarOrder`), `LaunchAtLoginStatus` enum, `SettingsStore` port (`load()`, `save(_:) throws`), `LaunchAtLoginService` port.
- Application: `@Observable @MainActor SettingsState` (loads on init, persists on mutation), `MetricsSampler.apply(interval:)` restarting the loop when running, pure `SamplingCadence.effective(configured:panelOpen:)`.
- Infrastructure: `UserDefaultsSettingsStore(defaults:)`, `SMAppServiceLaunchAtLogin` over `SMAppService.mainApp` (status read live; `.requiresApproval` exposes "Open Login Items…").
- Presentation: `SettingsView` (interval stepper 0.5–5 s in 0.5 s steps, module toggles and order, refuses to hide the last module) in an owned `NSWindow` via `SettingsWindowController`; context menu "Settings…", "Launch at Login" (checkmark from live status), Quit; popover delegate driving cadence; popover pinned to `darkAqua`; `statusItem.length` re-measured only when the module set changes; `Equatable` `StatusItemContent`/`ModuleLabel` (G2); `gaugeAnimation(reduceMotion:)` in `CPUCardModel`/`MemoryCardModel`; `StatusItemController.deinit` removes the item.
- App: composition root wires store, state, adapter and interval; Cmd+, opens the same window.
- Tests: Domain/Application/Infrastructure/Presentation suites, `FakeSettingsStore`, `FakeLaunchAtLoginService`, `ManualClock` replacing W1/W5 wall-clock cases; strict TDD.
- Manual: Instruments Time Profiler, 10 min, panel closed and open, numbers recorded in the verify report (PRD 10).
- Housekeeping: `openspec/config.yaml` lines 24, 25, 90 corrected; PRD 6.1 note that Application holds two observable objects.

### Out of Scope
- F7 light mode and any appearance setting: `Palette` stays `Color(.sRGB)` literals; F7 remains P2 for a later change. F8 GPU (PRD 11, v2). F9 NET. Memory pressure. G3 lazy panel hosting unless the manual profile shows off-window bodies evaluating. Any `project.pbxproj` edit.

## Capabilities

### New Capabilities
- `settings`: `Settings` invariants, `SettingsStore` port and `UserDefaults` adapter, `SettingsState`, settings window presentation and entry points, module visibility/order rules (never empty), runtime interval propagation contract.
- `launch-at-login`: `LaunchAtLoginService` port, status mapping table, menu item state, `.requiresApproval` and `.notFound` handling, test rule (never `register()` in tests).

### Modified Capabilities
- `menu-bar-widget`: MBW-1 "Data-driven module list" renders `SettingsState.menuBarModules` (default `menuBarOrder`); "Fixed-width, jitter-free layout" changes "set explicitly once" to "set when the module set changes, never per value tick" with a one-module width scenario (< 130 pt); ADDED requirement "Context menu" (R1.5, R6.4). Destructive on two requirements.
- `cpu-metrics`: "Startup double-sample and cadence" ADDED scenarios for `apply(interval:)` while stopped and while running (one restart, one CPU re-seed tick); "Loop resilience and cancellation" MODIFIED: the sentence "The loop MUST NOT depend on whether the panel is open" becomes "The loop MUST keep running whether or not the panel is open; only its cadence changes (2 s closed, configured interval open, fast restart on open)". Destructive on one requirement.
- `cpu-card`, `memory-card`: ADDED scenario "reduce motion yields nil animation" at model level. Non-destructive.

## Approach

Exploration recommendation S2 + T1 + P1 + `SamplingCadence` + G1/G2, adopted:
- **S2 owned window**: `SettingsWindowController` holds one reusable `NSWindow` with `NSHostingController(SettingsView)`, shown via `NSApp.activate()` + `makeKeyAndOrderFront`. Deterministic from an AppKit menu item on macOS 26 where `openSettings` is unreliable. S3 (temporary `.regular` activation policy) is documented as the fallback only if activation is refused.
- **T1 value + port + state**: invariants live in one `nonisolated` `Settings` value; the store is a boundary port with a trivial fake; `SettingsState` is the second `@Observable` object (PRD 6.1 deviation recorded).
- **P1 restart**: the interval is captured once at task start, so `apply(interval:)` stores and, if running, `stop(); start()`. Immediate effect, loop body untouched, existing loop tests hold; cost is one 100 ms gap and one CPU-seeding tick per change, stated in the spec.
- **Cadence**: popover delegate `popoverWillShow`/`popoverDidClose` feed `SamplingCadence.effective(configured:panelOpen:)` into `apply(interval:)`; opening the panel restarts at the fast rate so a fresh value appears in ~100 ms. Accepted: the sparkline spans 2 min while closed.
- **Launch at login**: `SMAppService.mainApp.status` is the only truth, read when the menu opens; never persisted.
- **Redraw**: G2 `Equatable` content plus the manual profile (G1) as PRD 10 evidence; G3 conditional on that profile.
- **Debt**: `ManualClock` drives loop tests through the already-injected `Clock`; `deinit` removes the `NSStatusItem`; animation choice moves into the card models so MC-10 becomes a unit test.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `Domain/Models/{Settings,LaunchAtLoginStatus}.swift` | New | Sendable values, clamping and ordering invariants |
| `Domain/Ports/{SettingsStore,LaunchAtLoginService}.swift` | New | Port protocols |
| `Domain/Models/MetricModule.swift` | Modified | `menuBarOrder` documented as the default order |
| `Application/{SettingsState,SamplingCadence}.swift` | New | Observable settings; pure cadence rule |
| `Application/MetricsSampler.swift` | Modified | `apply(interval:)`, restart path |
| `Infrastructure/System/{UserDefaultsSettingsStore,SMAppServiceLaunchAtLogin}.swift` | New | Adapters |
| `Presentation/Settings/{SettingsView,SettingsWindowController}.swift` | New | Settings UI and owned window |
| `Presentation/MenuBar/StatusItemController.swift` | Modified | Menu items, popover delegate, `darkAqua`, re-measure, `deinit` |
| `Presentation/MenuBar/StatusItemView.swift` | Modified | `build(modules:)`, `measurementReadings(for:)`, `Equatable` content |
| `Presentation/Panel/{CPUCard,MemoryCard}.swift` | Modified | `gaugeAnimation(reduceMotion:)` in models |
| `App/{AppDelegate,system_monitorApp}.swift` | Modified | Composition root; Cmd+, routing |
| `openspec/specs/{menu-bar-widget,cpu-metrics,cpu-card,memory-card}/spec.md` | Modified | Deltas above |
| `openspec/config.yaml`, `PRD.md` | Modified | Stale lines; 6.1 note |
| `system-monitorTests/**` | New/Modified | Suites per layer; `Support/{FakeSettingsStore,FakeLaunchAtLoginService,ManualClock}` |

## Conventions to inherit (from exploration; spec/design/tasks MUST carry these)

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

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `NSApp.activate()` refused; settings window opens behind | Med | Manual check from the menu; S3 activation-policy toggle documented as fallback in design |
| `SMAppService` dev builds register the DerivedData path; stale `.notFound` items | Med | Map `.notFound` to an explicit state; manual round trip in success criteria; never persist status |
| Sampler restart re-seeds CPU for one tick | High (by design) | Spec states one publish-free tick per interval change; memory still publishes on iteration 1 |
| Length re-measure regresses "Length stable across updates" | Med | Keep that scenario; add "length changes only on module-set change" beside it |
| Destructive deltas on `menu-bar-widget` and `cpu-metrics` | Low | Archive rule: warn before merging; delta names the rewritten sentence |
| Second `@Observable` object contradicts PRD 6.1 wording | Low | PRD amendment task |
| Popover delegate callbacks racing `apply(interval:)` on close/open | Low | All on main actor; `apply` idempotent for an unchanged interval |
| Single-PR size across five layers plus specs | Accepted | `size:exception` accepted up front; tasks grouped by layer for review |

## Rollback Plan

The change touches the sampling loop and the status item lifecycle. Revert to the M3 baseline (commit `f41bc05`): restore `MetricsSampler.swift` (hard-coded `interval`, no `apply`), `StatusItemController.swift` (Quit-only menu, no delegate, no appearance), `StatusItemView.swift` (static `menuBarOrder`), `AppDelegate.swift` (`.seconds(1)`), the card files and `MetricModule.swift`; delete the new Domain/Application/Infrastructure/Presentation files and tests (`PBXFileSystemSynchronizedRootGroup` picks up removals); drop the unmerged deltas. No feature flag: the store and window are additive, so a partial revert that keeps them compiles. A registered login item survives revert and is removed by the user in System Settings; the `UserDefaults` keys are harmless when unread.

## Dependencies

- `sdd-spec` and `sdd-design` follow from this proposal and may run in parallel.
- Convention `system-monitor/swift6-nonisolated-domain` (Engram); exploration above.
- `SMAppService` (macOS 13+), `NSApplication.activate()` (14+); deployment target 26.5.

## Success Criteria

- [ ] All existing 299 tests green; zero warnings under Swift 6 strict concurrency; W1/W5 wall-clock cases replaced by `ManualClock`.
- [ ] Domain: 0.4 s → 0.5 s, 6 s → 5 s, default 1 s; `menuBarModules` dedupes, keeps order, empty normalises to `menuBarOrder`; status mapping table.
- [ ] Application: `SettingsState` loads on init and persists on mutation; `apply(interval:)` stored while stopped, one restart while running; `SamplingCadence` truth table.
- [ ] Infrastructure: store round trip, defaults on missing/corrupt keys, unknown module raw values ignored; `.integration` `status` read does not throw.
- [ ] Presentation: `[.memory]` one reading, `[.memory, .cpu]` reversed; one-module width < 130 pt, both < 230 pt; length changes on module-set change only; menu titles `["Settings…", "Launch at Login", "Quit System Monitor"]` with `.on` for `.enabled`; single reusable window titled "Settings"; `gaugeAnimation(reduceMotion: true) == nil`.
- [ ] Manual: settings window opens from the menu and Cmd+,; interval change visible within one tick; hiding MEM shrinks the bar under 130 pt; launch-at-login round trip incl. `.requiresApproval`; Instruments < 1% CPU and < 50 MB RSS over 10 min with the panel closed, numbers recorded.
- [ ] `openspec/config.yaml` and PRD 6.1 amended; deltas drafted.

## Open Questions

None blocking. Design-owned: exact `SettingsView` layout, S3 trigger condition, `.notFound` menu wording, whether `MetricHistory.newest(_:)` (G5) ships. Ready for spec and design.
