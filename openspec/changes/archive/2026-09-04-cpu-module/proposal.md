# Proposal: CPU Module (PRD M2, "CPU end to end")

Serves PRD features F1 (CPU module) and F3 (CPU card). Milestone M2. Exploration: `exploration.md` (Engram `sdd/cpu-module/explore`, id 8196).

## Intent

The M1 skeleton renders a hardcoded "CPU 0%" and placeholder cards. Users get no live signal. This change delivers the first real metric end to end: Mach tick sampling off the main thread, pure Domain math, a live sparkline and percentage in the menu bar, and a CPU card with gauge, User/System/P-Cores/E-Cores rows, 120-sample history graph, and per-core bars grouped by performance level. It also establishes the port/adapter/sampler pattern that M3 (Memory) reuses.

## Scope

### In Scope
- PRD R1.2-R1.4, R3.1-R3.7, R5.1-R5.4; sections 6.1-6.5, 7.1-7.3, 8.
- Domain models, ports, and `CPUUsageCalculator` (`Domain/Services/`, extends 6.1).
- `MetricsSampler` (MainActor class, detached loop, injectable 1 s interval, startup double-sample ~100 ms apart) and `MetricsState`.
- `MachCPUProvider`, `SysctlReader`, `IORegistryCoreTopologyProvider` (exploration Approach A).
- Canvas components (`Sparkline`, `RingGauge`, `HistoryGraph`, `CoreBar`), `KeyValueRow`, `CPUCard`, `PercentFormatter`, `Palette` (Swift constants, PRD 7.1).
- Status item: explicit `statusItem.length`, `hostingView.sizingOptions = []`, `MetricsState` via `.environment`.
- Unit tests (Domain, Application, Presentation formatting) and `.integration` tests (Infrastructure), strict TDD.

### Out of Scope
- Memory card and provider (M3). Settings, launch at login, light mode, asset-catalog palette (M4/F5-F7). GPU (v2). Reduced sampling rate while panel closed (R5.4 P1). MEM widget stays a placeholder.

## Capabilities

### New Capabilities
- `cpu-metrics`: tick ports, delta math (sum-of-deltas aggregate, nice folded into User), ring-buffer history, sampler lifecycle and startup double-sample.
- `core-topology`: Mach index to performance level via IORegistry `cluster-type`, sysctl cross-check, all-`.unknown` degradation ("M" maps to `.unknown`).
- `menu-bar-widget`: data-driven CPU module with 60-sample sparkline, integer percentage, fixed-digit width, deterministic status item length.
- `cpu-card`: ring gauge, key/value rows, 120-sample history graph, per-core bars grouped P then E; P/E rows hidden and bars labelled "Cores" when all levels are `.unknown`.

### Modified Capabilities
- None (no existing specs).

## Approach

- Ports return raw `CPUTickSample`; `CPUUsageCalculator` (pure, nonisolated) computes `CPUSnapshot` from two samples plus `CoreTopology`. Returns nil when no previous sample or core counts differ.
- `MetricsSampler` (`@MainActor`) owns a `Task.detached(priority: .utility)` loop: read ticks (`try?`, errors never stop the loop), compute, `await state.apply(...)`, `clock.sleep`. `stop()` cancels. `sampleOnce()` for deterministic tests.
- Topology: `IORegistry` `cpus/cpuN` `cluster-type` + `logical-cpu-id`; cross-check P/E counts against `hw.perflevel0/1.logicalcpu` and Mach core count; any mismatch yields all `.unknown`. Never guess from counts.
- Rendering: `Canvas` views marked `Equatable`; `.monospacedDigit()` with fixed frame sized for "100%"; 40 pt sparkline on every module (both CPU and MEM; decision 2026-09-04).
- All Domain types and Infrastructure providers are `nonisolated` and `Sendable`; tests never `@MainActor`.

## Affected Areas

| Area | Impact | Description |
|---|---|---|
| `Domain/Models/{CPUSnapshot,CPUTicks,CoreTopology,MetricHistory}.swift` | New | Sendable value types |
| `Domain/Services/CPUUsageCalculator.swift` | New | Pure delta math |
| `Domain/Ports/{CPUMetricsProvider,CoreTopologyProvider}.swift` | New | Port protocols |
| `Application/{MetricsSampler,MetricsState}.swift` | New | Loop and observable state |
| `Infrastructure/Mach/MachCPUProvider.swift` | New | `host_processor_info` + `vm_deallocate` |
| `Infrastructure/System/{SysctlReader,IORegistryCoreTopologyProvider}.swift` | New | perflevel counts, cluster-type |
| `Presentation/Components/{Sparkline,RingGauge,HistoryGraph,CoreBar,KeyValueRow}.swift` | New | Canvas components |
| `Presentation/Panel/CPUCard.swift`, `Presentation/Formatting/PercentFormatter.swift`, `Presentation/Theme/Palette.swift` | New | Card, formatting, palette |
| `App/AppDelegate.swift` | Modified | Composition root, `sampler.start()` |
| `Presentation/MenuBar/{StatusItemController,StatusItemView}.swift` | Modified | Environment injection, explicit length, sizing options, live value |
| `Presentation/Panel/PanelView.swift` | Modified | `CPUCard` replaces placeholder |
| `system-monitorTests/{Domain,Application,Infrastructure,Presentation,Support}/` | New | Tests and fakes |

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| `logical-cpu-id` != Mach index (undocumented) | Med | Count cross-checks; degrade to all-`.unknown`; `.integration` test on real hardware |
| IORegistry read denied under App Sandbox | Low | Inferred allowed from profiles; integration test proves; degradation path keeps app functional |
| 1 Hz hosting-view relayout cost | Med | `sizingOptions = []`, explicit length, Equatable Canvas views; profile in M4 |
| Detached loop captures non-Sendable state | Med | Only Sendable providers and `mach_port_t` cross; compiler enforces |
| `.integration` tests run in unit command (no test plan) | Low | Shape-only assertions; single tagged suite |

## Rollback Plan

Touches status item lifecycle and sampling loop. Revert the four modified files (`AppDelegate`, `StatusItemController`, `StatusItemView`, `PanelView`) to M1 state and delete the new folders; `PBXFileSystemSynchronizedRootGroup` picks up removals without editing `project.pbxproj`. No persisted state or settings exist to migrate.

## Dependencies

- Spec (`sdd-spec`) and design (`sdd-design`) both follow from this proposal and may run in parallel.
- Convention `system-monitor/swift6-nonisolated-domain` (Engram).
- Test command: `xcodebuild -project system-monitor.xcodeproj -scheme system-monitor -destination 'platform=macOS' -quiet test -only-testing:system-monitorTests`.

## Success Criteria

- [ ] R1.2-R1.4: CPU module live in the bar, 60-sample sparkline, integer percentage, no width jitter.
- [ ] R3.1-R3.2: total = 1 - idle delta / total delta; User includes nice; unit tests cover wrap-around and zero delta.
- [ ] R3.3-R3.4: P/E averages per level; E-first and P-first fake topologies both group correctly; mismatch yields all-`.unknown`.
- [ ] R3.5-R3.7: bars grouped P then E, up to 16 P-cores wrap; Intel/unknown path shows "Cores"; 120-sample history.
- [ ] R5.1-R5.4: single sampler, 1 s injectable interval, capacity-120 ring buffer, loop off main thread, sampling continues with panel closed.
- [ ] Startup double-sample publishes a real value within ~200 ms of `start()`.
- [ ] Sections 7.1-7.3 palette, typography, and card skeleton applied to `CPUCard`.
- [ ] Section 8: Domain and Application at 80%+ coverage once enabled; `.integration` suite passes in the sandboxed test host.
