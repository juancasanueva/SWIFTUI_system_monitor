# Delta for menu-bar-widget

Purpose amendment (archive applies to the Purpose paragraph): replace "MEM renders its label, an empty 40 pt sparkline and a `0%` placeholder value until M3" with "MEM binds to `MetricsState.memory` and `memoryHistory`: integer percent of Used/Total and a 60-sample sparkline in `memAccent`". Add "R4.6" to the served PRD list. Layout constants, `StatusItemController` and the 230 pt budget are unchanged (proposal convention 7).

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Data-driven module list (Layer: Presentation) — R1.2

ID MBW-1. The status item view MUST render modules from `MetricModule.menuBarOrder` (CPU then MEM). Both modules MUST bind to `MetricsState` from the environment: CPU to `cpu`/`cpuHistory`, MEM to `memory`/`memoryHistory`. No module MAY render a static placeholder value.
(Previously: the CPU module bound to `MetricsState`; the MEM module MAY keep its placeholder value.)

#### Scenario: Order preserved

- GIVEN `menuBarOrder == [.cpu, .memory]`
- WHEN the status item view is built
- THEN two module labels appear, CPU first, MEM second

#### Scenario: Both modules follow state

- GIVEN a CPU snapshot with total 0.42 and a memory snapshot with fraction 0.59 applied
- WHEN the widget readings are built
- THEN the CPU value reads `"42%"` and the MEM value reads `"59%"`

### Requirement: Every module renders a sparkline

ID MBW-8. Every module in `menuBarOrder` MUST render a 40 pt sparkline in its accent color, including modules whose history is empty. Sparkline width is structural, never data-driven. Serves PRD F1, R1.2, R1.7, R4.6.
(Previously: the MEM scenario asserted an empty placeholder sparkline and a static `0%`.)

#### Scenario: MEM live sparkline

- GIVEN `menuBarOrder == [.cpu, .memory]` and `memoryHistory` holding 30 values
- WHEN the widget renders
- THEN the MEM module shows its label, a 40 pt sparkline of those 30 values in `memAccent` and the integer percent of the latest snapshot

#### Scenario: MEM empty history still has a sparkline

- GIVEN `memoryHistory` is empty and `memory == nil`
- WHEN the widget renders
- THEN the MEM module shows its label, an empty 40 pt sparkline area and `"0%"`
- AND the total content width measured at `"100%"` for both modules is under 230 pt

## REMOVED Requirements

None. (The scenario "MEM placeholder still has a sparkline" and the test `theMemoryModuleStaysAPlaceholder` are superseded by the MODIFIED block above; Migration: replace the test with the MBW-7/MBW-8 scenarios.)
