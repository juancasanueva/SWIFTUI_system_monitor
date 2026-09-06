# cpu-metrics Specification

## Purpose

Raw CPU tick acquisition through a Domain port, pure tick-delta math producing `CPUSnapshot`, a fixed-capacity history ring buffer, and the sampler lifecycle that publishes snapshots to the main actor. The sampler accepts a runtime interval change and follows an idle cadence: 2 s while the panel is closed, the configured interval while open. Loop behaviour is specified against an injected manual clock. Serves PRD F6, R3.1, R3.2, R3.3 (averages), R5.1, R5.2, R5.3, R5.4.

## Requirements

### Requirement: Tick sample port (Layer: Domain) — PRD 6.1, 6.4

The system MUST define a `CPUMetricsProvider` port that returns a `CPUTickSample` containing one `CPUTicks` (`user`, `system`, `idle`, `nice`, unsigned 32-bit) per logical core, indexed by Mach processor index. The port MAY throw. The port and all tick types MUST be `nonisolated` and `Sendable`.

#### Scenario: Fake provider satisfies the port

- GIVEN a test fake conforming to `CPUMetricsProvider` scripted with two samples of 2 cores
- WHEN `readTicks()` is called twice
- THEN each call returns the next scripted `CPUTickSample` with `cores.count == 2`

### Requirement: Per-core usage from tick deltas (Layer: Domain) — R3.1, R3.2

Per-core usage MUST be computed from the delta between two consecutive samples, never from a single read. Per core: `totalDelta = Δuser + Δsystem + Δidle + Δnice`; `usage = 1 - Δidle / totalDelta`; `user = (Δuser + Δnice) / totalDelta`; `system = Δsystem / totalDelta`. Deltas MUST use wrapping subtraction. A core whose `totalDelta` is 0 MUST report usage, user, and system of 0.

#### Scenario: Idle delta yields total usage

- GIVEN previous ticks (user 100, system 50, idle 800, nice 50) and current (user 200, system 100, idle 1000, nice 100)
- WHEN the snapshot is computed
- THEN the core usage is `1 - 200/400 = 0.5`

#### Scenario: Nice ticks fold into user

- GIVEN a core with deltas user 30, nice 10, system 10, idle 50
- WHEN the snapshot is computed
- THEN core `user == 0.4` and `system == 0.1` and `usage == 0.5`

#### Scenario: Counter wrap-around

- GIVEN previous idle `UInt32.max - 5` and current idle `4`, all other deltas 0
- WHEN the snapshot is computed
- THEN the idle delta is `10` and the core usage is `0`

#### Scenario: Zero total delta

- GIVEN previous and current ticks that are identical for one core
- WHEN the snapshot is computed
- THEN that core reports usage `0`, not NaN

### Requirement: Aggregate usage from summed deltas (Layer: Domain) — R3.1, R3.2

`CPUSnapshot.total`, `.user`, and `.system` MUST be computed from the deltas summed across all cores, not from the mean of per-core ratios.

#### Scenario: Unequal per-core deltas

- GIVEN core A deltas (user 90, system 0, idle 10, nice 0) and core B deltas (user 0, system 0, idle 100, nice 0)
- WHEN the snapshot is computed
- THEN `total == 90/200 == 0.45` and `user == 0.45` and `system == 0`

### Requirement: Per-level averages (Layer: Domain) — R3.3

`performanceAverage` and `efficiencyAverage` MUST be the arithmetic mean of `usage` over the cores at that level. When no core has a given level the corresponding average MUST be absent (`nil`).

#### Scenario: Mean per level

- GIVEN cores 0 and 1 at `.performance` with usage 0.2 and 0.6, core 2 at `.efficiency` with usage 0.9
- WHEN the snapshot is computed
- THEN `performanceAverage == 0.4` and `efficiencyAverage == 0.9`

#### Scenario: All cores unknown

- GIVEN a topology with every core `.unknown`
- WHEN the snapshot is computed
- THEN `performanceAverage == nil` and `efficiencyAverage == nil`

### Requirement: Snapshot preconditions (Layer: Domain) — R3.1

The calculator MUST return `nil` when there is no previous sample or when the two samples have different core counts.

#### Scenario: Missing previous sample

- GIVEN `previous == nil`
- WHEN the snapshot is computed
- THEN the result is `nil`

#### Scenario: Core count mismatch

- GIVEN a previous sample with 4 cores and a current sample with 8 cores
- WHEN the snapshot is computed
- THEN the result is `nil`

### Requirement: History ring buffer (Layer: Domain) — R5.2

`MetricHistory` MUST hold at most `capacity` values (120 for CPU), drop the oldest on overflow, expose values oldest-to-newest, and expose the last `n` values. It MUST be `nonisolated`, `Sendable`, and `Equatable`.

#### Scenario: Drop oldest beyond capacity

- GIVEN a history with capacity 3
- WHEN 1, 2, 3, 4 are appended
- THEN ordered values are `[2, 3, 4]` and `count == 3`

#### Scenario: Suffix and empty

- GIVEN a history with capacity 120 and 70 appended values
- WHEN the last 60 are requested
- THEN 60 values are returned ending with the most recent
- AND an empty history returns `[]` for both ordered values and any suffix

#### Scenario: Capacity one

- GIVEN a history with capacity 1
- WHEN 5 then 6 are appended
- THEN ordered values are `[6]`

### Requirement: Sampler publishes only from the second sample (Layer: Application) — R3.1, R5.1

`MetricsSampler` MUST retain the first tick sample and publish the first `CPUSnapshot` after the second sample. Each published snapshot MUST append its `total` to the CPU history.

#### Scenario: One step publishes nothing

- GIVEN a fresh sampler with a fake provider
- WHEN one sampling step runs
- THEN `MetricsState.cpu == nil` and history count is 0

#### Scenario: Second step publishes

- GIVEN the same sampler
- WHEN a second sampling step runs
- THEN `MetricsState.cpu` is non-nil and history count is 1

#### Scenario: History stays bounded

- GIVEN a sampler run for 130 steps
- WHEN the history is inspected
- THEN its count is 120

### Requirement: Startup double-sample and cadence (Layer: Application) — R5.1

On `start()` the sampler MUST take two samples approximately 100 ms apart so a real value is published within approximately 200 ms, then continue at the configured interval (default 1 s, injectable).

#### Scenario: Real value within 200 ms

- GIVEN a sampler started with a test clock
- WHEN 200 ms of clock time elapses
- THEN `MetricsState.cpu` is non-nil

#### Scenario: Injected interval drives the loop

- GIVEN a sampler with a 10 ms interval
- WHEN it runs for 100 ms
- THEN at least 5 snapshots have been published

### Requirement: Loop resilience and cancellation (Layer: Application) — R5.3, R5.4, PRD 8

ID CM-1. Sampling MUST run off the main thread; only the snapshot crosses to the main actor. A provider error MUST NOT stop the loop. `stop()` MUST cancel the loop. The loop MUST keep running whether or not the panel is open; only its cadence changes: the effective interval MUST be 2 s while the panel is closed and the configured interval while it is open. The rule MUST be a pure `nonisolated` function `SamplingCadence.effective(configured:panelOpen:)`, and each open or close transition (MBW-13) MUST feed its result to `apply(interval:)` (CM-2), so opening the panel restarts the loop at the configured rate and a fresh value appears within approximately 200 ms. While closed the 60-sample sparkline therefore spans about 2 minutes (accepted).

#### Scenario: Throwing provider keeps looping

- GIVEN a fake provider that throws on call 2 and succeeds otherwise
- WHEN 4 steps run
- THEN a snapshot is eventually published and no error propagates

#### Scenario: Stop cancels

- GIVEN a running sampler
- WHEN `stop()` is called and 5 intervals elapse
- THEN the published count does not change

#### Scenario: Off-main sampling

- GIVEN a fake provider that records whether `readTicks()` ran on the main thread
- WHEN the loop runs one iteration
- THEN the recorded flag is `false`

#### Scenario: Cadence truth table

- GIVEN configured intervals 0.5 s, 1 s and 5 s
- WHEN `SamplingCadence.effective(configured:panelOpen:)` is evaluated with `panelOpen == false` and `true`
- THEN the closed results are all 2 s and the open results equal the configured interval

#### Scenario: Loop keeps running while closed

- GIVEN a running sampler with a manual clock, configured 1 s, and the panel reported closed
- WHEN the clock advances 10 s
- THEN the CPU history grew by about 5 entries, not 10, and the loop is still running

#### Scenario: Opening the panel restarts at the configured rate

- GIVEN the sampler above running at the closed cadence
- WHEN the panel is reported open
- THEN the loop restarted once and, after the startup gap, a fresh snapshot is published and the next gap is 1 s

### Requirement: CM-2 Runtime interval change (Layer: Application) — R5.1, F6

`MetricsSampler` MUST expose `apply(interval:)`. While stopped, the interval MUST be stored and used by the next `start()`. While running, the sampler MUST restart its loop exactly once so the new interval takes effect immediately; the restart re-seeds the CPU delta, so exactly one CPU tick after the restart publishes no CPU snapshot, while memory publishes on that first tick (MM-5). Applying the interval that is already in effect MUST NOT restart the loop. Values outside 0.5 s–5 s never reach the sampler: clamping is a Domain concern (ST-1).

#### Scenario: Stored while stopped

- GIVEN a stopped sampler created with a 1 s interval and a manual clock
- WHEN `apply(interval: .seconds(3))` is called and then `start()`
- THEN the gap between the second startup sample and the next sample is 3 s

#### Scenario: One restart while running

- GIVEN a running sampler with a manual clock
- WHEN `apply(interval: .seconds(2))` is called
- THEN the loop was stopped and started exactly once and the next gap is 2 s

#### Scenario: Restart costs one publish-free CPU tick

- GIVEN a running sampler that has already published a CPU snapshot
- WHEN `apply(interval:)` with a new value runs and one sampling iteration completes
- THEN the CPU history count is unchanged and the memory history count has grown by one
- AND the following iteration publishes a CPU snapshot

#### Scenario: Unchanged interval is a no-op

- GIVEN a running sampler at 1 s
- WHEN `apply(interval: .seconds(1))` is called
- THEN the loop is not restarted and the CPU delta is not re-seeded

### Requirement: CM-3 Deterministic loop testing (Layer: Application) — PRD 8; debt W1/W5

Every loop-level scenario in this specification (startup double-sample, injected interval, stop, cadence, runtime interval change) MUST be verifiable through the sampler's injected `Clock` using a test `ManualClock` whose time advances only when the test says so. Loop tests MUST NOT sleep on wall-clock time and MUST NOT poll `ContinuousClock`. The sampler's timing MUST depend only on the injected clock.

#### Scenario: Startup under a manual clock

- GIVEN a sampler with `ManualClock`, interval 1 s and startup gap 100 ms
- WHEN `start()` runs and the clock advances 100 ms
- THEN `MetricsState.cpu` is non-nil and `cpuHistory.count == 1`
- AND advancing a further 1 s makes `cpuHistory.count == 2`

#### Scenario: Stop under a manual clock

- GIVEN the running sampler above
- WHEN `stop()` is called and the clock advances 5 s
- THEN the history counts do not change

#### Scenario: No wall-clock dependency

- GIVEN a started sampler with `ManualClock` and interval 5 s whose startup gap has not yet elapsed
- WHEN the clock advances by the interval ten times, each advance followed by awaiting the loop's next sleep
- THEN ten snapshots have been published and no wall-clock time elapsed
