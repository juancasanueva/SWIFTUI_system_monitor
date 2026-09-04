# Exploration: cpu-module

PRD milestone M2 "CPU end to end". Covers F1/F3 and requirements R1.2-R1.4, R3.1-R3.7, R5.1-R5.4.

Engram topic: `sdd/cpu-module/explore` (observation 8196). This file mirrors that observation for the hybrid artifact store.

## Current State

- M1 skeleton only: `App/AppDelegate.swift` creates `StatusItemController`; the controller owns the `NSStatusItem`, a `PassthroughHostingView<StatusItemView>` (hitTest returns nil), and an `NSPopover` whose content is `NSHostingController(rootView: PanelView())`. `statusItem.length` is set once at init from `hostingView.fittingSize.width` before any data exists.
- `StatusItemView` renders `ForEach(MetricModule.menuBarOrder)` with a hardcoded "0%" and `.monospacedDigit()`; `PanelView` shows two placeholder cards with inline palette colors (no asset catalog palette yet).
- `Domain/Models/MetricModule.swift` is a `nonisolated enum` (convention: every Domain type and Infrastructure provider is `nonisolated`; tests run nonisolated). Tests: `system-monitorTests/Domain/MetricModuleTests.swift` (Swift Testing). `Application/`, `Infrastructure/`, `Domain/Ports/`, `Presentation/Components/` do not exist yet.
- Build (verified in project.pbxproj): SWIFT_VERSION 6.0, SWIFT_DEFAULT_ACTOR_ISOLATION MainActor, SWIFT_APPROACHABLE_CONCURRENCY YES, MACOSX_DEPLOYMENT_TARGET 26.5, ENABLE_APP_SANDBOX YES (no .entitlements file; Xcode synthesizes). No shared scheme and no .xctestplan, so tag-based filtering is not configured; `.integration` tests run with the unit command.

## Q1. Mach API shape (from SDK headers)

- `mach/mach_host.h:136` `kern_return_t host_processor_info(host_t host, processor_flavor_t flavor, natural_t *out_processor_count, processor_info_array_t *out_processor_info, mach_msg_type_number_t *out_processor_infoCnt)`.
- `mach/processor_info.h:78` `typedef integer_t *processor_info_array_t;` `:94` `PROCESSOR_CPU_LOAD_INFO 2`; `:114-116` `struct processor_cpu_load_info { unsigned int cpu_ticks[CPU_STATE_MAX]; }`.
- `mach/machine.h:74-79` `CPU_STATE_MAX 4, CPU_STATE_USER 0, CPU_STATE_SYSTEM 1, CPU_STATE_IDLE 2, CPU_STATE_NICE 3`.
- `mach/arm/vm_types.h:96-97` `natural_t` = UInt32, `integer_t` = Int32. `mach/vm_map.h:110` `vm_deallocate(vm_map_t, vm_address_t, vm_size_t)`. `mach/mach_init.h:80` `mach_task_self_` is declared `__swift_nonisolated_unsafe` (usable from nonisolated Swift 6 code).
- Swift shape: `var count: natural_t = 0; var info: processor_info_array_t? = nil; var infoCount: mach_msg_type_number_t = 0; host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount)`; per core `base = i * Int(CPU_STATE_MAX)`, tick = `UInt32(bitPattern: info[base + Int(CPU_STATE_USER)])` (ticks are unsigned delivered through an Int32 array); `defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }`. Cache `mach_host_self()` once in the provider init (each call returns a send right).
- Sandbox: uses the plain host port, not host_priv. Apple DTS thread 748948 shows only `host_get_host_priv_port` / `host_processors` fail unprivileged; `application.sb` has no rule restricting host-port traps. PRD 6.3 claim holds; the `.integration` test running inside the sandboxed app host is the definitive proof.

## Q2. Mach index to P/E mapping

- xnu `bsd/kern/kern_mib.c`: "Perflevel 0 corresponds to the highest performance one." Keys per level: physicalcpu(_max), logicalcpu(_max), l1i/l1d/l2/l3 cache sizes, cpusperl2/l3, name; plus `hw.nperflevels`. Dev machine: perflevel0 = 8 (P), perflevel1 = 4 (E).
- Index order is undocumented and chip-dependent: M1 Pro boot log (eclecticlight) CPUs 0-1 E then 2-9 P; Asahi docs: E cores first on the A11/M1 lineage; community M5 dumps (chockenberry gist) report perflevel0 cores at 0-3 and E cores at 4-9 (reverse). Confirms R3.4: never assume E-first.
- Recommended runtime verification: IORegistry device tree `cpus/cpuN` entries expose `cluster-type` (OSData "E"/"P", "M" on M5) and `logical-cpu-id`. Stats (exelban SystemKit.swift) uses `IOServiceMatching("AppleARMPE")` + child names `^cpu\d` + `cluster-type`. Build `[Int: PerformanceLevel]` keyed by logical-cpu-id; cross-check "P" count == perflevel0.logicalcpu, "E" count == perflevel1.logicalcpu, total == host_processor_info count; on any mismatch degrade all cores to `.unknown` (R3.6 path) and log.
- Sandbox for IORegistry reads: `iokit-get-properties` is never denied in application.sb, system.sb, appsandbox-common.sb; daemon profiles must explicitly deny it after `(deny default)`, showing the op is allow-by-default. Expect reads to work; integration test verifies.
- R3.4 test: grouping function fed an E-first fake topology and a P-first fake topology must both yield `cores` ordered P then E with original `index` preserved and correct per-level averages; a count-mismatch fake yields all `.unknown`; Intel-style (nperflevels absent) yields all `.unknown`.

## Q3. Delta math (Domain, pure)

- `nonisolated struct CPUTicks: Sendable, Equatable { user, system, idle, nice: UInt32 }`; `CPUTickSample { cores: [CPUTicks] }` indexed by Mach index.
- `CPUUsageCalculator.snapshot(previous:current:topology:) -> CPUSnapshot?`: per-core delta with wrapping `&-`; totalDelta = sum of 4; if 0 (idle/down core) usage = 0; user = (user+nice)/total; system = system/total; total = 1 - idle/total. Aggregate total/user/system from summed deltas across cores; P/E averages = mean of per-core usage per level. Return nil when previous is nil or core counts differ.
- First sample: no snapshot; sampler stores ticks and publishes on the second sample.

## Q4. MetricHistory ring buffer

- `nonisolated struct MetricHistory: Sendable, Equatable { let capacity: Int; private var storage: [Double]; private var head: Int; private(set) var count: Int }` with O(1) `append`, `ordered` (oldest to newest) and `suffix(_:)`; capacity 120, widget uses `suffix(60)`. Publishing copies a 120-element array (CoW, ~1 KB) at 1 Hz, negligible. Tests: drop-oldest beyond capacity, chronological order, empty, capacity 1.

## Q5. Sampler loop under approachable concurrency

- Ports: `nonisolated protocol CPUMetricsProvider: Sendable { func readTicks() throws -> CPUTickSample }`, `nonisolated protocol CoreTopologyProvider: Sendable { func topology() -> CoreTopology }`. Providers return raw ticks; Domain does the math.
- `@MainActor final class MetricsSampler` owns `Task<Void, Never>?`, interval, providers, state; `start()` launches `Task.detached(priority: .utility)` (a plain `Task {}` inherits MainActor under the default-isolation setting); loop: read ticks (`try?`, provider errors never stop the loop), compute snapshot, `await state.apply(...)`, `try? await clock.sleep(for: interval)`; `stop()` cancels; `sampleOnce()` exposed for deterministic tests.
- `@MainActor @Observable final class MetricsState { private(set) var cpu: CPUSnapshot?; private(set) var cpuHistory = MetricHistory(capacity: 120) }` injected via `.environment(state)`.
- Pitfalls: closures/types without explicit isolation become MainActor; only Sendable values may cross into the detached task; `mach_port_t` (UInt32) is Sendable; fakes with mutable scripts need `Synchronization.Mutex` or `@unchecked Sendable`; never mark tests `@MainActor`; `CancellationError` from sleep ends the loop.

## Q6. Rendering

- `Sparkline`, `RingGauge`, `HistoryGraph`, `CoreBar` as `Canvas` views taking `[Double]` / `Double`; mark `Equatable` so unchanged data skips redraw (PRD risk: redraw only on >= 1 pt change).
- Jitter: keep `.monospacedDigit()`, wrap the value `Text` in a fixed `.frame(width:)` sized for "100%", fixed 60 pt sparkline width; compute `statusItem.length` once from a max-value sample and set explicitly; set `hostingView.sizingOptions = []` (macOS 13+ `NSHostingSizingOptions`; default behavior creates/updates min/ideal/max constraints on content changes) so 1 Hz updates do not churn Auto Layout. `PassthroughHostingView` needs no change beyond receiving a root view that observes `MetricsState`.
- Popover content `PanelView().environment(state)` updates live (R2.4). No animation in the bar; panel animations gated by `accessibilityReduceMotion`.

## Q7. Test plan (strict TDD)

- Domain unit: CPUUsageCalculator (wrap-around, zero delta, nice folded into user, aggregate math), CoreTopology grouping (E-first, P-first, mismatch, Intel), MetricHistory, PercentFormatter ("26%", "40.2%" under fixed locale).
- Application: MetricsSampler with `FakeCPUProvider` (scripted samples + `throwOnCall`) and `FakeCoreTopologyProvider`: publish after second sample, history bounded at 120, throwing provider keeps looping, cancellation stops; loop test with 10 ms interval and `.timeLimit`.
- Infrastructure `.integration` (single suite, `extension Tag { @Tag static var integration: Self }`): `MachCPUProvider().readTicks()` cores.count > 0 and == `hw.logicalcpu`; ticks non-decreasing across two reads; `SysctlReader` perflevel sum == cores.count on Apple Silicon; `IORegistryCoreTopologyProvider().topology()` count == cores.count and per-level counts == sysctl (the real R3.4 verification).

## Q8. Files

Create: `Domain/Models/{CPUSnapshot,CPUTicks,CoreTopology,MetricHistory}.swift`, `Domain/Services/CPUUsageCalculator.swift` (PRD 6.1 has no Services folder; decide), `Domain/Ports/{CPUMetricsProvider,CoreTopologyProvider}.swift`, `Application/{MetricsSampler,MetricsState}.swift`, `Infrastructure/Mach/MachCPUProvider.swift`, `Infrastructure/System/{SysctlReader,IORegistryCoreTopologyProvider}.swift`, `Presentation/Components/{Sparkline,RingGauge,HistoryGraph,CoreBar,KeyValueRow}.swift`, `Presentation/Panel/CPUCard.swift`, `Presentation/Formatting/PercentFormatter.swift`, `Presentation/Theme/Palette.swift`; tests under `system-monitorTests/{Domain,Application,Infrastructure,Presentation,Support}`.

Modify: `App/AppDelegate.swift` (composition root: providers, state, sampler.start()), `Presentation/MenuBar/StatusItemController.swift` (accept state, environment injection, explicit length, sizingOptions), `Presentation/MenuBar/StatusItemView.swift` (sparkline + live value; MEM stays placeholder), `Presentation/Panel/PanelView.swift` (CPUCard replaces the CPU placeholder).

## Approaches (core-level mapping)

| Approach | Pros | Cons | Effort |
|---|---|---|---|
| A. IORegistry `cluster-type` + sysctl cross-check (recommended) | Definitive per chip, matches Stats, satisfies R3.4 | IOKit import in Infrastructure; sandbox behavior inferred, verified by test | Medium |
| B. Assume E-first from perflevel counts | Trivial | Wrong on M5 family per community data; violates R3.4 | Low |
| C. Load-correlation heuristic at startup | No IOKit | Unreliable, slow, complex | High |

## Recommendation

Approach A with all-unknown degradation; raw-tick port + pure Domain calculator; MainActor sampler class owning a detached loop; Canvas components with Equatable; explicit status item length with `sizingOptions = []`.

## Open product decisions

1. First-sample behavior (placeholder ~1 s vs startup double-sample).
2. Fallback when topology is unavailable or mismatched (all-unknown recommended vs count heuristic).
3. Aggregate total: sum-of-deltas (recommended) vs mean of per-core.
4. M5 "M"/"Super" cluster type mapping (out of PRD model; propose .unknown).
5. Palette as Swift constants now vs asset catalog (F7 is P2).
6. Sampling interval: hardcode 1 s with injectable parameter until M4 settings.

## Risks

- `logical-cpu-id` == Mach processor index is assumed (undocumented); mitigated by count cross-checks.
- IORegistry reads under App Sandbox inferred from profiles, not executed.
- 1 Hz hosting-view relayout cost; measure in M4.
- No test plan: `.integration` tests run in the unit command.

## Sources

- chockenberry M5 core gist: https://gist.github.com/chockenberry/1d08129bdf41bfb70e98c3a75ce74578
- eclecticlight M1 Pro core allocation: https://eclecticlight.co/2022/07/18/virtualisation-on-apple-silicon-macs-4-core-allocation-in-vms/
- Asahi SMP docs: https://asahilinux.org/docs/hw/cpu/smp/
- xnu kern_mib.c: https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/kern/kern_mib.c
- Apple DTS thread 748948: https://developer.apple.com/forums/thread/748948
- Swift Forums vm_deallocate: https://forums.swift.org/t/how-to-release-memory-using-vm-deallocate-properly/13646
- Stats SystemKit.swift: https://raw.githubusercontent.com/exelban/stats/master/Kit/plugins/SystemKit.swift
- NSHostingSizingOptions: https://developer.apple.com/documentation/swiftui/nshostingsizingoptions
