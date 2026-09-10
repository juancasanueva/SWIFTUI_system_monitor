# Apply Progress — network-module

Change: `network-module` | Store: hybrid | Mode: **Strict TDD** | Delivery: `single-pr` under accepted `size:exception` (recorded 2026-09-10).

## Batch status

| Batch | Phases | Status | Date |
|---|---|---|---|
| A | Phase 1 (1.1–1.5) | Complete — green | 2026-09-10 |
| B | Phase 2 (2.1–2.8) | Complete — green | 2026-09-10 |
| C | Phase 3 (3.1–3.4) | Complete — green | 2026-09-10 |
| D | Phase 4 (4.1–4.4) | Complete — green | 2026-09-10 |
| E | Phase 4 (4.5–4.8) | Complete — green | 2026-09-10 |
| F | Phase 4 (4.9–4.10) | Complete — green | 2026-09-10 |
| G | Phases 5–7 (5.1, 6.1, 6.2, 7.1, 7.2) | Complete — green; corrective re-run 2026-09-10 added the NC-4 colour assertion | 2026-09-10 |
| — | 7.3–7.7 (MANUAL) | **Open — user-owned**, still `[ ]` in `tasks.md` | — |

**32/37 automated tasks done; 7.3–7.7 open. next_recommended: `sdd-verify`.**

## Batch A — Domain foundation (tasks 1.1–1.5)

### Completed tasks

- [x] 1.1 **RED** NM-2, NM-3 — `NetworkSnapshotTests.swift` + `NetworkFixtures.swift`
- [x] 1.2 **GREEN** NM-2, NM-3, NM-1 (shape) — counters, snapshot, port
- [x] 1.3 **RED** NM-4 — `NetworkThroughputCalculatorTests.swift`
- [x] 1.4 **GREEN** NM-4 — `NetworkThroughputCalculator.swift`
- [x] 1.5 **RED→GREEN** NM-1 — `FakeNetworkProvider.swift` + `NetworkMetricsProviderPortTests.swift`

### Files created

| File | Action | What it contains |
|---|---|---|
| `system-monitor/Domain/Models/NetworkThroughputCounters.swift` | Created | `bytesIn`, `bytesOut`, `interfaceCount`, `timestamp`; `nonisolated`, `Sendable`, `Equatable` |
| `system-monitor/Domain/Models/NetworkSnapshot.swift` | Created | `totalIn`, `totalOut`, optional rate pair; memberwise initialiser only |
| `system-monitor/Domain/Ports/NetworkMetricsProvider.swift` | Created | Single `readCounters() throws -> NetworkThroughputCounters` |
| `system-monitor/Domain/Services/NetworkThroughputCalculator.swift` | Created | `Rates` pair + `rates(previous:current:) -> Rates?`, Δt from `duration(to:)` with attoseconds |
| `system-monitorTests/Support/NetworkFixtures.swift` | Created | `base`, `instant(_:)`, `counters(in:out:interfaceCount:at:)`, `idle`, `referencePrevious`, `referenceCurrent`, `referenceSnapshot`, `climbing(steps:)` |
| `system-monitorTests/Support/FakeNetworkProvider.swift` | Created | `Mutex<Script>` double: zero-based `throwOnCall`, `callCount`, `readOnMainThread` |
| `system-monitorTests/Domain/NetworkSnapshotTests.swift` | Created | 9 cases (NM-2, NM-3) |
| `system-monitorTests/Domain/NetworkThroughputCalculatorTests.swift` | Created | 10 cases (NM-4) |
| `system-monitorTests/Domain/NetworkMetricsProviderPortTests.swift` | Created | 7 cases (NM-1) |

No tracked file was modified; `project.pbxproj` is untouched (convention 5). Authored lines: 651 across the nine new files.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 1.1 | `system-monitorTests/Domain/NetworkSnapshotTests.swift` | Unit | ✅ 558/558 unit baseline | ✅ Compile failure — `NetworkThroughputCounters`/`NetworkSnapshot` not in scope (`exit=65`) | ✅ 9/9 after 1.2 | ✅ 9 cases (equality, stamp, interface count, rates present/absent) | ➖ None needed |
| 1.2 | same | Unit | N/A (new files) | (paired with 1.1) | ✅ `RUN NetworkSnapshotTests` exit 0, 9 passed | ✅ via 1.1 cases | ➖ None needed |
| 1.3 | `system-monitorTests/Domain/NetworkThroughputCalculatorTests.swift` | Unit | N/A (new file) | ✅ Compile failure — `NetworkThroughputCalculator` not in scope (`exit=65`) | ✅ 10/10 after 1.4 | ✅ 10 cases (reference, 0.5 s window, nil previous, `interfaceCount 0`, Δt 0 and −1 ms, both negative deltas, re-seed recovery, zero rates) | ➖ None needed |
| 1.4 | same | Unit | N/A (new file) | (paired with 1.3) | ✅ `RUN NetworkThroughputCalculatorTests` exit 0, 10 passed | ✅ via 1.3 cases | ➖ None needed |
| 1.5 | `system-monitorTests/Domain/NetworkMetricsProviderPortTests.swift` | Unit | N/A (new file) | ✅ Compile failure — `FakeNetworkProvider` not in scope (`exit=65`) | ✅ `RUN NetworkMetricsProviderPortTests` exit 0, 7 passed | ✅ 7 cases (order, exhaustion, `throwOnCall: [1]`, empty script, thread recording, port existential, climbing script) | ➖ None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild … -only-testing:system-monitorTests/NetworkThroughputCalculatorTests` → exit 0, 10 passed, 0 failed (per-suite results above) |
| Runtime harness command/scenario and exact result | N/A — batch A is pure Domain values, a pure rule and test doubles; no runtime boundary exists (the sysctl adapter arrives in batch C) |
| Rollback boundary | Delete the nine files listed above; nothing tracked was modified, so the working tree returns to `de40106` exactly |
| Batch close | `xcodebuild … -only-testing:system-monitorTests` → exit 0, **584** distinct cases passed, 0 failed (baseline 558 + 26 new). Zero compiler warnings in the log. |

### Deviations from design

None. Every signature matches `design.md` verbatim: `NetworkThroughputCounters`, `NetworkSnapshot` (memberwise only), the single-method port, `NetworkThroughputCalculator.Rates` and `rates(previous:current:)`, `FakeNetworkProvider` and the `NetworkFixtures` members.

Two additions inside the design's latitude, both test-only:

1. `NetworkSnapshotTests` also pins `referencePrevious != referenceCurrent` and the `idle` shape (design's NM-2 test map row).
2. `NetworkMetricsProviderPortTests` pins that `climbing(steps:)` starts at `referencePrevious` with step 1 equal to `referenceCurrent`, so batch B's loop expectations rest on an asserted fact rather than an assumption.

### Notes for batch B

- `FakeNetworkProvider(counters:throwOnCall:)` — `counters` is the only required argument, `throwOnCall` defaults to `[]` and is zero-based. `FakeNetworkProvider(counters: [])` reads `NetworkFixtures.idle` (`interfaceCount 0`, totals 0) forever, which is exactly the defaulted value task 2.3 injects into the five compile sites.
- Readable state: `callCount: Int` and `readOnMainThread: [Bool]` (one entry per read, including throwing reads). A throwing call advances `callCount` but not the cursor.
- Exhausted scripts repeat the last value, so a short script never crashes a loop suite; use `NetworkFixtures.climbing()` when the rates must keep changing.
- `NetworkFixtures.climbing(steps:)` step `i` = `3_849_995_000 + i * 5_000` in / `2_759_922_000 + i * 78_000` out at `i` seconds, `interfaceCount 2`. Step 0 is `referencePrevious`, step 1 is `referenceCurrent`, so consecutive steps always yield 5 000 / 78 000.
- `NetworkThroughputCalculator.rates` returns `nil` for `interfaceCount == 0`, so an idle script publishes totals 0 with both rates `nil` — the shape task 2.3's fourth scenario expects.
- All new test types are plain `nonisolated`; no suite is `@MainActor`.

## Batch B — Application (tasks 2.1–2.8)

### Completed tasks

- [x] 2.1 **RED** NM-9 — network cases in `MetricsStateTests.swift`
- [x] 2.2 **GREEN** NM-9 — `MetricsState.network` + the two paired histories
- [x] 2.3 **RED** NM-5 + the five compile sites — `MetricsSamplerStepTests` network cases, both `makeSampler` helpers, `SamplingCadenceTests`, `SettingsStateTests`, `AppDelegate`
- [x] 2.4 **GREEN** NM-5 — `NetworkSamplingStep`, required `networkProvider:`, `inlineNetworkStep`, `sampleOnce()`
- [x] 2.5 **RED** NM-8 — failure-isolation cases in `MetricsSamplerStepTests`
- [x] 2.6 **GREEN** NM-8 — `advanced()` drops the baseline on a throw (decision 3)
- [x] 2.7 **RED** NM-6, NM-7 — restart and off-main cases in `MetricsSamplerLoopTests`
- [x] 2.8 **GREEN** NM-6, NM-7 — network read in the detached `.utility` loop

### Files changed

| File | Action | What was done |
|---|---|---|
| `system-monitor/Application/MetricsState.swift` | Modified | `network`, `networkDownloadHistory`, `networkUploadHistory` sized by `init(historyCapacity:)`, `apply(network:)` appending to both histories or neither |
| `system-monitor/Application/MetricsSampler.swift` | Modified | `NetworkSamplingStep` (memberwise only) with `advanced()`; required `networkProvider:` after `diskProvider:`; `inlineNetworkStep`; four reads before any publish in both `sampleOnce()` and the detached loop; fresh `networkStep` inside the closure; doc comments |
| `system-monitor/App/AppDelegate.swift` | Modified | `PlaceholderNetworkProvider` (task 2.3 compile site) injected as `networkProvider:`; **task 5.1 replaces it with `SysctlNetworkProvider()` and deletes the placeholder** |
| `system-monitorTests/Application/MetricsStateTests.swift` | Modified | 6 NM-9 cases + `networkSnapshot(download:upload:)` helper |
| `system-monitorTests/Application/MetricsSamplerTests.swift` | Modified | Both `makeSampler` helpers gain `networkProvider: FakeNetworkProvider = FakeNetworkProvider(counters: [])`; 4 NM-5 cases, 4 NM-8 cases, 2 NM-6 cases; `everyReadHappensOffTheMainThread` extended for NM-7 |
| `system-monitorTests/Application/SamplingCadenceTests.swift` | Modified | One inline `networkProvider:` compile site |
| `system-monitorTests/Application/SettingsStateTests.swift` | Modified | One inline `networkProvider:` compile site |

`project.pbxproj` untouched (convention 5). Batch B authored 593 insertions / 12 deletions across 7 files; cumulative change size stays inside the accepted `size:exception`.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 2.1 | `system-monitorTests/Application/MetricsStateTests.swift` | Unit | ✅ 584/584 unit baseline, exit 0 | ✅ `exit=65`, `value of type 'MetricsState' has no member 'network' / 'networkDownloadHistory' / 'networkUploadHistory'`, `no exact matches in call to instance method 'apply'` | ✅ (2.2) `RUN MetricsStateTests` exit 0, 24 passed | ✅ 6 cases (paired growth, nil rates append nothing, other state untouched, reverse isolation, capacity 3, fresh state) | ➖ None needed |
| 2.2 | same | Unit | N/A (paired) | (paired with 2.1) | ✅ `RUN MetricsStateTests` exit 0, 24 passed, 0 warnings | ✅ via 2.1 cases | ➖ None needed |
| 2.3 | `system-monitorTests/Application/MetricsSamplerTests.swift` | Unit | ✅ 584/584 baseline | ✅ `exit=65`, **zero compile errors** — all five sites fixed in the same step — and 4 failing scenarios: `theFirstNetworkStepPublishesTotalsWithBothRatesNil`, `theSecondNetworkStepPublishesTheReferenceRates`, `allFourProvidersAreReadOncePerStep`, `aScriptWithNoAdmittedInterfacePublishesZeroTotalsWithoutRates` | ✅ (2.4) `RUN MetricsSamplerStepTests` exit 0, 33 passed | ✅ 4 cases (first tick, second tick, call counts, idle script) | ➖ None needed |
| 2.4 | same | Unit | N/A (paired) | (paired with 2.3) | ✅ `RUN MetricsSamplerStepTests` exit 0, 33 passed, 0 warnings | ✅ via 2.3 cases | ➖ None needed |
| 2.5 | same | Unit | ✅ 33/33 step suite | ✅ `exit=65`, failing scenario `theSuccessAfterANetworkThrowIsARateFreeReSeedTick` (the baseline still survived a throw); the three companion NM-8 pins already held and stayed as regression guards | ✅ (2.6) `RUN MetricsSamplerStepTests` exit 0, 37 passed | ✅ 4 cases (throw before rates, throw after rates, re-seed + recovery, CPU throws) | ➖ None needed |
| 2.6 | same | Unit | N/A (paired) | (paired with 2.5) | ✅ `RUN MetricsSamplerStepTests` exit 0, 37 passed, 0 warnings | ✅ via 2.5 cases | ➖ None needed |
| 2.7 | same (loop suite) | Unit | ✅ 14/14 loop suite in the 584 baseline | ✅ `exit=65`, zero compile errors, 3 failing scenarios: `aRestartCostsOneRatesUnavailableNetworkTick`, `applyingTheIntervalAlreadyInEffectKeepsTheNetworkBaseline`, `everyReadHappensOffTheMainThread` | ✅ (2.8) `RUN MetricsSamplerLoopTests` exit 0, 16 passed | ✅ 3 cases (restart costs one tick + recovery, unchanged interval, off-main reads) | ➖ None needed |
| 2.8 | same | Unit | N/A (paired) | (paired with 2.7) | ✅ `RUN MetricsSamplerLoopTests` exit 0, 16 passed, 0 warnings | ✅ via 2.7 cases | ➖ None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild … -only-testing:system-monitorTests/MetricsSamplerStepTests` → exit 0, 37 passed, 0 failed; `…/MetricsSamplerLoopTests` → exit 0, 16 passed; `…/MetricsStateTests` → exit 0, 24 passed |
| Runtime harness command/scenario and exact result | N/A — batch B is Application wiring driven by `FakeNetworkProvider` and `ManualClock`; the real routing-socket boundary arrives with `SysctlNetworkProvider` in batch C, and `AppDelegate` currently holds the placeholder task 5.1 replaces |
| Rollback boundary | Revert `system-monitor/Application/{MetricsState,MetricsSampler}.swift`, `system-monitor/App/AppDelegate.swift` and the four test sites; batch A's nine new files stay green on their own |
| Batch close | `xcodebuild … -only-testing:system-monitorTests` → exit 0, **600** distinct cases passed, 0 failed, 0 compiler warnings (584 after batch A + 16 new). `git status --short`: 7 modified files, `project.pbxproj` untouched, nothing committed. `git diff --stat`: 593 insertions, 12 deletions |

### Deviations from design

None in the delivered end state. Two staging notes:

1. **TDD staging of `advanced()`'s throw branch.** Task 2.4 shipped the throw branch as `(nil, self)` (the `CPUSamplingStep` precedent) so that task 2.5's decision-3 scenario had a genuine RED; task 2.6 generalised it to `(nil, NetworkSamplingStep(provider:previous: nil))`, which is the design's normative algorithm verbatim. The delivered code matches the design.
2. **`AppDelegate` compile site.** The design's decision 9 names `networkProvider: SysctlNetworkProvider()` there, but that adapter only exists after batch C, so task 2.3's prescribed compile-fixing construction is used: a `nonisolated struct PlaceholderNetworkProvider` declared in `AppDelegate.swift` returning `interfaceCount 0` counters. Task 5.1 replaces the call and deletes the struct.

Everything else matches the design verbatim: `NetworkSamplingStep(provider:previous:)` with the memberwise initialiser only, `networkProvider:` required and placed after `diskProvider:`, `inlineNetworkStep` untouched by `apply(interval:)`, `var networkStep` built inside the detached closure, all four reads before any publish, and the publish order cpu → memory → disk → network.

### Notes for batch C

- **`NetworkMetricsProvider` conformance the sysctl adapter must satisfy**: a `nonisolated`, `Sendable`, stateless `struct SysctlNetworkProvider: NetworkMetricsProvider` with `init() {}` and the single `func readCounters() throws -> NetworkThroughputCounters`. `NetworkSamplingStep.advanced()` calls it with `try?`, so every throw is silently one rates-free tick — the typed `ReadError` exists for the `.integration` suite and direct callers, never for the loop. It is read on a detached `.utility` task, so it must never touch the main actor and must stamp `ContinuousClock.now` itself inside `readCounters()`.
- **Values the Application layer relies on**: `interfaceCount == 0` must return zero totals with a fresh stamp rather than throw (the sampler publishes it as totals 0 with `nil` rates, already pinned by `aScriptWithNoAdmittedInterfacePublishesZeroTotalsWithoutRates`); counters must be non-decreasing between reads, because a fall costs a tick of rates by design; the stamp must strictly advance between two reads or the window is discarded.
- **`AppDelegate` placeholder**: `PlaceholderNetworkProvider` at the top of `system-monitor/App/AppDelegate.swift`, injected at the single `MetricsSampler(...)` call. Task 5.1 swaps it for `SysctlNetworkProvider()` and deletes the struct; no other production file constructs a network provider.
- Both `makeSampler` helpers and the two inline test sites already default to `FakeNetworkProvider(counters: [])`, so batches C–G add no further compile pressure on the sampler initialiser.

## Batch C — Infrastructure (tasks 3.1–3.4)

### Completed tasks

- [x] 3.1 **RED** NM-11, NM-10 (pure seams) — `SysctlNetworkProviderTests.swift`
- [x] 3.2 **GREEN** NM-11, NM-10 (seams) — `SysctlNetworkProvider.swift` with `ReadError`, `mib`, `includes(type:flags:)`, `saturatingSum(_:_:)`
- [x] 3.3 **CONTINGENCY — skipped: not needed, every Darwin name imported at 3.2**
- [x] 3.4 **RED→GREEN** NM-10 (walk) — `SysctlNetworkIntegrationTests.swift` + the `NET_RT_IFLIST2` walk

### Files created

| File | Action | What it contains |
|---|---|---|
| `system-monitor/Infrastructure/System/SysctlNetworkProvider.swift` | Created | `nonisolated struct` conforming to `NetworkMetricsProvider`; nested `nonisolated enum ReadError { sizeQuery(errno:), listRead(errno:), malformedMessage(offset:) }`; private `mib`, `interfaceInfoMessageType`, `headerSize`, `interfaceInfoSize`, `ethernetType`, `cellularType`, `loopbackFlag` with header citations; `static includes(type:flags:)`; internal `static saturatingSum(_:_:)`; `readCounters()` (two-call sizing + one allocation) and the private `sum(_:length:)` walk |
| `system-monitorTests/Infrastructure/SysctlNetworkProviderTests.swift` | Created | 6 distinct cases; the NM-11 truth table is one parameterised case over 9 `InterfaceCase` rows |
| `system-monitorTests/Infrastructure/SysctlNetworkIntegrationTests.swift` | Created | 7 cases, `.tags(.integration)`, `.timeLimit(.minutes(1))` |

No tracked file was modified in batch C; `project.pbxproj` is untouched (convention 5). Batch C authored 415 lines across the three new files; cumulative change size stays inside the accepted `size:exception`.

### Contingency decision (task 3.3)

**Skipped: not needed, all names imported.** The 3.2 compile referenced `NET_RT_IFLIST2`, `RTM_IFINFO2`, `if_msghdr`, `if_msghdr2`, `IFT_ETHER`, `IFT_CELLULAR` and `IFF_LOOPBACK`, and 3.4's walk additionally reads `if_data64` through `ifm_data` (`ifi_type`, `ifi_ibytes`, `ifi_obytes`). Every one imported through `Darwin` on MacOSX26.5.sdk with zero compile errors, so no literal replacement was needed and the design gate's probe is confirmed. All header citations in the adapter were re-verified against the SDK headers before writing: `NET_RT_IFLIST2 = 6` `sys/socket.h:541`; `RTM_IFINFO2 = 0x12` `net/route.h:214`; `struct if_msghdr` `net/if.h:161`; `struct if_msghdr2` `net/if.h:202`; `struct if_data64` `net/if_var.h:189`; `IFT_OTHER 0x1` `net/if_types.h:76`; `IFT_ETHER 0x6` `:81`; `IFT_LOOP 0x18` `:99`; `IFT_GIF 0x37` `:134`; `IFT_STF 0x39` `:136`; `IFT_BRIDGE 0xd1` `:142`; `IFT_CELLULAR 0xff` `:149`; `IFF_UP 0x1` `net/if.h:93`; `IFF_LOOPBACK 0x8` `:96`; `IFF_RUNNING 0x40` `:99`.

### Sandbox proof and observed values (for the PRD 6.3 row that task 6.1 writes)

The routing-socket `sysctl` **is allowed inside App Sandbox**: the `.integration` suite runs in the sandboxed test host (`ENABLE_APP_SANDBOX = YES`) and all 7 cases pass, so neither `sysctl` call ever returned -1 and no entitlement was needed.

Observed in the sandboxed host on this machine (Apple Silicon, macOS 26.5), read from the expectation output of a temporary probe that was removed before the final green run:

| Value | Observed |
|---|---|
| `interfaceCount` | **14** admitted interfaces (`IFT_ETHER` / `IFT_CELLULAR` without `IFF_LOOPBACK`) |
| `bytesIn` | **301,295,616** (`> 0`, as NM-10 "Sandboxed shape" requires) |
| `bytesOut` | **94,707,712** |

The count is high because macOS publishes many `IFT_ETHER` interfaces (en0…enN Thunderbolt bridge members, `ap1`, `awdl0`, `llw0`); none of them is loopback, tunnel or bridge, so none double counts another interface's traffic. `interfaceCount` was identical across two back-to-back reads, which is what proves the two-call sizing walked the whole table.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 3.1 | `system-monitorTests/Infrastructure/SysctlNetworkProviderTests.swift` | Unit | N/A (new file; no tracked file modified in batch C) | ✅ `exit=65`, 14 × `Cannot find 'SysctlNetworkProvider' in scope` | ✅ 6/6 after 3.2 | ✅ 9 truth-table rows + 4 sum cases | ➖ None needed |
| 3.2 | same | Unit | N/A (new file) | (paired with 3.1) | ✅ `RUN SysctlNetworkProviderTests` exit 0, 6 distinct cases passed, 0 warnings | ✅ via 3.1 cases | ➖ None needed |
| 3.3 | — | — | — | ➖ Skipped: not needed, all names imported | ➖ | ➖ | ➖ |
| 3.4 | `system-monitorTests/Infrastructure/SysctlNetworkIntegrationTests.swift` | Integration (`.integration`, sandboxed test host) | N/A (new file) | ✅ `exit=65`, zero compile errors, 4 failing scenarios against the zero-interface stub: `theSandboxedHostSeesAtLeastOneInterfaceWithBytesIn`, `fiftyConsecutiveReadsAllSucceed`, `theSummedTotalsAreLargerThanZeroAndFitTheInterfaceCount`, `aLiveReadingPairProducesNonNegativeRates` | ✅ `-only-testing:…/SysctlNetworkIntegrationTests` exit 0, 7/7 passed | ✅ 7 cases (shape, monotonic + advancing stamp, 50 reads, stable count, stamp between surrounding instants, live rate pair, non-zero both directions) | ➖ None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild … -only-testing:system-monitorTests/SysctlNetworkProviderTests` → exit 0, 6 distinct cases passed, 0 failed |
| Runtime harness command/scenario and exact result | `xcodebuild … -only-testing:system-monitorTests/SysctlNetworkIntegrationTests` → exit 0, 7/7 passed in the sandboxed test host; `interfaceCount 14`, `bytesIn 301_295_616`, `bytesOut 94_707_712`. This is the App Sandbox proof NM-10 demands |
| Rollback boundary | Delete `system-monitor/Infrastructure/System/SysctlNetworkProvider.swift` and the two new test files; nothing tracked was touched, so batches A and B stay green on their own (`AppDelegate` still holds `PlaceholderNetworkProvider`, which task 5.1 replaces) |
| Batch close | `FULL` (`xcodebuild … test`) → exit 0, **616** distinct cases passed, 0 failed, 0 warnings. `UNIT` (`-only-testing:system-monitorTests`) → exit 0, **613** distinct cases passed, 0 failed, 0 warnings (600 after batch B + 6 unit + 7 integration). `git status --short`: 7 modified files from batches A–B plus the untracked new files; `project.pbxproj` untouched, nothing committed |

### Deviations from design

None in behaviour. Three readability choices inside the design's latitude, all recorded here:

1. **The walk lives in a private `static sum(_:length:)`** returning `(bytesIn:bytesOut:interfaceCount:)` instead of being inlined in `readCounters()`. The algorithm is the design's verbatim — short header first, length guard, wide header only for `RTM_IFINFO2`, `loadUnaligned` throughout, `saturatingSum` for both totals — but splitting it keeps `readCounters()` about the two `sysctl` calls and the walk about the messages. A tuple rather than a nested struct, so convention 1's "every nested type is `nonisolated` + `Sendable`" gains no new member to carry.
2. **Named private constants for the message type and the two sizes** (`interfaceInfoMessageType`, `headerSize`, `interfaceInfoSize`) rather than `RTM_IFINFO2` and `MemoryLayout<…>.size` inline. This is what let the 3.2 compile exercise every Darwin name the walk needs, so task 3.3's contingency could be decided at 3.2 as the tasks artifact requires, and it carries the header citation next to the name.
3. **`guard length > 0 else { return Self.empty() }` after the sizing call.** The design does not mention an empty table; passing `&buffer` for a zero-length array would hand `sysctl` a pointer with no storage. Returning the valid no-interface reading matches NM-10 "No admitted interface is not an error" rather than inventing a failure.
4. **A defensive `min(length, raw.count)` at `SysctlNetworkProvider.swift:129`**, where the design passes `length` straight into the walk. The two `sysctl` calls are separate: the first sizes the table, the second fills it, and the kernel is free to report a larger `length` on the second call if an interface appeared in between. Clamping to the buffer the process actually owns means such a race truncates the walk by one message instead of reading past the allocation, which is the difference between a slightly stale reading and undefined behaviour in the sampling loop.

### Issues found

**One transient environmental failure, resolved.** The first `FULL` run exited 65 with **zero failed test cases**: `system-monitorUITests-Runner encountered an error (The test runner failed to initialize for UI testing. (Underlying Error: Timed out while enabling automation mode.))`. That is the XCUITest runner's automation handshake, which runs before any project code and is unrelated to this batch. Isolating it confirmed the diagnosis: `-only-testing:system-monitorUITests` alone → exit 0, 4 UI cases passed; the re-run of `FULL` → exit 0, 616 distinct cases passed, 0 failed. The recorded `FULL` result is that green run. Worth knowing for task 7.1: this handshake can time out under load and a re-run clears it.

### Notes for batch D

- `SysctlNetworkProvider()` is ready for task 5.1's composition-root swap; it takes no arguments and holds no state.
- The adapter never throws on this machine, so the sampler's `try?` path stays untested by the integration suite by design; `MetricsSamplerStepTests` already covers the throw with `FakeNetworkProvider`.
- Batch D is Presentation (4.1–4.4) and touches no Infrastructure file.

## Batch D — Presentation tokens and multi-series graph (tasks 4.1–4.4)

### Completed tasks

- [x] 4.1 **RED** NC-10 (tokens) — `networkTokensMatchTheProductPalette` in the `PaletteTests` suite
- [x] 4.2 **GREEN** NC-10 (tokens) — three `Palette` tokens; `networkAccent` **replaced** with the measured value
- [x] 4.3 **RED** NC-9 — `HistoryGraphSeriesTests.swift` + the multi-series equality case in `CanvasComponentsTests.swift`
- [x] 4.4 **GREEN** NC-9 — `HistoryGraphSeries`, `init(series:capacity:)`, retained convenience init, `points(series:capacity:size:)` seam

### Files changed

| File | Action | What was done |
|---|---|---|
| `system-monitor/Presentation/Theme/Palette.swift` | Modified | `networkAccent = sRGB(0xC659E4)`, `networkDownload = sRGB(0x3DD68C)`, `networkUpload = sRGB(0x4D8DFF)`, each with the `memCached`-style "two tokens, one colour" note |
| `system-monitor/Presentation/Components/HistoryGraph.swift` | Modified | Top-level `nonisolated struct HistoryGraphSeries: Sendable, Equatable` (`samples`, `color`, `fillOpacity` defaulting to `SparklineGeometry.fillOpacity`); `HistoryGraph` now stores `series` + `capacity`; `init(series:capacity:)`; retained `init(samples:capacity:color:)` convenience; `nonisolated static points(series:capacity:size:)`; one `Canvas` drawing the shared baseline once then N series in array order, filling only when `fillOpacity > 0`; `Equatable` preserved; `#Preview` gained a two-line stroke-only graph and a partial/empty pair |
| `system-monitorTests/Presentation/HistoryGraphSeriesTests.swift` | Created | 6 cases in suite `HistoryGraphSeriesTests` |
| `system-monitorTests/Presentation/CanvasComponentsTests.swift` | Modified | `multiSeriesHistoryGraphsWithTheSameSeriesCompareEqual` in `CanvasComponentEqualityTests` (NC-9 "Equatable redraw skip") |
| `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Modified | `networkTokensMatchTheProductPalette` in `PaletteTests` |

`CPUCard.swift`, `MemoryCard.swift` and `project.pbxproj` are **not** in the diff (verified with `git status --porcelain`); the convenience initialiser kept both call sites byte-identical. Batch D authored 156 insertions / 17 deletions across 4 modified files plus 99 lines in one new file; cumulative change size stays inside the accepted `size:exception`.

### Measured `networkAccent` (task 4.2 replacement — for the PRD 7.1 row in task 6.1)

The design's estimate `0xA66BFF` was **replaced** with **`0xC659E4`**, and the same value is pinned in the 4.1 test.

`docs/reference/06-panel-network.png` (389×204) carries an **"Odyssey G5" display profile**, so the sampled number depends on whether the scan reads raw device bytes or converts to sRGB:

| Scan of the densest globe pixel at (25,27) | Value |
|---|---|
| Raw `NSBitmapImageRep.bitmapData` (native device values, what Digital Color Meter reports by default) | **`0xC659E4`** |
| The same pixel via `colorAt(x:y:).usingColorSpace(.sRGB)` | `0xD276EA` |

`0xC659E4` is the raw densest-pixel value and is the one pinned; it does not occur anywhere in the file under an sRGB-converted scan, which is a colour-profile artefact and not a disagreement about the pixel. Against the estimate `0xA66BFF` the raw deltas are **R +0x20, G −0x12, B −0x1B** — outside ±0x10 on every channel, so task 4.2's replacement rule fires. Anti-aliased neighbours are darker blends of the same hue (the sRGB-converted mean of the 20 brightest glyph pixels is `0xC278D7`), and the image is a compressed screenshot with no flat glyph colour.

Task 7.6 re-checks this with Digital Color Meter against the **running app**; because that tool also reports native values by default, `0xC659E4` is the value it should read back within ±0x10.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 4.1 | `system-monitorTests/Presentation/StatusItemReadingsTests.swift` | Unit | ✅ 18/18 (`PaletteTests` + `SparklineGeometryTests` + `CanvasComponentEqualityTests`), exit 0 | ✅ `exit=65`, 8 compile errors: `type 'Palette' has no member 'networkAccent' / 'networkDownload' / 'networkUpload'` | ✅ (4.2) `RUN PaletteTests` exit 0, 7 distinct cases passed | ➖ Skipped: purely structural — three colour constants, one possible output, no branching | ➖ None needed |
| 4.2 | same | Unit | N/A (paired) | (paired with 4.1) | ✅ `RUN PaletteTests` exit 0, 7 passed, 0 warnings | ➖ (as above) | ➖ None needed |
| 4.3 | `system-monitorTests/Presentation/HistoryGraphSeriesTests.swift`, `CanvasComponentsTests.swift` | Unit | ✅ 18/18 baseline above | ✅ `exit=65`, `cannot find 'HistoryGraphSeries' in scope`, `type 'HistoryGraph' has no member 'points'`, `extra argument 'series' in call` | ✅ 6/6 after 4.4 | ✅ 6 cases (two equal-length series, draw order + reversed order, 7-sample beside empty, empty series → `[[]]` and empty array → `[]`, convenience-init equivalence, per-series `fillOpacity`) + the equality case | ➖ None needed |
| 4.4 | same | Unit | N/A (paired) | (paired with 4.3) | ✅ `RUN HistoryGraphSeriesTests` exit 0, 6 passed; `SparklineGeometryTests` + `CanvasComponentEqualityTests` exit 0, 13 passed | ✅ via 4.3 cases | ➖ None needed |

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild … -only-testing:system-monitorTests/HistoryGraphSeriesTests` → exit 0, 6 distinct cases passed, 0 failed; `…/PaletteTests` → exit 0, 7 passed |
| Runtime harness command/scenario and exact result | N/A for an automated harness — the batch's runtime boundary is the Xcode `#Preview`, which cannot be driven from `xcodebuild`. The `#Preview` was extended with a stroke-only two-series graph and a partial/empty pair, and `BUILD` compiles it; the visual check belongs to task 7.6 |
| Rollback boundary | Revert `system-monitor/Presentation/{Theme/Palette,Components/HistoryGraph}.swift` and the two test-file additions, and delete `system-monitorTests/Presentation/HistoryGraphSeriesTests.swift`. Batches A–C stay green on their own; no other file depends on the new API yet |
| Batch close | `UNIT` → exit 0, **622** distinct cases passed, 0 failed, 0 compiler warnings. `BUILD` → exit 0, 0 warnings. `git status --short`: 11 modified files (7 from batches A–B, 4 from batch D) plus untracked new files; `project.pbxproj` untouched, nothing committed |

### Case-count reconciliation (matters for task 7.1)

The unit target reports **622** distinct passed cases against batch C's recorded **613**, but batch D only authored **8** new cases. The extra case is `MachIntegrationTests.swift:107`, `@Test(.enabled(if: SysctlReader().performanceLevelCount == 2))` — a conditionally-enabled case that its trait skipped during the batch C run and admitted during this one. It is environmental, not a batch D effect. Cross-check: the run's 622 distinct passed names equal the 622 `@Test` declarations in `system-monitorTests`, so every declared case ran and passed. Expect `UNIT` to report 621 **or** 622 depending on that trait.

### Deviations from design

None. `HistoryGraphSeries`, both initialisers, the `points(series:capacity:size:)` seam, the preserved `Equatable`, the single `Canvas` with one shared baseline, array draw order and the per-series `fillOpacity` default all match the design's Presentation block and decision 5 verbatim. Decision 8's tokens match, with the value replacement its own tolerance rule prescribes.

One recorded judgement inside the design's latitude: the body skips `context.fill` entirely when `fillOpacity == 0` rather than filling with a zero-opacity colour. Same rendering, one less no-op path per frame, and it makes "stroke only" explicit in the code.

### Issues found

**The verification command `-only-testing:system-monitorTests/CanvasComponentsTests` is vacuous.** It exits 0 while running **zero** test cases, because `CanvasComponentsTests` is a *file* name and `-only-testing` takes the Swift Testing *suite type* name (tasks.md convention: "`RUN <Suite>` … Swift Testing suite type name, not the file name"). That file declares two suites, `SparklineGeometryTests` and `CanvasComponentEqualityTests`; running those two gives exit 0, 13 distinct cases passed. Anything downstream that expects `RUN CanvasComponentsTests` to prove something must use the two suite names instead — a green exit code there proves nothing.

### Notes for batch E

- `HistoryGraph(series:capacity:)` is ready for task 4.8's `.graph` section; pass `fillOpacity: 0` on both series, which is what task 4.5 pins for `NetworkCardModel.graphSeries(download:upload:)`.
- `HistoryGraphSeries` is `nonisolated` + `Sendable`, so `NetworkCardModel.graphSeries` can stay a `nonisolated static func` and be asserted from a non-main-actor test.
- `HistoryGraph.points(series:capacity:size:)` is the assertion seam for anything that needs to check the card's rendered geometry without a view host.
- Constructing a `HistoryGraph` requires the main actor (default actor isolation is `MainActor`); the tests use `await MainActor.run`, the `CanvasComponentEqualityTests` precedent, and are never `@MainActor` themselves (convention 2).
- `Palette.networkAccent`/`networkDownload`/`networkUpload` exist now, so task 4.8's globe header and badges have their tokens.

---

## Batch E — Presentation card and fourth panel slot (tasks 4.5–4.8)

### Completed tasks

- [x] 4.5 **RED** NC-2 – NC-8, NC-10 (chrome), NC-13 (model) — `NetworkCardModelTests.swift`
- [x] 4.6 **GREEN** NC-2 – NC-8, NC-10 (chrome), NC-13 (model) — `NetworkCardRow`, `NetworkCardSection`, `NetworkCardModel`
- [x] 4.7 **RED** NC-1, NC-7 (height), NC-11, DC-1, DC-11 — `PanelViewTests.swift` additions
- [x] 4.8 **GREEN** NC-1, NC-3, NC-11, DC-1, DC-11 — the `NetworkCard` view half and `PanelView`'s fourth slot

### Files changed

| File | Action | What it contains |
|---|---|---|
| `system-monitor/Presentation/Panel/NetworkCard.swift` | Created | `NetworkCardRow`, `NetworkCardSection`, `NetworkCardModel` (sections, `graphCapacity` 120, `title`, three symbol names, unavailable pair, `graphFloorBytesPerSecond`, `rows`, `rateReadings`, `graphScale`, `normalised`, `graphSeries`, `animation`), the `NetworkCard` view with the `ForEach(sections)` switch and chrome constants, and two `#Preview`s (reference, nil) |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modified | `PanelCard.network`, `cards == [.cpu, .memory, .disk, .network]`, the switch arm binding `state.network`/`networkDownloadHistory`/`networkUploadHistory`, the live preview's network loop, doc comments |
| `system-monitorTests/Presentation/NetworkCardModelTests.swift` | Created | 21 cases covering NC-2..NC-8, NC-10 chrome and NC-13 |
| `system-monitorTests/Presentation/PanelViewTests.swift` | Modified | Four-card order (DC-1/NC-1), `networkCardHeight` helper, `fourCardChrome`, four new cases, refreshed height comments |

### Measured heights (for batch F's scroll cap and the PRD section 10 row that task 6.1 writes)

| Figure | Measured |
|---|---|
| CPU card | 370 pt |
| Memory card | 278 pt |
| Disk card | 175 pt |
| **Network card** | **166 pt** |
| Four-card chrome (3 spacings + 2 paddings) | 60 pt |
| **Four-card panel fitting height** | **1049 pt** |
| Three-card panel fitting height (unchanged) | 871 pt |

`370 + 278 + 175 + 166 + 60 = 1049`, exactly. The design's estimate for the card was 160–175 pt and for the panel ≈1050 pt; both land. 1049 pt exceeds a 14" display's ≈945 pt visible frame, which is precisely the condition NC-12 exists for, so batch F's `PanelLayout.maxHeight(fitting: 1049, visibleFrameHeight: 945)` will cap in production, not just in its unit fixture.

### TDD Cycle Evidence

| Task | Test File | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 4.5 | `Presentation/NetworkCardModelTests.swift` | Unit | N/A (new file) | ✅ Written first | — | — | — |
| 4.6 | `Presentation/NetworkCardModelTests.swift` | Unit | N/A (new production file) | ✅ Compile failure, `cannot find 'NetworkCardModel' in scope` | ✅ 21 cases passed | ✅ 21 cases: en_US + de_DE, populated + nil-rate + nil-snapshot + saturated `UInt64.max`, scale above floor + at floor, spike, capacity truncation | ✅ Clean — reading colours paired by `zip` rather than indexed |
| 4.7 | `Presentation/PanelViewTests.swift` | Integration (`NSHostingView`) | ✅ 12/12 before editing | ✅ Compile failure, `PanelCard has no member 'network'` | — | — | — |
| 4.8 | `Presentation/PanelViewTests.swift` | Integration (`NSHostingView`) | ✅ 12/12 | ✅ Then a real assertion failure, `(panel.height → 1049.0) > (threeCardHeight → 1049.0)` | ✅ 16 cases passed | ✅ 4 cases: card order, card-alone height, first-snapshot height stability, four-card sum, live reading | ✅ Clean |

### Test Summary

- **Total tests written**: 25 (21 `NetworkCardModelTests` + 4 `PanelViewTests`)
- **Total tests passing**: 25; unit target 647 distinct cases, 0 failed
- **Layers used**: Unit (21), Integration (4), E2E (0)
- **Approval tests**: None — no refactoring task in this batch
- **Pure functions created**: 7 (`rows`, `rateReadings`, `graphScale`, `normalised`, `graphSeries`, `animation`, plus the private `reading`)

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild … -only-testing:system-monitorTests/NetworkCardModelTests` → exit 0, 21 distinct cases passed, 0 failed; `…/PanelViewTests` → exit 0, 16 distinct cases passed, 0 failed |
| Runtime harness command/scenario and exact result | N/A for an automated harness — the batch's runtime boundary is the Xcode `#Preview` and the live popover, neither drivable from `xcodebuild`. `NetworkCard.swift` adds a reference and a nil `#Preview` and `PanelView`'s live preview now feeds 120 network ticks; `BUILD` compiles all three. The visual check belongs to task 7.6. The `NSHostingView` measurements in `PanelViewTests` are the closest automated proxy and are green |
| Rollback boundary | Delete `system-monitor/Presentation/Panel/NetworkCard.swift` and `system-monitorTests/Presentation/NetworkCardModelTests.swift`, and revert `PanelView.swift` and `PanelViewTests.swift`. Batches A–D stay green on their own: nothing outside these four files references `NetworkCard`, `NetworkCardModel` or `PanelCard.network` |
| Batch close | `UNIT` → exit 0, **647** distinct cases passed, 0 failed (622 baseline + 25 authored). `BUILD` → exit 0, 0 compiler warnings. `git status --short`: 13 modified files plus untracked new files; `CPUCard.swift`, `MemoryCard.swift`, `DiskCard.swift` and `project.pbxproj` are **not** in the diff; nothing committed |

### Symbol resolution settled (closes the design's open question)

`globe`, `arrow.down.circle.fill` and `arrow.up.circle.fill` all resolve through `NSImage(systemSymbolName:accessibilityDescription:)` on this SDK. **The design's unfilled fallback pair (`arrow.down.circle`/`arrow.up.circle`) was NOT needed and was not applied.**

### Deviations from design

None. `NetworkCardRow`, `NetworkCardSection`, every `NetworkCardModel` member signature, the `NetworkCard` section bodies, the chrome constants, decision 6's floor and symbol set, decision 10's order seam and decision 11's `.animation(_, value: snapshot)` on the `.ratesAndTotals` `HStack` all match the design verbatim.

Two recorded judgements inside the design's latitude:

1. The two rate readings are paired with their colours through `zip(rateReadings, readingColors)` and iterated by `ForEach(readings, id: \.reading.id)` rather than being indexed `[0]`/`[1]`. Same tree, but the view cannot silently mis-colour a badge if the model's order ever changes — the order stays owned by `rateReadings`.
2. `normalised(_:scale:)` returns zeros when `scale <= 0` instead of dividing. Unreachable through `graphSeries`, because `graphScale` never returns below the 10 000 floor, but the function is internal and a direct caller passing `0` would otherwise produce `NaN`/`inf`.

#### NC-4 colour clause: the reading text is not tinted (recorded 2026-09-10)

**The divergence.** NC-4 as originally written required the rate *reading* to carry `Palette.networkDownload` / `Palette.networkUpload`, which reads as "the text is tinted". The card does not tint the text. It reuses `ThroughputLabel` unchanged, and that component paints the value `Palette.textPrimary` (`system-monitor/Presentation/Components/ThroughputLabel.swift:56`) while applying the supplied colour to the icon only (`:53`).

**Why it was implemented this way, deliberately.** NC-4's own reuse half and confirmed product decision 7 both require the Network card to render its rates through the Disk card's `ThroughputLabel` rather than a second throughput component. `ThroughputLabel` is shared: tinting its value text to satisfy the Network card would have changed the Disk card's footer too and broken DC-7, which pins that text to the primary colour. The component was therefore left **unmodified**, and the direction token is carried by the icon — which is also what reference image 4.6 shows, a coloured badge beside neutral digits.

**Resolution.** The orchestrator amended NC-4 on 2026-09-10 (`specs/network-card/spec.md:61`) to read: "The download icon MUST use `Palette.networkDownload`; the upload icon MUST use `Palette.networkUpload`; the value text keeps the label's primary text colour, as in DC-7 and reference 4.6". The implementation already satisfies the amended clause; nothing in `ThroughputLabel.swift`, `DiskCard.swift` or the Disk card's tests was touched.

**Executable coverage added in the batch G corrective re-run.** The colour order had no assertion of its own — it lived in a view-private `NetworkCard.readingColors` that no test could reach, so only the graph series' colours (NC-9) were pinned. It is now `NetworkCardModel.readingColors`, the single source of truth the view zips against, covered by `NetworkCardModelTests.theReadingColoursAreDownloadThenUpload()`. See batch G.

### Issues found

**The four-card height cannot be compared against a rendered "three-card panel".** The first draft of `thePanelGrowsByTheFullNetworkCard` measured a panel with `network == nil` and expected the four-card panel to exceed it. It does not: both measure exactly 1049.0 pt, because `PanelView` always renders four slots and the Network card's skeleton is the same height as its populated form. That is NC-7 working, not a bug. The test now builds the three-card figure as a sum (`cpu + memory + disk + threeCardChrome` = 871 pt), which is the same shape `thePanelGrowsByTheFullDiskCard` already used for its two-card figure. Anything downstream that wants a "before the fourth card" height must compute it, never render it.

### Notes for batch F

- `PanelLayout` does not exist yet; task 4.10 creates it. `PanelView` still has **no** `maxHeight` parameter and **no** `ScrollView` branch, so `PanelView()` remains byte-identical to the three-card tree apart from the extra card — which is what keeps the 16 existing `PanelViewTests` assertions green.
- Task 4.9's `PanelView(maxHeight: 600)` vs `PanelView()` assertion has real headroom: the uncapped panel measures **1049 pt**, comfortably `> 600`.
- Task 4.9's `StatusItemController.panelMaxHeight(for: fourCardState, visibleFrameHeight: 945)` will measure a fitting height of 1049 pt against a 945 pt frame, so it must return `945 - 24 = 921`; with `2000` it must return `nil`.
- `PanelViewTests` now carries `fourCardChrome` (60) and a `networkCardHeight(for:)` helper; reuse them rather than re-deriving.
- Use the Swift Testing **suite type** name with `-only-testing` (`NetworkCardModelTests`, `PanelViewTests`). A file name exits 0 having run zero cases — see batch D's issue.

---

## Batch F — Visible-frame scroll cap (tasks 4.9–4.10)

### Completed tasks

- [x] 4.9 **RED** NC-12 — `PanelLayoutTests.swift` + additions to `PanelViewTests.swift` and `StatusItemControllerTests.swift`
- [x] 4.10 **GREEN** NC-12 — `PanelLayout`, `PanelView(maxHeight:)`, `PanelRootView`, and the controller's stored `hostingController` + `updatePanelCap()` + `panelMaxHeight(for:visibleFrameHeight:)`

### Files changed

| File | Action | What it contains |
|---|---|---|
| `system-monitor/Presentation/Panel/PanelLayout.swift` | Created | `nonisolated enum PanelLayout` importing `CoreGraphics` only: `screenMargin = 24`, `maxHeight(fitting:visibleFrameHeight:margin:) -> CGFloat?` (`nil` when the cap is non-positive or the panel fits) and `height(fitting:visibleFrameHeight:margin:) = maxHeight(...) ?? fitting` |
| `system-monitor/Presentation/Panel/PanelView.swift` | Modified | `var maxHeight: CGFloat? = nil`; `body` branches to `ScrollView(.vertical) { cardsStack }.scrollBounceBehavior(.basedOnSize).frame(width: 320, height: maxHeight).background(Palette.panelBackground)` when a cap is supplied and to `cardsStack` otherwise; the old body extracted verbatim into `private var cardsStack`; new `PanelRootView(state:maxHeight:)`; a third `#Preview` showing the four cards capped to 921 pt |
| `system-monitor/Presentation/MenuBar/StatusItemController.swift` | Modified | Stored `private let hostingController: NSHostingController<PanelRootView>` built in `init` and assigned in `configurePopover()` (the inline `NSHostingController(rootView: PanelView().environment(state))` is gone); `private static measuredPanelHeight(for:)`; internal `static panelMaxHeight(for:visibleFrameHeight:)`; `private func updatePanelCap()`; `togglePopover()`'s show branch calls `updatePanelCap()` before `popover.show(...)` |
| `system-monitorTests/Presentation/PanelLayoutTests.swift` | Created | 6 cases in suite `PanelLayoutTests` |
| `system-monitorTests/Presentation/PanelViewTests.swift` | Modified | `fittingSize(for:maxHeight:)` helper plus 2 NC-12 cases |
| `system-monitorTests/Presentation/StatusItemControllerTests.swift` | Modified | `fourCardState()` helper plus 3 NC-12 cases |

`project.pbxproj` is **not** in the diff. Batch F authored ~432 insertions / ~13 deletions across two new files and four modified ones (`PanelLayout.swift` 52 lines, `PanelLayoutTests.swift` 75 lines, `StatusItemController.swift` +65/−3, `StatusItemControllerTests.swift` +77, plus the `PanelView.swift` / `PanelViewTests.swift` portions); cumulative change size stays inside the accepted `size:exception`.

### The measured cap (task 7.5's expected figure)

`StatusItemController.panelMaxHeight(for: fourCardState, visibleFrameHeight: 945)` returns **921.0** — 945 − 24, asserted as an exact equality rather than a bound. The same state against 1 000 pt returns 976.0 and against 1 200 pt returns `nil`, which is what proves the controller measured the real 1 049 pt panel rather than a constant: the branch flips between 1 073 pt and 1 176 pt of available room, exactly where a 1 049 pt panel would put it.

### Root-swap timing (design open question 5)

**The root swap happens before `popover.show(...)`**, inside `togglePopover()`'s show branch, as decision 7 prescribes. It is a `hostingController.rootView` assignment on a hosting controller the popover already owns, so it issues no second `show` and MBW-13's "one `show`/`performClose` per transition" is untouched — `togglingTwiceNeverReportsASecondOpen` and `thePopoverDelegateReportsEachTransitionOnce` are both green. Open question 5 (moving the swap into `popoverWillShow` if the cap lags one open) stays open for **manual check 7.5**; nothing observed in this batch argues for it, but only a real display change can settle it.

### TDD Cycle Evidence

| Task | Test file | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 4.9 | `Presentation/PanelLayoutTests.swift` | Unit | ✅ 37/37 (`PanelViewTests` 16 + `StatusItemControllerTests` 12 + `StatusItemControllerMenuTests` 9), exit 0 | ✅ `exit=65`, 16 × `cannot find 'PanelLayout' in scope` | ✅ 6/6 after 4.10 | ✅ 6 cases (1050/945 → 921, 871/1132 → nil, 921/945 → nil, non-positive cap at 20 and 24, margins 0/100/900, branch flip at 900 pt) | ➖ None needed |
| 4.9 | `Presentation/PanelViewTests.swift` | Integration (`NSHostingView`) | ✅ 16/16 | ✅ `exit=65`, `PanelViewTests.swift:60:44: argument passed to call that takes no arguments` (`PanelView(maxHeight:)`) — surfaced by isolating the file, see "Issues found" | ✅ 18/18 after 4.10 | ✅ 2 cases (600 pt cap against a 1 049 pt panel; 1 500 pt cap the panel fits inside, cross-checked against `PanelLayout.maxHeight`) | ➖ None needed |
| 4.9 | `Presentation/StatusItemControllerTests.swift` | Integration (real `NSStatusItem` + `NSHostingView`) | ✅ 12/12 | ✅ `exit=65`, 4 × `type 'StatusItemController' has no member 'panelMaxHeight'` | ✅ 15/15 after 4.10 | ✅ 3 cases (945 → 921, 2000 → nil, 1000 → 976 beside 1200 → nil) | ➖ None needed |
| 4.10 | all three | Unit + Integration | N/A (paired) | (paired with 4.9) | ✅ `PanelLayoutTests` + `PanelViewTests` + `StatusItemControllerTests` + `StatusItemControllerMenuTests` → exit 0, **48** distinct cases passed, 0 failed, 0 warnings | ✅ via the 4.9 cases | ✅ Clean — the pre-cap body extracted verbatim into `cardsStack`, so the uncapped branch is the same tree it always was |

### Test Summary

- **Total tests written**: 11 (6 `PanelLayoutTests` + 2 `PanelViewTests` + 3 `StatusItemControllerTests`)
- **Total tests passing**: 11; unit target 659 distinct cases, 0 failed
- **Layers used**: Unit (6), Integration (5), E2E (0)
- **Approval tests**: None — the `cardsStack` extraction is behaviour-preserving by construction and is covered by the 16 pre-existing `PanelViewTests` assertions, which stayed green throughout
- **Pure functions created**: 2 (`PanelLayout.maxHeight`, `PanelLayout.height`)

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild … -only-testing:system-monitorTests/PanelLayoutTests` → exit 0, 6 distinct cases passed, 0 failed; the four-suite run → exit 0, 48 distinct cases passed, 0 failed |
| Runtime harness command/scenario and exact result | N/A for an automated harness — the real boundary is a live popover on a physical 14" display, which `xcodebuild` cannot drive. The closest automated proxies are green: `StatusItemControllerTests` builds a real `NSStatusItem`, measures the real four-card panel and returns 921.0 for a 945 pt frame, and `PanelViewTests` measures the capped `NSHostingView` at exactly 600 pt. A third `#Preview` renders the capped panel and `BUILD` compiles it. The physical check is **task 7.5** |
| Rollback boundary | Delete `system-monitor/Presentation/Panel/PanelLayout.swift` and `system-monitorTests/Presentation/PanelLayoutTests.swift`, and revert `PanelView.swift`, `StatusItemController.swift`, `PanelViewTests.swift` and `StatusItemControllerTests.swift`. Batches A–E stay green on their own; reverting only this pair restores today's unbounded popover, which still fits three cards |
| Batch close | `UNIT` → exit 0, **659** distinct cases passed, 0 failed, 0 warnings (647 after batch E + 11 authored + 1 conditionally-enabled `MachIntegrationTests` case, see batch D's reconciliation). `BUILD` → exit 0, **0** compiler warnings. `git status --short`: 15 modified files plus untracked new files; `project.pbxproj` is **not** in `git diff --name-only`; nothing committed. `git diff --stat`: 1 172 insertions, 45 deletions across 15 files |

### Deviations from design

None in behaviour or signature. `PanelLayout.screenMargin`, both function signatures with their defaulted `margin:`, `PanelView.maxHeight`, the `ScrollView(.vertical)` + `.scrollBounceBehavior(.basedOnSize)` + `frame(width: 320, height:)` branch, `PanelRootView(state:maxHeight:)`, the stored `hostingController`, `updatePanelCap()` before `show`, and `panelMaxHeight(for:visibleFrameHeight:)` measuring a throwaway `NSHostingView` all match decision 7 and the `StatusItemController` paragraph verbatim.

Three recorded judgements inside the design's latitude:

1. **`PanelLayout.swift` imports `CoreGraphics`, not `SwiftUI`.** It needs `CGFloat` and nothing else, and the narrower import is the compiler enforcing decision 7's "AppKit stays out of the layout rule" rather than a comment asserting it.
2. **`maxHeight` declines to cap on a non-positive result** (`guard cap > 0`) rather than returning a negative height. The design's table names the `nil`-when-it-fits branch but not this one; NC-12's "Content MUST NOT be clipped" settles it, and the tasks artifact already pinned `maxHeight(1050, 20) == nil`.
3. **`Palette.panelBackground` is applied twice in the capped branch** — once inside `cardsStack` and once on the frame outside the scroll view. The design says "the background also wraps the scroll view". Same rendering when the content overflows (which is the only case a cap is supplied in), and it keeps the popover chrome painted if a future card set ever leaves the frame short.

### Issues found

**A failing test file can mask another file's RED.** The first RED run reported only `PanelLayoutTests`' 16 errors; after `PanelLayout` existed, the second reported only `StatusItemControllerTests`' four. `PanelViewTests`' own error never appeared in either, because `swift-frontend` compiles the test target in parallel primary-file batches and xcodebuild cancels the remaining batches once one fails — `SWIFT_ENABLE_BATCH_MODE=NO` did not change that. The RED was confirmed by temporarily reverting `StatusItemControllerTests.swift`, rebuilding (`PanelViewTests.swift:60:44: argument passed to call that takes no arguments`), then restoring it. Anything downstream that reads a compile log as a complete error inventory is reading a truncated one; verify per file when the claim matters.

### Notes for batch G

- `SysctlNetworkProvider()` is still waiting for task 5.1's composition-root swap; `AppDelegate.swift` continues to hold `PlaceholderNetworkProvider`, which 5.1 deletes.
- Task 6.1's PRD section 10 row wants the four-card height **1 049 pt** and the cap **921 pt on a 945 pt visible frame**; R2.5's scroll rule is `PanelLayout.maxHeight(fitting:visibleFrameHeight:margin: 24)`.
- Task 6.1's 6.1-tree row: `Panel/` now really does contain `NetworkCard, PanelLayout (M6)`, and `PanelView.swift` also declares `PanelRootView`.
- Task 7.1 should expect `UNIT` to report **659 or 660** distinct passed cases, for the same conditionally-enabled `MachIntegrationTests` reason batch D recorded.
- Task 7.5's expected observation: the popover pinned at 921 pt on the 14" display, scrolling to reach the Network card. If the cap lags one open after a display change, design open question 5 says to move `updatePanelCap()` into `popoverWillShow` — the call is one line in `togglePopover()`'s show branch, and `panelMaxHeight` itself needs no change.

---

## Batch G — Composition root, product documentation and verification (tasks 5.1, 6.1, 6.2, 7.1, 7.2)

### Completed tasks

- [x] 5.1 **RED→GREEN** NM-12 — two new `AppDelegateCompositionTests` cases, then `networkProvider: SysctlNetworkProvider()` in `AppDelegate.swift` with `PlaceholderNetworkProvider` deleted
- [x] 6.1 **DOC** NM-13 — `PRD.md` raised to Draft v4 (design "PRD Alignment" items 1–17)
- [x] 6.2 **DOC** NM-13 — `openspec/config.yaml` proposal rule and product line
- [x] 7.1 `FULL` run recorded below
- [x] 7.2 `BUILD` run recorded below, plus the `project.pbxproj` and reference-image checks

Tasks **7.3–7.7 are MANUAL and remain `[ ]`**; they are the user's to run. See "Manual checks still open" below.

### Files changed

| File | Action | What it contains |
|---|---|---|
| `system-monitorTests/App/AppDelegateCompositionTests.swift` | Modified | New `// MARK: - Network provider (NM-12)` section with `theRealGraphPublishesRealNetworkReadings()` (awaits `state.network`, then a snapshot whose `downloadBytesPerSecond` is non-nil; asserts both since-boot totals are `> 0`, both rates non-nil, and that the totals never go backwards) and `publishingNetworkReadingsLeavesTheModulesAndWidgetUnchanged()` (asserts `MetricModule.allCases == [.cpu, .memory]`, `menuBarOrder` likewise, and that `statusItemLength` survives both the loop's own reading and `state.apply(network: NetworkFixtures.referenceSnapshot)`) |
| `system-monitor/App/AppDelegate.swift` | Modified | `PlaceholderNetworkProvider` (struct + doc comment, 18 lines) deleted; the sampler now receives `networkProvider: SysctlNetworkProvider()`. Net effect against `de40106` is a single added line |
| `PRD.md` | Modified | Draft v4: header, section 1, section 2 anti-goals + success metric, F2 wording and the new `F11` row, new 4.6, R2.2 order and new R2.5, R5.1/R5.2, the new section 5.8 (R11.1–R11.11), the 6.1 tree, the 6.2 models, the 6.3 data-source row, the 7.1 palette rows, the 7.3 note, the section 8 rows, `M6 Network` with GPU at `M7`, the section 10 popover-height and interface-churn rows, open question 3 answered, and the section 11 milestone reference |
| `openspec/config.yaml` | Modified | Exactly two lines: the proposal rule now reads `F1..F11` / `M1..M6`, and the `context` product line now reads `Draft v4: v1 = CPU + RAM + Disk; M6 Network (F11) added 2026-09-10; GPU deferred to v2 as M7` |

`project.pbxproj` is **not** in `git diff --name-only`. `docs/reference/06-panel-network.png` is present (53 634 bytes, untracked, read-only input).

### TDD Cycle Evidence

| Task | Test file | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| 5.1 | `App/AppDelegateCompositionTests.swift` | Integration (real composition root, `.integration`) | ✅ 10/10 `AppDelegateCompositionTests`, exit 0 | ✅ `theRealGraphPublishesRealNetworkReadings()` **failed** on both test processes (5.23 s and 5.21 s — the 5 s `awaitValue` deadline expired), because `PlaceholderNetworkProvider` reads no interface and publishes zero totals forever | ✅ After the swap: exit 0, 12/12 distinct cases passed, 0 failed | ✅ 2 cases — the real-reading case and the modules/width case exercise different code paths (the sysctl walk versus the widget measurement under `apply(network:)`) | ➖ None needed — the change is one injected argument and one deleted stand-in |
| 6.1 | — | Documentation | N/A | N/A — NM-13 is a documentation requirement with no executable scenario | N/A | N/A | N/A |
| 6.2 | — | Documentation | N/A | N/A — same | N/A | N/A | N/A |

**Why the RED is a real RED.** The placeholder returns zero deltas over a real elapsed time, so the calculator produces a rate pair of `0 B/s` — non-nil. A case asserting only "rates are eventually non-nil" would therefore have passed against the stand-in and proved nothing. The discriminator is `totalIn > 0` / `totalOut > 0`, mirroring the disk case's `first.total > 0`; that is what failed before the swap and passes after it.

### Test Summary

- **Total tests written**: 2 (both integration, in the existing suite)
- **Total tests passing**: 2; unit target **661** distinct cases, 0 failed
- **Layers used**: Unit (0), Integration (2), E2E (0)
- **Approval tests**: None — no refactoring task in this batch
- **Pure functions created**: 0

### Work Unit Evidence

| Evidence | Value |
|---|---|
| Focused test command and exact result | `xcodebuild … -only-testing:system-monitorTests/AppDelegateCompositionTests` → exit 0, **12** distinct cases passed, 0 failed (baseline 10 + 2 authored) |
| Runtime harness command/scenario and exact result | The real graph itself is the harness: `AppDelegateCompositionTests` builds the production `AppDelegate`, starts the detached sampling loop and reads what `SysctlNetworkProvider` publishes through `MetricsState`. Green, with non-zero since-boot totals and a real rate pair. The remaining runtime boundary — a live popover on a physical display — is manual tasks 7.3–7.7 |
| Rollback boundary | Revert `system-monitor/App/AppDelegate.swift` (restoring `PlaceholderNetworkProvider`), the network section of `system-monitorTests/App/AppDelegateCompositionTests.swift`, `PRD.md` and `openspec/config.yaml`. Batches A–F stay green on their own; nothing else in this batch touches production behaviour |
| Batch close | `FULL` → exit 0, **664** distinct cases passed, 0 failed, 0 warnings. `UNIT` → exit 0, **661** distinct cases passed, 0 failed. `BUILD` (`build`) → exit 0, **0** warnings; `build-for-testing` → exit 0, **0** warnings. `git status --short`: 18 modified files plus untracked new files; `project.pbxproj` untouched, nothing committed. `git diff --stat`: **1 307 insertions, 73 deletions** across 18 tracked files, inside the accepted `size:exception` |

### Verification runs (tasks 7.1 and 7.2)

| Command | Observed result |
|---|---|
| `FULL` = `xcodebuild … -quiet test` | exit 0 — **664** distinct cases passed, **0** failed. No XCUITest automation-mode timeout this time, so the single run stands; the three UI cases (`system_monitorUITests.testExample`, `.testLaunchPerformance`, `system_monitorUITestsLaunchTests.testLaunch`) all ran |
| `UNIT` = `… -only-testing:system-monitorTests` | exit 0 — **661** distinct cases passed, **0** failed (659 after batch F + 2 authored). Cross-check: `system-monitorTests` declares exactly 661 `@Test` cases, so every declared case ran; `FULL` = 661 unit + 3 UI = 664 |
| `BUILD` = `… -quiet build` | exit 0, **0** compiler warnings |
| `… -quiet build-for-testing` | exit 0, **0** compiler warnings — run in addition, because task 7.2 asks for a build that actually recompiles the touched test target and plain `build` does not |
| `docs/reference/06-panel-network.png` | Present, 53 634 bytes, untouched |
| `git diff --name-only` | `project.pbxproj` absent — no test-run noise to revert |

### Issues found

**1. Counting distinct cases from an xcodebuild log needs a tolerant match.** Under `-quiet`, xcodebuild's own `IDETestOperationsObserverDebug` timestamps interleave into the middle of a result line, so a line can read `Test case 'MetricsStateTests/memoryHistoryStaysBounded…()' p2026-09-10 12:46:11.556 xcodebuild[…]`. Matching on `' passed` therefore under-counts: it lost one case in each log (`memoryHistoryStaysBoundedAtOneHundredTwentySamples` in `UNIT`, `theInjectedIntervalIsExactlyWhenTheNextSampleLands` in `FULL`). Both cases really ran and really passed — exit 0 with zero `failed` lines, and the counts reconcile against the 661 `@Test` declarations. Match on `Test case '<id>'` and count `failed` separately.

**2. The `MachIntegrationTests` conditional case ran this time.** Batch D predicted `UNIT` would report 659 **or** 660 for batch G's baseline depending on `@Test(.enabled(if: SysctlReader().performanceLevelCount == 2))`. It was admitted in every run of this batch, so the baseline was the full 659 and the total is 661, not 660.

**3. The specs and the design numbered a few R11.x rules differently — RESOLVED by the orchestrator on 2026-09-10.** `PRD.md` follows the design's "PRD Alignment" item 8 ordering, which task 6.1 names as normative: R11.7 paired histories, R11.8 shared graph scale, R11.9 formatting reuse, R11.10 unavailable states, R11.11 palette and no menu bar module. Three spec cross-references had been written against a neighbouring numbering. All three are now corrected in the spec files: `specs/network-metrics/spec.md:273` (`NM-12`) cites **R11.11**, and `specs/network-card/spec.md:129` (`NC-8`) and `:151` (`NC-9`) cite **R11.8**. No PRD change was needed and none was made; the entry is kept for the audit trail.

### Deviations from design

1. **`networkAccent` is `#C659E4`, not the design's `#A66BFF`.** The PRD's 7.1 row carries the measured value and says why, per task 4.2's replacement rule and batch D's measurement. The design's item 12 estimate is superseded.
2. **Section 10 carries the exact measured figures** (1 049 pt for four cards, ~945 pt visible, 921 pt cap) rather than the design's "~1050 pt" placeholder, which is what task 6.1's closing sentence asks for.
3. **`build-for-testing` was run in addition to `build`.** Task 7.2's `BUILD` alias is `build-for-testing`; the phase's verification contract names `build`. Both were run and both are green, so no interpretation of 7.2 is left unproven.

Nothing else departs from the design. The composition root matches decision 9 verbatim: one `SysctlNetworkProvider()` injected into the single `MetricsSampler`, with no `MetricModule`, settings, widget or login-item change.

### Manual checks still open (tasks 7.3–7.7, user-owned)

| Task | What it must observe |
|---|---|
| 7.3 Live rates (R11.4) | With the popover open, start a large download and a large upload: both readings must move, then fall back to low values or em dashes when the transfer ends. Record the peak figures |
| 7.4 Totals correctness (section 2 success metric) | Total In / Total Out against Activity Monitor's Network tab Data received / Data sent — the same order of magnitude. Record both pairs |
| 7.5 Visible-frame cap (NC-12, R2.5) | On the 14" display at default scaling the four-card popover must be pinned at **921 pt** and scroll to the Network card without clipping, and must cap on the **first** open after a display change. If it lags one open, move `updatePanelCap()` into `popoverWillShow` in `StatusItemController.swift` (design open question 5) and re-run `RUN StatusItemControllerTests` |
| 7.6 Accent, unavailable and motion | Digital Color Meter on the running app must read the globe accent within ±0x10 of **`0xC659E4`** (it reports native values by default, as batch D's measurement did); the no-rate path must show em dashes rather than `0 B/s`, with VoiceOver reading "unavailable"; Reduce Motion must change nothing observable on this card |
| 7.7 Instruments (sections 8 and 10) | Time Profiler, panel closed, 10 minutes with the network step running: average CPU under 1%. Record it and the resident size next to the M5 baseline; the figure goes into the verify report |

### Corrective re-run (2026-09-10) — NC-4 colour clause

The fresh-context apply gate returned FAIL on one narrow point: the amended NC-4 colour clause had no executable assertion, because the colour order lived in a view-private `NetworkCard.readingColors`. One permitted corrective re-run added it under strict TDD.

| Task | Test file | Layer | Safety Net | RED | GREEN | TRIANGULATE | REFACTOR |
|---|---|---|---|---|---|---|---|
| NC-4 colour clause | `Presentation/NetworkCardModelTests.swift` | Unit | ✅ 22/22 `NetworkCardModelTests`, exit 0 | ✅ `exit=65`, 2 × `type 'NetworkCardModel' has no member 'readingColors'` (`NetworkCardModelTests.swift:130,132`) | ✅ exit 0, **23** distinct cases passed, 0 failed, 0 warnings | ➖ Single — NC-4 defines exactly one colour order; the second `#expect` pins the count against `rateReadings` so the two can never fall out of step | ✅ Clean — the array moved rather than being copied, so there is still one source of truth |

Production change, smallest that satisfies the test: the existing `nonisolated private static let readingColors` moved off the `NetworkCard` view onto `NetworkCardModel` (internal, with the DC-7 rationale in its doc comment), and `NetworkCard.readings` now zips `NetworkCardModel.readingColors`. No duplicate array was introduced and no behaviour changed — the view renders the same colours in the same order.

**`ThroughputLabel.swift` was NOT modified**, by instruction and by DC-7: it is shared with the Disk card's footer, and tinting its value text would change that card too. Tasks 7.3–7.7 were not touched.

Also recorded in this re-run: the NC-4 divergence and its spec amendment (batch E deviations), the resolution of stale issue 3 (batch G), and the `min(length, raw.count)` clamp (batch C deviations).

### Status

**32/37 tasks complete.** Every automated task in the change is done and green. The five open tasks are exactly the manual checks 7.3–7.7, which only a person at the running app can perform and which remain `[ ]` in `tasks.md`.

**next_recommended: sdd-verify.** The automated scope is closed; verify can run now with 7.3–7.7 recorded as open, or after the user performs them (task 7.7's CPU figure is owed to the verify report either way).

---

## Review correction (2026-09-10) — `R3-zero-interface-baseline`

Native review lineage `review-6998e0189040a8d8`, reliability lens, severity **CRITICAL**, deterministic, introduced by this candidate. This is the one bounded correction the review permits (budget 200 changed lines). Scope was limited to this finding.

### The defect, confirmed against the code

`NetworkThroughputCalculator.rates(previous:current:)` guarded only `current.interfaceCount > 0`; `previous.interfaceCount` was never inspected. `SysctlNetworkProvider` deliberately returns a **valid** reading with `interfaceCount 0` and zero totals when nothing passes the filter, and `NetworkSamplingStep` re-seeds its baseline with every reading unconditionally. The first populated tick after a zero-interface reading therefore computed `current.bytesIn − 0` over one window and published the machine's entire since-boot totals as a rate — gigabytes per second. `MetricsState.apply(network:)` appends any available pair to both histories, so that fabricated sample became the shared graph divisor (R11.8) and would have flattened the next 120 real samples.

The proof gap was real: the only zero-interface case placed the reading in `current`, and the sampler's idle case repeated the idle fixture forever, so no test ever crossed idle → populated.

### Edits

| File:line | Change |
|---|---|
| `system-monitor/Domain/Services/NetworkThroughputCalculator.swift:48-52` | The guard became `guard let previous, previous.interfaceCount > 0, current.interfaceCount > 0 else { return nil }` |
| `system-monitor/Domain/Services/NetworkThroughputCalculator.swift:27-41` | Doc comment now says "**either** reading covers no interface" and explains the two halves of interface churn: the disappearing half is the falling-counter guard, the reappearing half is this one |
| `system-monitorTests/Domain/NetworkThroughputCalculatorTests.swift:77-99` | New case `aZeroInterfaceBaselineYieldsNoRates()` |
| `system-monitorTests/Application/MetricsSamplerTests.swift:749-816` | New case `theIdleToPopulatedTransitionCostsOneRateFreeTick()` |
| `openspec/changes/network-module/specs/network-metrics/spec.md:61` | NM-4 rule now reads "when **either** reading has `interfaceCount == 0`", with the rationale sentence |
| `openspec/changes/network-module/specs/network-metrics/spec.md:85-89` | New scenario "Zero-interface baseline yields nil" |
| `PRD.md` R11.4 | One sentence: a zero-interface reading is never one end of a window, and the first populated tick after one costs a rate-free tick |

### TDD evidence

| Step | Command | Observed |
|---|---|---|
| RED (calculator) | `… -only-testing:system-monitorTests/NetworkThroughputCalculatorTests` | `exit=65` — `aZeroInterfaceBaselineYieldsNoRates()` **failed** on both test processes |
| GREEN (calculator) | same | exit 0, **11** distinct cases passed, 0 failed |
| RED (sampler) | `… -only-testing:system-monitorTests/MetricsSamplerStepTests` with the guard temporarily reverted | `exit=65` — `theIdleToPopulatedTransitionCostsOneRateFreeTick()` **failed**, 6 recorded issues (the three step-2 assertions plus both history assertions, across both processes) |
| GREEN (sampler) | same, guard restored | exit 0, **38** distinct cases passed, 0 failed |

**A ghost-green was caught and removed.** The sampler case was first scripted `[idle, referencePrevious, referenceCurrent]` as suggested, and it passed even with the guard reverted. The reason is that `NetworkFixtures.idle` and `NetworkFixtures.referencePrevious` are **both stamped at `at: 0`**, so step 2 was a zero-length window and the case was satisfied by the `elapsed > 0` guard without ever reaching the baseline rule. The script is now explicit counters stamped 0, 1 and 2, which is what produced the true RED above. Any future case that needs an idle → populated crossing must stamp its own fixtures; the two shared reference fixtures cannot be chained after `idle`.

The calculator fix alone was sufficient to make the sampler case pass — the sampler needed no change. It is kept as the transition proof, since it is the only test that exercises the provider → step → state → history path across the crossing.

### Supersedes

`verify-report.md` **W1 (zero-interface path)** is superseded by this correction. The verify report itself was not edited.

### Correction size

**≈117 added / 7 replaced authored lines** across 6 files, inside the 200-line correction budget (forecast 60; the overrun is comment, not logic — the two new cases carry the reasoning that made the defect invisible). Measured: `system-monitorTests/Application/MetricsSamplerTests.swift` is tracked and its `git diff --numstat` went **330 → 401 insertions (+71)**; the calculator's new case is ~24 lines, the calculator's doc comment and guard ~13, the spec scenario 6, and `PRD.md` R11.4 one replaced line (its numstat stays 78/26). `project.pbxproj` absent from `git diff --name-only`; nothing committed (HEAD still `de40106`); tasks 7.3–7.7 still `[ ]`.

---

## Correction (2026-09-10): IFMIB 64-bit counters

User-requested correction after manual check **7.3**. The data source was wrong: the adapter now reads the interface MIB (`net/if_mib.h`) instead of the routing socket.

### What the user saw, and why

During a large download the rate readings showed em dashes for a tick and Total In appeared to reset to a small value; the graph was unaffected. Nothing in the app was at fault downstream — NM-4 was doing exactly what it should with the numbers it was given.

**Root cause.** `NET_RT_IFLIST2` → `if_msghdr2.ifm_data` declares `ifi_ibytes`/`ifi_obytes` as `u_int64_t`, but this platform's driver fills only the low 32 bits, so the counter wraps every 4 GB. The wrap makes the summed delta negative, NM-4 returns `nil` (em dashes, baseline re-seed) and the snapshot carries the wrapped sum (the apparent reset).

**Independently reproduced here** with a compiled Swift probe, no download running, reading both sources in the same process microseconds apart:

| Interface | Interface MIB `ifi_ibytes` | Routing socket `ifi_ibytes` |
|---|---|---|
| `en1` | **13 563 204 219** | 678 301 696 |
| `awdl0` | 44 233 | 44 032 |

`13 563 204 219 − 3 × 2^32 = 678 302 331`, against the routing socket's 678 301 696 — the low 32 bits exactly, the ~600-byte gap being background chatter between the two reads. The design gate's compiled probe had confirmed the *struct layout* of `if_data64`; layout is not behaviour, and no probe had ever read a value above 2^32.

### Edits

| File:line | Change |
|---|---|
| `system-monitor/Infrastructure/System/SysctlNetworkProvider.swift:1-196` | Rewritten. Count from `IFMIB_SYSTEM`/`IFMIB_IFCOUNT`, then one `IFMIB_IFDATA`/`index`/`IFDATA_GENERAL` read per index into `ifmibdata`. `ReadError` is now `{ countQuery(errno:), interfaceRead(index:errno:) }`; `sizeQuery`, `listRead`, `malformedMessage`, the `if_msghdr` walk, its stride and length guards and the three layout constants are gone — none of them describes anything that can happen without a variable-length buffer |
| `…/SysctlNetworkProvider.swift:99-107` | New pure seam `isMissingInterface(errno:)` — `ENOENT`/`ENXIO`/`EINVAL` mark a hole in a sparse index range, every other errno throws |
| `…/SysctlNetworkProvider.swift:146-152` | Filter call converts `ifmd_flags` with `Int32(bitPattern:)`; the field is `UInt32` here, unlike `if_msghdr2.ifm_flags` |
| `system-monitorTests/Infrastructure/SysctlNetworkIntegrationTests.swift:105-215` | Two new `.integration` cases plus an in-test `ifmibdata` witness that reads the MIB directly, deliberately using its own error type so it tests counters rather than the production error taxonomy |
| `system-monitorTests/Infrastructure/SysctlNetworkProviderTests.swift:110-131` | Parameterised truth table for `isMissingInterface(errno:)`, 8 rows |
| `openspec/changes/network-module/specs/network-metrics/spec.md` NM-10, NM-11 | Adapter shape rewritten to the interface MIB with the wrap explained and measured; three new scenarios; NM-11 gains the `Int32(bitPattern:)` rule and the sibling seam |
| `PRD.md` R11.1, 6.1 tree, 6.3 row, section 8 | New MIB and `net/if_mib.h` citations; the IFLIST2 wrap recorded as the reason, with the measured figures |
| `openspec/changes/network-module/exploration.md` Q1 | Dated correction note: the "64-bit, no wrap" verdict was wrong for this driver |
| `openspec/changes/network-module/design.md` | Decision 2 flagged amended, with a dated amendment section after the table |

### Test evidence

| Step | Command | Observed |
|---|---|---|
| RED (integration) | `… -only-testing:system-monitorTests/SysctlNetworkIntegrationTests` | `exit=65` — **both** new cases failed on both test processes: `theSummedCountersAreNotTruncatedToThirtyTwoBits()` and `theAdapterTotalsMatchTheSumOfThePerInterfaceMIBCounters()`. Assertion failures, not thrown errors, which also proves the sandboxed host can reach the interface MIB |
| GREEN (integration) | same | exit 0, **9** distinct cases passed, 0 failed |
| Unit seams | `… -only-testing:system-monitorTests/SysctlNetworkProviderTests` | exit 0, **8** distinct cases passed, 0 failed (filter truth table and saturating sum unchanged and still green) |

Largest per-interface MIB value observed: **13 563 204 219** (`en1`), well above 2^32, which is what makes the truncation assertion bite on this machine. A machine that has moved less than 4 GB since boot passes it trivially — the case asserts a relationship, not a hardware value.

### Deviations from the correction brief

1. **The integration RED is an assertion failure, not a compile error.** The brief's sketch had the test throw `SysctlNetworkProvider.ReadError.countQuery`, which does not exist before GREEN and would have made the RED a compile failure — weaker evidence, since it would prove only that a case was added. The witness throws its own `MIBUnavailable` instead, so the test compiles against the old adapter and fails on the truncation it is there to detect.
2. **A unit case was added** (`isMissingInterface`), which the brief allowed only if a new pure seam appeared. One did.
3. `ifmd_flags` is `UInt32` while `if_msghdr2.ifm_flags` was `Int32`; the brief did not mention it and a plain `Int32(...)` conversion would trap on a flag set with the high bit. `Int32(bitPattern:)` is used.

### Correction size

`git diff --stat` is **unchanged at 1 378 insertions / 73 deletions across 18 tracked files**, and `PRD.md`'s numstat stays 78/26: every PRD line this correction touched was already an added line from batch G, and every other file involved (`SysctlNetworkProvider.swift`, both test files, the spec, `exploration.md`, `design.md`) is untracked, so none of this correction appears in the tracked diff. Authored change, counted directly: `SysctlNetworkProvider.swift` rewritten in place 202 → 196 lines (~150 of them changed), +111 test lines, ~40 artifact lines — inside the 400-line budget. `project.pbxproj` absent from `git diff --name-only`; nothing committed; tasks 7.3–7.7 untouched.

### Consequence for the manual checks

Task **7.3** should be re-run: the em dashes and the apparent Total In reset it surfaced were this defect, and both should now be absent under a sustained multi-gigabyte transfer. Task **7.4** (totals against Activity Monitor) becomes meaningful for the first time — before this correction the totals were the wrapped low 32 bits and could not have matched.
