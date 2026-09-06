# Design: Polish Module (PRD M4, "Polish — ship v1")

Revision 2 (2026-09-06): amended after validator (PASS_WITH_AMENDMENTS). Applied: (1) cadence is literal `panelOpen ? configured : 2 s` (CM-1); (2) `UserDefaultsSettingsStore` is `@unchecked Sendable` with `nonisolated(unsafe) let defaults` because `UserDefaults` is not `Sendable` on MacOSX26.5.sdk; (3) port names `enable()`/`disable()`/`openLoginItemsSettings()` and `LaunchAtLoginStatus.needsApproval` (LAL-1/LAL-2); (4) `Settings.samplingInterval` with a defaulted initialiser so `Settings()` compiles (ST-1); (5) `SettingsState` read-only pass-throughs plus intent methods (ST-4 amended in the spec); (6) interval label via `.number.precision(.fractionLength(1))` + literal `" s"` (ST-6 pins "2.5 s"/"2,5 s"); (7) pure `SettingsFormModel.incremented(_:)`/`decremented(_:)`; (8) `FakeLaunchAtLoginService` zero-based `throwOnEnable`/`throwOnDisable` sets; (9) MBW-13 no-duplicate mechanism stated and tested; (10) `ManualClock` advance semantics and CM-3 scenario aligned; (11) ST-7 end-to-end case in `SettingsStateTests`; (12) File Changes table authoritative for test file names (existing `CPUCardTests`, `MemoryCardModelTests` reused). Optional items applied: citation `:54`, `installedStatusItem` accessor for MBW-12, LAL-3 "Nothing persisted" and ST-3 `["gpu"]` cases, CM-2 stored-while-stopped gap assertion, `ModuleRow.isToggleEnabled`, `errorPresenter` activation note, decision 15 promoted (`isolated deinit` confirmed on Xcode 26.6 / Swift 6.3.3), LAL-4 supersedes the proposal's `.requiresApproval` wording sentence.

Proposal: `proposal.md` (Engram `sdd/polish-module/proposal`, id 8240). Exploration: `exploration.md` (8237). Research: unselected. Engram mirror of this file: `sdd/polish-module/design`. Specs `settings` (ST-*), `launch-at-login` (LAL-*), and the `menu-bar-widget` (MBW-*), `cpu-metrics` (CM-*), `cpu-card`, `memory-card` deltas are the scenario source; IDs below refer to them. Product decisions confirmed in `state.yaml:27-35` are fixed: dark-only v1, hide/reorder with a last-module guard, R5.4 idle cadence, interval 0.5–5 s clamped in 0.5 s steps, Settings from the context menu and Cmd+, on one owned window, launch at login read live, Instruments as a manual task. The proposal's sentence on `.requiresApproval` exposing "Open Login Items…" is superseded by LAL-4, which delegates the wording to this design (decision 12).

## Technical Approach

Same hexagonal shape as the CPU and memory modules (`openspec/changes/archive/2026-09-06-memory-module/design.md`), adopting the proposal's S2 + T1 + P1 + `SamplingCadence` + `LaunchAtLoginService` + G1/G2:

- **Domain** owns two values (`Settings`, `LaunchAtLoginStatus`) and two ports (`SettingsStore`, `LaunchAtLoginService`). Every invariant of the settings (interval clamp, non-empty de-duplicated module list, last-module guard) lives in the `Settings` initialiser and its pure transition helpers, so no layer can build an invalid value.
- **Application** adds the second `@Observable` object `SettingsState` (loads on init, persists on every accepted mutation, notifies synchronous observers), the pure `SamplingCadence`, a small `SamplingCadenceController` that turns "panel open/closed" plus the configured interval into `MetricsSampler.apply(interval:)`, and the `apply(interval:)` restart path itself.
- **Infrastructure** adds two adapters: `UserDefaultsSettingsStore` (two plain keys) and `SMAppServiceLaunchAtLogin` (a stateless wrapper over `SMAppService.mainApp` with a unit-testable status map).
- **Presentation** adds `SettingsView` + `SettingsWindowController` (one owned, reusable `NSWindow`), a pure `ContextMenuModel`, and modifies `StatusItemController` (menu, `NSPopoverDelegate`, dark appearance, re-measure on module-set change, `isolated deinit`) and `StatusItemView` (`build(modules:)`, `measurementReadings(for:)`, `Equatable` content). Card models gain `gaugeAnimation(reduceMotion:)`.
- **Tests** get `ManualClock`, `FakeSettingsStore`, `FakeLaunchAtLoginService`, `PanelVisibilitySpy`; the five wall-clock loop tests at `system-monitorTests/Application/MetricsSamplerTests.swift:324-434` are rewritten on the injected clock (CM-3).

Isolation rule (proposal convention 1): every Domain type, port, adapter, pure model enum, and test double below is explicitly `nonisolated` + `Sendable`, including nested types. Only `MetricsState`, `SettingsState`, `MetricsSampler`, `SamplingCadenceController`, views, `StatusItemController` and `SettingsWindowController` are main-actor.

## Component Diagram

```
App/AppDelegate (composition root, @MainActor)
  ├─ UserDefaultsSettingsStore(.standard)           Infrastructure (nonisolated, @unchecked Sendable)   ← port SettingsStore
  ├─ SMAppServiceLaunchAtLogin()                     Infrastructure (nonisolated, Sendable)             ← port LaunchAtLoginService
  ├─ SettingsState(store:)  (@MainActor @Observable)  settings, samplingInterval, menuBarModules, lastSaveError, observe(_:)
  ├─ MetricsState (unchanged)
  ├─ MetricsSampler(…, interval: SamplingCadence.effective(configured:, panelOpen: false)) + apply(interval:)
  ├─ SamplingCadenceController(sampler:, settings:)  : PanelVisibilityObserver, observes SettingsState
  ├─ SettingsWindowController(settings:)             one NSWindow ← NSHostingController(SettingsRootView(settings:))
  └─ StatusItemController(state:, settings:, launchAtLogin:, panelObserver: cadence, openSettings: { window.show() })
        ├─ StatusItemRootView(state:, settings:) → StatusItemView → StatusItemReadings.build(modules:…) → StatusItemContent (Equatable)
        ├─ NSPopover(.darkAqua, delegate: self) → PanelView (unchanged)
        └─ makeContextMenu() ← ContextMenuModel.items(launchAtLogin:)  [Settings…, Launch at Login, Quit]
system_monitorApp: Settings { EmptyView() } + CommandGroup(replacing: .appSettings) → appDelegate.showSettings()
```

## Interfaces / Contracts

All signatures are normative; tasks implement them verbatim.

### Domain (imports Foundation only) — ports defined before any adapter

```swift
/// User-editable settings (ST-1). Every instance satisfies the invariants: the initialiser normalises.
nonisolated struct Settings: Sendable, Equatable {
    static let minimumInterval: Duration = .milliseconds(500)
    static let maximumInterval: Duration = .seconds(5)
    static let intervalStep: Duration = .milliseconds(500)      // UI step only; not an invariant
    static let defaultInterval: Duration = .seconds(1)
    static let `default` = Settings()

    let samplingInterval: Duration      // clamped to minimumInterval...maximumInterval
    let menuBarModules: [MetricModule]  // non-empty, first-occurrence order, no duplicates

    /// Clamps `samplingInterval`; de-duplicates `menuBarModules` keeping the first occurrence;
    /// an empty list normalises to `MetricModule.menuBarOrder`. `Settings()` is the ST-1 default.
    init(samplingInterval: Duration = .seconds(1), menuBarModules: [MetricModule] = MetricModule.menuBarOrder)

    func withSamplingInterval(_ interval: Duration) -> Settings
    func canHide(_ module: MetricModule) -> Bool          // contains(module) && count > 1
    func showing(_ module: MetricModule) -> Settings      // appends at the end when absent; self otherwise
    func hiding(_ module: MetricModule) -> Settings       // removes when canHide; self otherwise (last-module guard)
    func movingUp(_ module: MetricModule) -> Settings     // swaps with its predecessor; self at index 0 or when absent
    func movingDown(_ module: MetricModule) -> Settings   // swaps with its successor; self at the end or when absent
}

/// Mirror of SMAppService.Status without importing ServiceManagement (LAL-1; mapping lives in the adapter).
nonisolated enum LaunchAtLoginStatus: Sendable, Equatable, CaseIterable {
    case notRegistered, enabled, requiresApproval, notFound
    var isEnabled: Bool { self == .enabled }
    var needsApproval: Bool { self == .requiresApproval }
}

nonisolated protocol SettingsStore: Sendable {                 // ST-2
    /// Never throws: a missing or corrupt store yields `Settings()` (or the recoverable part of it).
    func load() -> Settings
    func save(_ settings: Settings) throws
}

nonisolated protocol LaunchAtLoginService: Sendable {          // LAL-2
    var status: LaunchAtLoginStatus { get }   // read live on every call, never cached (convention 12)
    func enable() throws
    func disable() throws
    func openLoginItemsSettings()
}
```

`MetricModule.menuBarOrder` (`system-monitor/Domain/Models/MetricModule.swift:21-24`) keeps its value `[.cpu, .memory]` (pinned by `MetricModuleTests.swift:6-8`) and its doc comment becomes "Default left-to-right order; the effective order is `Settings.menuBarModules`".

### Application (`@MainActor` classes, `nonisolated` pure rule)

```swift
@MainActor @Observable final class SettingsState {             // ST-4
    private(set) var settings: Settings
    var samplingInterval: Duration { settings.samplingInterval }      // read-only pass-through
    var menuBarModules: [MetricModule] { settings.menuBarModules }   // read-only pass-through
    /// Error from the last `save`; `nil` after a successful save. The in-memory value is kept either way.
    private(set) var lastSaveError: (any Error)?
    @ObservationIgnored private let store: any SettingsStore
    @ObservationIgnored private var observers: [@MainActor (Settings) -> Void] = []

    init(store: any SettingsStore)                       // settings = store.load(); no save on init
    func observe(_ observer: @escaping @MainActor (Settings) -> Void)   // called synchronously after each accepted commit

    // Mutation happens only through these intent methods; every one passes the Settings initialiser (ST-1).
    func setInterval(_ interval: Duration)               // commit(settings.withSamplingInterval(interval))
    func setModule(_ module: MetricModule, visible: Bool) // commit(visible ? showing : hiding); hiding the last module is a no-op
    func moveUp(_ module: MetricModule); func moveDown(_ module: MetricModule)
    func canHide(_ module: MetricModule) -> Bool          // settings.canHide

    /// guard updated != settings else return; settings = updated;
    /// do { try store.save(updated); lastSaveError = nil } catch { lastSaveError = error }; observers.forEach { $0(updated) }
    private func commit(_ updated: Settings)
}

/// Pure R5.4 rule (CM-1): 2 s while the panel is closed, the configured interval while open.
nonisolated enum SamplingCadence {
    static let idleInterval: Duration = .seconds(2)
    static func effective(configured: Duration, panelOpen: Bool) -> Duration   // panelOpen ? configured : idleInterval
}

@MainActor protocol PanelVisibilityObserver: AnyObject {
    func panelDidOpen(); func panelDidClose()
}

@MainActor final class SamplingCadenceController: PanelVisibilityObserver {
    private let sampler: MetricsSampler
    private let settings: SettingsState
    private(set) var isPanelOpen = false
    init(sampler: MetricsSampler, settings: SettingsState)   // settings.observe { [weak self] _ in self?.refresh() }
    func panelDidOpen()   // isPanelOpen = true; refresh()
    func panelDidClose()  // isPanelOpen = false; refresh()
    private func refresh() { sampler.apply(interval: SamplingCadence.effective(configured: settings.samplingInterval, panelOpen: isPanelOpen)) }
}

@MainActor final class MetricsSampler {
    private(set) var interval: Duration                   // was `private let` (MetricsSampler.swift:62)
    init(…, interval: Duration = .seconds(1), startupGap: Duration = .milliseconds(100),
         clock: any Clock<Duration> = ContinuousClock())  // unchanged (MetricsSampler.swift:72-80)
    /// CM-2. Idempotent for an unchanged value. Otherwise stores the interval and, only while running,
    /// `stop(); start()` so the new task captures it (start() copies `interval` at MetricsSampler.swift:104).
    func apply(interval: Duration)
    func start(); func stop(); var isRunning: Bool; func sampleOnce()   // bodies unchanged
}
```

Restart semantics of `apply(interval:)`: `stop()` cancels the running task and nils it (`MetricsSampler.swift:148-151`); `start()` then passes its `task == nil` guard (`:98`) and launches a new `Task.detached(priority: .utility)` (`:108`) capturing the new `interval` as a local (`:104`) and the same `Sendable` providers, state and clock. The new task's first iteration seeds the CPU step (`previous: nil`, `:109-113`) and publishes memory only; after `startupGap` (`:118`) the second iteration publishes CPU. So one interval change costs exactly one publish-free CPU tick and no memory gap, and opening the panel yields a fresh value within approximately 200 ms (100 ms gap plus one iteration), matching CM-1. The cancelled task is parked in `clock.sleep` (`:137`) in steady state and exits through the `catch { break }` (`:138-140`); if cancellation lands mid-iteration it may still publish one in-flight reading before exiting, which is a valid sample and never a duplicate publish of the same tick. The loop body is untouched; `sampleOnce()` (`:159-178`) and `inlineStep` are unaffected.

### Infrastructure (nonisolated)

```swift
/// ST-3. Two plain keys: independently recoverable, readable with `defaults read`, no custom Codable.
///
/// `UserDefaults` is not `Sendable` on MacOSX26.5.sdk (the compiler rejects a stored `UserDefaults` in a
/// `Sendable` struct), but Apple documents the class as thread-safe ("The UserDefaults class is thread-safe",
/// UserDefaults reference, Overview), so the conformance is `@unchecked` and the property `nonisolated(unsafe)`.
nonisolated struct UserDefaultsSettingsStore: SettingsStore, @unchecked Sendable {
    nonisolated enum Key {
        static let samplingIntervalSeconds = "settings.samplingIntervalSeconds"   // Double
        static let menuBarModules = "settings.menuBarModules"                     // [String] of MetricModule.rawValue
    }
    nonisolated(unsafe) private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard)
    /// interval: `object(forKey:) as? Double`, finite → `.seconds(value)`, else `Settings.defaultInterval`;
    /// modules: `stringArray(forKey:)` → `compactMap(MetricModule.init(rawValue:))` (unknown raw values dropped), nil → [];
    /// then `Settings(samplingInterval:menuBarModules:)` clamps, de-duplicates and turns [] into `menuBarOrder`.
    func load() -> Settings
    /// Writes both keys and nothing else (LAL-3 "Nothing persisted"); never throws in practice (the port throws for other stores and fakes).
    func save(_ settings: Settings) throws
    static func seconds(_ interval: Duration) -> Double   // Double(components.seconds) + Double(components.attoseconds) / 1e18
}

import ServiceManagement
nonisolated struct SMAppServiceLaunchAtLogin: LaunchAtLoginService {   // LAL-3
    init()
    var status: LaunchAtLoginStatus { Self.map(SMAppService.mainApp.status) }   // resolved per call, nothing stored
    func enable() throws { try SMAppService.mainApp.register() }
    func disable() throws { try SMAppService.mainApp.unregister() }
    func openLoginItemsSettings() { SMAppService.openSystemSettingsLoginItems() }
    /// .enabled → .enabled, .notRegistered → .notRegistered, .requiresApproval → .requiresApproval,
    /// .notFound → .notFound, @unknown default → .notRegistered. Unit-tested without any SM call.
    static func map(_ status: SMAppService.Status) -> LaunchAtLoginStatus
}
```

### Presentation

```swift
// Presentation/MenuBar/ContextMenuModel.swift — pure, testable without an NSMenu (MBW-10, LAL-4)
nonisolated struct ContextMenuItem: Sendable, Equatable {
    nonisolated enum Action: Sendable, Equatable { case openSettings, toggleLaunchAtLogin, openLoginItems, quit }
    let title: String; let isChecked: Bool; let action: Action
}
nonisolated enum ContextMenuModel {
    /// Always three items, in order:
    /// "Settings…" (openSettings) · launch item (below) · "Quit System Monitor" (quit).
    /// .enabled         → "Launch at Login", checked,   toggleLaunchAtLogin (→ disable())
    /// .notRegistered   → "Launch at Login", unchecked, toggleLaunchAtLogin (→ enable())
    /// .notFound        → "Launch at Login", unchecked, toggleLaunchAtLogin (→ enable() re-registers the current bundle path)
    /// .requiresApproval→ "Launch at Login (Requires Approval)…", unchecked, openLoginItems
    static func items(launchAtLogin status: LaunchAtLoginStatus) -> [ContextMenuItem]
}

// Presentation/MenuBar/StatusItemView.swift
nonisolated enum StatusItemReadings {
    static let sampleCount = 60
    /// One reading per module in `modules` order (MBW-1; replaces the static map at StatusItemView.swift:42).
    static func build(modules: [MetricModule], cpu: CPUSnapshot?, cpuHistory: MetricHistory,
                      memory: MemorySnapshot?, memoryHistory: MetricHistory) -> [ModuleReading]
}
@MainActor enum StatusItemMetrics {
    /// Replaces the `static let measurementReadings` (StatusItemView.swift:105-111).
    static func measurementReadings(for modules: [MetricModule]) -> [ModuleReading]
}
struct StatusItemContent: View, Equatable { let readings: [ModuleReading] }   // MBW-14; body wraps each label in .equatable()
struct ModuleLabel: View, Equatable { let reading: ModuleReading }             // was private (StatusItemView.swift:166); internal for the MBW-14 test
struct StatusItemView: View {   // @Environment(MetricsState.self), @Environment(SettingsState.self); StatusItemContent(...).equatable()
struct StatusItemRootView: View { let state: MetricsState; let settings: SettingsState }   // injects both environments

// Presentation/MenuBar/StatusItemController.swift
final class StatusItemController: NSObject, NSPopoverDelegate {   // NSObject for the delegate conformance
    init(state: MetricsState, settings: SettingsState, launchAtLogin: any LaunchAtLoginService,
         panelObserver: (any PanelVisibilityObserver)? = nil,
         openSettings: @escaping @MainActor () -> Void = {})
    /// Presents enable/disable failures; default builds an NSAlert. Tests replace it with a recorder.
    var errorPresenter: @MainActor (any Error) -> Void
    // Layout contract (existing accessors keep their names: statusItemLength, hostingSizingOptions)
    func contentFittingWidth(for modules: [MetricModule]) -> CGFloat   // replaces the property at :88-90
    var installedStatusItem: NSStatusItem                              // test-visible for MBW-12 (weak reference target)
    var popoverAppearanceName: NSAppearance.Name?                      // .darkAqua (MBW-11)
    var isPanelOpen: Bool                                              // popover.isShown
    func togglePopover()                                               // was private (:102-109); test-visible for MBW-13
    // Behaviour (test-visible)
    func makeContextMenu() -> NSMenu          // from ContextMenuModel.items(launchAtLogin: launchAtLogin.status); status read at build time
    func toggleLaunchAtLogin()                // .enabled → disable(); otherwise enable(); errors → errorPresenter
    func openLoginItems()                     // launchAtLogin.openLoginItemsSettings()
    // NSPopoverDelegate (MBW-13)
    func popoverWillShow(_ notification: Notification)   // panelObserver?.panelDidOpen()
    func popoverDidClose(_ notification: Notification)   // panelObserver?.panelDidClose()
    isolated deinit { NSStatusBar.system.removeStatusItem(statusItem) }   // MBW-12 / W6
}

// Presentation/Settings/SettingsView.swift
nonisolated struct ModuleRow: Sendable, Equatable, Identifiable {
    let module: MetricModule; let isVisible: Bool; let canHide: Bool; let canMoveUp: Bool; let canMoveDown: Bool
    var isToggleEnabled: Bool { !isVisible || canHide }   // ST-6 "Last visible toggle disabled"
    var id: String { module.id }
}
nonisolated enum SettingsFormModel {                         // ST-6 pure derivations
    static let intervalRange: ClosedRange<Double>   // 0.5...5 (seconds)
    static let intervalStep: Double                  // 0.5
    static func intervalSeconds(_ settings: Settings) -> Double
    /// Project precedent (`PercentFormatter.oneDecimal`, convention 9): the seconds value formatted with
    /// `.number.precision(.fractionLength(1)).locale(locale)` plus the literal suffix " s".
    /// 2.5 s → "2.5 s" (en_US), "2,5 s" (de_DE). Never `Measurement.formatted` (yields "2.5 sec" / "2,5 Sek.").
    static func intervalLabel(for interval: Duration, locale: Locale = .current) -> String
    /// One 0.5 s step up/down, clamped by passing through `Settings(samplingInterval:)`: 1 s → 1.5 s; 5 s stays 5 s; 0.5 s stays 0.5 s.
    static func incremented(_ interval: Duration) -> Duration
    static func decremented(_ interval: Duration) -> Duration
    /// Visible modules in `menuBarModules` order, then hidden ones in `menuBarOrder` order.
    /// canHide = visible && count > 1; canMoveUp/Down only for visible rows not at the respective edge.
    static func moduleRows(for settings: Settings) -> [ModuleRow]
}
struct SettingsView: View { @Environment(SettingsState.self) private var settings }   // Form(.grouped), width 360
struct SettingsRootView: View { let settings: SettingsState }                          // SettingsView().environment(settings)

// Presentation/Settings/SettingsWindowController.swift (ST-5)
final class SettingsWindowController {
    init(settings: SettingsState)
    /// Lazily creates the single window on first call, then NSApp.activate(); window.makeKeyAndOrderFront(nil).
    func show()
    func close()                      // orderOut; the instance survives (isReleasedWhenClosed = false)
    var isWindowVisible: Bool         // window?.isVisible ?? false
    var windowTitle: String?          // "Settings"
    var windowNumber: Int?            // stable per NSWindow; equal across two show() calls
}
```

`SettingsView` layout: a grouped `Form` with two sections. "Sampling": one `Stepper` whose `onIncrement`/`onDecrement` call `settings.setInterval(SettingsFormModel.incremented(settings.samplingInterval))` / `decremented`, label `Text(SettingsFormModel.intervalLabel(for: settings.samplingInterval))`. "Menu Bar": `ForEach(SettingsFormModel.moduleRows(for: settings.settings))` rows with a `Toggle` bound through `Binding(get: { row.isVisible }, set: { settings.setModule(row.module, visible: $0) })` and `.disabled(!row.isToggleEnabled)` (the last-module guard in the UI; `SettingsState` refuses too), plus "Move Up"/"Move Down" buttons disabled by `canMoveUp`/`canMoveDown`, and a footer that reads `lastSaveError?.localizedDescription` when non-nil. Every write goes through a `SettingsState` intent method, never through `@Bindable`, so every value passes the `Settings` initialiser.

`SettingsWindowController.show()`: `NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)`, `title = "Settings"`, `isReleasedWhenClosed = false`, `contentViewController = NSHostingController(rootView: SettingsRootView(settings:))`, then an explicit `setContentSize(width: SettingsView.formWidth, height: max(hosting.view.fittingSize.height, SettingsView.formHeight))` **before** `center()` once — **Revision 2.1 (batch H correction)**: the hosting controller's default `sizingOptions` (`.standardBounds`) publish min/intrinsic/max on the hosted *view* but never set `preferredContentSize`, and a grouped `Form` is a scrolling container with no intrinsic height that accepts any proposed size, so `contentRect: .zero` survived and the window opened as a bare title bar with a (0, 0) content area (manual check 8.3, 2026-09-06). The window is sized explicitly from the hosted form's fitting size floored at the `SettingsView.formHeight` design constant; every call does `NSApp.activate()` (macOS 14+ API) then `makeKeyAndOrderFront(nil)`. S3 fallback: not implemented by default. Trigger condition is the manual checklist item "window becomes key on first show from the context menu" failing on the development machine; if it fails, the implementation is an unconditional `NSApp.setActivationPolicy(.regular)` before `activate()` and `.accessory` restored from `windowWillClose(_:)` (the controller becomes the window delegate), not a runtime probe of `NSApp.isActive`, which lags activation and would make the behaviour timing-dependent. The default `errorPresenter` (an `NSAlert` run from `toggleLaunchAtLogin()`) shares this risk: an alert from an LSUIElement app is only guaranteed in front after `NSApp.activate()`, so the presenter activates before `runModal()` and inherits the S3 fallback if activation is refused.

`StatusItemController` re-measure (MBW-9): the controller registers `settings.observe { [weak self] in self?.settingsDidChange($0) }` in `init`; `settingsDidChange` compares `menuBarModules` with the last measured list and only on a difference sets `statusItem.length = Self.measuredContentWidth(for: modules)` (the measurement helper at `StatusItemController.swift:66-72` gains a `modules` parameter). Value ticks never touch `length` (`:46` stays the only other write). `configurePopover()` (`:53-58`) adds `popover.delegate = self` and `popover.appearance = NSAppearance(named: .darkAqua)`. `showContextMenu()` (`:111-126`) keeps its attach/perform/detach pattern but takes `makeContextMenu()`; the "Settings…" item gets `keyEquivalent: ","` as the visible hint, Quit keeps `NSApplication.terminate(_:)` with `target = NSApp` (`:113-118`).

MBW-13 "No duplicate transitions" mechanism: the controller has no show-only entry point. `togglePopover()` (`StatusItemController.swift:102-109`) guards on `popover.isShown` (`:104-108`) and issues `performClose(nil)` instead of `show(...)` while the popover is visible, so `show` is never re-issued for an open popover and `popoverWillShow` fires exactly once per open; `popoverDidClose` fires once per close, including closes caused by an outside click that `togglePopover()` never sees (decision 17).

Card models: `CPUCardModel.gaugeAnimation(reduceMotion: Bool) -> Animation?` and `MemoryCardModel.gaugeAnimation(reduceMotion:)` return `nil` when true, else `.easeOut(duration: 0.25)`; the views drop their private `gaugeAnimation` constants (`CPUCard.swift:136`, `MemoryCard.swift:169`) and call `.animation(CPUCardModel.gaugeAnimation(reduceMotion: reduceMotion), value:)` at `CPUCard.swift:153` / `MemoryCard.swift:231`. `SwiftUI.Animation` is `Equatable`, so the tests compare values and the memory-card scenario "equals the CPU card's gauge animation" is a direct equality.

### App

```swift
// AppDelegate.applicationDidFinishLaunching — construction order
let settingsStore = UserDefaultsSettingsStore()
let settingsState = SettingsState(store: settingsStore)
let state = MetricsState()
let sampler = MetricsSampler(state:, cpuProvider: MachCPUProvider(), memoryProvider: MachMemoryProvider(),
                             topologyProvider: IORegistryCoreTopologyProvider(sysctl: SysctlReader()),
                             interval: SamplingCadence.effective(configured: settingsState.samplingInterval, panelOpen: false))
let cadence = SamplingCadenceController(sampler: sampler, settings: settingsState)
let settingsWindow = SettingsWindowController(settings: settingsState)
statusItemController = StatusItemController(state:, settings: settingsState, launchAtLogin: SMAppServiceLaunchAtLogin(),
                                            panelObserver: cadence, openSettings: { [settingsWindow] in settingsWindow.show() })
sampler.start()
func showSettings()   // settingsWindow.show(); used by the Cmd+, command (ST-5, ST-7 wiring lives here, no view calls the sampler)
```

Every collaborator is retained by `AppDelegate` (replacing the three optionals at `AppDelegate.swift:10-12`); `applicationWillTerminate` (`:31-33`) is unchanged.

`system_monitorApp` keeps `Settings { EmptyView() }` (`system_monitorApp.swift:10-12`) as the mandatory scene and adds `.commands { CommandGroup(replacing: .appSettings) { Button("Settings…") { appDelegate.showSettings() }.keyboardShortcut(",", modifiers: .command) } }` using the `@NSApplicationDelegateAdaptor` instance (`:5`). Cmd+, therefore opens the owned window and never the empty scene window. Limitation, stated for the spec: a main-menu key equivalent fires only while the app is active (settings window key, or after any activation); the context menu is the primary entry point.

## Architecture Decisions

| # | Decision | Choice | Rejected alternatives | Rationale |
|---|---|---|---|---|
| 1 | Where `Settings` invariants live | Normalising memberwise `init` with defaults (clamp, de-dupe, empty → default) plus pure transition helpers | Static `normalized(_:)` on a plain struct; validation in `SettingsState` | An instance that cannot be invalid means fakes, the adapter and the view model never need a validation path; `normalized` would leave a window where an un-normalised value exists and every consumer would have to remember to call it. Defaulted parameters make `Settings()` the ST-1 default without a second constructor. Transition helpers keep the last-module rule in one place. |
| 2 | Interval snapping | Clamp only; 0.5 s steps are a UI property (`SettingsFormModel.intervalStep`, `incremented`/`decremented`) | Snap to the 0.5 s grid in the initialiser | The confirmed criteria are 0.4 → 0.5 and 6 → 5 (ST-1); snapping would silently rewrite a persisted 0.7 s and is not a product requirement. The pure step functions produce grid values and saturate at the bounds (ST-6). |
| 3 | Store shape | Per-key `UserDefaults` (`Double` seconds + `[String]` raw values) | One Codable JSON blob | `Duration` encodes as an unkeyed `Int64` pair (opaque, hard to inspect); one corrupt blob would lose both settings; unknown module raw values must be ignored (ST-3), which `compactMap(MetricModule.init(rawValue:))` does for free while a Codable array would fail decoding as a whole. Per-key survives partial corruption and reads with `defaults read`. |
| 4 | `load()` never throws | Missing/corrupt keys fall back field by field to `Settings()` | `load() throws` with the caller choosing defaults | Every caller would choose the same fallback; keeping it in the adapter makes "corrupt store yields defaults" a single adapter test and keeps `SettingsState.init` non-throwing (ST-2). |
| 5 | Non-view observation of `SettingsState` | Synchronous observer list `observe(_:)` invoked after each accepted commit | `withObservationTracking` re-armed on change; `Observations` async sequence (SE-0475); SwiftUI `.onChange` in the hosting view | Two non-view consumers (cadence controller, status item re-measure) need the new value synchronously so tests stay deterministic (`await state.setInterval(...)` then assert). `withObservationTracking`'s `onChange` fires at `willSet` and requires a main-actor hop whose ordering relative to the test's next `await` is a runtime property; `Observations` is asynchronous by design; the hosting-view route depends on the run loop. Observers are main-actor closures held by a main-actor object, so nothing crosses an isolation boundary. |
| 6 | Save-failure policy | Keep the in-memory change, record `lastSaveError`, notify observers | Roll back to the previous value; `fatalError`; silent | ST-4: the user's choice must take effect for the session even if the disk write fails; rolling back would make the UI fight the user. The error surfaces in the settings form footer; `lastSaveError` resets on the next successful save. |
| 7 | Cadence rule | `effective = panelOpen ? configured : .seconds(2)` (literal, CM-1 and the confirmed product decision) | `panelOpen ? configured : max(configured, 2 s)` | CM-1 and `state.yaml:30` fix the closed cadence at 2 s for every configured value; the truth table (0.5 s, 1 s, 5 s closed → 2 s) is a spec scenario. The `max` variant would have kept a 5 s configuration from speeding up while closed, but it contradicts the confirmed decision and would make the closed cadence depend on the setting, which the spec does not allow. |
| 8 | How the sampler learns panel open/close | `StatusItemController` is the `NSPopoverDelegate` and forwards to an injected `PanelVisibilityObserver`; `SamplingCadenceController` implements it and owns `isPanelOpen` | `MetricsSampler` observing a `panelOpen` flag; `AppDelegate` closure holding the flag; `SettingsState` holding panel state | The sampler stays policy-free (`apply(interval:)` is the only new primitive, so every existing loop test holds unchanged); panel visibility is not a setting; a controller class is unit-testable with a fake store and a real sampler, whereas `AppDelegate` is not. The protocol lets the controller test use a spy without an `NSPopover` (MBW-13). |
| 9 | Interval propagation | P1 restart inside `apply(interval:)` (`stop(); start()` only when running and changed) | P2 shared `Mutex<Duration>` read per iteration; P3 racing the sleep against a stream | `start()` copies `interval` once (`MetricsSampler.swift:104`), so a restart is the smallest change that takes effect immediately; P2 would defer the change by up to one in-flight 5 s sleep; P3 adds task-group plumbing to the hot loop. The cost (one publish-free CPU tick, memory unaffected) is CM-2's third scenario. Idempotence for an unchanged interval (CM-2 fourth scenario) avoids restarts when the panel toggles with `configured == 2 s`. |
| 10 | `ManualClock` shape | `nonisolated final class` conforming to `Clock` with a `Duration`-offset `Instant`, `Mutex`-guarded sleeper queue, `advance(by:)`, `awaitSleepCount(_:)`, `pendingDeadlines` | Injecting a `sleep` closure into the sampler; keeping wall-clock polling with longer timeouts | The injection point already exists (`clock: any Clock<Duration>`, `MetricsSampler.swift:64,79`) and the loop only calls `clock.sleep(for:)` (`:137`), which the protocol extension routes through `now` + `sleep(until:tolerance:)`. `awaitSleepCount` gives the test a deterministic rendezvous ("the loop is parked at its n-th sleep") without `Task.sleep` polling; cancellation resumes the sleeper with `CancellationError` so `stop()` still ends the task (CM-3). |
| 11 | Context-menu content | Pure `ContextMenuModel.items(launchAtLogin:)`; controller maps items to `NSMenuItem`s; status read once per build | Building `NSMenuItem`s inline in `showContextMenu()`; caching status | Titles, check state and action mapping become a parameterised unit test over `LaunchAtLoginStatus.allCases` (LAL-4, MBW-10); reading status at build time is convention 12 (users toggle it in System Settings). |
| 12 | `.requiresApproval` and `.notFound` wording | `.requiresApproval` → "Launch at Login (Requires Approval)…" whose action opens Login Items; `.notFound` → plain "Launch at Login", unchecked, action `enable()` again | A fourth "Open Login Items…" item (the proposal's wording, superseded by LAL-4); disabling the item | Three items keep the MBW-10 title list stable for `.enabled`/`.notRegistered`/`.notFound`; the ellipsis follows the HIG for an action that opens another window; re-registering is the documented recovery for a stale `.notFound` item after a moved dev build. |
| 13 | Settings entry points | S2 owned window; Cmd+, via `CommandGroup(replacing: .appSettings)` calling the same controller | S1 `Settings` scene hosting the real view; an `NSMenu` key equivalent on the context menu | Exploration verified `openSettings`/`SettingsLink` unreliability from an AppKit menu on macOS 26 (exploration lines 21, 49); a context-menu key equivalent only fires while the menu is open. Replacing `.appSettings` removes the empty scene window from the Cmd+, path without deleting the mandatory scene (ST-5 "Both entry points share the window"). Fallback if the replacement does not take effect on macOS 26 (manual check): retarget the `NSApp.mainMenu` item whose key equivalent is "," in `applicationDidFinishLaunching`. |
| 14 | Settings window appearance | System appearance (not pinned) | Pin to `.darkAqua` like the popover | The form uses semantic system colours and standard controls; pinning would only matter for `Palette` content, which the window does not render. The popover is pinned (MBW-11) because `PanelView` paints `Palette.panelBackground` unconditionally (`PanelView.swift:23`). |
| 15 | `StatusItemController` lifetime | `isolated deinit` removes the `NSStatusItem`; controller becomes an `NSObject` subclass. Confirmed: `isolated deinit` compiles and runs on Xcode 26.6 / Swift 6.3.3 (validator check), so this is no longer an open question | `deinit { MainActor.assumeIsolated { … } }`; explicit `uninstall()` | Tests drop their last reference off the main actor, so `assumeIsolated` would trap; `isolated deinit` (SE-0371) hops to the main actor. `NSObject` is required by `NSPopoverDelegate`. MBW-12 is asserted through the test-visible `installedStatusItem` accessor held weakly. |
| 16 | G2 scope | `StatusItemContent` and `ModuleLabel` `Equatable` with `.equatable()` (MBW-14); G3 conditional on the manual profile; G5 (`MetricHistory.newest`) not shipped | G3 unconditionally; G4 publish gating | `Sparkline` already skips identical bodies (`StatusItemView.swift:181`); G2 extends that to the label/value layer at zero risk (precedent: `StackedBar: View, Equatable`, memory design line 177). G3 changes the popover lifecycle and is only justified by evidence; G5 is a micro-optimisation with no measured need. |
| 17 | Popover delegate vs KVO on `isShown` | `NSPopoverDelegate` `popoverWillShow`/`popoverDidClose` | KVO on `popover.isShown`; wrapping `togglePopover()` | The delegate also fires when the transient popover closes from an outside click, which `togglePopover()` (`StatusItemController.swift:102-109`) never sees; `popoverWillShow` fires before the panel renders (MBW-13 "Opening MUST be reported before the panel becomes visible"), so the fast restart begins before the first frame. |
| 18 | `UserDefaults` Sendability | `@unchecked Sendable` struct with `nonisolated(unsafe) let defaults`, doc comment citing the documented thread safety | Storing a suite name and resolving `UserDefaults(suiteName:)` per call; a `@MainActor` adapter | The SDK does not mark `UserDefaults` `Sendable` (verified diagnostic on MacOSX26.5.sdk) but documents it as thread-safe, so the unchecked conformance is honest. Resolving per call would break `init(defaults:)`, which ST-3 and the proposal pin, and would not work for `.standard` injected from tests; a main-actor adapter would violate convention 15 (the port is `nonisolated` + `Sendable`). |

## Concurrency Design

| Type | Layer | Isolation | Sendable | Crosses a task boundary? |
|---|---|---|---|---|
| `Settings`, `LaunchAtLoginStatus` | Domain | `nonisolated` struct/enum | Yes (`Duration`, `[MetricModule]`) | No: read and written on the main actor; the store call is synchronous |
| `SettingsStore`, `LaunchAtLoginService` | Domain ports | `nonisolated protocol … : Sendable` | Required by the protocol | Held as `any` existentials by main-actor objects; never captured by the detached loop |
| `UserDefaultsSettingsStore` | Infrastructure | `nonisolated struct` | `@unchecked Sendable`; the only stored property is `nonisolated(unsafe) let defaults: UserDefaults`, a class Apple documents as thread-safe but the MacOSX26.5.sdk does not mark `Sendable` (decision 18) | No: every call happens on the main actor through `SettingsState` |
| `SMAppServiceLaunchAtLogin` | Infrastructure | `nonisolated struct`, stateless | Yes | No; `SMAppService.mainApp` is resolved inside each call, never stored |
| `SettingsState` | Application | `@MainActor @Observable` | No | Never leaves the main actor |
| `SamplingCadence` | Application | `nonisolated enum`, pure | Yes | Called on the main actor only |
| `PanelVisibilityObserver`, `SamplingCadenceController` | Application | `@MainActor` | No | Never leaves the main actor |
| `MetricsSampler.interval` | Application | main-actor `private(set) var` | `Duration` | Copied into a local at `start()`; the detached task never reads the property |
| Detached loop captures | Application | — | unchanged set: `state`, providers, `interval`, `startupGap`, `clock` (all `Sendable`, `MetricsSampler.swift:100-106`) | Yes, by value |
| `ContextMenuItem`, `ContextMenuModel`, `ModuleRow`, `SettingsFormModel` | Presentation | `nonisolated` | Yes | No |
| `StatusItemContent`, `ModuleLabel` `Equatable` | Presentation | `@MainActor` isolated conformance (inferred under default isolation, precedent `StackedBar`) | n/a | No |
| `StatusItemController`, `SettingsWindowController`, `SettingsView` | Presentation | `@MainActor` | No | No; `errorPresenter` and `openSettings` are `@MainActor` closures |
| `ManualClock` | Tests | `nonisolated final class`; `Sendable` because its only stored property is a `let Mutex` (same argument as `FakeCPUProvider.swift:7-9`) | Yes | Yes: captured by the detached loop as `any Clock<Duration>`; continuations resumed outside `withLock` |
| `ManualClock.Instant` | Tests | `nonisolated struct: InstantProtocol` | Yes | Yes, as sleep deadlines |
| `FakeSettingsStore`, `FakeLaunchAtLoginService` | Tests | `nonisolated final class`, `Mutex<Script>` | Yes | No, but built to the convention (record `Thread.isMainThread`, zero-based throw sets) |
| `PanelVisibilitySpy`, `ErrorRecorder` | Tests | `@MainActor` | No | No |

Nested types (`ContextMenuItem.Action`, `UserDefaultsSettingsStore.Key`, `ManualClock.Instant`, fake `Script`/`ScriptedError`) carry explicit `nonisolated` because default isolation would otherwise make them main-actor.

## Data Flow

```
UserDefaults ──load()──► SettingsState.settings ──@Observable──► SettingsView (stepper, module rows)
     ▲                        │ commit(): save(_:) throws → lastSaveError; then observers (sync, main actor)
     └── save(_:) ────────────┤
                              ├──► SamplingCadenceController.refresh() ──SamplingCadence.effective──► MetricsSampler.apply(interval:)
                              │        ▲ panelDidOpen / panelDidClose                                     │ changed && running
                              │        └── StatusItemController (NSPopoverDelegate)                stop(); start() → new Task.detached
                              └──► StatusItemController.settingsDidChange ──modules differ──► statusItem.length = measured(for: modules)

StatusItemView: SettingsState.menuBarModules + MetricsState ──build(modules:…)──► StatusItemContent (Equatable) ──► ModuleLabel ×N
Context menu:   LaunchAtLoginService.status (live) ──ContextMenuModel.items──► NSMenu; toggle → enable()/disable() → errorPresenter on throw
Cmd+, :         CommandGroup(replacing: .appSettings) ──► AppDelegate.showSettings() ──► SettingsWindowController.show()  (same path as "Settings…")
```

## File Changes (authoritative for test file names; spec Verification notes reference these)

| File | Action | Description |
|---|---|---|
| `system-monitor/Domain/Models/Settings.swift` | Create | Value, constants, normalising defaulted init, transition helpers |
| `system-monitor/Domain/Models/LaunchAtLoginStatus.swift` | Create | Four-case enum, `isEnabled`, `needsApproval` |
| `system-monitor/Domain/Ports/SettingsStore.swift`, `LaunchAtLoginService.swift` | Create | Ports (defined before the adapters) |
| `system-monitor/Domain/Models/MetricModule.swift` | Modify | `menuBarOrder` doc comment: default order |
| `system-monitor/Application/SettingsState.swift` | Create | Observable settings, pass-throughs, `observe`, intent methods, `lastSaveError` |
| `system-monitor/Application/SamplingCadence.swift` | Create | `SamplingCadence`, `PanelVisibilityObserver`, `SamplingCadenceController` |
| `system-monitor/Application/MetricsSampler.swift` | Modify | `private let interval` → `private(set) var` (`:62`); `apply(interval:)`; doc comment on the restart cost |
| `system-monitor/Infrastructure/System/UserDefaultsSettingsStore.swift` | Create | Adapter (`@unchecked Sendable`), `Key`, `seconds(_:)` |
| `system-monitor/Infrastructure/System/SMAppServiceLaunchAtLogin.swift` | Create | Adapter, `map(_:)` |
| `system-monitor/Presentation/MenuBar/ContextMenuModel.swift` | Create | `ContextMenuItem`, `ContextMenuModel` |
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | Modify | `NSObject` + `NSPopoverDelegate`; new init; `makeContextMenu`, `toggleLaunchAtLogin`, `openLoginItems`, `errorPresenter`; `settingsDidChange` re-measure; `measuredContentWidth(for:)`; `installedStatusItem`; `togglePopover()` internal; `.darkAqua`; `isolated deinit` |
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | Modify | `build(modules:…)`; `measurementReadings(for:)`; `StatusItemContent`/`ModuleLabel` `Equatable` + `.equatable()`; `StatusItemView` reads `SettingsState`; `StatusItemRootView(state:settings:)`; previews |
| `system-monitor/Presentation/Settings/SettingsView.swift` | Create | `ModuleRow`, `SettingsFormModel`, `SettingsView`, `SettingsRootView`, previews |
| `system-monitor/Presentation/Settings/SettingsWindowController.swift` | Create | Owned window, `show`/`close`, test accessors |
| `system-monitor/Presentation/Panel/CPUCard.swift`, `MemoryCard.swift` | Modify | `gaugeAnimation(reduceMotion:)` in the models (`CPUCard.swift:136,153`; `MemoryCard.swift:169,231`) |
| `system-monitor/App/AppDelegate.swift` | Modify | Composition root above; `showSettings()` |
| `system-monitor/App/system_monitorApp.swift` | Modify | `.commands { CommandGroup(replacing: .appSettings) … }` |
| `openspec/config.yaml` | Modify | Line 24 deployment target, 25 Swift version, 90 "no commits yet" (housekeeping from the proposal) |
| `PRD.md` | Modify | 6.1 note: Application holds two observable objects |
| `system-monitorTests/Support/ManualClock.swift` | Create | Manual `Clock` (CM-3) |
| `system-monitorTests/Support/FakeSettingsStore.swift` | Create | ST-2 double |
| `system-monitorTests/Support/FakeLaunchAtLoginService.swift` | Create | LAL-2 double |
| `system-monitorTests/Support/PanelVisibilitySpy.swift` | Create | `PanelVisibilitySpy`, `ErrorRecorder` |
| `system-monitorTests/Domain/SettingsTests.swift` | Create | ST-1 |
| `system-monitorTests/Domain/LaunchAtLoginStatusTests.swift` | Create | LAL-1 |
| `system-monitorTests/Application/SettingsStateTests.swift` | Create | ST-4, ST-7 |
| `system-monitorTests/Application/SamplingCadenceTests.swift` | Create | CM-1 truth table; `SamplingCadenceController` |
| `system-monitorTests/Application/MetricsSamplerTests.swift` | Modify | `MetricsSamplerLoopTests` suite (`:277-435`) rewritten on `ManualClock` (CM-1 loop scenarios, CM-2, CM-3); `makeSampler` at `:307-321` gains `clock:`; `waitUntil` (`:293-305`) deleted |
| `system-monitorTests/Infrastructure/UserDefaultsSettingsStoreTests.swift` | Create | ST-3, LAL-3 "Nothing persisted" |
| `system-monitorTests/Infrastructure/SMAppServiceLaunchAtLoginTests.swift` | Create | LAL-3 mapping table + `.integration` status read |
| `system-monitorTests/Presentation/ContextMenuModelTests.swift` | Create | MBW-10 titles/order, LAL-4 title/state/action table |
| `system-monitorTests/Presentation/SettingsFormModelTests.swift` | Create | ST-6 |
| `system-monitorTests/Presentation/SettingsWindowControllerTests.swift` | Create | ST-5 |
| `system-monitorTests/Presentation/StatusItemControllerMenuTests.swift` | Create | MBW-10 actions and window opening, LAL-4 controller behaviour with the fake |
| `system-monitorTests/App/AppDelegateCompositionTests.swift` | Create (added at batch G, validator amendment) | Composition-root identity invariants: one `SettingsState`, one `SettingsWindowController`, cadence controller is the panel observer, closed cadence seeded before `start()` |
| `system-monitorTests/Presentation/StatusItemControllerTests.swift` | Modify | New init at `:30,45,54,64`; MBW-9 re-measure, MBW-11 appearance, MBW-12 release, MBW-13 transitions |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Modify | `build(modules:…)` call sites; MBW-1 hidden/reversed; MBW-9 widths; MBW-14 equality |
| `system-monitorTests/Presentation/CPUCardTests.swift` | Modify | cpu-card `CPUCardModel.gaugeAnimation(reduceMotion:)` scenarios (existing file; there is no `CPUCardModelTests.swift`) |
| `system-monitorTests/Presentation/MemoryCardModelTests.swift` | Modify | memory-card MC-10 `MemoryCardModel.gaugeAnimation(reduceMotion:)` scenarios (existing file) |

Unchanged: `MetricsState`, `PanelView`, `Palette`, `MetricHistory`, all Domain/Infrastructure CPU and memory code, `Sparkline`, `HistoryGraph`, `RingGauge`, `project.pbxproj` (convention 6).

## Test Doubles

```swift
import Synchronization

nonisolated final class ManualClock: Clock {                 // Sendable: only a `let` Mutex
    nonisolated struct Instant: InstantProtocol, Sendable, Hashable, Comparable {
        let offset: Duration
        func advanced(by duration: Duration) -> Instant; func duration(to other: Instant) -> Duration
    }
    private struct Sleeper { let id: Int; let deadline: Instant; let continuation: CheckedContinuation<Void, any Error> }
    private struct State: Sendable {   // continuations are stored, never copied out under the lock
        var now = Instant(offset: .zero); var sleepers: [Sleeper] = []; var cancelled: Set<Int> = []
        var sleepCount = 0; var nextID = 0; var countWaiters: [(threshold: Int, continuation: CheckedContinuation<Void, Never>)] = []
    }
    private let state: Mutex<State>
    var now: Instant; var minimumResolution: Duration { .zero }
    /// Task.checkCancellation first; then registers a sleeper (or resumes immediately when deadline <= now);
    /// `withTaskCancellationHandler` removes the sleeper by id and resumes it throwing CancellationError;
    /// an id cancelled before registration resumes throwing at registration. Every resume happens outside `withLock`.
    func sleep(until deadline: Instant, tolerance: Duration?) async throws
    /// Moves `now`; resumes every sleeper with deadline <= now in deadline order.
    /// One large advance resumes only the sleepers parked at that moment and never replays iterations: the loop
    /// registers its next sleep only after it has run, so "ten iterations" is ten `advance(by: interval)` calls,
    /// each followed by `awaitSleepCount(n)`, never one `advance(by: 10 * interval)`.
    func advance(by duration: Duration)
    /// Rendezvous: resumes once `sleepCount >= count` (immediately if already reached). Deterministic replacement for polling.
    func awaitSleepCount(_ count: Int) async
    var sleepCount: Int; var pendingDeadlines: [Duration]   // offsets of parked sleepers, sorted
}

nonisolated final class FakeSettingsStore: SettingsStore {  // Sendable: only a `let` Mutex
    nonisolated struct ScriptedError: Error, Equatable {}
    private struct Script: Sendable { var stored: Settings?; var saved: [Settings] = []; var throwOnSave: Set<Int>; var loadCount = 0; var saveCount = 0; var savedOnMainThread: [Bool] = [] }
    init(stored: Settings? = nil, throwOnSave: Set<Int> = [])
    func load() -> Settings                 // stored ?? Settings(); increments loadCount
    func save(_ settings: Settings) throws  // records Thread.isMainThread; throws on zero-based indexes in throwOnSave (saveCount still advances); else appends and updates `stored`
    var saved: [Settings]; var loadCount: Int; var saveCount: Int; var savedOnMainThread: [Bool]
}

nonisolated final class FakeLaunchAtLoginService: LaunchAtLoginService {
    nonisolated struct ScriptedError: Error, Equatable {}
    private struct Script: Sendable { var status: LaunchAtLoginStatus; var enableCalls = 0; var disableCalls = 0; var openLoginItemsCalls = 0; var statusReads = 0; var throwOnEnable: Set<Int>; var throwOnDisable: Set<Int> }
    init(status: LaunchAtLoginStatus = .notRegistered, throwOnEnable: Set<Int> = [], throwOnDisable: Set<Int> = [])
    var status: LaunchAtLoginStatus         // increments statusReads (proves "read at menu build time")
    func enable() throws                    // zero-based call index in throwOnEnable → throws (enableCalls still advances); else status = .enabled
    func disable() throws                   // zero-based call index in throwOnDisable → throws (disableCalls still advances); else status = .notRegistered
    func openLoginItemsSettings()
    func setStatus(_ status: LaunchAtLoginStatus)   // test-side rescripting between menu builds
    var enableCalls: Int; var disableCalls: Int; var openLoginItemsCalls: Int; var statusReads: Int
}

@MainActor final class PanelVisibilitySpy: PanelVisibilityObserver { private(set) var events: [Bool] = [] }   // true = open
@MainActor final class ErrorRecorder { private(set) var errors: [any Error] = []; func record(_ error: any Error) }
```

## Testing Strategy (strict TDD; unit command `xcodebuild … -only-testing:system-monitorTests`)

| Layer | What to Test | Approach |
|---|---|---|
| Domain unit (`SettingsTests`, `LaunchAtLoginStatusTests`) | ST-1: 0.4 s → 0.5 s, 6 s → 5 s, 2.5 s preserved, `Settings()` defaults; `[.memory, .cpu, .memory]` → `[.memory, .cpu]`; `[]` → `menuBarOrder`; `canHide` false for the last module and for an absent one; `hiding` the last module returns `self`; `showing` appends at the end and is idempotent; `movingUp`/`movingDown` at the edges return `self`; `withSamplingInterval` clamps; `Equatable`. LAL-1: `isEnabled` only for `.enabled`, `needsApproval` only for `.requiresApproval`, `allCases.count == 4` | Swift Testing, parameterised over interval inputs, module lists and `allCases` |
| Application unit (`SettingsStateTests`, `SamplingCadenceTests`) | ST-4: init loads (`loadCount == 1`, no save, `samplingInterval == 2 s`, `menuBarModules == [.memory]`); `setInterval(.seconds(3))` saves once with interval 3 s; `setInterval(.seconds(3))` twice saves once; `setInterval(.milliseconds(100))` → exposed and persisted 0.5 s; `setModule(.memory, visible: false)` → `[.cpu]`; `setModule(.cpu, visible: false)` on `[.cpu]` leaves `menuBarModules` and `saveCount` unchanged; `moveUp(.memory)` on `[.cpu, .memory]` → `[.memory, .cpu]` and the fake's last saved value matches; `throwOnSave: [0]` then `setInterval(3 s)` keeps 3 s, sets `lastSaveError`, no error propagates, the next successful save clears it; `observe` receives each committed value exactly once, synchronously, after the save; `savedOnMainThread` all `true`. ST-7 end to end: `MetricsSampler` on `ManualClock` at 1 s, started, `SamplingCadenceController` bound to the `SettingsState`, `panelDidOpen()`; park at sleep n; `setInterval(.seconds(3))` → `sleepCount == n + 1` (restarted exactly once), `pendingDeadlines == [now + 100 ms]`; `advance(100 ms)`, `awaitSleepCount(n + 2)` → next deadline `now + 3 s`. CM-1 truth table: (0.5 s, 1 s, 5 s) × (closed → 2 s, open → configured). `SamplingCadenceController`: stopped sampler follows `panelDidOpen()` (configured), `panelDidClose()` (2 s), `setInterval` while open; running sampler on `ManualClock`: `panelDidOpen()` restarts (new sleeper at the `startupGap` deadline), a second `panelDidOpen()` does not | Fakes + real `MetricsSampler`; never `@MainActor` tests |
| Sampler loop (`MetricsSamplerTests`, suite `MetricsSamplerLoopTests`; W1/W5 rewrite, CM-3) | Startup: start; `awaitSleepCount(1)`; `cpu == nil`, `memoryHistory.count == 1`, `pendingDeadlines == [100 ms]`; `advance(100 ms)`; `awaitSleepCount(2)`; `cpu != nil`, `cpuHistory.count == 1`; `advance(1 s)`; `awaitSleepCount(3)`; `cpuHistory.count == 2`. Interval: after seeding, `advance(interval − 1 ms)` adds nothing, `advance(1 ms)` adds exactly one CPU sample, repeated three times. Stop: park at sleep 2; `stop()`; `advance(5 s)`; counts frozen, `pendingDeadlines == []`, `isRunning == false`. Idempotent start: two `start()`s produce one sleeper. Off-main: same rendezvous, assertions unchanged (`:426-433`). CM-3 "No wall-clock dependency": interval 5 s, before the startup gap elapses, ten times `advance(by: .seconds(5))` + `awaitSleepCount(k)` → `cpuHistory.count == 10`, `ContinuousClock` never consulted. CM-1 "Loop keeps running while closed": sampler at `effective(1 s, closed) == 2 s`, five times `advance(2 s)` + rendezvous → exactly 5 new entries, `isRunning`. CM-1 "Opening restarts at the configured rate": `panelDidOpen()` through the controller → one new sleeper at `+100 ms`; after `advance(100 ms)` a fresh CPU snapshot and next deadline `+1 s`. CM-2 "Stored while stopped": `apply(interval: 3 s)` while stopped → `interval == 3 s`, `sleepCount == 0`; then `start()`, `awaitSleepCount(1)` deadline `+100 ms`, `advance(100 ms)`, `awaitSleepCount(2)` → next deadline `now + 3 s`. CM-2 "One restart while running": park at sleep 2; `apply(interval: 2 s)`; `awaitSleepCount(3)`; exactly one new sleeper, deadline `+100 ms`; after the gap the next deadline is `+2 s`. CM-2 "Restart costs one publish-free CPU tick": `cpuHistory.count` unchanged across the restart's first iteration, `memoryHistory.count` grew by one, the following iteration publishes CPU. CM-2 "Unchanged interval is a no-op": `apply(interval: 1 s)` at 1 s → `sleepCount` unchanged, `cpuProvider.callCount` unchanged | `ManualClock` through `makeSampler(clock:)`; `.timeLimit(.minutes(1))` stays as the only safety net; no `Task.sleep`, no `ContinuousClock` |
| Infrastructure unit (`UserDefaultsSettingsStoreTests`, `SMAppServiceLaunchAtLoginTests`) | ST-3 with `UserDefaults(suiteName: UUID().uuidString)` and `removePersistentDomain` cleanup (convention 14): round trip of `Settings(samplingInterval: 3 s, menuBarModules: [.memory, .cpu])`; missing keys → `Settings()`; `"fast"` under the interval key → 1 s with modules preserved, no throw; 9 s persisted → 5 s; `["gpu", "memory"]` → `[.memory]`; `["gpu"]` → `menuBarOrder`; `seconds(_:)` exact for 0.5 multiples. LAL-3 "Nothing persisted": after `save`, `defaults.dictionaryRepresentation().keys` filtered to the suite contain only the two `Key` values and none mentions login. LAL-3 mapping: `SMAppServiceLaunchAtLogin.map` over all four `SMAppService.Status` cases | Plain unit suites |
| Infrastructure `.integration` | `SMAppServiceLaunchAtLogin().status` read twice returns values in `LaunchAtLoginStatus.allCases` without throwing; **never** `enable()`/`disable()` (convention 13) | Tagged `.integration` (`Tags.swift:5`) |
| Presentation unit (`StatusItemReadingsTests`, `ContextMenuModelTests`, `SettingsFormModelTests`, `CPUCardTests`, `MemoryCardModelTests`) | MBW-1: `build(modules: [.memory], …)` → one MEM reading; `[.memory, .cpu]` → MEM then CPU; `[.cpu, .memory]` with total 0.42 / fraction 0.59 → `"42%"`, `"59%"`; `[]` → `[]`. MBW-9: `measurementReadings(for: [.memory])` fitting width < 130, both < 230. MBW-14: two `StatusItemContent`s from identical readings compare equal; differing CPU value text compares unequal. MBW-10/LAL-4 (`ContextMenuModelTests`): `items` over `allCases` yields three items with titles `["Settings…", "Launch at Login", "Quit System Monitor"]` for `.enabled` (checked), `.notRegistered` and `.notFound` (unchecked); `.requiresApproval` → annotated title, unchecked, `.openLoginItems`. ST-6 (`SettingsFormModelTests`): `incremented(1 s) == 1.5 s`; `incremented(5 s) == 5 s`; `decremented(0.5 s) == 0.5 s`; `intervalLabel(2.5 s, en_US) == "2.5 s"`, `de_DE == "2,5 s"` (Unicode-aware comparison after mapping U+00A0/U+202F → U+0020); `moduleRows([.memory])` → MEM visible with `isToggleEnabled == false`, CPU hidden with `isToggleEnabled == true`; `moduleRows([.memory, .cpu])` → MEM then CPU, both visible, MEM `canMoveUp == false`, CPU `canMoveDown == false`. cpu-card (`CPUCardTests`): `CPUCardModel.gaugeAnimation(reduceMotion: true) == nil`, `false` → non-nil `.easeOut(duration: 0.25)`. memory-card (`MemoryCardModelTests`): `MemoryCardModel.gaugeAnimation(reduceMotion: true) == nil`, `false` → equals `CPUCardModel.gaugeAnimation(reduceMotion: false)` | Pure helpers; `@MainActor` view measurement awaited from nonisolated tests |
| Presentation AppKit host (`StatusItemControllerTests`, `StatusItemControllerMenuTests`, `SettingsWindowControllerTests`) | `StatusItemControllerTests`: existing four cases (`:28-70`) with the new init; MBW-9 "Length changes only when the module set changes": value ticks keep `length`, `setModule(.memory, visible: false)` sets `length == contentFittingWidth(for: [.cpu]) < 130`, further CPU and memory values keep it, `setInterval` keeps it, re-showing restores `< 230`; MBW-11 `popoverAppearanceName == .darkAqua`; MBW-12: `weak var item = controller.installedStatusItem` and `weak var weakController`; end the scope, `await MainActor.run {}` once → both `nil`; MBW-13 "Open and close are reported": `popoverWillShow`/`popoverDidClose` invoked directly → spy `[true, false]`; MBW-13 "No duplicate transitions": `togglePopover()` twice in the test host → spy `[true, false]` and never two consecutive `true`, `isPanelOpen == false` (if the popover cannot display headless, the fallback is calling `togglePopover()` once, then `popoverWillShow` directly a second time is not a valid request, so the assertion becomes `isPanelOpen` guard coverage through `togglePopover()` only). `StatusItemControllerMenuTests`: `makeContextMenu()` titles `["Settings…", "Launch at Login", "Quit System Monitor"]`; "Settings…" action fires → `openSettings` closure called once (and, with a real `SettingsWindowController`, `isWindowVisible` and title "Settings"); Quit item action is `#selector(NSApplication.terminate(_:))`; LAL-4: `makeContextMenu()` twice with `setStatus(.enabled)` in between → second item state `.on`, `statusReads == 2`; `toggleLaunchAtLogin()` from `.notRegistered` → `enableCalls == 1`; from `.enabled` → `disableCalls == 1`; `.requiresApproval` item action → `openLoginItemsCalls == 1`, no enable/disable; `throwOnEnable: [0]` → `ErrorRecorder.errors.count == 1`, rebuilt menu item state `.off`. `SettingsWindowControllerTests` (ST-5): `show()` → `isWindowVisible`, `windowTitle == "Settings"`; two `show()`s → same `windowNumber`; `close()` then `show()` → visible again with the same number; `defer { close() }` | Real `NSStatusItem`/`NSWindow` in the test host (existing practice, `StatusItemControllerTests.swift:6-9`); every controller is released so `isolated deinit` removes the item (convention 16) |

Existing tests impact: `StatusItemControllerTests` (4 inits at `:30,45,54,64`), `MetricsSamplerLoopTests` (5 rewrites, helper at `:293-305` deleted), `StatusItemReadingsTests` `build` call sites and the `reading` helper (memory design decision 9 lists them), `MetricModuleTests` untouched. Test count goes from 299 to roughly 370.

## Manual Verification Checklist (recorded in the verify report)

1. Right-click → "Settings…": the window opens in front and is key on the first show (S3 trigger if not). Cmd+, with the window key re-shows it; Cmd+, after activating the app opens it.
2. Stepper 1 s → 0.5 s: the widget updates twice per second within one tick; 5 s: one update per 5 s with the panel open; closing the panel drops to one update per 2 s.
3. Hide MEM: the bar shrinks to one module (< 130 pt, read with `statusItemLength` in the debugger or by eye against the 221 pt baseline); show MEM: restored; reorder MEM/CPU: widget order follows.
4. Launch at Login: toggle on → System Settings › Login Items lists the app; toggle off → removed; approve-required state (deny in System Settings) → menu shows the "(Requires Approval)…" title and opens Login Items; a stale `.notFound` item from a moved DerivedData build re-registers on toggle.
5. Popover chrome is dark under a light system appearance.
6. Reduce Motion on: the ring gauge jumps without animation.
7. Instruments Time Profiler + SwiftUI template, 10 min panel closed then 10 min open: < 1% CPU and < 50 MB RSS closed; numbers recorded. If closed-panel samples show `PanelView` bodies evaluating, apply G3 (hosting controller built on `popoverWillShow`, dropped on close) as a follow-up task.

## Threat Matrix

N/A — no routing, shell, subprocess, VCS/PR automation, executable-file classification, or process-integration boundary. `SMAppService` is an in-process framework API (no subprocess, no shell) and is exercised only through the port; every matrix row targets Git/PR/shell boundaries this change does not have.

## Migration / Rollout

No data migration: absent `UserDefaults` keys yield `Settings()`, so first launch after upgrade behaves exactly like M3 except for the 2 s idle cadence. Single PR (`single-pr`, `size:exception` accepted in `state.yaml:7`). Rollback per the proposal's plan: revert `MetricsSampler.swift`, `StatusItemController.swift`, `StatusItemView.swift`, `AppDelegate.swift`, `system_monitorApp.swift`, the two card files and `MetricModule.swift` to `f41bc05`; delete the new Domain/Application/Infrastructure/Presentation files and tests (synchronized groups pick up removals); drop the unmerged deltas. A registered login item survives and is removed by the user in System Settings; the two `UserDefaults` keys are inert when unread. Archive must warn before merging the destructive `menu-bar-widget` and `cpu-metrics` deltas (config rule).

## Open Questions

- [x] Cadence rule: closed by the validator ruling; `SamplingCadence.effective` is the literal CM-1 rule (decision 7).
- [x] `isolated deinit` confirmed on Xcode 26.6 / Swift 6.3.3; `UserDefaults` Sendability resolved by decision 18.
- [x] `intervalLabel` strings: ST-6 pins "2.5 s" / "2,5 s"; the formatter follows the `PercentFormatter.oneDecimal` precedent (no ICU unit formatting).
- [ ] `CommandGroup(replacing: .appSettings)` next to a `Settings` scene on macOS 26 is confirmed by manual check 1; fallback named in decision 13.
