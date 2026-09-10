# network-card Specification

## Purpose

The Network detail card inside the popover: globe header, download and upload rate readings on the left, Total In / Total Out since boot on the right, and a dual-line history graph last, plus the panel's fourth-card placement and the visible-frame scroll cap that keeps four cards presentable. Serves PRD Draft v4 F11, section 5.8 (R11.7, R11.9, R11.10), R2.2, R2.3, 4.6, 6.1, 6.5, 7.1, 7.2, 7.3, PRD 10. Proposal conventions 1, 2, 9, 10, 14 apply; precedents MC-1, MC-7, MC-8, MC-10, DC-1, DC-7, DC-8, DC-9, DC-11. Reference image: `docs/reference/06-panel-network.png`.

Reference fixture (shared with `network-metrics`): `totalIn` 3 850 000 000, `totalOut` 2 760 000 000, `downloadBytesPerSecond` 5 000, `uploadBytesPerSecond` 78 000.

## Requirements

### Requirement: NC-1 Presentational contract and panel placement (Layer: Presentation) — PRD 6.1, R2.2, R11.7

`NetworkCard` MUST accept only a `NetworkSnapshot?` and the two network histories, and MUST NOT read `sysctl`, Mach, IOKit or any interface API. All derivations (sections, header symbol and title, rate texts, icons, accessibility labels, total rows, normalised graph series, animation) MUST live in a pure `nonisolated enum NetworkCardModel` that accepts an injected `Locale`. `PanelView` MUST render the Network card fourth, after the Disk card, inside the existing 12 pt-spaced stack at 320 pt width, bound to `MetricsState.network`, `networkDownloadHistory` and `networkUploadHistory`; `PanelView.cards` MUST equal `[.cpu, .memory, .disk, .network]`.

#### Scenario: Card renders from fixed inputs

- GIVEN the reference fixture and two histories
- WHEN `NetworkCard` is instantiated
- THEN it builds without any environment beyond the inputs

#### Scenario: Card order

- GIVEN the panel layout
- WHEN its cards are enumerated
- THEN the order is CPU, Memory, Disk, Network

#### Scenario: Live update while open

- GIVEN the panel is open
- WHEN `apply(network:)` publishes the reference fixture
- THEN the download reading reads `"5.0 kB/s"` under `en_US`

### Requirement: NC-2 Section order (Layer: Presentation) — 4.6, 7.3

`NetworkCardModel.sections` MUST equal `[.header, .ratesAndTotals, .graph]` and the view MUST render exactly those sections in that order, with the graph last. The card MUST NOT render a ring gauge or a stacked bar.

#### Scenario: Sections

- GIVEN any snapshot or `nil`
- WHEN `sections` is read
- THEN it equals `[.header, .ratesAndTotals, .graph]`

### Requirement: NC-3 Header (Layer: Presentation) — 4.6, 7.2

The header MUST show a globe SF Symbol whose name resolves via `NSImage(systemSymbolName:accessibilityDescription:)` and the title "Network" with the header accessibility trait, tinted `Palette.networkAccent`. The exact symbol name and any sublabel are design-owned and MUST be pinned by a Presentation test.

#### Scenario: Header symbol resolves

- GIVEN `NetworkCardModel.headerSymbolName`
- WHEN resolved through `NSImage(systemSymbolName:accessibilityDescription:)`
- THEN the image is non-nil

#### Scenario: Header title and tint

- GIVEN the card header
- WHEN inspected
- THEN the title is `"Network"` and the accent is `Palette.networkAccent`

### Requirement: NC-4 Rate readings (Layer: Presentation) — 4.6, R11.9, R11.10, DC-7

The left column MUST show the download reading then the upload reading, each a `ThroughputLabel` at 12 pt with an icon followed by the value text, formatted by `ByteFormatter.throughput` with the injected locale. The download and upload symbol names MUST differ and both MUST resolve via `NSImage(systemSymbolName:accessibilityDescription:)`. The readings MUST carry accessibility labels "Download" and "Upload". The download icon MUST use `Palette.networkDownload`; the upload icon MUST use `Palette.networkUpload`; the value text keeps the label's primary text colour, as in DC-7 and reference 4.6 (amended 2026-09-10 at the apply gate: the reused `ThroughputLabel` colours only its icon). Tests MUST normalise U+00A0/U+202F before comparing.

#### Scenario: Populated readings under en_US

- GIVEN the reference fixture
- WHEN the readings are derived under `en_US`
- THEN they are `"5.0 kB/s"` then `"78.0 kB/s"` with accessibility labels `"Download"` then `"Upload"`

#### Scenario: Readings under de_DE

- GIVEN the reference fixture
- WHEN the readings are derived under `de_DE`
- THEN they are `"5,0 kB/s"` then `"78,0 kB/s"`

#### Scenario: Distinct icons resolve

- GIVEN `NetworkCardModel.downloadSymbolName` and `uploadSymbolName`
- WHEN compared and resolved
- THEN they differ and both images are non-nil

### Requirement: NC-5 Total In / Total Out rows (Layer: Presentation) — 4.6, R11.3, DC-5

The right column MUST show rows `Total In` then `Total Out` in that order, each carrying the corresponding since-boot total formatted by `ByteFormatter.capacity` (decimal, base 1000) with the injected locale's decimal separator. `UInt64` totals MUST format without trapping. Tests MUST normalise U+00A0/U+202F before comparing.

#### Scenario: Two rows under en_US

- GIVEN the reference fixture
- WHEN the rows are derived under `en_US`
- THEN they are `Total In 3.85 GB` then `Total Out 2.76 GB` in that order

#### Scenario: Rows under de_DE

- GIVEN the reference fixture
- WHEN the rows are derived under `de_DE`
- THEN the values are `"3,85 GB"` and `"2,76 GB"`

#### Scenario: Extreme totals do not trap

- GIVEN `totalIn == 0` and `totalOut == UInt64.max`
- WHEN the rows are derived under `en_US`
- THEN the first value starts with `"0"` and the second formats without trapping

### Requirement: NC-6 Unavailable rates (Layer: Presentation) — R11.6, R11.10, DC-7

When both rates are `nil` on a non-`nil` snapshot, each reading MUST render an em dash (U+2014) with accessibility value "unavailable" while the icons, accessibility labels and both total rows MUST still render their real values. A reading MUST NOT render `"0 B/s"` in place of an unavailable rate.

#### Scenario: Rates unavailable, totals present

- GIVEN a snapshot with the reference totals and both rates `nil`
- WHEN the model is derived under `en_US`
- THEN both readings are `"—"` with accessibility value `"unavailable"`, and the rows still read `"3.85 GB"` and `"2.76 GB"`

### Requirement: NC-7 Nil-snapshot skeleton (Layer: Presentation) — R11.10, MC-8, DC-8

With `snapshot == nil` the card MUST render the full skeleton: header, both readings as em dashes, both total rows with em dash values, and an empty graph. The skeleton MUST occupy the same height as the populated card, so the panel's fitting height does not change when the first snapshot arrives. Design MAY add a distinct "Unavailable" caption without changing the height.

#### Scenario: Nil model

- GIVEN `snapshot == nil` and empty histories
- WHEN the model is derived under `en_US`
- THEN both reading texts are `"—"`, both row values are `"—"` and both graph series are empty

#### Scenario: Height is stable

- GIVEN a panel with CPU, memory and disk snapshots applied and `network == nil`
- WHEN the first network snapshot is applied
- THEN the panel's fitting height does not change

### Requirement: NC-8 Shared graph scale (Layer: Presentation) — R11.8, convention 14

`NetworkCardModel.graphSeries` MUST normalise both raw bytes-per-second histories by the SAME divisor, `max(maxDownload, maxUpload, floor)`, where `floor` is a design-owned constant of about 10 kB/s, so the two lines stay comparable and an idle link draws flat lines instead of amplified noise. Both returned series MUST have equal length and every value MUST fall in `0...1` after `SparklineGeometry` clamping. `MetricsState` MUST NOT perform this normalisation.

#### Scenario: Shared divisor keeps the ratio

- GIVEN download samples `[5 000]` and upload samples `[78 000]`
- WHEN `graphSeries` is derived
- THEN both series divide by 78 000, the upload value is 1.0 and the download value is `5 000 / 78 000`

#### Scenario: Floor flattens an idle link

- GIVEN download and upload samples all below 1 000 B/s
- WHEN `graphSeries` is derived
- THEN every normalised value is below 0.1 rather than near 1.0

#### Scenario: Values stay clamped

- GIVEN any histories, including one holding a single spike
- WHEN the series reach `SparklineGeometry`
- THEN every value is within `0...1` and the two series have equal length

### Requirement: NC-9 Multi-series history graph (Layer: Presentation) — R11.8, R5.2, MC-7

`HistoryGraph` MUST gain a `series:capacity:` initialiser that draws N line paths over one shared baseline in a single `Canvas`, each series carrying its own Presentation colour token, tolerating fewer than `capacity` samples including zero. The existing `init(samples:capacity:color:)` MUST remain as a convenience so the CPU and Memory call sites are unchanged, and `Equatable` conformance MUST be preserved. The Network card MUST pass exactly two series — download in `Palette.networkDownload` and upload in `Palette.networkUpload` — as its last section at full card width. Series colours MUST be Presentation tokens; the graph MUST NOT receive a unit.

#### Scenario: Two series equal two single-series geometries

- GIVEN two sample arrays of equal length
- WHEN the multi-series graph's geometry is compared with two single-series geometries built from the same arrays and capacity
- THEN the point sets are equal

#### Scenario: Existing call sites unchanged

- GIVEN `CPUCard` and `MemoryCard`
- WHEN their `HistoryGraph` usage is inspected
- THEN they still use `init(samples:capacity:color:)` and render one series

#### Scenario: Fewer samples and empty series

- GIVEN a series with 7 samples and a second series with 0 samples, capacity 120
- WHEN the graph renders
- THEN it renders at full width without trapping

#### Scenario: Equatable redraw skip

- GIVEN two multi-series graphs built from identical series and capacity
- WHEN they are compared
- THEN they are equal

### Requirement: NC-10 Palette tokens and card chrome (Layer: Presentation) — 7.1, R2.3

`Palette` MUST expose `networkAccent` (a distinct header accent sampled from the reference image and pinned by the palette test), `networkDownload == sRGB(0x3DD68C)` (the same value as `memFree` and `diskAccent`) and `networkUpload == sRGB(0x4D8DFF)` (the same value as `cpuAccent`); token tests MUST NOT assert pairwise distinctness. The card MUST use `cardBackground`, `cardCornerRadius`, padding 16, section spacing 14 and row spacing 6, identical to the other cards.

#### Scenario: Token values

- GIVEN `Palette`
- WHEN the network tokens are read
- THEN `networkDownload` equals `memFree` and `diskAccent`, `networkUpload` equals `cpuAccent`, and `networkAccent` equals the value pinned by the test

#### Scenario: Chrome parity

- GIVEN `NetworkCard`'s layout constants
- WHEN compared with `DiskCard`'s
- THEN padding, section spacing, row spacing and corner radius are equal

### Requirement: NC-11 Four-card panel height (Layer: Presentation) — R2.2, PRD 10

`PanelView`'s fitting height MUST be at least the sum of the CPU, Memory, Disk and Network card heights plus chrome and the 12 pt gaps, and MUST exceed the three-card height. Existing lower-bound height assertions MUST stay green.

#### Scenario: Four-card height

- GIVEN a panel with CPU, memory, disk and network snapshots applied
- WHEN its fitting height is measured
- THEN it is `>= cpu + memory + disk + network + chrome` and exceeds the three-card height

### Requirement: NC-12 Visible-frame scroll cap (Layer: Presentation) — PRD 10, R2.2

A pure `nonisolated` rule `PanelLayout.height(fitting:visibleFrameHeight:)` MUST cap the panel: when the fitting height exceeds the presenting screen's `visibleFrame` height minus a design-owned margin, the rule MUST return that capped height and the cards MUST be presented inside a `ScrollView` reaching the Network card; otherwise the rule MUST return the fitting height unchanged and the layout MUST stay identical to the three-card panel with no scroll view behaviour observable. Whether the cap is applied by `PanelView` (injected max height) or at popover configuration time is design-owned; the rule MUST be unit-tested either way. Content MUST NOT be clipped.

#### Scenario: Taller than the visible frame

- GIVEN a fitting height of 1 050 pt and a visible-frame height of 945 pt
- WHEN the rule is evaluated
- THEN the returned height is `<= 945 pt` minus the margin and the cards scroll

#### Scenario: Shorter than the visible frame

- GIVEN a fitting height of 871 pt and a visible-frame height of 1 132 pt
- WHEN the rule is evaluated
- THEN the returned height equals 871 pt unchanged

#### Scenario: Exactly at the cap

- GIVEN a fitting height equal to the visible-frame height minus the margin
- WHEN the rule is evaluated
- THEN the returned height equals the fitting height and no cap is applied

### Requirement: NC-13 Reduce motion (Layer: Presentation) — PRD 6.5, MC-10, DC-10

Any animated element of the Network card MUST take its animation from `NetworkCardModel.animation(reduceMotion:)`, which MUST delegate to `CPUCardModel.gaugeAnimation`: `nil` when reduce motion is on and the CPU card's animation otherwise; the view MUST apply exactly that result.

#### Scenario: Reduce motion

- GIVEN `reduceMotion == true`
- WHEN the animation is evaluated
- THEN the result is `nil`

#### Scenario: Motion allowed

- GIVEN `reduceMotion == false`
- WHEN the animation is evaluated
- THEN the result is non-nil and equals `CPUCardModel.gaugeAnimation(reduceMotion: false)`
