# menu-bar-widget Specification

## Purpose

Replace the hardcoded "CPU 0%" status item with a data-driven CPU module showing a 60-sample sparkline and an integer percentage, rendered at a deterministic width that does not jitter. MEM binds to `MetricsState.memory` and `memoryHistory`: integer percent of Used/Total and a 60-sample sparkline in `memAccent`; every module in `menuBarOrder` renders a sparkline (decision 2026-09-04: 40 pt each; budget raised to 230 pt so normal spacing fits). Serves PRD R1.2, R1.3, R1.4, R1.6, R1.7, R4.6, 6.5, 7.2.

## Requirements

### Requirement: Data-driven module list (Layer: Presentation) — R1.2

ID MBW-1. The status item view MUST render modules from `MetricModule.menuBarOrder` (CPU then MEM). Both modules MUST bind to `MetricsState` from the environment: CPU to `cpu`/`cpuHistory`, MEM to `memory`/`memoryHistory`. No module MAY render a static placeholder value.

#### Scenario: Order preserved

- GIVEN `menuBarOrder == [.cpu, .memory]`
- WHEN the status item view is built
- THEN two module labels appear, CPU first, MEM second

#### Scenario: Both modules follow state

- GIVEN a CPU snapshot with total 0.42 and a memory snapshot with fraction 0.59 applied
- WHEN the widget readings are built
- THEN the CPU value reads `"42%"` and the MEM value reads `"59%"`

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

The value text MUST occupy a fixed frame sized for `"100%"`. `statusItem.length` MUST be set explicitly once and MUST NOT change as values change. The hosting view MUST use empty `sizingOptions` so 1 Hz updates do not trigger Auto Layout constraint updates. Total width for two modules MUST be under 230 pt.

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
- AND the total content width measured at `"100%"` for both modules is under 230 pt

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
