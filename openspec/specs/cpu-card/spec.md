# cpu-card Specification

## Purpose

The CPU detail card inside the popover: ring gauge, key/value rows, 120-sample history graph, and per-core bars grouped by performance level, with a degraded "Cores" layout when levels are unknown. Serves PRD R2.4, R3.5, R3.6, R3.7, 7.1, 7.2, 7.3.

## Requirements

### Requirement: Presentational contract (Layer: Presentation) — 6.1

`CPUCard` MUST accept only a `CPUSnapshot?` and a `MetricHistory`. It MUST NOT read Mach, IOKit, or sysctl. `PanelView` MUST pass the live values from `MetricsState` so the card updates while open.

#### Scenario: Card renders from fixed inputs

- GIVEN a fixed snapshot and history in a preview or test
- WHEN `CPUCard` is instantiated
- THEN it builds without any environment beyond the inputs

#### Scenario: Live update while open

- GIVEN the panel is open
- WHEN a new snapshot is applied to `MetricsState`
- THEN the gauge value text changes to the new total

### Requirement: Header and gauge (Layer: Presentation) — 4.2, 7.2, 7.3

The card MUST show a CPU icon with the title "CPU", and a ring gauge of `total` in `Palette.cpuAccent` with the value at one decimal (22 pt bold rounded) and sublabel "CPU".

#### Scenario: One-decimal formatting

- GIVEN totals `0.402`, `0.4`, `1`
- WHEN formatted for the gauge under `en_US`
- THEN the strings are `"40.2%"`, `"40.0%"`, `"100.0%"`

#### Scenario: Locale decimal separator

- GIVEN total `0.402`
- WHEN formatted under `de_DE`
- THEN the string is `"40,2%"`

### Requirement: Key/value rows (Layer: Presentation) — 4.2, R3.3, R3.6

The card MUST show rows `User`, `System`, `P-Cores` (value in `cpuAccent`), `E-Cores` (value in `cpuEfficiency`), each at one decimal. When `performanceAverage` and `efficiencyAverage` are both absent, the `P-Cores` and `E-Cores` rows MUST be hidden.

#### Scenario: Four rows on Apple Silicon

- GIVEN a snapshot with user 0.306, system 0.096, P average 0.706, E average 0.098
- WHEN the rows are derived
- THEN they are `User 30.6%`, `System 9.6%`, `P-Cores 70.6%`, `E-Cores 9.8%` in that order

#### Scenario: Two rows when levels unknown

- GIVEN a snapshot whose averages are both `nil`
- WHEN the rows are derived
- THEN only `User` and `System` are present

### Requirement: History graph (Layer: Presentation) — R3.7

The card MUST draw an area graph of the last 120 history values in `cpuAccent`, full card width, tolerating fewer than 120 samples.

#### Scenario: Full history

- GIVEN a history with 120 values
- WHEN the graph selects its data
- THEN all 120 are used, oldest first

#### Scenario: Short history

- GIVEN a history with 3 values
- WHEN the graph renders
- THEN it renders 3 points without error

### Requirement: Per-core bars grouped P then E (Layer: Presentation) — R3.5

The card MUST render one bar per core with its integer percentage below. Bars MUST be grouped under `P-Cores` (cpuAccent) then `E-Cores` (cpuEfficiency), preserving snapshot order. Each group MUST wrap so that no row holds more than 8 bars.

#### Scenario: 8 P + 4 E

- GIVEN a snapshot with 8 `.performance` then 4 `.efficiency` cores
- WHEN groups are derived
- THEN group 1 is titled `P-Cores` with 8 bars and group 2 is `E-Cores` with 4 bars

#### Scenario: 16 P-cores wrap

- GIVEN a snapshot with 16 `.performance` cores
- WHEN the P group rows are derived
- THEN there are 2 rows of 8 bars each

#### Scenario: Bar label

- GIVEN a core usage `0.734`
- WHEN its label is derived
- THEN it reads `"73%"`

### Requirement: Degraded "Cores" layout (Layer: Presentation) — R3.6

When every core is `.unknown` the card MUST render a single group titled `Cores` in `cpuAccent`, ordered by core index.

#### Scenario: Intel or mismatch topology

- GIVEN a snapshot with 8 `.unknown` cores
- WHEN groups are derived
- THEN exactly one group titled `Cores` with 8 bars exists and no `P-Cores`/`E-Cores` titles appear

### Requirement: No-snapshot placeholder (Layer: Presentation)

Before the first snapshot the card MUST render the header, a gauge at `0.0%`, rows `User` and `System` showing `0.0%`, an empty graph, and no bar groups.

#### Scenario: Nil snapshot

- GIVEN `snapshot == nil` and an empty history
- WHEN the card renders
- THEN no bar groups exist and the gauge text is `"0.0%"`

### Requirement: Palette and card surface (Layer: Presentation) — 7.1, R2.3

`Palette` MUST expose the section 7.1 tokens as constants; the card MUST use `cardBackground` with a 12 pt corner radius and no border. Animations MUST be disabled when `accessibilityReduceMotion` is on.

#### Scenario: Token values

- GIVEN `Palette`
- WHEN `cpuAccent`, `cpuEfficiency`, `cardBackground`, `textSecondary` are read
- THEN they equal `#4D8DFF`, `#3FC1C9`, `#1A2131`, `#8A93A6`
