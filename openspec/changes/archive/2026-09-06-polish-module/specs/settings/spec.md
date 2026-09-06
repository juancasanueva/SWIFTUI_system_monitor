# settings Specification

## Purpose

User-configurable sampling interval and menu-bar module visibility and order. The values and their invariants live in one Domain `Settings` value; persistence goes through a `SettingsStore` port with a `UserDefaults` adapter; `SettingsState` exposes the value to the UI and persists every mutation; one reusable "Settings" window edits it, reachable from the status-item context menu and Cmd+,. Serves PRD F6, R1.5, R5.1, R6.2, R6.3, milestone M4. Proposal conventions 1, 2, 4, 6, 9, 10, 14, 15 apply to every type and test named here. Launch at login is specified separately (`launch-at-login`); how the widget consumes the module list is specified in `menu-bar-widget` (MBW-1); how the sampler consumes the interval is specified in `cpu-metrics` (CM-1, CM-2).

## Requirements

### Requirement: ST-1 Settings value invariants (Layer: Domain) — F6, R5.1

`Settings` MUST be a `nonisolated`, `Sendable`, `Equatable` value with `samplingInterval: Duration` and `menuBarModules: [MetricModule]`. The interval MUST be clamped to the closed range 0.5 s–5 s on construction; the default MUST be 1 s. `menuBarModules` MUST preserve the caller's order, MUST drop later duplicates (first occurrence wins) and MUST NOT be empty: an empty input normalises to `MetricModule.menuBarOrder`, which is also the default. `MetricModule.menuBarOrder` MUST be documented as the default order, not the rendered order.

#### Scenario: Interval clamped at the low bound

- GIVEN an interval of 0.4 s
- WHEN a `Settings` value is constructed
- THEN `samplingInterval == .milliseconds(500)`

#### Scenario: Interval clamped at the high bound

- GIVEN an interval of 6 s
- WHEN a `Settings` value is constructed
- THEN `samplingInterval == .seconds(5)`

#### Scenario: In-range interval preserved

- GIVEN an interval of 2.5 s
- WHEN a `Settings` value is constructed
- THEN `samplingInterval == .milliseconds(2500)`

#### Scenario: Defaults

- GIVEN no arguments
- WHEN `Settings()` is constructed
- THEN `samplingInterval == .seconds(1)` and `menuBarModules == MetricModule.menuBarOrder`

#### Scenario: Duplicates dropped, order kept

- GIVEN modules `[.memory, .cpu, .memory]`
- WHEN a `Settings` value is constructed
- THEN `menuBarModules == [.memory, .cpu]`

#### Scenario: Empty list normalises to the default order

- GIVEN modules `[]`
- WHEN a `Settings` value is constructed
- THEN `menuBarModules == MetricModule.menuBarOrder`

### Requirement: ST-2 Settings store port (Layer: Domain) — PRD 6.1, 6.4

The system MUST define a `SettingsStore` port with `load() -> Settings` and `save(_ settings: Settings) throws`. `load()` MUST NOT throw: any unreadable state yields a value that satisfies ST-1. The port MUST be `nonisolated` and `Sendable`; a Mutex-backed `FakeSettingsStore` MUST satisfy it for tests (convention 4).

#### Scenario: Fake round trip

- GIVEN a `FakeSettingsStore` seeded with interval 2 s and modules `[.memory]`
- WHEN `load()` is called
- THEN the returned value has interval 2 s and modules `[.memory]`

#### Scenario: Scripted save failure

- GIVEN a fake scripted to throw on save call 0 (zero-based)
- WHEN `save(_:)` is called twice
- THEN the first call throws and the second call records the saved value

### Requirement: ST-3 UserDefaults adapter (Layer: Infrastructure) — R6.2, R6.3

`UserDefaultsSettingsStore(defaults:)` MUST persist the interval and the ordered module list under stable keys in the injected `UserDefaults` and MUST read them back as an equal `Settings` value. Missing keys MUST yield the ST-1 defaults. A value of the wrong type MUST yield that field's default. An out-of-range interval MUST be clamped through ST-1 on load. Module raw values that do not name a `MetricModule` case MUST be ignored; if none remain the list normalises to `menuBarOrder`. The adapter MUST work under App Sandbox and MUST NOT store any launch-at-login value.

#### Scenario: Round trip

- GIVEN a store over a fresh `UserDefaults(suiteName:)` and a `Settings` with interval 3 s and modules `[.memory, .cpu]`
- WHEN `save(_:)` then `load()` run
- THEN the loaded value equals the saved value

#### Scenario: Missing keys

- GIVEN a suite with no keys
- WHEN `load()` runs
- THEN the result equals `Settings()`

#### Scenario: Corrupt interval

- GIVEN the interval key holds the string `"fast"`
- WHEN `load()` runs
- THEN `samplingInterval == .seconds(1)` and no error is thrown

#### Scenario: Out-of-range persisted interval

- GIVEN the interval key holds 9 s
- WHEN `load()` runs
- THEN `samplingInterval == .seconds(5)`

#### Scenario: Unknown module raw values ignored

- GIVEN the modules key holds `["gpu", "memory"]`
- WHEN `load()` runs
- THEN `menuBarModules == [.memory]`

#### Scenario: Only unknown module raw values

- GIVEN the modules key holds `["gpu"]`
- WHEN `load()` runs
- THEN `menuBarModules == MetricModule.menuBarOrder`

### Requirement: ST-4 Observable settings state (Layer: Application) — PRD 6.1 (amended), R6.2

`SettingsState` MUST be `@Observable` and `@MainActor`, MUST load its value from the injected `SettingsStore` on init, MUST expose the read-only pass-throughs `samplingInterval: Duration` and `menuBarModules: [MetricModule]` (plus the whole `settings: Settings` value, read-only), and MUST mutate only through the intent methods `setInterval(_:)`, `setModule(_:visible:)`, `moveUp(_:)` and `moveDown(_:)`, persisting through the store after every accepted mutation. Every mutation MUST pass through ST-1, so the exposed value is always valid. A mutation that does not change the value MUST NOT persist. A save failure MUST NOT crash and MUST NOT discard the in-memory value. `SettingsState` MUST refuse to hide the last visible module: `setModule(_:visible: false)` on it is a no-op and nothing is persisted. It is the second `@Observable` object in Application; PRD 6.1 MUST be amended to say so.

#### Scenario: Loads on init

- GIVEN a fake store seeded with interval 2 s and modules `[.memory]`
- WHEN `SettingsState(store:)` is created
- THEN `samplingInterval == .seconds(2)` and `menuBarModules == [.memory]`

#### Scenario: Persists on mutation

- GIVEN a state over a fake store
- WHEN `setInterval(.seconds(3))` is called
- THEN the fake recorded exactly one save whose interval is 3 s and `samplingInterval == .seconds(3)`

#### Scenario: Unchanged mutation does not persist

- GIVEN a state over a fake store with `samplingInterval == .seconds(3)`
- WHEN `setInterval(.seconds(3))` is called again
- THEN the fake recorded no additional save

#### Scenario: Mutation is clamped

- GIVEN a state over a fake store
- WHEN `setInterval(.milliseconds(100))` is called
- THEN `samplingInterval == .milliseconds(500)` and the persisted interval is 0.5 s

#### Scenario: Save failure keeps the in-memory value

- GIVEN a fake store that throws on save call 0
- WHEN `setInterval(.seconds(3))` is called
- THEN `samplingInterval == .seconds(3)` and no error propagates

#### Scenario: Hiding a module persists

- GIVEN `menuBarModules == [.cpu, .memory]`
- WHEN `setModule(.memory, visible: false)` is called
- THEN `menuBarModules == [.cpu]` and the fake's last saved value has modules `[.cpu]`

#### Scenario: Last module cannot be hidden

- GIVEN `menuBarModules == [.cpu]`
- WHEN `setModule(.cpu, visible: false)` is called
- THEN `menuBarModules == [.cpu]` and the fake recorded no save

#### Scenario: Reorder persists

- GIVEN `menuBarModules == [.cpu, .memory]`
- WHEN `moveUp(.memory)` is called
- THEN `menuBarModules == [.memory, .cpu]` and the fake's last saved value matches

### Requirement: ST-5 Single reusable settings window (Layer: Presentation) — F6, R1.5

`SettingsWindowController` MUST own at most one window titled "Settings" hosting `SettingsView` bound to `SettingsState`. `show()` MUST create the window on first use, MUST size its content area explicitly so the whole form is on screen (the fixed form width, and a height that is at least the `SettingsView.formHeight` floor and never less than the hosted form's own fitting height), MUST bring it to the front and make it key, and MUST reuse the same window on later calls. Closing the window MUST hide it, not destroy the controller. Both entry points, the context-menu item "Settings…" (MBW-10) and Cmd+,, MUST call `show()` on the same controller so only one settings window ever exists. Activation-policy toggling is a design-owned fallback only if activation is refused.

#### Scenario: First show creates the window

- GIVEN a controller that has never shown its window
- WHEN `show()` is called
- THEN a window titled "Settings" is visible

#### Scenario: First show presents the whole form

- GIVEN a controller that has never shown its window
- WHEN `show()` runs
- THEN the window's content area is 360 pt wide and at least 280 pt tall, never shorter than the height the hosted form measures for itself

#### Scenario: Second show reuses the window

- GIVEN the window is visible
- WHEN `show()` is called again
- THEN the same window instance is key and the controller owns exactly one window

#### Scenario: Both entry points share the window

- GIVEN the window was opened from the context menu
- WHEN the Cmd+, command is handled
- THEN no second window is created and the existing one is key

### Requirement: ST-6 Settings view controls (Layer: Presentation) — F6, R5.1, R6.3

`SettingsView` MUST offer an interval stepper over 0.5 s–5 s in 0.5 s steps whose label shows the value with one fraction digit and the unit "s" formatted for the injected locale (convention 9), a visibility toggle per `MetricModule` listed in the current order, and controls to move a module up or down. The toggle of the only visible module MUST be disabled. All derivations (label text, step results, toggle enablement) MUST live in the pure `nonisolated` `SettingsFormModel` (`intervalLabel(for:locale:)`, `incremented(_:)`, `decremented(_:)`, `moduleRows(for:)`) that accepts an injected `Locale`; the label is the one-fraction-digit number under that locale followed by the literal `" s"`, never a unit-formatted measurement.

#### Scenario: Stepper increments in half seconds

- GIVEN interval 1 s
- WHEN the stepper increments
- THEN the interval is 1.5 s

#### Scenario: Stepper saturates at the bounds

- GIVEN interval 5 s
- WHEN the stepper increments
- THEN the interval stays 5 s
- AND from 0.5 s a decrement stays 0.5 s

#### Scenario: Interval label under en_US

- GIVEN interval 2.5 s
- WHEN the label is derived under `en_US`
- THEN it is `"2.5 s"` (Unicode-aware comparison)

#### Scenario: Interval label under de_DE

- GIVEN interval 2.5 s
- WHEN the label is derived under `de_DE`
- THEN it is `"2,5 s"` (Unicode-aware comparison)

#### Scenario: Last visible toggle disabled

- GIVEN `menuBarModules == [.memory]`
- WHEN toggle enablement is derived
- THEN the `.memory` toggle is disabled and the `.cpu` toggle is enabled

#### Scenario: Toggles follow the current order

- GIVEN `menuBarModules == [.memory, .cpu]`
- WHEN the module rows are derived
- THEN they list MEM then CPU, MEM checked and CPU checked

#### Scenario: Move buttons reorder the widget

- GIVEN a settings form over `menuBarModules == [.cpu, .memory]`
- WHEN the move-down intent runs for `.cpu`
- THEN the persisted order is `[.memory, .cpu]`
- AND repeating the move for a module already at that edge persists nothing

### Requirement: ST-7 Interval reaches the sampler (Layer: Application) — R5.1, R5.4

A change to `SettingsState.samplingInterval` MUST reach the running sampler through `MetricsSampler.apply(interval:)` (CM-2) with the cadence rule of CM-1 applied, so the new interval is observable within one tick. The composition root MUST wire this; no view MAY call the sampler directly.

#### Scenario: Interval change is applied to the sampler

- GIVEN a running sampler driven by a manual clock at 1 s with the panel open, bound to a `SettingsState`
- WHEN `setInterval(.seconds(3))` is called
- THEN the sampler restarts once and its next gap is 3 s

## Verification notes

- `SettingsTests` (Domain): ST-1 clamp, default, dedupe and empty normalisation as parameterised cases.
- `FakeSettingsStore` under `system-monitorTests/Support`: ST-2 round trip and `throwOnSave` (zero-based set).
- `UserDefaultsSettingsStoreTests` (Infrastructure): ST-3 with a unique `suiteName` per test and `removePersistentDomain(forName:)` cleanup (convention 14); also hosts LAL-3 "Nothing persisted".
- `SettingsStateTests` (Application): ST-4 and ST-7 (with `ManualClock` and `SamplingCadenceController`, see CM-3); tests are not `@MainActor` and `await` main-actor members.
- `SettingsWindowControllerTests` and `SettingsFormModelTests` (Presentation): ST-5, ST-6; locale-pinned labels compared with Unicode-aware equality.
- `SettingsViewTests` (Presentation): the ST-6 control wiring the pure model cannot see — the stepper, the two move buttons ("Move buttons reorder the widget") and the visibility toggle, each driven through `SettingsFormIntent` over a real `SettingsState`.
- `AppDelegateCompositionTests` (App): the composition root's half of ST-5 "Both entry points share the window" and of ST-7 — one `SettingsState`, one `SettingsWindowController`, and the panel transition reaching the sampler. Cmd+, itself is a manual check.
- Test file names follow the design's File Changes table (`design.md`, revision 2, including the `AppDelegateCompositionTests.swift` row added at batch G).
- Manual: the window opens in front from the context menu and from Cmd+, on macOS 26 (activation risk from the proposal).
