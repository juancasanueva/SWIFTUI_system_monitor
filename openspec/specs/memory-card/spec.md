# memory-card Specification

## Purpose

The Memory detail card inside the popover: header, ring gauge, Used/Total/Wired/Compressed rows, stacked bar with legend, and a 120-sample history graph at the bottom, formatted with locale-aware byte strings. Serves PRD F4, R2.4, R4.4, R4.5, R4.6, 4.3, 7.1, 7.2, 7.3 (4.3 wins over the generic 7.3 skeleton: graph last). Memory pressure indicator is out of scope. Proposal conventions 1, 2, 9, 10 apply.

## Requirements

### Requirement: MC-1 Presentational contract (Layer: Presentation) — PRD 6.1

`MemoryCard` MUST accept only a `MemorySnapshot?` and a `MetricHistory` and MUST NOT read Mach, IOKit or sysctl. All derivations (rows, gauge text, segments, legend, graph samples) MUST live in a pure `nonisolated` `MemoryCardModel` that accepts an injected `Locale`. `PanelView` MUST render `MemoryCard` bound to `MetricsState.memory` and `memoryHistory` in place of the Memory placeholder card, which MUST be removed.

#### Scenario: Card renders from fixed inputs

- GIVEN a fixed snapshot and history
- WHEN `MemoryCard` is instantiated
- THEN it builds without any environment beyond the inputs

#### Scenario: Live update while open

- GIVEN the panel is open
- WHEN `apply(memory:)` publishes a snapshot with fraction 0.69
- THEN the gauge text reads `"69.0%"`

#### Scenario: Panel grows with the memory card

- GIVEN a panel with CPU and memory snapshots applied
- WHEN its fitting height is measured
- THEN it exceeds the CPU-only height and no placeholder titled "Memory" exists

### Requirement: MC-2 Locale-aware byte formatting (Layer: Presentation) — R4.4, 4.3; research C13–C17, R4

Byte values MUST be formatted with `ByteCountFormatStyle(style: .memory)` and an injected locale: base-1024 units labelled kB/MB/GB, up to two fraction digits at GB without trailing zeros, decimal separator from the locale. Zero MUST render with digits, never spelled out. `UInt64` inputs MUST be clamped to `Int64` without trapping. Tests MUST compare strings with Unicode-aware equality (non-breaking spaces are locale-legal).

#### Scenario: Two decimals under en_US

- GIVEN 5 926 000 000 bytes
- WHEN formatted under `en_US`
- THEN the string is `"5.52 GB"`

#### Scenario: Decimal comma under de_DE

- GIVEN 5 926 000 000 bytes
- WHEN formatted under `de_DE`
- THEN the string is `"5,52 GB"`

#### Scenario: Exact multiple has no trailing zeros

- GIVEN 8 589 934 592 bytes
- WHEN formatted under `en_US`
- THEN the string is `"8 GB"`

#### Scenario: Zero and clamping

- GIVEN 0 bytes and `UInt64.max`
- WHEN formatted under `en_US`
- THEN the zero string starts with `"0"` and `UInt64.max` formats without trapping

### Requirement: MC-3 Header and ring gauge (Layer: Presentation) — 4.3, 7.2, 7.3

The card MUST show a memory icon with the title "Memory" and a ring gauge of `fraction` in `Palette.memAccent`, value at one decimal (22 pt bold rounded) with sublabel "RAM".

#### Scenario: One-decimal gauge

- GIVEN fractions 0.69 and 1
- WHEN formatted under `en_US`
- THEN the strings are `"69.0%"` and `"100.0%"`

#### Scenario: Locale decimal separator

- GIVEN fraction 0.69
- WHEN formatted under `de_DE`
- THEN the string is `"69,0%"`

### Requirement: MC-4 Key/value rows (Layer: Presentation) — 4.3

The card MUST show rows `Used`, `Total`, `Wired`, `Compressed` in that order, each formatted per MC-2.

#### Scenario: Four rows

- GIVEN the `eightGiB` fixture: used 5 926 092 800, total 8 589 934 592, wired 1 986 560 000, compressed 1 954 283 520
- WHEN rows are derived under `en_US`
- THEN they are `Used 5.52 GB`, `Total 8 GB`, `Wired 1.85 GB`, `Compressed 1.82 GB` in that order

### Requirement: MC-5 Stacked bar (Layer: Presentation) — R4.5

The bar MUST draw segments proportional to Total in the order App (`memAccent`), other-used remainder (unlabeled, `memAccent`), Wired (`memWired`), Compressed (`memCompressed`), Cached (`memCached`), Free (`memFree`), where remainder = Used − App − Wired − Compressed (saturating). Design MUST pick one rendering for the remainder: an unlabeled segment drawn in `memAccent`, or folding it into the App segment; in both cases the legend keeps five entries and the width drawn in `memAccent` equals (Used − Wired − Compressed) / Total. Segment fractions MUST sum to 1 when the components fit in Total; no segment MAY be negative and the cumulative width MUST NOT exceed 1. With `nil` snapshot or `total == 0` the bar MUST have no segments.

#### Scenario: Segments sum to Total

- GIVEN the MM-2 reference snapshot (remainder 24 288 pages)
- WHEN segments are derived
- THEN colours appear in the order memAccent, [memAccent], memWired, memCompressed, memCached, memFree
- AND fractions sum to 1 ± 1e-9 and the memAccent width == (used − wired − compressed) / total

#### Scenario: Components exceed Used

- GIVEN app + wired + compressed > used
- WHEN segments are derived
- THEN the remainder is 0, no fraction is negative and the cumulative width is clamped at 1

#### Scenario: No snapshot

- GIVEN `snapshot == nil`
- WHEN segments are derived
- THEN the list is empty

### Requirement: MC-6 Legend (Layer: Presentation) — R4.5, 4.3

The legend MUST list `App`, `Wired`, `Compressed`, `Cached`, `Free` in that order with the MC-5 colours, and MUST be present even when the snapshot is `nil`.

#### Scenario: Legend entries

- GIVEN any snapshot or `nil`
- WHEN the legend is derived
- THEN labels are `[App, Wired, Compressed, Cached, Free]` with colours `[memAccent, memWired, memCompressed, memCached, memFree]`

### Requirement: MC-7 History graph at the bottom (Layer: Presentation) — R4.6, 4.3

The card MUST draw an area graph of the last 120 `memoryHistory` values in `memAccent`, full card width, as the last section after the legend, tolerating fewer than 120 samples.

#### Scenario: Full history

- GIVEN a history with 120 values
- WHEN the graph selects its data
- THEN all 120 are used, oldest first

#### Scenario: Short and empty history

- GIVEN histories with 3 and 0 values
- WHEN the graph renders
- THEN it renders 3 points and an empty area respectively, without error

#### Scenario: Section order

- GIVEN the card layout
- WHEN its sections are enumerated
- THEN the order is header, gauge with rows, stacked bar, legend, history graph

### Requirement: MC-8 No-snapshot placeholder (Layer: Presentation)

Before the first snapshot the card MUST render the header, gauge `"0.0%"`, the four rows at 0 bytes (MC-2 zero string), an empty bar, the legend and an empty graph.

#### Scenario: Nil snapshot

- GIVEN `snapshot == nil` and an empty history
- WHEN the model is derived under `en_US`
- THEN gauge text is `"0.0%"`, every row value starts with `"0"`, segments are empty and graph samples are empty

### Requirement: MC-9 Palette tokens (Layer: Presentation) — 7.1

`Palette` MUST expose `memWired`, `memCompressed`, `memCached`, `memFree` as constants and keep `memAccent`. Token tests MUST NOT assert pairwise distinctness (`memCached` equals `cpuAccent`).

#### Scenario: Token values

- GIVEN `Palette`
- WHEN `memAccent`, `memWired`, `memCompressed`, `memCached`, `memFree` are read
- THEN they equal `#F5A623`, `#E5484D`, `#F5D90A`, `#4D8DFF`, `#3DD68C`

### Requirement: MC-10 Card surface and reduce motion (Layer: Presentation) — R2.3, 7.1, PRD 6.5

The card MUST use `cardBackground` with a 12 pt corner radius and no border. Animations MUST be disabled when `accessibilityReduceMotion` is on, using the same mechanism as `CPUCard`: `MemoryCardModel.gaugeAnimation(reduceMotion:)` MUST return `nil` when reduce motion is on and the card's standard gauge animation otherwise, and the view MUST apply exactly that result.

#### Scenario: Reduce motion

- GIVEN `reduceMotion == true`
- WHEN `MemoryCardModel.gaugeAnimation(reduceMotion:)` is evaluated
- THEN the result is `nil` and the gauge value changes without animation

#### Scenario: Motion allowed

- GIVEN `reduceMotion == false`
- WHEN `MemoryCardModel.gaugeAnimation(reduceMotion:)` is evaluated
- THEN the result is non-nil and equals the CPU card's gauge animation
