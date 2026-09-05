# Apply Progress: memory-module

**Mode**: Strict TDD (`strict_tdd: true`, runner available)
**Artifact store**: hybrid (this file + Engram `sdd/memory-module/apply-progress`, id 8226). This file is the single complete document; the Engram mirror is split in two because one observation is capped at 50 000 characters — 8226 holds batches A–C and batch D lives in `sdd/memory-module/apply-progress-batch-d` (id 8230).
**Delivery**: single-pr, `size:exception` accepted by the user (review budget unlimited)
**Batch A work unit**: `apply-phases-1-3-domain-application-infrastructure` (tasks 1.1 – 3.3)
**Baseline before batch A**: 188 tests passing, 0 failing (`exit=0`)
**After batch A**: 249 tests passing, 0 failing (`exit=0`); `build` exit 0, zero compiler warnings

`TEST` = `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`

## TDD Cycle Evidence — batch A (tasks 1.1 – 3.3, 6.3)

| Task | Test file | Layer | Safety net | RED evidence (verbatim first line) | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| 1.1 RED / 1.2 GREEN | `system-monitorTests/Domain/MemorySnapshotTests.swift` | Unit | 188/188 | `exit=65` — `MemorySnapshotTests.swift:21:10: error: cannot find type 'MemorySnapshot' in scope` (+ 4 more, `MemoryPageCounts` missing) | `exit=0`, 200 passing | 12 cases: fraction, zero total, clamp at 1, equality, `unattributedUsed` remainder / covered / saturating | Not needed — new files written clean |
| 1.3 RED / 1.4 GREEN | `system-monitorTests/Domain/MemoryUsageCalculatorTests.swift`, `Support/MemoryFixtures.swift` | Unit | N/A (new) | `exit=65` — `MemoryFixtures.swift:137:9: error: cannot find 'MemoryUsageCalculator' in scope` | `exit=0`, 215 passing | Parameterized over `reference` + `eightGiB` (4 assertions × 2) plus 6 saturation/edge cases | Saturating helpers extracted to three private functions (`subtracting`, `adding`, `bytes`) |
| 1.5 RED + GREEN | `system-monitorTests/Domain/MemoryMetricsProviderPortTests.swift`, `Support/FakeMemoryProvider.swift` | Unit | 215/215 | `exit=65` — `MemoryMetricsProviderPortTests.swift:10:24: error: cannot find 'FakeMemoryProvider' in scope` (9 sites) | `exit=0`, 222 passing | 7 cases: order, exhaustion, throw at index 0, throw mid-script, thread recording, empty script, use through the port | Fake mirrors `FakeCPUProvider` exactly |
| 2.1 RED / 2.2 GREEN | `system-monitorTests/Application/MetricsStateTests.swift` | Unit | 222/222 | `exit=65` — `MetricsStateTests.swift:94:29: error: value of type 'MetricsState' has no member 'memory'` (16 errors) | `exit=0`, 228 passing | 7 cases: fresh state, store+append, replace+extend, 130→120 bound, CPU untouched, memory untouched by CPU, injected capacity | Doc comment rewritten for the two independent metric pairs |
| 2.3 RED / 2.4 GREEN | `system-monitorTests/Application/MetricsSamplerTests.swift` | Unit | 228/228 | `exit=65` — `MetricsSamplerTests.swift:148:20: error: cannot find 'MemorySamplingStep' in scope`; `:27:29: error: extra argument 'memoryProvider' in call` | `exit=0`, 242 passing (verified together with 3.2, see deviation D1) | 8 cases: step reads/derives, step nil on throw, MM-5 first & second step, MM-6 3/3 call counts, MM-7 throw-twice-recovers, always-throws, CPU-throws-memory-publishes | `sampleOnce()` mirrors the loop body ordering |
| 2.5 RED / 2.6 GREEN | `system-monitorTests/Application/MetricsSamplerTests.swift` (`everyReadHappensOffTheMainThread`) | Unit (loop) | 242/242 | `exit=65`, `failed=1` — `Test case 'MetricsSamplerLoopTests/everyReadHappensOffTheMainThread()' failed` (real assertion failure: memory `readOnMainThread` was empty because the loop did not read memory yet) | `exit=0`, 242 passing | Existing CPU assertions retained; memory assertions added to the same test (no new wall-clock test) | Loop comment updated to state both reads precede both publishes |
| 3.1 RED / 3.2 GREEN | `system-monitorTests/Infrastructure/MachMemoryProviderTests.swift` | Unit (no Mach call) | 228/228 | `exit=65` — `AppDelegate.swift:19:29: error: cannot find 'MachMemoryProvider' in scope` (app target fails first, so the test-target errors for `requiredFieldCount`/`validate` were masked in the same run) | `exit=0`, 242 passing | 6 cases: offset formula, ≤ full count, accepts required count, accepts full count, rejects required−1, rejects 0 | `fullFieldCount` extracted as a private static so `readCounts()` and the test share one definition |
| 3.3 | `system-monitorTests/Infrastructure/MachMemoryIntegrationTests.swift` | Integration (`.integration`) | 242/242 | N/A — verification suite over the already-green adapter | `exit=0`, 249 passing | 6 cases: total/physicalMemory/`hw.memsize`, page size ∈ {4096, 16384}, free > 0, every component ≤ total, app+wired+compressed ≤ used ≤ total with fraction ∈ 0…1, repeated reads agree | None needed |

## Work Unit Evidence — batch A

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` → `exit=0`, `passed=249`, `failed=0` |
| Runtime harness command/scenario and exact result | `.integration` suite `MachMemoryIntegrationTests` runs the real `host_statistics64` inside the sandboxed test host within the same `TEST` run — 6/6 passing on Apple M4 Pro. Build check: `xcodebuild … -quiet build` → exit 0, zero compiler warnings |
| Rollback boundary | Delete `system-monitor/Domain/{Models/MemoryPageCounts.swift,Models/MemorySnapshot.swift,Ports/MemoryMetricsProvider.swift,Services/MemoryUsageCalculator.swift}`, `system-monitor/Infrastructure/Mach/MachMemoryProvider.swift`, `system-monitorTests/Support/{MemoryFixtures,FakeMemoryProvider}.swift`, `system-monitorTests/Domain/Memory*Tests.swift`, `system-monitorTests/Infrastructure/MachMemory*Tests.swift`; revert `MetricsState.swift`, `MetricsSampler.swift`, `AppDelegate.swift`, `MetricsStateTests.swift`, `MetricsSamplerTests.swift` to `60cca91`. Presentation, PRD and specs are untouched. |

## Completed Tasks — batch A

- [x] 1.1 RED `MemorySnapshotTests.swift`
- [x] 1.2 GREEN `MemoryPageCounts.swift`, `MemorySnapshot.swift`, `MemoryMetricsProvider.swift`
- [x] 1.3 RED `MemoryUsageCalculatorTests.swift` + `MemoryFixtures.swift`
- [x] 1.4 GREEN `MemoryUsageCalculator.swift`
- [x] 1.5 RED + GREEN `MemoryMetricsProviderPortTests.swift` + `FakeMemoryProvider.swift`
- [x] 2.1 RED `MetricsStateTests.swift` memory scenarios
- [x] 2.2 GREEN `MetricsState.memory`, `memoryHistory`, `apply(memory:)`
- [x] 2.3 RED `MetricsSamplerTests.swift` MM-5/MM-6/MM-7
- [x] 2.4 GREEN `MemorySamplingStep`, required `memoryProvider`, `sampleOnce()`
- [x] 2.5 RED memory assertions inside `everyReadHappensOffTheMainThread`
- [x] 2.6 GREEN memory read inside the detached `.utility` loop
- [x] 3.1 RED `MachMemoryProviderTests.swift`
- [x] 3.2 GREEN `MachMemoryProvider.swift`
- [x] 3.3 `MachMemoryIntegrationTests.swift` (`.integration`)
- [x] 6.3 `AppDelegate` injects `MachMemoryProvider()` — pulled forward, see deviation D1

## Files Changed — batch A

| File | Action | Lines |
|---|---|---|
| `system-monitor/Domain/Models/MemoryPageCounts.swift` | Create | 38 |
| `system-monitor/Domain/Models/MemorySnapshot.swift` | Create | 53 |
| `system-monitor/Domain/Ports/MemoryMetricsProvider.swift` | Create | 10 |
| `system-monitor/Domain/Services/MemoryUsageCalculator.swift` | Create | 59 |
| `system-monitor/Infrastructure/Mach/MachMemoryProvider.swift` | Create | 102 |
| `system-monitor/Application/MetricsState.swift` | Modify | +24 / −7 |
| `system-monitor/Application/MetricsSampler.swift` | Modify | +66 / −9 |
| `system-monitor/App/AppDelegate.swift` | Modify | +1 |
| `system-monitorTests/Support/MemoryFixtures.swift` | Create | 139 |
| `system-monitorTests/Support/FakeMemoryProvider.swift` | Create | 62 |
| `system-monitorTests/Domain/MemorySnapshotTests.swift` | Create | 189 |
| `system-monitorTests/Domain/MemoryUsageCalculatorTests.swift` | Create | 163 |
| `system-monitorTests/Domain/MemoryMetricsProviderPortTests.swift` | Create | 96 |
| `system-monitorTests/Infrastructure/MachMemoryProviderTests.swift` | Create | 58 |
| `system-monitorTests/Infrastructure/MachMemoryIntegrationTests.swift` | Create | 67 |
| `system-monitorTests/Application/MetricsStateTests.swift` | Modify | +94 |
| `system-monitorTests/Application/MetricsSamplerTests.swift` | Modify | +152 / −7 |

Changed-lines estimate for batch A: **~1 373** (`git diff --stat`: 321 insertions / 16 deletions across 5 tracked files, plus 1 036 lines in 12 new files). `project.pbxproj` untouched — new files join the targets through `PBXFileSystemSynchronizedRootGroup`.

## Decisions and Deviations — batch A

- **D1 — task 6.3 pulled forward into batch A (forced).** Design decision 5 makes `memoryProvider` a required `MetricsSampler` init parameter with no default. The moment task 2.4 landed, `AppDelegate.swift:18` stopped compiling, and with a broken app target no test can run at all. The one-line composition-root injection (`memoryProvider: MachMemoryProvider()`) was therefore added as soon as `MachMemoryProvider` existed, which is exactly task 6.3's content. It is marked `[x]`; batch 3 must not re-add it. Consequence for TDD evidence: the 3.1 RED run reports the app-target error first, so the test-target errors for the missing `requiredFieldCount`/`validate` members were masked in that same run. The RED ordering itself is intact — `MachMemoryProviderTests.swift` was written and run before a single line of `MachMemoryProvider.swift` existed.
- **D2 — typed throws compiled cleanly.** `nonisolated static func validate(returnedCount:) throws(ReadError)` builds without warnings in the `nonisolated static` context; convention 9's untyped-`throws` fallback was **not** needed.
- **D3 — one extra RED assertion in task 1.1.** `MemoryPageCounts` is created by GREEN 1.2 but the task text only names `MemorySnapshot` scenarios. Two `MemoryPageCounts` cases (memberwise init exposes all nine fields; one differing counter breaks equality) were added to `MemorySnapshotTests` so no production type in 1.2 is written without a failing test first.
- **D4 — `MemoryFixtures.overflowingCounts` refined.** The design sketch said "`UInt64.max` counts → every byte field saturates". With every field at `.max`, `app` and `free` would come out as `0` (`max − max`), so the fixture uses `purgeableCount = .max / 2` and `speculativeCount = .max / 4`. That makes all three saturation paths fire for real (subtraction floor, addition ceiling, multiplication ceiling) and the assertion honest: `app`/`wired`/`compressed`/`cached`/`free` all reach `UInt64.max` while `used` floors at `0`.
- **D5 — `speculativeExceedsFree` uses the design's numbers.** Spec MM-2 writes "free 5, speculative 9"; design rev 2's fixture writes "free 10, speculative 20". The design fixture is normative for fixture values and the assertion (`free == 0`) is identical.
- **D6 — `unattributedUsed` overflow guard.** `app + wired + compressed` can overflow `UInt64` on hand-built snapshots, so it is summed with `addingReportingOverflow`; on overflow the attributed total already exceeds `used`, so the remainder is `0`. No new shared arithmetic type was introduced.
- **D7 — extra `MemorySamplingStep` unit tests.** Task 2.3 only names sampler scenarios, but design decision 7 makes the step a first-class type, so two direct tests (`read()` derives the snapshot; `read()` is `nil` on a throw) were added to give it its own RED.
- **No design deviations otherwise.** Every signature matches design rev 2 verbatim: `MemoryPageCounts` field names and order, `MemorySnapshot` stored `used` with computed `fraction`/`unattributedUsed`, the `MemoryMetricsProvider` port, the saturating calculator, `MemorySamplingStep`, `MetricsState.apply(memory:)`, `MachMemoryProvider.ReadError`/`requiredFieldCount`/`validate(returnedCount:)`, and the `FakeMemoryProvider` `Mutex<Script>` shape.

## Convention Compliance — batch A

1. Every new Domain, Infrastructure, fixture and double type — and every nested type (`ReadError`, `Script`, `ScriptedError`) — is explicitly `nonisolated` and `Sendable`. Only `MetricsState` and `MetricsSampler` remain main-actor.
2. No test suite is `@MainActor`; they `await` main-actor members. The two `makeSampler` helpers stay `@MainActor` functions.
3. The loop is still `Task.detached(priority: .utility)`; `memoryProvider` is captured as a local `let` before the closure, no `self` capture.
4. `FakeMemoryProvider` uses `Synchronization.Mutex` with no `@unchecked Sendable`; `throwOnCall` is zero-based and each call records `Thread.isMainThread`.
5. Only `.timeLimit(.minutes(1))` is used (unchanged, on the pre-existing loop suite).
6. `project.pbxproj` untouched.
7. `host_statistics64` fills a caller-owned `vm_statistics64_data_t`; no `vm_deallocate`. Count computed from `MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride`, validated through the static seam. Page size from `host_page_size(host, &size)`. `vm_kernel_page_size` / `vm_page_size` are never referenced in code (a doc comment names them to record why). Total from `ProcessInfo.processInfo.physicalMemory`.
8. The adapter widens each `natural_t` with `UInt64(_:)` before it reaches the calculator; the calculator subtracts with a floor at 0 and adds/multiplies with a ceiling at `UInt64.max`; `uint32MaxWired` asserts `wired == 70_368_744_161_280` exactly and `!= UInt64.max`; `fraction` is 0 when `total == 0` and clamps at 1.
9. Zero build warnings (`xcodebuild … build` → exit 0, no `warning:` lines from the compiler).
10. No new wall-clock tests. MM-8 lives only inside the existing `everyReadHappensOffTheMainThread`. Both `makeSampler` helpers gained the defaulted `memoryProvider`, so no existing test body changed.
11. Presentation, `PRD.md` and the specs are untouched.

## Test Counts — batch A

| Point | Passing | Failing |
|---|---|---|
| Baseline (pre-batch) | 188 | 0 |
| After 1.2 | 200 | 0 |
| After 1.4 | 215 | 0 |
| After 1.5 | 222 | 0 |
| After 2.2 | 228 | 0 |
| After 2.4 + 3.2 | 242 | 0 |
| After 2.6 | 242 | 0 |
| After 3.3 (batch A final) | **249** | **0** |

61 tests added; all 188 pre-existing tests still pass.

Count correction (batch A validator): the batch A table was off by one from step 1.5 onward. `xcodebuild` occasionally interleaves a timestamped log line into a `Test case '…' passed on` line, which drops that line from a `rg` count; the endpoints above are the authoritative numbers (222 after 1.5, 249 after 3.3). The intermediate rows may still under-count by one for the same reason.

## Open Items Carried Forward — batch A

- Design open question on the exact ICU zero string for `ByteFormatter.memory(0)` is still open — it is pinned at task 4.3's RED, in the next batch.
- The `hw.memsize_usable` fallback (design decision 3) was not needed for the automated assertions: `totalBytes == ProcessInfo.processInfo.physicalMemory == UInt64(hw.memsize)` holds on this host. The manual Activity Monitor comparison remains task 7.3.

---

# Batch B — `apply-phases-4-5-presentation-primitives-and-card` (tasks 4.1 – 5.3)

**Baseline before batch B**: 249 tests passing, 0 failing (`exit=0`)
**After batch B**: 288 tests passing, 0 failing (`exit=0`); `build` exit 0, zero compiler warnings
**Attempt token**: `sha256:c503676a0a331e8caa21ae0ccb01979e1f628f52bfc36ee89e732b444040aa3a`

## TDD Cycle Evidence — batch B

| Task | Test file | Layer | Safety net | RED evidence (verbatim first line) | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| 4.1 RED / 4.2 GREEN | `system-monitorTests/Presentation/StatusItemReadingsTests.swift` (`PaletteTests`) | Unit | 249/249 | `exit=65` — `StatusItemReadingsTests.swift:56:25: error: type 'Palette' has no member 'memWired'` (+ `memCompressed`, `memCached`, `memFree`) | `exit=0`, 250 passing | One case asserting all five token values; pairwise distinctness deliberately **not** asserted (`memCached == cpuAccent`) | Not needed |
| 4.3 RED / 4.4 GREEN | `system-monitorTests/Presentation/ByteFormatterTests.swift` | Unit | N/A (new) | `exit=65` — `ByteFormatterTests.swift:28:20: error: cannot find 'ByteFormatter' in scope` (5 sites) | First GREEN `exit=65`, 259 passing / 1 failing (`valuesAboveTheSignedRangeClampInsteadOfTrapping` — the pinned ICU string was wrong, see D8); after re-pinning `exit=0`, 260 passing | 10 cases: four GB values, de_DE comma, three exact multiples, zero, `UInt64.max` clamp | Not needed |
| 4.5 RED / 4.6 GREEN | `system-monitorTests/Presentation/StackedBarGeometryTests.swift` | Unit | N/A (new) | `exit=65` — `StackedBarGeometryTests.swift:13:21: error: cannot find 'StackedBarGeometry' in scope` (8 sites) | `exit=0`, 269 passing | 9 cases: cumulative rects, clamp at width, zero fraction, NaN, negative fraction, empty list, three degenerate sizes | Not needed — one pure `map` with a running offset |
| 4.7 RED / 4.8 GREEN | `system-monitorTests/Presentation/MemoryCardModelTests.swift` | Unit | N/A (new) | `exit=65` — `MemoryCardModelTests.swift:43:47: error: cannot find 'MemoryCardModel' in scope` (24 sites) | `exit=0`, 285 passing | 16 cases: three gauge fractions, de_DE gauge, gauge fraction, four rows, locale rows, six segments (kind/colour/bytes/sum), fraction sum + accent width, components-exceed-used, nil + zero-total bar, colour map, legend, section order, graph 120/3/0, nil placeholder | Not needed — `legend` is built from `color(for:)` so the token order exists once |
| 5.1 RED / 5.2 GREEN | `system-monitorTests/Presentation/PanelViewTests.swift` | Unit (`NSHostingView.fittingSize`) | 285/285 | `exit=65` — `PanelViewTests.swift:55:24: error: cannot find 'MemoryCard' in scope` | 5.2 → `exit=65`, 286 passing / **2 failing**: the view now compiles but `PanelView` still renders the placeholder | Card height, panel composition and gauge text asserted separately | Not needed |
| 5.3 GREEN | `system-monitorTests/Presentation/PanelViewTests.swift` | Unit (`NSHostingView.fittingSize`) | 286/288 | Assertion RED (not a compile error): `Test case 'PanelViewTests/thePanelStacksTheFullMemoryCardUnderTheCPUCard()' failed` and `Test case 'PanelViewTests/publishingAMemorySnapshotGrowsThePanel()' failed` | `exit=0`, 288 passing | 3 cases: panel composition + pinned bound, first-snapshot layout stability, live gauge text | One assertion rewritten against the spec, see D9 |

## Work Unit Evidence — batch B

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` → `exit=0`, `passed=288`, `failed=0`. Focused runs during the cycle: `xcodebuild … test -only-testing:system-monitorTests/ByteFormatterTests` and `…/PanelViewTests`, both `exit=0`. Final tail lines: `MetricsSamplerLoopTests/everyReadHappensOffTheMainThread() passed`, `…/theInjectedIntervalKeepsTheLoopPublishing() passed`, `…/startIsIdempotentSoStopHaltsEveryIteration() passed`, `…/stopFreezesThePublishedCount() passed` |
| Runtime harness command/scenario and exact result | Presentation-only unit: no new I/O boundary. Rendering is exercised through `NSHostingView` measurement inside `TEST` (`PanelViewTests` measured panel 678 pt = CPU 370 + memory 272 + 36 chrome) and through four new Xcode `#Preview`s (`StackedBar`, `SegmentLegend`, `MemoryCard` 8 GiB, `MemoryCard` nil) plus the updated live `PanelView` preview. Build check: `xcodebuild … -quiet build` → `exit 0`, zero `warning:` lines |
| Rollback boundary | Delete `system-monitor/Presentation/{Formatting/ByteFormatter.swift,Components/StackedBar.swift,Components/SegmentLegend.swift,Panel/MemoryCard.swift}` and `system-monitorTests/Presentation/{ByteFormatterTests,StackedBarGeometryTests,MemoryCardModelTests}.swift`; revert `Presentation/Theme/Palette.swift`, `Presentation/Panel/PanelView.swift` (restores `PlaceholderCard`), `system-monitorTests/Presentation/{PanelViewTests,StatusItemReadingsTests}.swift`. Domain, Application, Infrastructure, MenuBar, `AppDelegate`, `PRD.md` and the specs are untouched by this batch. |

## Completed Tasks — batch B

- [x] 4.1 RED `PaletteTests` memory tokens (MC-9)
- [x] 4.2 GREEN `Palette.memWired/memCompressed/memCached/memFree`
- [x] 4.3 RED `ByteFormatterTests.swift` (MC-2)
- [x] 4.4 GREEN `ByteFormatter.memory(_:locale:)`
- [x] 4.5 RED `StackedBarGeometryTests.swift` (MC-5 geometry)
- [x] 4.6 GREEN `StackedBar.swift` + `SegmentLegend.swift`
- [x] 4.7 RED `MemoryCardModelTests.swift` (MC-3 – MC-8)
- [x] 4.8 GREEN the model half of `MemoryCard.swift`
- [x] 5.1 RED `PanelViewTests.swift` memory scenarios (MC-1)
- [x] 5.2 GREEN the view half of `MemoryCard.swift`
- [x] 5.3 GREEN `PanelView` renders `MemoryCard`; `PlaceholderCard` deleted

## Files Changed — batch B

| File | Action | Lines |
|---|---|---|
| `system-monitor/Presentation/Formatting/ByteFormatter.swift` | Create | 28 |
| `system-monitor/Presentation/Components/StackedBar.swift` | Create | 88 |
| `system-monitor/Presentation/Components/SegmentLegend.swift` | Create | 54 |
| `system-monitor/Presentation/Panel/MemoryCard.swift` | Create | 271 |
| `system-monitor/Presentation/Theme/Palette.swift` | Modify | +15 / −2 |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modify | +14 / −26 |
| `system-monitorTests/Presentation/ByteFormatterTests.swift` | Create | 70 |
| `system-monitorTests/Presentation/StackedBarGeometryTests.swift` | Create | 73 |
| `system-monitorTests/Presentation/MemoryCardModelTests.swift` | Create | 245 |
| `system-monitorTests/Presentation/PanelViewTests.swift` | Modify | +72 / −0 |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Modify | +13 / −0 |

Changed-lines for batch B: **~971** (829 lines in 7 new files plus 114 insertions / 28 deletions across 4 tracked files). `project.pbxproj` untouched — the new files join the targets through `PBXFileSystemSynchronizedRootGroup`. Cumulative for the change so far: ~2 344 lines, inside the accepted `size:exception`.

## Decisions and Deviations — batch B

- **D8 — ICU strings pinned from the runner, not from the design sketch.** Under `en_US` the style prints `"5.52 GB"`, `"8 GB"` and `"0 bytes"` with a plain U+0020; under `de_DE` `"5,52\u{00A0}GB"` (U+00A0) and `"0 Byte"`; under `fr_FR` `"5,52\u{202F}Go"` (U+202F). Design decision 12's open question is therefore closed: the en_US zero string is **`"0 bytes"`**. The one wrong pin was `UInt64.max`: `.memory` with `allowedUnits: .all` stops at petabytes, so `Int64.max` prints `"8,192 PB"`, not `"8 EB"`. The test expectation was corrected (the spec only requires "formats without trapping"); the production code was not touched to make it pass. Every string comparison maps U+00A0 and U+202F to U+0020 first, per convention 9.
- **D9 — "the panel grows with the memory card" is a composition assertion, not a growth-on-publish assertion.** The first draft of MC-1 asserted that publishing a memory snapshot increases the panel height. That is false by design: MC-8 requires the card to render its full skeleton (header, gauge, four zero rows, empty bar, legend, empty graph) before the first reading, so the card is a fixed 272 pt and the first snapshot fills it rather than resizing the popover. The assertion was replaced by two honest ones: (1) `panel.height >= cpuCardHeight + memoryCardHeight + chrome` with the pinned lower bound `> 620` (measured 678 = 370 + 272 + 36) — a placeholder in the memory slot fails both, as the 5.2 run proved; (2) the panel size is unchanged by the first snapshot while `gaugeText` moves from `"0.0%"` to `"69.0%"`, which is MC-8's observable consequence.
- **D10 — the stacked-bar track is always filled, not only when the bar is empty.** The design sketch says "track in `Palette.textSecondary.opacity(0.18)` when empty". `Canvas` fills the track first and draws the segments over it, so an empty bar shows only the track and a full bar hides it completely. Same rendering, one code path, no `isEmpty` branch that a test could not observe.
- **D11 — `MemoryCardSection` conforms to `Identifiable` with `var id: Self`.** The design text already asks for "`Identifiable` via `self` for the `ForEach`"; it is spelled out here because the signature block did not list the conformance.
- **D12 — `MemoryCardModel.legend` is built through `color(for:)`.** The palette order then exists in exactly one place, so a token swap cannot desynchronise the bar and its legend. The test still asserts the literal `Palette` tokens, so the mapping itself remains pinned.
- **D13 — `MemoryCard` uses `KeyValueRow`'s default value colour.** `MemoryCardRow` carries no `valueColor` (design), unlike `CPUCardRow`; every memory value is `Palette.textPrimary`.
- **No other design deviations.** `Palette` tokens, `ByteFormatter`, `StackedBarGeometry`/`StackedBar`/`Segment`, `LegendEntry`/`SegmentLegend`, `MemoryCardRow`, `MemorySegmentKind`, `MemorySegment`, `MemoryCardSection`, `MemoryCardModel` (`graphCapacity`, `sections`, `rows`, `gaugeText`, `gaugeFraction`, `segments`, `legend`, `color(for:)`, `graphSamples`) and `MemoryCard(snapshot:history:)` match design rev 2 verbatim.

## Convention Compliance — batch B

1. `ByteFormatter`, `StackedBarGeometry`, `LegendEntry`, `StackedBar.Segment`, `MemoryCardRow`, `MemorySegmentKind`, `MemorySegment`, `MemoryCardSection` and `MemoryCardModel` are all explicitly `nonisolated` (plus `Sendable`/`Equatable`/`Hashable`/`CaseIterable`/`Identifiable` where the design says). `StackedBar`, `SegmentLegend`, `MemoryCard` and `PanelView` stay main-actor views.
2. No test suite is `@MainActor`. `PanelViewTests` keeps its existing shape: `@MainActor` static helpers (`fittingSize(for:)`, `cardHeight(_:)`, `cardHeights(for:)`) awaited from nonisolated tests.
3. `project.pbxproj` untouched; the four new production files and three new test files joined their targets automatically.
4. Locale strings pinned from the runner under `en_US` and `de_DE`, with U+00A0/U+202F normalised before comparison; percentages go through `PercentFormatter`, which stays free of non-breaking spaces.
5. Zero build warnings (`xcodebuild … build` → `exit 0`, no `warning:` lines). `StackedBar`, `RingGauge` and `HistoryGraph` children are used with `.equatable()` exactly as `CPUCard` does.
6. `accessibilityReduceMotion` gates the gauge animation with the same `reduceMotion ? nil : Self.gaugeAnimation` mechanism as `CPUCard`, keyed on `snapshot?.fraction`.
7. The pre-existing panel heuristic (`height > 260`) is unchanged; the new memory assertion adds a tolerance-free lower bound of 620 pt against a measured 678 pt.
8. Domain, Application, Infrastructure, MenuBar, `AppDelegate`, `PRD.md` and the specs were not touched in this batch.

## Test Counts — batch B

| Point | Passing | Failing |
|---|---|---|
| Baseline (after batch A) | 249 | 0 |
| After 4.2 | 250 | 0 |
| After 4.4 | 260 | 0 |
| After 4.6 | 269 | 0 |
| After 4.8 | 285 | 0 |
| After 5.2 | 286 | 2 |
| After 5.3 (batch B final) | **288** | **0** |

39 tests added in batch B; all 249 tests from the baseline still pass.

## Open Items Carried Forward — batch B

- Design decision 12's open question is now closed: `ByteFormatter.memory(0, locale: en_US) == "0 bytes"` (see D8). `de_DE` renders `"0 Byte"`, which no assertion depends on.
- `StatusItemReadingsTests.theMemoryModuleStaysAPlaceholder` still asserts the old MEM placeholder behaviour. Task 6.1 deletes it; until then the MEM widget legitimately still reads `"0%"` with no samples.
- Manual verification (task 7.3) and the `PRD.md` amendment (task 7.1) remain open.

## Next Batch

Start at **task 6.1** (Phase 6: menu bar readings for MEM, then 6.2; 6.3 is already done). Tasks 6.1, 6.2, 7.1, 7.2 and 7.3 remain.

---

# Batch C — `apply-phases-6-7-menubar-composition-docs` (tasks 6.1, 6.2, 7.1, 7.2, 7.3)

**Baseline before batch C**: 288 tests passing, 0 failing (`exit=0`)
**After batch C**: 294 tests passing, 0 failing (`exit=0`); `build` exit 0, zero compiler warnings
**Attempt token**: `sha256:6814d6adaabfefef1e9b6a7874b801ea09218406ca4b510cc0bb8abdde438ffb`
**Scope note**: task 6.3 was already delivered in batch A (deviation D1) and was not touched again.

## TDD Cycle Evidence — batch C

| Task | Test file | Layer | Safety net | RED evidence (verbatim first line) | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| 6.1 RED / 6.2 GREEN | `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Unit + `NSHostingView` measurement | 288/288 (`exit=0`) | `exit=65` — `StatusItemReadingsTests.swift:126:33: error: extra arguments at positions #1, #2, #3, #4 in call`; same site `error: missing arguments for parameters 'snapshot', 'history' in call` (the symmetric `build(cpu:cpuHistory:memory:memoryHistory:)` did not exist yet) | `exit=0`, 294 passing, 0 failing | 7 cases: MEM `"59%"` from fraction 0.59, MEM `"0%"` + empty samples before the first snapshot, newest 60 of 120, MEM accent on the reading, both modules follow their own pair, MEM live 30-sample sparkline with reserved width, MEM empty history keeps its sparkline + full-scale width under 230 pt | Not needed — the switch stays two symmetric arms |
| 7.1 | `PRD.md` | Documentation (MM-10) | N/A — no behaviour change | N/A — documentation task, no test seam. The behaviour it documents was driven RED-first in batch A (`MemoryUsageCalculatorTests`, `MachMemoryProviderTests`) | `TEST` still `exit=0`, 294 passing | N/A | N/A |
| 7.2 | whole suite | Unit + `.integration` | 294/294 | N/A — verification task | `TEST` `exit=0`, 294 passing / 0 failing; `build` `exit=0`, zero `warning:` lines | N/A | N/A |
| 7.3 | manual | Manual, machine-dependent | N/A | N/A | **Not run — pending user manual check** (see Open Items) | N/A | N/A |

Deleted in RED 6.1: `theMemoryModuleStaysAPlaceholder` (superseded by the MBW-7/MBW-8 scenarios, per the spec delta's REMOVED note). `everyModuleReservesItsSparklineArea` was kept unchanged apart from dropping the stale `"MEM placeholder still has a sparkline"` reference from its comment.

## Work Unit Evidence — batch C

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` → `exit=0`, 294 test-case lines, 0 failing. Tail lines: `MetricsSamplerLoopTests/startPublishesARealValueWithinTwoHundredMilliseconds() passed`, `…/everyReadHappensOffTheMainThread() passed`, `…/theInjectedIntervalKeepsTheLoopPublishing() passed`, `…/stopFreezesThePublishedCount() passed`, `…/startIsIdempotentSoStopHaltsEveryIteration() passed`. Widget budget: all four `StatusItemControllerTests` pass, including `theWidgetStaysUnderTheWidthBudgetAtFullScale` (< 230 pt) |
| Runtime harness command/scenario and exact result | `xcodebuild … -quiet build` → `exit=0`, zero `warning:` lines under Swift 6 strict concurrency. The `.integration` suite `MachMemoryIntegrationTests` runs the real `host_statistics64` inside the same `TEST` run. Widget rendering is exercised through `NSHostingView.fittingSize` in `StatusItemMetricsTests` and through the two `StatusItemView` `#Preview`s. Task 7.3's Activity Monitor comparison is the one runtime check that cannot be automated and stays with the user |
| Rollback boundary | Revert `system-monitor/Presentation/MenuBar/StatusItemView.swift`, `system-monitorTests/Presentation/StatusItemReadingsTests.swift` and `PRD.md`. Domain, Application, Infrastructure, `AppDelegate`, the panel and the memory card are untouched by this batch; reverting these three files restores the MEM placeholder without disturbing batches A and B |

## Completed Tasks — batch C

- [x] 6.1 RED `StatusItemReadingsTests.swift` — placeholder test deleted, MBW-7/MBW-1/MBW-8 added
- [x] 6.2 GREEN `StatusItemReadings.build(cpu:cpuHistory:memory:memoryHistory:)`, MEM bound to `memory`/`memoryHistory`
- [x] 7.1 `PRD.md` R4.2, R4.3 and 6.2 amended (MM-10)
- [x] 7.2 Full `TEST` + `build`, zero warnings, widget budget confirmed
- [~] 7.3 Manual Activity Monitor verification — pending user manual check at the end of batch C (only task left open then; run by the user on 2026-09-06 and closed in batch D)

## Files Changed — batch C

| File | Action | Lines |
|---|---|---|
| `system-monitor/Presentation/MenuBar/StatusItemView.swift` | Modify | +23 / −8 |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Modify | +183 / −22 |
| `PRD.md` | Modify | +7 / −4 |

Changed-lines for batch C: **~247**. No new files. `project.pbxproj` untouched. Cumulative for the change: ~2 591 lines, inside the accepted `size:exception`.

Whole-change `git diff --stat` at the end of batch C (tracked files only, excluding the 19 new untracked files): 11 files changed, 648 insertions, 78 deletions.

PRD diff summary (7 insertions / 4 deletions):
- **R4.2** — `Free = free_count` → `Free = free_count − speculative_count` with the "speculative pages are counted inside `free_count`" parenthetical; `Used = App + Wired + Compressed` → `Used = Total − Free − Cached`; new note that Used carries kernel-managed pages and boot-time carve-outs, so App + Wired + Compressed is roughly 0.5 GB below Used on Apple Silicon.
- **R4.3** — "multiplied by `vm_kernel_page_size`" → "multiplied by the kernel page size, read once from `host_page_size()`".
- **6.2** — `var used: UInt64 { app + wired + compressed }` → `let used: UInt64` with the Total − Free − Cached carve-out comment.
- Verified afterwards: no `Used = App + Wired + Compressed` definition, no `Free = free_count` definition, no `vm_kernel_page_size` reference and no computed `used` remain in `PRD.md`. The only surviving mention of "App + Wired + Compressed" is the new explanatory note.

## Decisions and Deviations — batch C

- **D14 — views omit an explicit `@MainActor` annotation.** The design signature block writes `@MainActor struct StackedBar/SegmentLegend/MemoryCard`. The target sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so the annotation is inferred and the existing `CPUCard`, `PanelView` and `StatusItemView` all omit it. Writing it would have made the new views the only annotated ones in the codebase. Benign deviation: the isolation is identical, only the spelling differs, and it matches the `CPUCard` precedent.
- **D15 — the MBW-7 "MEM accent" scenario is asserted on the reading.** `StatusItemReadingsTests.memoryUsesTheMemoryAccent` already pinned `MetricModule.memory.accent == Palette.memAccent`. The new `theMemoryModuleCarriesTheMemoryAccent` asserts the same equality through a reading actually produced by `build`, so the scenario is covered on the path the widget renders rather than only on the enum.
- **D16 — the MBW-8 width assertion reuses the existing measurement helper.** `contentWidth(for:)` gained an array overload so the full-scale widget can be measured in one call; the single-reading overload now forwards to it. `everyModuleReservesItsSparklineArea` is untouched apart from its comment, as the task required.
- **D17 — PRD prose carries no source citations.** The proposal's R4.2 replacement text is prefixed with research markers (S1–S5). Those are OpenSpec research references, not product requirements, so they were dropped; the definitions themselves are verbatim. The PRD's existing U+2212 minus sign was preserved instead of the proposal's ASCII hyphen so the amended lines match the surrounding document.
- **D18 — the widget test helper builds a fraction-only snapshot.** `memorySnapshot(fraction:)` sets `total` and `used` and leaves every component at zero. The widget must read `MemorySnapshot.fraction`; a build that re-derived a percentage from `app`/`wired`/`compressed` would report `"0%"` and fail every MEM value assertion.
- **No other design deviations.** `StatusItemReadings.build(cpu:cpuHistory:memory:memoryHistory:)`, `.memory` bound to `memoryHistory.suffix(sampleCount)` and `PercentFormatter.integer(memory?.fraction ?? 0)`, and `StatusItemView` forwarding all four values match design rev 2 decision 9 verbatim. `StatusItemMetrics`, `ModuleLabel` and `StatusItemController` are unchanged, and no layout constant moved.

## Convention Compliance — batch C

1. `StatusItemReadings` and `ModuleReading` remain `nonisolated`; no new type was introduced. `StatusItemView`, `StatusItemContent` and `ModuleLabel` stay main-actor views.
2. No test suite is `@MainActor`; the new width cases `await` the `@MainActor` helpers exactly as the existing ones do.
3. `project.pbxproj` untouched; no new files in this batch.
4. Widget budget respected: no new label text entered the bar, no layout constant changed, and `theWidgetStaysUnderTheWidthBudgetAtFullScale` plus the new full-scale assertion both confirm < 230 pt.
5. Zero build warnings (`xcodebuild … build` → `exit=0`, no `warning:` lines).
6. Domain, Application and Infrastructure files were not touched in this batch — no compile error forced a fix there.
7. All code, comments, UI strings, tests and documentation are in English.

## Test Counts — batch C

| Point | Passing | Failing |
|---|---|---|
| Baseline (after batch B) | 288 | 0 |
| RED 6.1 | — | compile failure (`exit=65`) |
| After 6.2 (GREEN) | 294 | 0 |
| After 7.1 (`PRD.md`) | 294 | 0 |
| After 7.2 (batch C final) | **294** | **0** |

7 tests added, 1 deleted (net +6); all 288 tests from the batch B baseline still pass.

Counting note: `xcodebuild` occasionally interleaves a timestamped log line into a `Test case '…' passed on` line, so `rg -c "' passed on '"` reported 293 while `rg -c "^Test case '"` reported 294 for the same run. 294 is the authoritative total (288 − 1 + 7).

## Change Roll-Up (all batches)

| Batch | Tasks | Tests after | Changed lines |
|---|---|---|---|
| A | 1.1 – 3.3, 6.3 | 249 | ~1 373 |
| B | 4.1 – 5.3 | 288 | ~971 |
| C | 6.1, 6.2, 7.1, 7.2 | 294 | ~247 |
| **Total** | **30 of 31 complete** | **294** | **~2 591** |

19 new files (9 production, 10 test) plus 11 modified tracked files. Final `TEST` `exit=0`, 294 passing, 0 failing. Final `build` `exit=0`, zero warnings.

## Open Items Carried Forward — batch C

- **Task 7.3 is pending a user manual check** and is the only task left `[ ]`. Exact procedure: (1) launch the app; (2) open Activity Monitor › Memory; (3) compare Activity Monitor "Memory Used" to the MEM card's Used row at the same moment — target |Δ| ≤ 100 MB; (4) compare Activity Monitor "Physical Memory" to the card's Total row; (5) confirm the live MEM percentage, the menu bar sparkline and the memory card render as expected. If the Totals match but Used does not, apply the `hw.memsize_usable` fallback from design decision 3 (a single line in `MachMemoryProvider.init`) and re-run. The automated half of 7.3 — widget fitting width < 230 pt — already passes in `StatusItemControllerTests`.
- **MC-10 "Reduce motion" is verified by code inspection and `#Preview` only.** `MemoryCard` gates its gauge animation on `accessibilityReduceMotion` with the same mechanism as `CPUCard`, but the SwiftUI accessibility environment is not readable from the unit target here, so there is no automated assertion. This matches the `CPUCard` precedent already in the codebase; it is a known coverage gap for the scenario, not an unimplemented behaviour.
- No other open items. Design decision 12's ICU question was closed in batch B (D8); the `hw.memsize_usable` fallback was not needed for any automated assertion (batch A).

---

# Batch D — post-verify bounded correction (2026-09-06)

**Work unit**: `apply-correction-used-formula-activity-monitor-match`
**Trigger**: user decision after the task 7.3 manual check (Engram observation 8218). The card must show what Activity Monitor shows.
**Mode**: Strict TDD (expectations changed first, RED recorded, then production)
**Baseline before batch D**: 294 tests passing, 0 failing (`exit=0`)
**After batch D**: 299 tests passing, 0 failing (`exit=0`); `build` exit 0, zero `warning:` lines

## What the manual check found

Total matched Activity Monitor "Physical Memory". Wired, Compressed and App (= internal − purgeable) matched exactly. Used ran **0.27–0.42 GB below** Activity Monitor's "Memory Used" in simultaneous screenshots. A three-minute `vm_stat` window showed Activity Monitor's own unattributed remainder — Used − App − Wired − Compressed — reaching 0.95 GB, which the shipped formula cannot produce, because it had already removed both the purgeable and the speculative pages from Used.

Because the Totals matched, the `hw.memsize_usable` fallback from design decision 3 was **not** applied. `ProcessInfo.processInfo.physicalMemory` stays as the Total source; only the split between Used, Cached and Free moved.

## Formula change (design revision 3, decision 14)

| Component | Before | After |
|---|---|---|
| App | (internal − purgeable) × pageSize | unchanged |
| Wired | wired × pageSize | unchanged |
| Compressed | compressor × pageSize | unchanged |
| **Cached** | (external + purgeable) × pageSize | **(external + speculative) × pageSize** |
| Free | (free − speculative) × pageSize | unchanged |
| **Used** | Total − Free − Cached (old Cached) | **Total − free × pageSize − external × pageSize** |

`Used` is still coded as `total ⊖ free ⊖ cached`, so the invariant `Used + Cached + Free == Total` holds by construction: Free and Cached share exactly the speculative pages, and the two saturating subtractions are untouched. Purgeable pages now sit inside Used (and inside the unlabeled `.unattributed` bar segment) but not inside App, exactly like Activity Monitor. All arithmetic stays saturating `UInt64`.

## Fixture arithmetic (pageSize 16384, total 8 589 934 592)

| Fixture | Change | Derived values |
|---|---|---|
| `reference` | counts unchanged | app 2 949 120 000, wired 1 966 080 000, compressed 1 474 560 000, **cached 983 040 000** (60 000 pages), **free 819 200 000** (50 000 pages), **used 6 787 694 592**, fraction 0.79019…, **unattributed 397 934 592** (24 288 pages). used + cached + free = 8 589 934 592 |
| `eightGiB` | `freeCount` 107 588 → **112 588** | used stays 5 926 092 800 ("5.52 GB", 69.0%), wired 1 986 560 000, compressed 1 954 283 520, app 1 460 961 280, unattributed 524 288 000 all unchanged; **cached 901 120 000** (55 000 pages), **free 1 762 721 792** (107 588 pages) |
| `freePlusCachedExceedTotal` | counts unchanged | free 960 + cached 640 > total 1 000 → used 0, fraction 0; doc wording now "free plus file-backed pages exceed Total" |
| `purgeableExceedsInternal` | counts unchanged | app 0, **cached 0** (was 327 680), **used == total** |
| `speculativeExceedsFree` | counts unchanged | free 0, **cached 327 680** (was 0), **used == total − 327 680** |
| `zero`, `uint32MaxWired`, `overflowingCounts` | counts unchanged | every expected value unchanged; `overflowingCounts` still drives both the saturating add and the saturating multiply to `UInt64.max` with `used == 0` |

The `eightGiB` bump exists so the reference card keeps the numbers MC-4, MC-3 and the panel tests pin: five thousand extra free pages replace the five thousand speculative pages that moved from Free into Cached.

## TDD Cycle Evidence — batch D

| Task | Test file | Layer | Safety net | RED evidence | GREEN | Triangulate | Refactor |
|---|---|---|---|---|---|---|---|
| 8.1 RED / 8.2 GREEN | `MemoryUsageCalculatorTests.swift`, `Support/MemoryFixtures.swift`, `MemoryCardModelTests.swift`, `MetricsSamplerTests.swift`, `MemoryMetricsProviderPortTests.swift` | Unit | 294/294 | `exit=65`, 16 failing cases: `MemoryUsageCalculatorTests/{everyByteComponentFollowsTheActivityMonitorFormula,fractionMatchesTheUsedShareOfTotal,unattributedUsedIsTheRemainderTheLabelledComponentsDoNotCover,cachedCountsSpeculativePagesAndKeepsPurgeableOnesInsideUsed}(testCase:)`, `MemoryUsageCalculatorTests/{appSaturatesAtZeroWhenPurgeableExceedsInternal,freeSaturatesAtZeroWhenSpeculativeExceedsFree}()`, `MemoryCardModelTests/{theBarSplitsTotalIntoSixSegmentsInProductOrder,theRowsReadUsedTotalWiredAndCompressedFromTheSnapshot,theRowValuesFollowTheInjectedLocale}()`, `MemoryMetricsProviderPortTests/theFakeIsUsableThroughThePortItself()`, `MetricsSamplerStepTests/{theMemoryStepConvertsOneReadIntoASnapshot,theFirstStepPublishesMemoryWhileTheCPUIsStillSeeding,aThrowingMemoryReadPublishesNothingAndRecoversOnTheNextStep,aThrowingCPUReadDoesNotPreventTheMemoryPublish}()`, `PanelViewTests/{theFirstMemorySnapshotFillsTheCardWithoutResizingThePanel,theMemoryGaugeTextFollowsTheAppliedSnapshot}()` | `exit=0`, 296 passing | New parameterized case over both full fixtures pinning `cached == (external + speculative) × pageSize`, `used + cached + free == total` and `unattributedUsed >= purgeable × pageSize`; the two saturation cases re-derived from opposite sides (purgeable leaves Cached, speculative enters it) | None needed — one expression and one comment moved in the calculator |
| 8.3 RED / 8.3 GREEN | `system-monitorTests/Presentation/SegmentLegendTests.swift` (new) | Unit (rendered geometry) | 296/296 | `exit=65` — `SegmentLegendTests.swift:70:53: error: type 'SegmentLegend' has no member 'rowSpacing'` plus `'labelFontSize'/'dotSize'/'dotSpacing'/'entrySpacing' is inaccessible due to 'private' protection level`; then `error: main actor-isolated static property 'rowSpacing' cannot be accessed from outside of the actor` | `exit=0`, 299 passing | 3 cases: the five entries cannot share one row at 264 pt; the legend is exactly two single-line rows there; a two-entry legend stays on one row (both `ViewThatFits` branches exercised) | None needed |
| 8.4 | Artifacts only | — | 299/299 | N/A — documentation | `exit=0`, 299 passing | N/A | N/A |

The 8.3 upper and lower height bounds are the load-bearing assertions: the lower bound (`>= 2 rows + rowSpacing`) fails when the legend stays on one row and squeezes its labels, and the upper bound (`<= 2 rows + rowSpacing`) fails when any label breaks across lines, because a wrapped row is two text lines tall.

## Work Unit Evidence — batch D

| Evidence | Value |
|---|---|
| Focused test command and exact result | `TEST` → `exit=0`, `passed=299`, `failed=0` (`rg -c "^Test case '"` = 299) |
| Runtime harness command/scenario and exact result | `.integration` suite `MachMemoryIntegrationTests` runs the real `host_statistics64` inside the same `TEST` run and stays green under the new formula (its bounds `app + wired + compressed <= used <= total` now hold with more slack, not less). Build check: `xcodebuild … -quiet build` → `exit=0`, zero `warning:` lines. The remaining runtime step — a visual re-check of the running app against Activity Monitor — is a user action and is listed under open items. |
| Rollback boundary | Revert `system-monitor/Domain/Services/MemoryUsageCalculator.swift` and `system-monitor/Presentation/Components/SegmentLegend.swift`, the two `#Preview` snapshots in `MemoryCard.swift`/`PanelView.swift`, the batch D expectation edits in `MemoryFixtures.swift`, `MemoryUsageCalculatorTests.swift`, `MemoryCardModelTests.swift`, `MetricsSamplerTests.swift`, `MemoryMetricsProviderPortTests.swift`, and delete `system-monitorTests/Presentation/SegmentLegendTests.swift`. Nothing in Application or Infrastructure moved; `MemorySnapshot` keeps its stored `used`. |

## Decisions and Deviations — batch D

- **D19 — `used` keeps its `total ⊖ free ⊖ cached` spelling.** The user decision states `Used = Total − free × pageSize − external × pageSize`. With `cached = (external + speculative) × p` and `free = (free − speculative) × p`, the shipped expression is arithmetically identical whenever `speculative <= free`, and it is strictly better when it is not: it keeps `Used + Cached + Free == Total` true by construction instead of letting the literal form overshoot. The production change is therefore one expression (`cached`) plus comments, and MC-5's stacked bar keeps summing to Total.
- **D20 — `MemorySnapshotTests` was left untouched.** It hand-builds snapshots to test `MemorySnapshot` arithmetic (fraction, clamping, `unattributedUsed`, `Equatable`) and never calls the calculator, so every case stayed green and every value stayed internally consistent. Its `used 6 623 854 592 → 0.7711` case is spec scenario MM-3 "Fraction" verbatim, which is a statement about the value type rather than about the formula; changing it would have broken the spec-to-test trace for a scenario the correction does not touch.
- **D21 — the two `#Preview` snapshots were realigned.** `MemoryCard.swift` and `PanelView.swift` hand-build the `eightGiB` snapshot for their previews. They are preview-only literals, but leaving `cached 983 040 000 / free 1 680 801 792` there would have contradicted the fixture, so both moved to `901 120 000 / 1 762 721 792`. No rendered behaviour changed: `used`, `app`, `wired` and `compressed` are identical.
- **D22 — the legend uses `ViewThatFits`, not an adaptive `LazyVGrid`.** The prompt suggested a grid with `GridItem(.adaptive(minimum: 84))`. At the real content width (296 pt card − 2 × 16 pt padding = 264 pt) an adaptive grid needs three columns of at most 81.3 pt to keep the legend at two rows, which is within a few points of the widest entry ("Compressed" plus its dot). That is a magic number that has to be re-tuned whenever a label or a font size changes. `ViewThatFits` asks the layout engine the same question directly, keeps the MC-6 entry order in both branches, and needs no width constant. Design decision 15 records it.
- **D23 — the legend layout constants became `nonisolated static let`.** `SegmentLegend` is a main-actor `View` under the target's default isolation, so its `static let`s were main-actor isolated and unreadable from a non-`@MainActor` test. Marking the five constants `nonisolated` matches convention 1 (pure presentation values are `nonisolated`) and is what makes the geometry assertable without a main-actor test suite.
- **D24 — `project.pbxproj` carries a two-line cosmetic diff not authored here.** `INFOPLIST_KEY_LSUIElement` and `INFOPLIST_KEY_NSHumanReadableCopyright` are swapped in both build configurations. No file reference, target or build phase changed. It is an alphabetical re-sort emitted by a tool run, not an edit from this batch; it was left as found rather than fought, since reverting invites the same re-sort on the next run.

## Convention Compliance — batch D

1. `MemoryUsageCalculator` stays a `nonisolated enum` of pure static functions; the five new `SegmentLegend` constants are explicitly `nonisolated`.
2. No test suite is `@MainActor`; `SegmentLegendTests` awaits `@MainActor` measurement helpers exactly as `PanelViewTests` does.
3. `project.pbxproj` was not edited (see D24); the new test file is picked up by the synchronized group.
4. Application and Infrastructure code was not touched. `MemorySnapshot` keeps its stored `used`.
5. Zero build warnings (`xcodebuild … build` → `exit=0`, no `warning:` lines).
6. All code, comments, UI strings, tests and documentation are in English.

## Test Counts — batch D

| Point | Passing | Failing |
|---|---|---|
| Baseline (after batch C) | 294 | 0 |
| RED 8.1 | 280 | 16 (296 cases) |
| GREEN 8.2 | 296 | 0 |
| RED 8.3 | — | compile failure (`exit=65`) |
| GREEN 8.3 | 299 | 0 |
| After 8.4 (batch D final) | **299** | **0** |

5 test cases added (2 from the new parameterized calculator case over both full fixtures, 3 from `SegmentLegendTests`), none deleted.

## Change Roll-Up (all batches)

| Batch | Tasks | Tests after | Changed lines |
|---|---|---|---|
| A | 1.1 – 3.3, 6.3 | 249 | ~1 373 |
| B | 4.1 – 5.3 | 288 | ~971 |
| C | 6.1, 6.2, 7.1, 7.2 | 294 | ~247 |
| D | 7.3, 8.1 – 8.4 | 299 | ~205 |
| **Total** | **35 of 35 complete** | **299** | **~2 796** |

20 new files (9 production, 11 test) plus 11 modified tracked files. Final `TEST` `exit=0`, 299 passing, 0 failing. Final `build` `exit=0`, zero warnings. Whole-change `git diff --stat` over tracked files: 12 files changed, 653 insertions, 81 deletions (the twelfth is the cosmetic `project.pbxproj` re-sort from D24).

## Open Items Carried Forward — batch D

- **Final visual re-check by the user.** Launch the app, open Activity Monitor › Memory, and confirm the card's Used row now tracks "Memory Used" within 100 MB, that Wired / Compressed / App still match, and that the legend reads `App  Wired  Compressed` / `Cached  Free` on two clean rows with no word broken. This is the only remaining verification and it cannot be automated.
- **MC-10 "Reduce motion" is still verified by code inspection and `#Preview` only** — unchanged from batch C, and unrelated to this correction.
- **MM-3 "Fraction" scenario keeps its pre-correction numbers on purpose** (D20). It is arithmetic on a hand-built snapshot, not a claim about the calculator.
- No other open items.
