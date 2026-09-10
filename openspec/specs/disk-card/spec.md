# disk-card Specification

## Purpose

The Disk detail card inside the popover: header, ring gauge, Used/Free/Total rows and a read/write throughput footer, with no history graph and no stacked bar, formatted with locale-aware decimal capacity and per-second throughput strings. Serves PRD F10, R2.2, R10.5 (amended to `.decimal`), R10.6, R10.8, R10.9, R10.10, 4.5, 7.1, 7.2, 7.3. Proposal conventions 1, 2, 9, 10 apply; precedents MC-1, MC-8, MC-10. Reference fixture: total 494 354 000 000, free 62 286 000 000 (used 432 068 000 000), read 27 100 000 B/s, write 2 200 000 B/s.

## Requirements

### Requirement: DC-1 Presentational contract and panel placement (Layer: Presentation) — PRD 6.1, R2.2

`DiskCard` MUST accept only a `DiskSnapshot?` and MUST NOT read Mach, IOKit, sysctl or Foundation volume APIs. All derivations (sections, rows, gauge text and fraction, throughput texts, icons, animation) MUST live in a pure `nonisolated enum DiskCardModel` that accepts an injected `Locale`. `PanelView` MUST render `DiskCard(snapshot: state.disk)` third, after `MemoryCard` and before the Network card, inside the existing 12 pt-spaced stack at 320 pt width.
(Previously: the Disk card was the last card and the panel order ended at Disk.)

#### Scenario: Card renders from a fixed input

- GIVEN the reference snapshot
- WHEN `DiskCard` is instantiated
- THEN it builds without any environment beyond the input

#### Scenario: Card order

- GIVEN the panel layout
- WHEN its cards are enumerated
- THEN the order is CPU, Memory, Disk, Network

#### Scenario: Live update while open

- GIVEN the panel is open
- WHEN `apply(disk:)` publishes a snapshot with fraction 0.874
- THEN the gauge text reads `"87.4%"`

### Requirement: DC-2 Section order without graph or bar (Layer: Presentation) — 4.5, 7.3, R10.6, R10.8

`DiskCardModel.sections` MUST equal `[.header, .gaugeAndRows, .throughput]` and the view MUST render exactly those sections in that order. The card MUST NOT take a `MetricHistory` and MUST NOT render a history graph or a stacked bar.

#### Scenario: Sections

- GIVEN any snapshot or `nil`
- WHEN `sections` is read
- THEN it equals `[.header, .gaugeAndRows, .throughput]`

### Requirement: DC-3 Header and ring gauge (Layer: Presentation) — 4.5, 7.2, R10.10

The header MUST show an internal-drive SF Symbol whose name resolves via `NSImage(systemSymbolName:accessibilityDescription:)` and the title "Disk" with the header accessibility trait. The ring gauge MUST draw `snapshot.fraction` in `Palette.diskAccent` with the value at one decimal (22 pt bold rounded) and the sublabel "Disk".

#### Scenario: One-decimal gauge

- GIVEN fractions 0.874 and 1
- WHEN formatted under `en_US`
- THEN the strings are `"87.4%"` and `"100.0%"` and the gauge fraction equals the snapshot's

#### Scenario: Locale decimal separator

- GIVEN fraction 0.874
- WHEN formatted under `de_DE`
- THEN the string is `"87,4%"`

#### Scenario: Header symbol resolves

- GIVEN `DiskCardModel.headerSymbolName`
- WHEN resolved through `NSImage(systemSymbolName:accessibilityDescription:)`
- THEN the image is non-nil

### Requirement: DC-4 Key/value rows (Layer: Presentation) — 4.5, R10.6

The card MUST show rows `Used`, `Free`, `Total` in that order, each formatted per DC-5.

#### Scenario: Three rows

- GIVEN the reference snapshot
- WHEN rows are derived under `en_US`
- THEN they are `Used 432.07 GB`, `Free 62.29 GB`, `Total 494.35 GB` in that order

#### Scenario: Rows under de_DE

- GIVEN the reference snapshot
- WHEN rows are derived under `de_DE`
- THEN the values are `"432,07 GB"`, `"62,29 GB"`, `"494,35 GB"`

### Requirement: DC-5 Decimal capacity formatting (Layer: Presentation) — R10.5 (amended), 4.5, R4.4

Capacity MUST be formatted with `ByteCountFormatStyle(style: .decimal)` (base 1000) and an injected locale, with the locale's decimal separator, no trailing zeros, digits for zero, and `UInt64` clamped to `Int64` without trapping. Tests MUST normalise U+00A0/U+202F before comparing.

#### Scenario: Two decimals under en_US

- GIVEN 432 068 000 000 bytes
- WHEN formatted under `en_US`
- THEN the string is `"432.07 GB"`

#### Scenario: Decimal comma under de_DE

- GIVEN 432 068 000 000 bytes
- WHEN formatted under `de_DE`
- THEN the string is `"432,07 GB"`

#### Scenario: Exact multiple and clamping

- GIVEN 512 000 000 000 bytes, 0 bytes and `UInt64.max`
- WHEN formatted under `en_US`
- THEN the strings are `"512 GB"`, a string starting with `"0"`, and a value that formats without trapping

### Requirement: DC-6 Throughput formatting (Layer: Presentation) — R10.5, 4.5

Throughput MUST be formatted as decimal bytes per second (units by 1000-steps) with exactly one fraction digit, the locale's decimal separator and a `/s` suffix. The unit vocabulary below 1 kB and the zero string are design-owned, and the design's tests MUST pin them under both `en_US` and `de_DE`.

#### Scenario: Megabytes per second

- GIVEN 27 100 000 and 2 200 000 B/s
- WHEN formatted under `en_US`
- THEN the strings are `"27.1 MB/s"` and `"2.2 MB/s"`

#### Scenario: Decimal comma

- GIVEN 27 100 000 B/s
- WHEN formatted under `de_DE`
- THEN the string is `"27,1 MB/s"`

#### Scenario: Whole values keep one fraction digit

- GIVEN 1 000 000 000 B/s
- WHEN formatted under `en_US`
- THEN the string is `"1.0 GB/s"`

### Requirement: DC-7 Throughput footer (Layer: Presentation) — R10.6, R10.9, R10.10

The footer MUST show read then write, each as a `ThroughputLabel` with an icon in `Palette.diskAccent` followed by the value text. The read and write symbol names MUST differ and both MUST resolve via `NSImage(systemSymbolName:accessibilityDescription:)`. The labels MUST carry accessibility labels "Read" and "Write". A `nil` rate MUST render an em dash (U+2014) with accessibility value "unavailable".

#### Scenario: Populated footer

- GIVEN the reference snapshot
- WHEN the footer texts are derived under `en_US`
- THEN they are `"27.1 MB/s"` then `"2.2 MB/s"` with accessibility labels `"Read"` then `"Write"`

#### Scenario: Distinct icons resolve

- GIVEN `DiskCardModel.readSymbolName` and `writeSymbolName`
- WHEN compared and resolved
- THEN they differ and both images are non-nil

#### Scenario: Unavailable rates

- GIVEN a snapshot with both rates `nil`
- WHEN the footer texts are derived
- THEN both are `"—"` with accessibility value `"unavailable"`

### Requirement: DC-8 Nil-snapshot skeleton (Layer: Presentation) — R10.9, MC-8

With `snapshot == nil` the card MUST render the full skeleton: header, gauge with fraction 0 and an em dash as value text (never `"0%"` or `"0.0%"`), the three rows with em dash values, and the footer per DC-7. The skeleton MUST occupy the same height as the populated card. Design MAY add a distinct "Unavailable" caption without changing the height.

#### Scenario: Nil model

- GIVEN `snapshot == nil`
- WHEN the model is derived under `en_US`
- THEN gauge text is `"—"`, gauge fraction is 0, every row value is `"—"` and both footer texts are `"—"`

#### Scenario: Height is stable

- GIVEN a panel with CPU and memory snapshots applied and `disk == nil`
- WHEN the first disk snapshot is applied
- THEN the panel's fitting height does not change

### Requirement: DC-9 Palette token and card chrome (Layer: Presentation) — 7.1, R2.3, R10.10

`Palette` MUST expose `diskAccent == sRGB(0x3DD68C)`, the same value as `memFree`; token tests MUST NOT assert pairwise distinctness. The card MUST use `cardBackground`, `cardCornerRadius`, padding 16, section spacing 14 and row spacing 6, identical to the other cards.

#### Scenario: Token value

- GIVEN `Palette`
- WHEN `diskAccent` is read
- THEN it equals `#3DD68C` and equals `memFree`

#### Scenario: Chrome parity

- GIVEN `DiskCard`'s layout constants
- WHEN compared with `MemoryCard`'s
- THEN padding, section spacing, row spacing and corner radius are equal

### Requirement: DC-10 Reduce motion (Layer: Presentation) — PRD 6.5, MC-10

`DiskCardModel.gaugeAnimation(reduceMotion:)` MUST delegate to `CPUCardModel.gaugeAnimation`: `nil` when reduce motion is on and the CPU card's gauge animation otherwise; the view MUST apply exactly that result.

#### Scenario: Reduce motion

- GIVEN `reduceMotion == true`
- WHEN the animation is evaluated
- THEN the result is `nil`

#### Scenario: Motion allowed

- GIVEN `reduceMotion == false`
- WHEN the animation is evaluated
- THEN the result is non-nil and equals `CPUCardModel.gaugeAnimation(reduceMotion: false)`

### Requirement: DC-11 Panel height (Layer: Presentation) — R2.2, PRD 10

`PanelView`'s fitting height MUST be at least the sum of the CPU, Memory, Disk and Network card heights plus chrome, so it grows with the fourth card. The presented panel height MUST be bounded by the visible-frame cap specified in `network-card` NC-12 rather than being unbounded, and content MUST NOT be clipped. Existing lower-bound height assertions MUST stay green.
(Previously: the height was the three-card sum and the popover had no fixed content size, so it grew without bound.)

#### Scenario: Three-card height

- GIVEN a panel with CPU, memory and disk snapshots applied
- WHEN its fitting height is measured
- THEN it is `>= cpu + memory + disk + chrome` and exceeds the two-card height

#### Scenario: Four-card height

- GIVEN a panel with CPU, memory, disk and network snapshots applied
- WHEN its fitting height is measured
- THEN it is `>= cpu + memory + disk + network + chrome` and exceeds the three-card height

#### Scenario: Height is bounded by the visible frame

- GIVEN a fitting height that exceeds the presenting screen's visible-frame height minus the design-owned margin
- WHEN the panel is presented
- THEN the height is capped per NC-12 and the cards scroll instead of being clipped
