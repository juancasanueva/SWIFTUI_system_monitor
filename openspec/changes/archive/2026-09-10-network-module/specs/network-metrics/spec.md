# network-metrics Specification

## Purpose

Since-boot network byte-counter acquisition through one Domain port, pure Domain delta-to-rate math with the negative-delta re-seed, a network step inside the single sampler iteration, and `MetricsState.network` plus two aligned 120-sample histories. Serves PRD Draft v4 F11, section 5.8 (R11.x), R5.1, R5.2, R5.3, 6.1, 6.2, 6.3, 8. Proposal conventions 1–6, 8, 10–14 apply to every type and test named here. Precedents: `disk-metrics` DM-1..DM-15; loop precedents CM-2 (restart), MM-5 (first iteration), MM-7 (failure isolation), MM-8 (off-main read).

Reference fixture (shared with `network-card`): previous counters `bytesIn` 3 849 995 000, `bytesOut` 2 759 922 000, `interfaceCount` 2, stamped `t0`; current counters `bytesIn` 3 850 000 000, `bytesOut` 2 760 000 000, `interfaceCount` 2, stamped `t0 + 1 s`. The resulting snapshot carries `totalIn` 3 850 000 000, `totalOut` 2 760 000 000, `downloadBytesPerSecond` 5 000 and `uploadBytesPerSecond` 78 000.

## Requirements

### Requirement: NM-1 Network metrics port (Layer: Domain) — PRD 6.1, 6.4, R11.1

The system MUST define a `NetworkMetricsProvider` port with exactly one read, `readCounters() throws -> NetworkThroughputCounters`. The port MUST NOT expose a second read, a rate, a formatted string or a colour. The port and every network value type MUST be `nonisolated`, `Sendable` and `Equatable`.

#### Scenario: Fake provider returns scripted counters in order

- GIVEN a test fake conforming to `NetworkMetricsProvider` scripted with two `NetworkThroughputCounters`
- WHEN `readCounters()` is called twice
- THEN each call returns the next scripted value in order

#### Scenario: Scripted failure is observable

- GIVEN a fake scripted to throw on call 1 (zero-based)
- WHEN `readCounters()` is called twice
- THEN call 0 succeeds and call 1 throws

### Requirement: NM-2 Throughput counters value (Layer: Domain) — PRD 6.2, R11.2

`NetworkThroughputCounters` MUST expose `bytesIn` and `bytesOut` (`UInt64`, cumulative since boot, summed over every interface that passes the NM-11 filter), `interfaceCount` (number of interfaces summed) and `timestamp: ContinuousClock.Instant` stamped by the adapter at read time. Equality MUST cover every field.

#### Scenario: Timestamp participates in equality

- GIVEN two counters with identical bytes and interface count whose timestamps differ by 1 ms
- WHEN they are compared
- THEN they are not equal

#### Scenario: Summed counters carry the interface count

- GIVEN a read that summed two interfaces
- WHEN the counters are inspected
- THEN `interfaceCount == 2` and `bytesIn`/`bytesOut` are the sums of both interfaces

### Requirement: NM-3 Network snapshot value (Layer: Domain) — PRD 6.2, R11.3, PRD 8

`NetworkSnapshot` MUST expose `totalIn` and `totalOut` (`UInt64`, bytes since boot), `downloadBytesPerSecond: Double?` and `uploadBytesPerSecond: Double?`. The two rates MUST be either both non-`nil` or both `nil`; a snapshot with exactly one rate MUST NOT be representable. Totals MUST be published even when the rates are `nil`.

#### Scenario: Rates travel together

- GIVEN the reference fixture's current counters and the NM-4 rates
- WHEN the snapshot is built
- THEN `totalIn == 3 850 000 000`, `totalOut == 2 760 000 000`, `downloadBytesPerSecond == 5 000` and `uploadBytesPerSecond == 78 000`

#### Scenario: Totals without rates

- GIVEN the reference fixture's current counters and no rates
- WHEN the snapshot is built
- THEN both totals are carried and both rates are `nil`

### Requirement: NM-4 Rate from consecutive counters (Layer: Domain) — R11.4, PRD 8

A pure `NetworkThroughputCalculator` MUST derive `downloadBytesPerSecond` and `uploadBytesPerSecond` from a previous and a current `NetworkThroughputCounters` as `Double(Δbytes) / Δt`, where Δt is `current.timestamp − previous.timestamp` in seconds. Both rates MUST be `nil` (never one without the other) when `previous == nil`, when **either** reading has `interfaceCount == 0`, when `Δt <= 0`, or when either byte delta is negative. A reading covering no interface is valid and carries zero totals, so admitting it as a baseline would subtract from zero and report the since-boot totals as one window of traffic; it is a gap in the series, never one end of a window. The calculator MUST be `nonisolated`, MUST hold no state, and MUST NOT format or clamp. The caller MUST always re-seed the baseline with `current`, so a negative delta costs exactly one tick.

#### Scenario: Reference rate

- GIVEN the reference fixture's previous and current counters, 1 s apart
- WHEN the rates are computed
- THEN `downloadBytesPerSecond == 5 000` (5.0 kB/s) and `uploadBytesPerSecond == 78 000` (78.0 kB/s)

#### Scenario: Elapsed time scales the rate

- GIVEN the same byte deltas stamped 0.5 s apart
- WHEN the rates are computed
- THEN `downloadBytesPerSecond == 10 000` and `uploadBytesPerSecond == 156 000`

#### Scenario: No baseline

- GIVEN `previous == nil`
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: No interfaces

- GIVEN a current sample with `interfaceCount == 0`
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: Zero-interface baseline yields nil

- GIVEN a previous sample with `interfaceCount == 0` and zero totals, and a current sample 1 s later covering two interfaces with non-zero totals
- WHEN the rates are computed
- THEN both rates are `nil`, so the since-boot totals are never published as one window of traffic

#### Scenario: Non-positive elapsed time

- GIVEN current stamped at the same instant as previous, and separately 1 ms earlier than previous
- WHEN the rates are computed
- THEN both rates are `nil` in both cases

#### Scenario: Negative inbound delta nils both rates

- GIVEN previous `bytesIn` 2 000 000 and current `bytesIn` 1 000 000 while `bytesOut` grew by 100 000
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: Negative outbound delta nils both rates

- GIVEN `bytesIn` grew by 100 000 while `bytesOut` fell
- WHEN the rates are computed
- THEN both rates are `nil`

#### Scenario: Re-seeded baseline recovers on the next tick

- GIVEN a negative delta on tick n whose current counters became the baseline
- WHEN tick n+1 arrives 1 s later with both counters grown by 1 000
- THEN both rates equal 1 000

### Requirement: NM-5 Same-iteration read and first-tick publication (Layer: Application) — R5.1, R11.5, MM-5, DM-6

The single `MetricsSampler` MUST read the network provider in the same iteration as the CPU, memory and disk providers, before any of the four publishes; no second loop, task or timer SHALL exist for network. The sampler MUST accept the provider as a required `networkProvider:` initialiser parameter. The first iteration after `start()` MUST publish a `NetworkSnapshot` carrying totals with both rates `nil`; the second iteration MUST publish rates. `sampleOnce()` MUST keep the network baseline across calls, as it does for the CPU delta and the disk baseline.

#### Scenario: First step publishes totals without rates

- GIVEN a fresh sampler with fake CPU, memory, disk and network providers
- WHEN `sampleOnce()` runs once
- THEN `MetricsState.network != nil` with both rates `nil` and both network histories empty

#### Scenario: Second step publishes rates

- GIVEN the same sampler whose network fake scripts the reference fixture's second sample 1 s later
- WHEN `sampleOnce()` runs a second time
- THEN `network.downloadBytesPerSecond == 5 000` and `network.uploadBytesPerSecond == 78 000`

#### Scenario: Call counts advance together

- GIVEN fake CPU, memory, disk and network providers counting calls
- WHEN 3 steps run
- THEN `cpuCalls == 3`, `memoryCalls == 3`, `throughputCalls == 3` and `networkCalls == 3`

### Requirement: NM-6 Runtime interval restart (Layer: Application) — CM-2, R5.1, DM-8

An `apply(interval:)` restart MUST discard the network step and build a fresh one, so exactly one tick after the restart publishes a snapshot with both rates `nil` while the totals still render; the following tick publishes rates. Applying the interval already in effect MUST NOT reset the network step.

#### Scenario: Restart costs one rates-unavailable tick

- GIVEN a running sampler under `ManualClock` that has already published rates
- WHEN `apply(interval:)` with a new value runs and one iteration completes
- THEN the published network snapshot has both rates `nil` and non-zero totals
- AND the following iteration publishes non-nil rates

#### Scenario: Unchanged interval keeps the baseline

- GIVEN the same sampler
- WHEN `apply(interval:)` with the current value runs and one iteration completes
- THEN the published rates are non-nil

### Requirement: NM-7 Off-main network reads (Layer: Application) — R5.3, MM-8

`readCounters()` MUST run off the main thread inside the detached sampling loop; only the `NetworkSnapshot` value SHALL cross to the main actor.

#### Scenario: Off-main reads

- GIVEN a network fake recording `Thread.isMainThread` for each read
- WHEN the loop runs one iteration under `ManualClock`
- THEN every recorded flag is `false`

### Requirement: NM-8 Network failure isolation (Layer: Application) — R11.6, MM-7, PRD 8

A `readCounters()` throw MUST NOT stop the loop, MUST NOT propagate and MUST NOT prevent CPU, memory or disk publication. On a throw the sampler MUST publish nothing for network — `MetricsState.network` and both network histories MUST stay exactly as they were — and MUST drop the baseline, so the next successful read is a re-seed tick publishing totals with both rates `nil`. A CPU, memory or disk error MUST NOT prevent network publication.

#### Scenario: Throw publishes nothing and keeps the last snapshot

- GIVEN a network fake throwing on call 1 after a successful tick 0 that published rates
- WHEN 2 steps run
- THEN `MetricsState.network` still equals the tick-0 snapshot, both network histories are unchanged, no error propagates and `cpu != nil`

#### Scenario: The next success is a re-seed tick

- GIVEN the fake above continued with a successful read 1 s later
- WHEN a third step runs
- THEN the published snapshot carries fresh totals with both rates `nil`
- AND the following successful step publishes non-nil rates

#### Scenario: CPU throws, network still publishes

- GIVEN a CPU fake throwing on call 0
- WHEN 1 step runs
- THEN `network != nil`

### Requirement: NM-9 Network state publication and paired histories (Layer: Application) — R11.7, R5.2

`MetricsState` MUST expose `network: NetworkSnapshot?` (initially `nil`), `networkDownloadHistory` and `networkUploadHistory` (each a `MetricHistory` of raw bytes per second, sized by `init(historyCapacity:)`, default 120), and `apply(network:)`. `apply(network:)` MUST store the snapshot and MUST append one sample to BOTH histories in the same call when both rates are non-`nil`, and MUST append to NEITHER when the rates are `nil`, so the two series always have equal length and a shared x axis. It MUST NOT modify `cpu`, `cpuHistory`, `memory`, `memoryHistory` or `disk`. `MetricsState` MUST NOT hold a colour, a unit or a normalised value for network.

#### Scenario: Both histories grow together

- GIVEN a fresh state
- WHEN `apply(network:)` runs three times with non-nil rates
- THEN `networkDownloadHistory.count == 3`, `networkUploadHistory.count == 3` and the newest values are the raw bytes-per-second rates

#### Scenario: Nil rates append nothing

- GIVEN a state whose histories hold 2 samples each
- WHEN `apply(network:)` runs with both rates `nil`
- THEN `network` equals the new snapshot and both histories still hold 2 samples

#### Scenario: Other state untouched

- GIVEN `cpu == nil`, `memory == nil` and `disk == nil`
- WHEN `apply(network:)` runs
- THEN `cpu`, `memory` and `disk` are still `nil` and `cpuHistory.count == 0` and `memoryHistory.count == 0`

#### Scenario: Capacity bounds both histories

- GIVEN a state built with `historyCapacity: 3`
- WHEN `apply(network:)` runs 5 times with non-nil rates
- THEN each network history holds exactly 3 samples, newest last

### Requirement: NM-10 sysctl network adapter (Layer: Infrastructure) — R11.1, R11.2, PRD 6.3; conventions 8, 12, 13

`SysctlNetworkProvider.readCounters()` MUST read the interface MIB (`net/if_mib.h`): the row count from `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_SYSTEM, IFMIB_IFCOUNT}`, then for each index `1...count` one `{CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, index, IFDATA_GENERAL}` read into a `struct ifmibdata`. It MUST read `ifi_ibytes`/`ifi_obytes` from that row's `ifmd_data` (`if_data64`), MUST sum them with saturating addition over the interfaces admitted by NM-11 (applying the filter to `ifmd_data.ifi_type` and `ifmd_flags`), MUST count those interfaces in `interfaceCount`, and MUST stamp the result with `ContinuousClock.now` after the loop.

It MUST NOT read the counters from the routing-socket MIB `NET_RT_IFLIST2`. That export declares `ifi_ibytes` as `u_int64_t`, but on this platform the driver fills only the low 32 bits, so the value wraps every 4 GB; the wrap makes the summed delta negative, NM-4 discards the tick, and the totals appear to reset. Measured on this machine on 2026-09-10: `en1` reported 13 563 204 219 through the interface MIB against 678 301 696 through the routing socket at the same moment — exactly the low 32 bits.

The index range is an upper bound, not a dense range: a per-index read failing with `ENOENT`, `ENXIO` or `EINVAL` MUST be skipped as a gap. It MUST throw a typed `ReadError` when the count query fails or when a per-index read fails with any other errno, and MUST return `interfaceCount == 0` with zero totals rather than throwing when no interface is admitted. The adapter MUST work inside App Sandbox; the `.integration` suite running in the sandboxed test host is the proof of interface-MIB sysctl access. The adapter MUST be `nonisolated` and `Sendable`, MUST hold no state, and MUST NOT import SwiftUI or AppKit.

#### Scenario: Sandboxed shape (`.integration`)

- GIVEN the real adapter inside the sandboxed test host
- WHEN `readCounters()` is called
- THEN it does not throw, `interfaceCount >= 1` and `bytesIn > 0`

#### Scenario: Counters are monotonic with advancing stamps (`.integration`)

- GIVEN two reads at least 120 ms apart with no interface churn
- WHEN they are compared
- THEN `second.bytesIn >= first.bytesIn`, `second.bytesOut >= first.bytesOut` and `second.timestamp > first.timestamp`

#### Scenario: Repeated reads (`.integration`)

- GIVEN the real adapter
- WHEN `readCounters()` is called 50 times
- THEN every call succeeds

#### Scenario: No admitted interface is not an error

- GIVEN a read in which no interface row passes the NM-11 filter
- WHEN the read completes
- THEN it returns `interfaceCount == 0`, `bytesIn == 0`, `bytesOut == 0` and a fresh stamp instead of throwing

#### Scenario: Counters are not 32-bit truncated (`.integration`)

- GIVEN the largest `ifmd_data.ifi_ibytes` over the admitted interfaces, read independently by the test
- WHEN the adapter's `bytesIn` is compared against it
- THEN the adapter's total is greater than or equal to it, so a source truncating at 2^32 fails on any machine that has moved more than 4 GB since boot

#### Scenario: Sum matches the MIB within one tick (`.integration`)

- GIVEN the adapter's totals and the per-interface MIB counters summed by the test
- WHEN the two are compared
- THEN both sources admit the same interface count and the totals agree within a tolerance that absorbs traffic between the two reads

#### Scenario: A missing index is a gap, not a failure

- GIVEN a per-index read failing with `ENOENT`, `ENXIO` or `EINVAL`
- WHEN the read continues
- THEN that index is skipped and every other errno throws `ReadError.interfaceRead(index:errno:)`

#### Scenario: Sums saturate

- GIVEN two admitted interfaces whose `ifi_ibytes` values would overflow `UInt64`
- WHEN they are summed
- THEN the sum saturates at `UInt64.max` without trapping

### Requirement: NM-11 Interface filter seam (Layer: Infrastructure) — R11.2; conventions 12, 13

The interface decision MUST live in a pure `nonisolated static func includes(type:flags:) -> Bool` that takes only the interface type and flag bits, so it is unit-testable without a socket. It MUST admit an interface whose type is `IFT_ETHER` or `IFT_CELLULAR` and whose flags do not contain `IFF_LOOPBACK`, and MUST reject every other type. It MUST NOT require `IFF_UP` or `IFF_RUNNING`, so a configured-but-down Ethernet interface still contributes its counters. The `sysctl` constants and struct names MUST come from `Darwin` with header citations; any that fail to import MUST become private literals carrying the same citations. The caller MUST convert `ifmibdata.ifmd_flags`, which is `UInt32`, with `Int32(bitPattern:)` rather than a trapping conversion. The sparse-index rule of NM-10 MUST live in a sibling pure seam, `nonisolated static func isMissingInterface(errno:) -> Bool`, so its truth table is a unit test as well.

#### Scenario: Admitted interfaces

- GIVEN `IFT_ETHER` without `IFF_LOOPBACK` (en*, awdl0, llw0) and `IFT_CELLULAR`
- WHEN `includes(type:flags:)` is evaluated
- THEN it returns `true` for each

#### Scenario: Rejected interfaces

- GIVEN loopback (`IFT_LOOP` with `IFF_LOOPBACK`), tunnel (`IFT_OTHER`, utun*), bridge (`IFT_BRIDGE`), gif and stf types
- WHEN `includes(type:flags:)` is evaluated
- THEN it returns `false` for each, so VPN traffic is never double counted

#### Scenario: Loopback flag overrides an admitted type

- GIVEN type `IFT_ETHER` with `IFF_LOOPBACK` set
- WHEN `includes(type:flags:)` is evaluated
- THEN it returns `false`

#### Scenario: Link state is not required

- GIVEN type `IFT_ETHER` with neither `IFF_UP` nor `IFF_RUNNING` set
- WHEN `includes(type:flags:)` is evaluated
- THEN it returns `true`

### Requirement: NM-12 Composition root and unchanged modules (Layer: Application — composition root in App) — R5.1, R11.11

The composition root MUST construct `SysctlNetworkProvider()` and inject it into the single `MetricsSampler`. `MetricModule`, the settings module list, the menu bar widget, `statusItem.length` and the login item MUST remain unchanged; network MUST add no `MetricModule` case and no persisted setting.

#### Scenario: Real graph publishes network (`.integration`)

- GIVEN the app composition root
- WHEN the sampler starts with the production providers
- THEN a `NetworkSnapshot` is eventually published (`network != nil`)

#### Scenario: Modules and widget untouched

- GIVEN `MetricModule.allCases` and the widget width
- WHEN inspected
- THEN the module set is unchanged and the widget width is unchanged

### Requirement: NM-13 Product documentation alignment (Layer: none — product documentation)

`PRD.md` MUST become Draft v4: feature `F11` (Network card) with `F9` (menu bar NET module) still Future, a new section 5.8 carrying R11.x, milestone `M6 Network` with GPU renumbered to `M7`, the 4.6 reference image, the 6.1 tree, the 6.2 models, the 6.3 data-source row, the 7.1 tokens, the 7.3 note, the section 8 rows, and a section 10 popover-height risk row plus the answer to open question 3. `openspec/config.yaml` MUST widen its proposal rule to F1..F11 / M1..M6 and update the `context` PRD line to Draft v4.

#### Scenario: PRD and config text

- GIVEN the amended `PRD.md` and `openspec/config.yaml`
- WHEN 5.8, 6.2, 6.3, 7.1, section 9 and section 10 and the config rule line are read
- THEN they match NM-1..NM-12 and NC-1..NC-13, name `M6 Network` with GPU at `M7`, and reference F1..F11 / M1..M6
