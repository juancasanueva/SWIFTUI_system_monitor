# Delta for cpu-metrics

Purpose amendment (archive applies to the Purpose paragraph): append "The sampler accepts a runtime interval change and follows an idle cadence: 2 s while the panel is closed, the configured interval while open. Loop behaviour is specified against an injected manual clock." Add F6, R5.4 (cadence) to the served PRD list. The Domain tick math and the history ring buffer are unchanged.

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Loop resilience and cancellation (Layer: Application) — R5.3, R5.4, PRD 8

ID CM-1. Sampling MUST run off the main thread; only the snapshot crosses to the main actor. A provider error MUST NOT stop the loop. `stop()` MUST cancel the loop. The loop MUST keep running whether or not the panel is open; only its cadence changes: the effective interval MUST be 2 s while the panel is closed and the configured interval while it is open. The rule MUST be a pure `nonisolated` function `SamplingCadence.effective(configured:panelOpen:)`, and each open or close transition (MBW-13) MUST feed its result to `apply(interval:)` (CM-2), so opening the panel restarts the loop at the configured rate and a fresh value appears within approximately 200 ms. While closed the 60-sample sparkline therefore spans about 2 minutes (accepted).
(Previously: "The loop MUST NOT depend on whether the panel is open"; no cadence rule.)
Destructive: archive must warn.

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

## REMOVED Requirements

None.

## Verification notes

- `SamplingCadenceTests` (Application): CM-1 truth table as a parameterised test, plus `SamplingCadenceController` open/close behaviour.
- `MetricsSamplerLoopTests` suite in `MetricsSamplerTests.swift` (Application): rewritten over `ManualClock` (CM-3) covering CM-1 cadence scenarios, CM-2 restart and re-seed, and the existing startup, injected-interval, stop and off-main scenarios; the W1/W5 wall-clock cases are deleted. Loop scenarios advance the clock one interval at a time and await the loop's next sleep after each advance; a single large advance never replays iterations.
- `ManualClock` under `system-monitorTests/Support`: `Clock<Duration>` conformance; `.timeLimit(.minutes(1))` only (convention 5).
- Test file names follow the design's File Changes table (`design.md`, revision 2).
- Manual: an interval change in Settings is visible within one tick; Instruments < 1% CPU over 10 min with the panel closed.
