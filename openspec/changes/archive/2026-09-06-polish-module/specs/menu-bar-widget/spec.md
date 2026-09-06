# Delta for menu-bar-widget

Purpose amendment (archive applies to the Purpose paragraph): replace "every module in `menuBarOrder` renders a sparkline" with "every module in the user's ordered subset (`SettingsState.menuBarModules`, default `MetricModule.menuBarOrder`) renders a sparkline"; append "The status item length is re-measured only when that module set changes. Right-click shows a context menu with Settings…, Launch at Login and Quit; the popover is pinned to the dark appearance." Add F5, F6, R1.5, R5.4, R6.2, R6.3, R6.4 to the served PRD list. Layout constants and the 230 pt budget are unchanged (proposal convention 7).

## ADDED Requirements

### Requirement: Context menu (Layer: Presentation) — R1.5, R6.4

ID MBW-10. Right-clicking the status item MUST show a menu rebuilt on every open with exactly three action items in this order: "Settings…", "Launch at Login", "Quit System Monitor" (separators MAY appear between them). "Settings…" MUST call `SettingsWindowController.show()` (ST-5); "Launch at Login" MUST behave per LAL-4; "Quit System Monitor" MUST terminate the application. Left-click MUST keep toggling the popover.

#### Scenario: Item titles and order

- GIVEN a controller with fake settings and launch-at-login services
- WHEN the context menu is built
- THEN its action-item titles are `["Settings…", "Launch at Login", "Quit System Monitor"]` in that order

#### Scenario: Settings item opens the window

- GIVEN the same controller
- WHEN the "Settings…" action fires
- THEN the settings window is visible and titled "Settings"

#### Scenario: Quit terminates

- GIVEN the same controller
- WHEN the "Quit System Monitor" item is inspected
- THEN its action is the application terminate action

### Requirement: Popover pinned to the dark appearance (Layer: Presentation) — 7.1, PRD OQ2 (decided: dark only in v1)

ID MBW-11. The popover MUST use the `darkAqua` appearance regardless of the system appearance, so its chrome matches `Palette.panelBackground`. No palette token changes for this requirement.

#### Scenario: Popover appearance

- GIVEN a controller is initialised
- WHEN the popover appearance is inspected
- THEN its name is `darkAqua`

#### Scenario: Palette untouched

- GIVEN `Palette`
- WHEN `cardBackground` and `memAccent` are read
- THEN they still equal `#1A2131` and `#F5A623` (no token changes in this change)

### Requirement: Status item released with its controller (Layer: Presentation) — PRD 8; debt W6

ID MBW-12. When a `StatusItemController` is deallocated it MUST remove its `NSStatusItem` from the system status bar so no orphaned item survives. Test suites MUST release every controller they create (convention 16).

#### Scenario: Deinit removes the item

- GIVEN a controller holding a status item, with a weak reference kept to that item through the controller's test-visible `installedStatusItem` accessor
- WHEN the controller is released
- THEN the weak reference is `nil`

### Requirement: Panel open state drives the sampling cadence (Layer: Presentation) — R5.4

ID MBW-13. The controller MUST observe its popover and report every open and close transition to the cadence consumer exactly once per transition, so the sampler can switch between the closed cadence and the configured interval (CM-1). Opening MUST be reported before the panel becomes visible. The controller MUST NOT expose a show-only path: its `togglePopover()` closes an already-shown popover instead of re-issuing show, so no open transition can be reported twice for one open.

#### Scenario: Open and close are reported

- GIVEN a controller with a recorder for panel transitions
- WHEN the popover shows and then closes
- THEN the recorder holds `[open, closed]`

#### Scenario: No duplicate transitions

- GIVEN the popover is already open (one `open` recorded)
- WHEN `togglePopover()` is called again
- THEN the popover closes, the recorder holds `[open, closed]` and no additional `open` transition was recorded

### Requirement: Redraw gating on unchanged readings (Layer: Presentation) — PRD 10

ID MBW-14. `StatusItemContent` and each module label MUST be `Equatable` so that identical readings compare equal and SwiftUI can skip their bodies; differing values or samples compare unequal. This complements the existing "Live updates" requirement without changing it.

#### Scenario: Identical readings compare equal

- GIVEN two contents built from identical readings for `[.cpu, .memory]`
- WHEN compared
- THEN they are equal

#### Scenario: Changed value compares unequal

- GIVEN two contents that differ only in the CPU value text
- WHEN compared
- THEN they are not equal

## MODIFIED Requirements

### Requirement: Data-driven module list (Layer: Presentation) — R1.2, R6.3

ID MBW-1. The status item view MUST render the modules in `SettingsState.menuBarModules`, read from the environment, in that order; the default is `MetricModule.menuBarOrder` (CPU then MEM). Hidden modules MUST NOT render. Both modules MUST bind to `MetricsState` from the environment: CPU to `cpu`/`cpuHistory`, MEM to `memory`/`memoryHistory`. No module MAY render a static placeholder value.
(Previously: the view rendered the static `MetricModule.menuBarOrder`; the module list was not user-configurable.)
Destructive: archive must warn.

#### Scenario: Order preserved

- GIVEN `menuBarModules == [.cpu, .memory]`
- WHEN the status item view is built
- THEN two module labels appear, CPU first, MEM second

#### Scenario: Both modules follow state

- GIVEN a CPU snapshot with total 0.42 and a memory snapshot with fraction 0.59 applied
- WHEN the widget readings are built
- THEN the CPU value reads `"42%"` and the MEM value reads `"59%"`

#### Scenario: Hidden module omitted

- GIVEN `menuBarModules == [.memory]`
- WHEN the widget readings are built
- THEN exactly one reading exists and it is MEM

#### Scenario: Reversed order

- GIVEN `menuBarModules == [.memory, .cpu]`
- WHEN the widget readings are built
- THEN the readings are MEM then CPU

### Requirement: Fixed-width, jitter-free layout (Layer: Presentation) — R1.4, R1.7, 6.5

ID MBW-9. The value text MUST occupy a fixed frame sized for `"100%"`. `statusItem.length` MUST be set explicitly on initialisation from a measurement of the current module set rendered at `"100%"`, MUST be re-measured only when the module set changes, and MUST NOT change as values change. The hosting view MUST use empty `sizingOptions` so 1 Hz updates do not trigger Auto Layout constraint updates. Total width MUST be under 130 pt for one module and under 230 pt for two.
(Previously: `statusItem.length` was "set explicitly once" from the static two-module set; no one-module width scenario.)
Destructive: archive must warn.

#### Scenario: Length stable across updates

- GIVEN a status item controller with a live state
- WHEN the CPU total changes from `0.05` to `1.0`
- THEN `statusItem.length` is unchanged

#### Scenario: Sizing options disabled

- GIVEN the controller is initialised
- WHEN the hosting view is inspected
- THEN `sizingOptions == []`

#### Scenario: Width budget

- GIVEN the widget rendering `"100%"` for both modules
- WHEN its fitting width is measured
- THEN the width is less than 230 pt

#### Scenario: One-module width

- GIVEN the widget rendering `"100%"` for `[.memory]` only
- WHEN its fitting width is measured
- THEN the width is less than 130 pt

#### Scenario: Length changes only when the module set changes

- GIVEN a controller showing `[.cpu, .memory]`
- WHEN `menuBarModules` becomes `[.cpu]`
- THEN `statusItem.length` decreases
- AND subsequent CPU and memory value changes leave it unchanged

## REMOVED Requirements

None.

## Verification notes

- `StatusItemReadingsTests` (Presentation): MBW-1 hidden/reversed readings, MBW-9 widths via `NSHostingView.fittingSize`, MBW-14 equality.
- `StatusItemControllerTests` (Presentation): MBW-9 length stability and module-set re-measure, MBW-11 appearance, MBW-12 weak-reference release via `installedStatusItem`, MBW-13 transition recorder and the `togglePopover()` no-duplicate case; every `NSStatusItem` removed (convention 16).
- `ContextMenuModelTests` (Presentation): MBW-10 titles and order as a pure table over `ContextMenuModel.items(launchAtLogin:)`.
- `StatusItemControllerMenuTests` (Presentation): MBW-10 actions and window opening through `makeContextMenu()`, shared with LAL-4.
- Test file names follow the design's File Changes table (`design.md`, revision 2).
- Manual: hiding MEM visibly shrinks the bar; Instruments Time Profiler, 10 min, panel closed and open (PRD 10 evidence recorded in the verify report).
