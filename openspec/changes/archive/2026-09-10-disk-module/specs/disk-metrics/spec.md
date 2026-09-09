# disk-metrics Specification

## Purpose

Boot-volume capacity and summed block-storage throughput acquisition through one Domain port, pure Domain math for used/fraction and for cumulative-counter-to-rate conversion with the negative-delta re-seed, a sampler-owned 10 s capacity cadence, and `MetricsState.disk` holding only the latest snapshot. Serves PRD F10, R10.1–R10.4, R10.7–R10.9, R10.11, R5.1–R5.3, 6.1, 6.2 (amended per the proposal: `DiskCounters` becomes `DiskThroughputCounters` + `VolumeCapacity`), 6.3, 8. Proposal conventions 1–6, 8, 10, 17, 18, 19 apply to every type and test named here. Loop precedents: CM-2 (restart), MM-5 (first iteration), MM-7 (failure isolation), MM-8 (off-main read).

## Requirements

### Requirement: DM-1 Disk metrics port (Layer: Domain) — PRD 6.1, 6.4, R10.1

The system MUST define a `DiskMetricsProvider` port with two independent reads: `readThroughput() throws -> DiskThroughputCounters` and `readCapacity() throws -> VolumeCapacity`. Either read MAY throw without affecting the other. The port and every disk value type MUST be `nonisolated`, `Sendable` and `Equatable`.

#### Scenario: Fake provider satisfies both halves

- GIVEN a test fake conforming to `DiskMetricsProvider` scripted with two `DiskThroughputCounters` and two `VolumeCapacity` values
- WHEN `readThroughput()` and `readCapacity()` are each called twice
- THEN each call returns the next scripted value of its own kind in order

#### Scenario: Scripted failures are independent

- GIVEN a fake scripted to throw on throughput call 0 and on capacity call 1 (zero-based)
- WHEN both reads are called twice
- THEN throughput call 0 throws and call 1 succeeds, capacity call 0 succeeds and call 1 throws

### Requirement: DM-2 Throughput counters value (Layer: Domain) — PRD 6.2 (amended), R10.3

`DiskThroughputCounters` MUST expose `bytesRead` and `bytesWritten` (`UInt64`, cumulative, summed over every block storage driver), `driverCount` (number of drivers whose statistics were read) and `timestamp: ContinuousClock.Instant` stamped by the adapter at read time. Equality MUST cover every field.

#### Scenario: Timestamp participates in equality

- GIVEN two counters with identical bytes and driver count whose timestamps differ by 1 ms
- WHEN they are compared
- THEN they are not equal

### Requirement: DM-3 Capacity value and disk snapshot (Layer: Domain) — R10.2, PRD 6.2, PRD 8

`VolumeCapacity` MUST expose `total` and `free` in bytes (`UInt64`). `DiskSnapshot` MUST expose `total`, `free`, `used`, `readBytesPerSecond: Double?`, `writeBytesPerSecond: Double?` and `fraction`. `used` MUST equal `total − free` saturating at 0. `fraction` MUST equal `Double(used) / Double(total)`, MUST be exactly 0 when `total == 0`, and MUST NOT exceed 1.

#### Scenario: Reference capacity

- GIVEN total 494 354 000 000 and free 62 286 000 000
- WHEN the snapshot is built
- THEN `used == 432 068 000 000` and `fraction == 0.874 ± 0.0005`

#### Scenario: Free exceeds total

- GIVEN total 1 000 and free 1 500
- WHEN the snapshot is built
- THEN `used == 0` and `fraction == 0` with no wraparound

#### Scenario: Zero total

- GIVEN total 0 and free 0
- WHEN `fraction` is read
- THEN it is exactly 0, not NaN or infinity

#### Scenario: Full volume

- GIVEN total 1 000 and free 0
- WHEN `fraction` is read
- THEN it is exactly 1

### Requirement: DM-4 Throughput rate from consecutive counters (Layer: Domain) — R10.3, R10.4, PRD 8

A pure `DiskThroughputCalculator` MUST derive `readBytesPerSecond` and `writeBytesPerSecond` from a previous and a current `DiskThroughputCounters` as `Double(Δbytes) / Δt`, where Δt is `current.timestamp − previous.timestamp` in seconds. Both rates MUST be `nil` (never one without the other) when `previous == nil`, when `current.driverCount == 0`, when `Δt <= 0`, or when either byte delta is negative. The caller MUST always re-seed the baseline with `current`, so a negative delta costs exactly one tick.

#### Scenario: Reference rate

- GIVEN previous (bytesRead 1 000 000 000, bytesWritten 500 000 000) and current (bytesRead 1 027 100 000, bytesWritten 502 200 000) stamped 1 s later, driverCount 1
- WHEN the rates are computed
- THEN `readBytesPerSecond == 27 100 000` (27.1 MB/s) and `writeBytesPerSecond == 2 200 000` (2.2 MB/s)

#### Scenario: Elapsed time scales the rate

- GIVEN the same byte deltas stamped 0.5 s apart
- WHEN the rates are computed
- THEN `readBytesPerSecond == 54 200 000`

#### Scenario: No baseline

- GIVEN `previous == nil`
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: No drivers

- GIVEN a current sample with `driverCount == 0`
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: Non-positive elapsed time

- GIVEN current stamped at the same instant as previous, and separately 1 ms earlier than previous
- WHEN the rates are computed
- THEN both rates are `nil` in both cases

#### Scenario: Negative read delta nils both rates

- GIVEN previous bytesRead 2 000 000 and current bytesRead 1 000 000 while bytesWritten grew by 100 000
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: Negative write delta nils both rates

- GIVEN bytesRead grew by 100 000 while bytesWritten fell
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: Re-seeded baseline recovers on the next tick

- GIVEN a negative delta on tick n whose current counters became the baseline
- WHEN tick n+1 arrives 1 s later with both counters grown by 1 000
- THEN both rates equal 1 000

### Requirement: DM-5 Capacity refresh cadence rule (Layer: Domain) — R10.7

A pure `nonisolated` rule `shouldRefresh(lastReadAt:now:minimum:)` with a 10 s default minimum MUST return `true` when `lastReadAt == nil` or when `now − lastReadAt >= minimum`, and `false` otherwise.

#### Scenario: Never read

- GIVEN `lastReadAt == nil`
- WHEN the rule is evaluated
- THEN it returns `true`

#### Scenario: Under the minimum

- GIVEN `now` 9.999 s after `lastReadAt`, and separately `now == lastReadAt`
- WHEN the rule is evaluated
- THEN it returns `false` in both cases

#### Scenario: At the minimum

- GIVEN `now` exactly 10 s after `lastReadAt`
- WHEN the rule is evaluated
- THEN it returns `true`

### Requirement: DM-6 Same-iteration read and first-tick publication (Layer: Application) — R5.1, R10.3, MM-5

The single `MetricsSampler` MUST read the disk provider in the same iteration as the CPU and memory providers, before any of the three publishes; no second loop or timer SHALL exist for disk. The first iteration after `start()` MUST publish a `DiskSnapshot` carrying capacity with both rates `nil` while the CPU second-sample rule stays unchanged; the second iteration MUST publish rates. `sampleOnce()` MUST keep the disk baseline and cached capacity across calls, as it does for the CPU delta.

#### Scenario: First step publishes capacity without throughput

- GIVEN a fresh sampler with fake CPU, memory and disk providers
- WHEN `sampleOnce()` runs once
- THEN `MetricsState.disk != nil` with both rates `nil`, `memory != nil` and `cpu == nil`

#### Scenario: Second step publishes rates

- GIVEN the same sampler whose disk fake scripts a second sample 1 s later with the DM-4 reference deltas
- WHEN `sampleOnce()` runs a second time
- THEN `disk.readBytesPerSecond == 27 100 000` and `cpu != nil`

#### Scenario: Call counts advance together

- GIVEN fake providers counting calls
- WHEN 3 steps run
- THEN `cpuCalls == 3`, `memoryCalls == 3` and `throughputCalls == 3`

### Requirement: DM-7 Sampler-owned capacity cadence (Layer: Application) — R10.7, PRD 8

The sampler MUST read `readCapacity()` on a tick only when DM-5 returns `true` for the tick's throughput timestamp against the instant of the last successful capacity read, and MUST reuse the cached `VolumeCapacity` otherwise. Throughput MUST be read on every tick regardless.

#### Scenario: One capacity read under 10 s

- GIVEN a disk fake scripting throughput stamps at 0, 1, 2 and 9.999 s from one base
- WHEN 4 steps run
- THEN `capacityCalls == 1`, `throughputCalls == 4` and every published snapshot carries the first capacity

#### Scenario: Refresh once the cadence is crossed

- GIVEN the fake above continued with stamps at 10 and 11 s and a second scripted capacity
- WHEN 2 more steps run
- THEN `capacityCalls == 2` and the last two snapshots carry the second capacity

### Requirement: DM-8 Runtime interval restart (Layer: Application) — CM-2, R5.1

An `apply(interval:)` restart MUST discard the disk step: the first tick of the new loop MUST re-read capacity regardless of the cadence and MUST re-seed the throughput baseline, so exactly one tick after the restart publishes a snapshot with both rates `nil`; the following tick publishes rates. Applying the interval already in effect MUST NOT reset the disk step.

#### Scenario: Restart costs one throughput-unavailable tick

- GIVEN a running sampler under `ManualClock` that has already published rates
- WHEN `apply(interval:)` with a new value runs and one iteration completes
- THEN the published disk snapshot has both rates `nil` and `capacityCalls` grew by one
- AND the following iteration publishes non-nil rates

#### Scenario: Unchanged interval keeps the baseline

- GIVEN the same sampler
- WHEN `apply(interval:)` with the current value runs and one iteration completes
- THEN the published rates are non-nil and `capacityCalls` is unchanged

### Requirement: DM-9 Off-main disk reads (Layer: Application) — R5.3

`readThroughput()` and `readCapacity()` MUST run off the main thread; only the `DiskSnapshot` crosses to the main actor.

#### Scenario: Off-main reads

- GIVEN a disk fake recording `Thread.isMainThread` for each read
- WHEN the loop runs one iteration under `ManualClock`
- THEN every recorded flag is `false`

### Requirement: DM-10 Disk failure isolation (Layer: Application) — R10.9, MM-7, PRD 8

A disk provider error MUST NOT stop the loop, MUST NOT propagate and MUST NOT prevent CPU or memory publication; a CPU or memory error MUST NOT prevent disk publication. A `readThroughput()` throw MUST publish the cached capacity with both rates `nil`; that tick SHOULD skip the cadence check and SHOULD keep the existing baseline. A `readCapacity()` throw before any success MUST publish nothing for disk; a throw after a prior success MUST keep the cached capacity and publish normally.

#### Scenario: Throughput throws, capacity keeps rendering

- GIVEN a disk fake throwing on throughput call 1 after a successful tick 0
- WHEN 2 steps run
- THEN after step 2 `disk != nil` with the tick-0 capacity, both rates `nil`, and `cpu != nil`

#### Scenario: Throughput throw skips the refresh that tick

- GIVEN a throughput throw on the tick whose stamp is 10 s after the last capacity read
- WHEN that step and the next successful step run
- THEN `capacityCalls` is unchanged after the throwing step and grows by one after the next

#### Scenario: Capacity throws before any success

- GIVEN a disk fake throwing on capacity calls 0 and 1
- WHEN 2 steps run
- THEN `disk == nil`, `memory != nil` and no error propagates

#### Scenario: Capacity throws after a success

- GIVEN a fake whose capacity call 0 succeeds and call 1 throws, with stamps 0 and 10 s
- WHEN 2 steps run
- THEN the second snapshot carries the call-0 capacity and non-nil rates

#### Scenario: CPU throws, disk still publishes

- GIVEN a CPU fake throwing on call 0
- WHEN 1 step runs
- THEN `disk != nil`

### Requirement: DM-11 Disk state publication (Layer: Application) — R10.8, R5.2

`MetricsState` MUST expose `disk: DiskSnapshot?` (initially `nil`) and `apply(disk:)`, which MUST store the snapshot, MUST NOT append to any history, and MUST NOT modify `cpu`, `cpuHistory`, `memory` or `memoryHistory`. No `MetricHistory` for disk SHALL exist.

#### Scenario: Apply stores the latest only

- GIVEN a fresh state
- WHEN `apply(disk:)` runs twice with different snapshots
- THEN `disk` equals the second snapshot and no disk history property exists

#### Scenario: Other state untouched

- GIVEN `cpu == nil`, `memory == nil`
- WHEN `apply(disk:)` runs
- THEN `cpu == nil`, `memory == nil`, `cpuHistory.count == 0` and `memoryHistory.count == 0`

### Requirement: DM-12 IOKit throughput adapter (Layer: Infrastructure) — R10.1, R10.3, 6.3; conventions 8, 17, 18

`IOKitDiskProvider.readThroughput()` MUST iterate every `IOBlockStorageDriver` service, read each driver's `Statistics` dictionary and sum `Bytes (Read)` and `Bytes (Write)` with saturating addition, counting in `driverCount` only drivers whose statistics were read, and MUST stamp the result with `ContinuousClock.now`. It MUST throw a typed error when the matching dictionary cannot be created or the IOKit call fails, and MUST return `driverCount == 0` (not throw) when no driver exposes statistics. Every iterator and driver handle MUST be released in a `defer`; the consumed matching dictionary MUST NOT be released by the caller. The adapter MUST work inside App Sandbox.

#### Scenario: Sandboxed shape (`.integration`)

- GIVEN the real adapter inside the sandboxed test host
- WHEN `readThroughput()` is called
- THEN `driverCount >= 1` and `bytesRead > 0`

#### Scenario: Counters are monotonic with advancing stamps (`.integration`)

- GIVEN two reads at least 120 ms apart
- WHEN they are compared
- THEN `second.bytesRead >= first.bytesRead`, `second.bytesWritten >= first.bytesWritten` and `second.timestamp > first.timestamp`

#### Scenario: Repeated reads (`.integration`)

- GIVEN the real adapter
- WHEN `readThroughput()` is called 50 times
- THEN every call succeeds

### Requirement: DM-13 Volume capacity reader (Layer: Infrastructure) — R10.2, 6.3

`VolumeCapacityReader` MUST read `/` with `.volumeTotalCapacityKey` and `.volumeAvailableCapacityForImportantUsageKey`, map `total = volumeTotalCapacity` and `free = volumeAvailableCapacityForImportantUsage`, and MUST throw a typed error when either key is missing or either value is negative. `IOKitDiskProvider.readCapacity()` MUST delegate to the composed reader. The reader MUST work inside App Sandbox.

#### Scenario: Sandboxed shape (`.integration`)

- GIVEN the real reader inside the sandboxed test host
- WHEN it reads and `volumeAvailableCapacity` is read in the same test
- THEN `total > 0`, `0 < free <= total` and `free >= volumeAvailableCapacity`

#### Scenario: Provider delegates (`.integration`)

- GIVEN `IOKitDiskProvider(capacity: VolumeCapacityReader())`
- WHEN `readCapacity()` is called
- THEN it succeeds with `total` equal to the reader's `total`

#### Scenario: Missing or negative value rejected

- GIVEN a resource-value reading that omits a key, and separately one carrying a negative value
- WHEN it is converted
- THEN the read fails with the typed error instead of returning 0

### Requirement: DM-14 Composition root and unchanged modules (Layer: Application — composition root in App) — R5.1, R10.11

The composition root MUST inject `IOKitDiskProvider(capacity: VolumeCapacityReader())` into the single sampler. `MetricModule`, the settings module list, the widget and the login item MUST remain unchanged.

#### Scenario: Real graph runs with disk (`.integration`)

- GIVEN the app composition root
- WHEN the sampler starts with the production providers
- THEN a `DiskSnapshot` is eventually published

#### Scenario: Modules untouched

- GIVEN `MetricModule.allCases`
- WHEN inspected
- THEN it is `[.cpu, .memory]` and the widget length is unchanged

### Requirement: DM-15 PRD alignment (Layer: none — product documentation)

`PRD.md` 6.2 MUST replace `DiskCounters` with `DiskThroughputCounters` and `VolumeCapacity` behind the two-method port, R10.5 MUST read `.decimal`, 6.3 MUST record that the `.integration` suite proves IOKit statistics access under App Sandbox, and section 10 MUST note the popover height growth.

#### Scenario: PRD text

- GIVEN the amended `PRD.md`
- WHEN 6.2, R10.5, 6.3 and section 10 are read
- THEN they match DM-1, DM-2, DC-5 and DC-11 and no longer name `DiskCounters` or `.file`
