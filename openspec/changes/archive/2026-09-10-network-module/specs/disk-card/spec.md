# Delta for disk-card

Purpose unchanged. This delta adjusts the two `disk-card` requirements that the fourth card invalidates: DC-1's card-order scenario now ends with Network, and DC-11's panel height becomes the four-card sum while the "no fixed content size" clause is replaced by the visible-frame cap owned by `network-card` (NC-12). DC-2..DC-10 hold unchanged. Non-destructive: every existing scenario is retained except the two whose text is superseded.

## MODIFIED Requirements

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

## Verification notes

- `PanelViewTests` (Presentation, existing file): the card-order scenario becomes four cards and the height assertions gain the four-card lower bound; the three-card lower bound stays as is.
- The visible-frame cap itself is specified and tested under `network-card` NC-12; this delta only records that DC-11 no longer claims an unbounded popover.
