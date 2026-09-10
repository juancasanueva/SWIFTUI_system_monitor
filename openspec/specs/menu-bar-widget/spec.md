# menu-bar-widget Specification

## Purpose

Replace the hardcoded "CPU 0%" status item with a data-driven CPU module showing a 60-sample sparkline and an integer percentage, rendered at a deterministic width that does not jitter. MEM binds to `MetricsState.memory` and `memoryHistory`: integer percent of Used/Total and a 60-sample sparkline in `memAccent`; every module in the user's ordered subset (`SettingsState.menuBarModules`, default `MetricModule.menuBarOrder`) renders a sparkline (decision 2026-09-04: 40 pt each; budget raised to 230 pt so normal spacing fits; 2026-09-10: a hairline separator between modules and a rounded card behind the widget, budget raised to 250 pt). The status item length is re-measured only when that module set changes. Right-click shows a context menu with Settings…, Launch at Login and Quit; the popover is pinned to the dark appearance. Serves PRD F5, F6, R1.2, R1.3, R1.4, R1.5, R1.6, R1.7, R4.6, R5.4, R6.2, R6.3, R6.4, 6.5, 7.2.

## Requirements

### Requirement: Data-driven module list (Layer: Presentation) — R1.2, R6.3

ID MBW-1. The status item view MUST render the modules in `SettingsState.menuBarModules`, read from the environment, in that order; the default is `MetricModule.menuBarOrder` (CPU then MEM). Hidden modules MUST NOT render. Both modules MUST bind to `MetricsState` from the environment: CPU to `cpu`/`cpuHistory`, MEM to `memory`/`memoryHistory`. No module MAY render a static placeholder value.

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

### Requirement: Integer percentage value (Layer: Presentation) — R1.4, 7.2

The CPU value MUST be the total usage as a whole-number percentage with no decimals, rounded to nearest, rendered with monospaced digits at 11 pt. Before the first snapshot the value MUST render as `0%`.

#### Scenario: Integer formatting

- GIVEN totals `0.264`, `0.266`, `0`, `1`
- WHEN formatted as integer percent
- THEN the strings are `"26%"`, `"27%"`, `"0%"`, `"100%"`

#### Scenario: No snapshot yet

- GIVEN `MetricsState.cpu == nil`
- WHEN the CPU module renders
- THEN the value text is `"0%"`

### Requirement: Sixty-sample sparkline (Layer: Presentation) — R1.3, 6.5

The CPU sparkline MUST draw the last 60 values of the CPU history at a fixed 40 pt width using the CPU accent color, and MUST handle fewer than 60 (including zero) samples.

#### Scenario: Last 60 of 120

- GIVEN a history containing 120 values
- WHEN the widget selects sparkline data
- THEN exactly the newest 60 values are used, oldest first

#### Scenario: Partial history

- GIVEN a history with 7 values
- WHEN the widget selects sparkline data
- THEN all 7 values are used and the sparkline still renders at 40 pt

#### Scenario: Empty history

- GIVEN an empty history
- WHEN the sparkline renders
- THEN it renders an empty 40 pt area without error

### Requirement: Fixed-width, jitter-free layout (Layer: Presentation) — R1.4, R1.7, 6.5

ID MBW-9. The value text MUST occupy a fixed frame sized for `"100%"`. `statusItem.length` MUST be set explicitly on initialisation from a measurement of the current module set rendered at `"100%"`, MUST be re-measured only when the module set changes, and MUST NOT change as values change. The hosting view MUST use empty `sizingOptions` so 1 Hz updates do not trigger Auto Layout constraint updates. Total width MUST be under 130 pt for one module and under 250 pt for two. Two modules MUST be separated by a 1 pt hairline, and the whole widget MUST sit on a rounded card with 6 pt horizontal insets.

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
- THEN the width is less than 250 pt

#### Scenario: Module separator

- GIVEN the widget rendering `"100%"` for both modules
- WHEN its fitting width is compared with each module rendered alone
- THEN it is exactly one 1 pt hairline and one extra module gap wider than the two modules side by side

#### Scenario: One-module width

- GIVEN the widget rendering `"100%"` for `[.memory]` only
- WHEN its fitting width is measured
- THEN the width is less than 130 pt

#### Scenario: Length changes only when the module set changes

- GIVEN a controller showing `[.cpu, .memory]`
- WHEN `menuBarModules` becomes `[.cpu]`
- THEN `statusItem.length` decreases
- AND subsequent CPU and memory value changes leave it unchanged

### Requirement: Live updates (Layer: Presentation) — R2.4, PRD 10

The widget MUST reflect the latest published snapshot at each sampling interval. Unchanged sparkline data SHOULD skip redraw (Canvas views compare as `Equatable`).

#### Scenario: Value follows state

- GIVEN a widget bound to `MetricsState`
- WHEN a snapshot with total `0.42` is applied
- THEN the CPU value reads `"42%"`

#### Scenario: Equal data compares equal

- GIVEN two sparkline views built from identical value arrays
- WHEN compared
- THEN they are equal

### Requirement: Legibility (Layer: Presentation) — R1.6

The value MUST use the system label color; the module label and sparkline MUST use the module accent color, on both dark and light menu bars.

#### Scenario: Accent from module

- GIVEN the CPU module
- WHEN its accent color is resolved
- THEN it equals `Palette.cpuAccent`

### Requirement: Every module renders a sparkline

ID MBW-8. Every module in `menuBarOrder` MUST render a 40 pt sparkline in its accent color, including modules whose history is empty. Sparkline width is structural, never data-driven. Serves PRD F1, R1.2, R1.7, R4.6.

#### Scenario: MEM live sparkline

- GIVEN `menuBarOrder == [.cpu, .memory]` and `memoryHistory` holding 30 values
- WHEN the widget renders
- THEN the MEM module shows its label, a 40 pt sparkline of those 30 values in `memAccent` and the integer percent of the latest snapshot

#### Scenario: MEM empty history still has a sparkline

- GIVEN `memoryHistory` is empty and `memory == nil`
- WHEN the widget renders
- THEN the MEM module shows its label, an empty 40 pt sparkline area and `"0%"`
- AND the total content width measured at `"100%"` for both modules is under 250 pt

### Requirement: MEM live value and sparkline (Layer: Presentation) — R1.3, R1.4, R4.2, R4.6

ID MBW-7. The MEM module MUST show `MetricsState.memory?.fraction` as an integer percent (same formatter as CPU) and a 40 pt sparkline of the newest 60 `memoryHistory` values in `Palette.memAccent`. Before the first memory snapshot the value MUST be `"0%"` and the sparkline empty. The MEM accent MUST be `Palette.memAccent`.

#### Scenario: MEM value from fraction

- GIVEN a memory snapshot with fraction 0.59 applied to `MetricsState`
- WHEN the widget readings are built
- THEN the MEM value text is `"59%"`

#### Scenario: MEM newest 60 samples

- GIVEN `memoryHistory` holding 120 values
- WHEN the widget readings are built
- THEN the MEM samples are exactly the newest 60, oldest first

#### Scenario: MEM before first snapshot

- GIVEN `MetricsState.memory == nil` and an empty `memoryHistory`
- WHEN the widget readings are built
- THEN the MEM value text is `"0%"` and its samples are empty

#### Scenario: MEM accent

- GIVEN the memory module
- WHEN its accent color is resolved
- THEN it equals `Palette.memAccent`

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
