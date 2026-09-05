# memory-metrics Specification

## Purpose

Raw memory page-count acquisition through a Domain port, pure Domain math that reproduces Activity Monitor's "Memory Used" (research C1, C3, C4, C5), a `MemorySnapshot` value type, and the extension of the single sampler loop and `MetricsState` so memory publishes on the first iteration. Serves PRD F4, R4.1, R4.2 (replacement text in the proposal), R4.3, R4.6, R5.1–R5.4, 6.2, 6.3. Proposal conventions 1–11 apply to every type and test named here.

## Requirements

### Requirement: MM-1 Raw page-count port (Layer: Domain) — PRD 6.1, 6.4, R4.1

The system MUST define a `MemoryMetricsProvider` port returning a `MemoryPageCounts` value holding the seven `vm_statistics64` counters `free`, `wired`, `purgeable`, `speculative`, `compressor`, `external`, `internal` (research C2), the kernel `pageSize` in bytes and `total` bytes. The port MAY throw. The port and all memory value types MUST be `nonisolated`, `Sendable` and `Equatable`.

#### Scenario: Fake provider satisfies the port

- GIVEN a test fake conforming to `MemoryMetricsProvider` scripted with two `MemoryPageCounts`
- WHEN `readCounts()` is called twice
- THEN each call returns the next scripted value in order

#### Scenario: Scripted failure

- GIVEN a fake scripted to throw on call 0 (zero-based)
- WHEN `readCounts()` is called twice
- THEN the first call throws and the second returns the scripted value

### Requirement: MM-2 Byte components from page counts (Layer: Domain) — R4.2, R4.3; research C3, C4, C5, R5

A pure `MemoryUsageCalculator` MUST derive a `MemorySnapshot` from `MemoryPageCounts` as: App = (internal − purgeable) × pageSize; Wired = wired × pageSize; Compressed = compressor × pageSize; Cached = (external + speculative) × pageSize; Free = (free − speculative) × pageSize; Used = Total − free × pageSize − external × pageSize, which is Total − Free − Cached because Free and Cached share the speculative pages. Only free and file-backed pages leave Used: purgeable pages are deducted from App but stay inside Used, and speculative pages are deducted from Free but stay inside Cached, which is what Activity Monitor reports as "Memory Used". Every operation MUST run in `UInt64`, every subtraction MUST saturate at 0, and 32-bit counts MUST be widened before multiplication.

#### Scenario: Reference counts at 16 KiB pages

- GIVEN pageSize 16384, total 8 589 934 592 and counts free 60 000, speculative 10 000, wired 120 000, purgeable 20 000, compressor 90 000, external 50 000, internal 200 000
- WHEN the snapshot is computed
- THEN app == 180 000 × 16384, wired == 120 000 × 16384, compressed == 90 000 × 16384, cached == 60 000 × 16384, free == 50 000 × 16384
- AND used == 8 589 934 592 − 819 200 000 − 983 040 000 == 6 787 694 592
- AND used + cached + free == 8 589 934 592

#### Scenario: Purgeable exceeds internal

- GIVEN internal 10 and purgeable 20
- WHEN the snapshot is computed
- THEN app == 0 with no wraparound
- AND cached == 0, because purgeable pages stay inside Used

#### Scenario: Speculative exceeds free

- GIVEN free 5 and speculative 9
- WHEN the snapshot is computed
- THEN free == 0
- AND cached == 9 × pageSize, because speculative pages are cache rather than free memory

#### Scenario: Free plus file-backed pages exceed Total

- GIVEN total 1 000 and counts whose Free + Cached bytes exceed 1 000
- WHEN the snapshot is computed
- THEN used == 0 and fraction == 0

#### Scenario: Large 32-bit counts do not overflow

- GIVEN wired == UInt32.max and pageSize 16384
- WHEN the snapshot is computed
- THEN wired == UInt64(UInt32.max) × 16384 without trapping

### Requirement: MM-3 Memory snapshot value (Layer: Domain) — PRD 6.2 (amended)

`MemorySnapshot` MUST expose `total`, `app`, `wired`, `compressed`, `cached`, `free`, `used` in bytes (`UInt64`) and `fraction = Double(used) / Double(total)`, which MUST be 0 when `total == 0`. `used` MUST equal Total − Free − Cached (saturating) and MUST NOT be defined as App + Wired + Compressed.

#### Scenario: Fraction

- GIVEN used 6 623 854 592 and total 8 589 934 592
- WHEN fraction is read
- THEN it equals 0.7711 ± 0.0001

#### Scenario: Zero total

- GIVEN total 0
- WHEN fraction is read
- THEN it is exactly 0, not NaN or infinity

### Requirement: MM-4 Memory state publication (Layer: Application) — R4.6, R5.2

`MetricsState` MUST expose `memory: MemorySnapshot?` (initially `nil`) and `memoryHistory: MetricHistory` with capacity 120. `apply(memory:)` MUST store the snapshot and append its `fraction` to `memoryHistory`, and MUST NOT modify `cpu` or `cpuHistory`.

#### Scenario: Apply stores and appends

- GIVEN a fresh state
- WHEN `apply(memory:)` is called with a snapshot whose fraction is 0.5
- THEN `memory` is that snapshot and `memoryHistory.ordered == [0.5]`

#### Scenario: History bounded

- GIVEN 130 `apply(memory:)` calls
- WHEN `memoryHistory` is inspected
- THEN `count == 120` and the oldest 10 values were dropped

#### Scenario: CPU state untouched

- GIVEN `cpu == nil`
- WHEN `apply(memory:)` runs
- THEN `cpu == nil` and `cpuHistory.count == 0`

### Requirement: MM-5 Memory publishes on the first iteration (Layer: Application) — R5.1

Memory is an absolute reading. The sampler MUST publish a `MemorySnapshot` on the first sampling iteration, independent of the CPU second-sample rule, which MUST remain unchanged.

#### Scenario: First step publishes memory only

- GIVEN a fresh sampler with fake CPU and memory providers
- WHEN `sampleOnce()` runs once
- THEN `MetricsState.memory != nil`, `memoryHistory.count == 1` and `MetricsState.cpu == nil`

#### Scenario: Second step publishes both

- GIVEN the same sampler
- WHEN `sampleOnce()` runs a second time
- THEN `cpu != nil` and `memoryHistory.count == 2`

### Requirement: MM-6 Single loop, same iteration (Layer: Application) — R5.1

One `MetricsSampler` on one timer MUST read the CPU and memory providers within the same iteration; no second loop or timer SHALL exist for memory. The app composition root MUST inject the production memory provider (MM-9) into that sampler.

#### Scenario: Call counts advance together

- GIVEN fake providers counting calls
- WHEN 3 steps run
- THEN `cpuCalls == 3` and `memoryCalls == 3`

### Requirement: MM-7 Memory failure isolation (Layer: Application) — R5.3, PRD 8

A memory provider error MUST NOT stop the loop, MUST NOT propagate and MUST NOT prevent CPU publication. Nothing is published for memory on a failed iteration; the next successful read publishes normally. A CPU provider error MUST NOT prevent memory publication.

#### Scenario: Memory throws twice then recovers

- GIVEN a memory fake throwing on calls 0 and 1
- WHEN 3 steps run
- THEN after step 2 `memory == nil` and `cpu != nil`
- AND after step 3 `memory != nil` and `memoryHistory.count == 1`

#### Scenario: Memory always throws

- GIVEN a memory fake throwing on every call
- WHEN 4 steps run
- THEN `memory == nil`, `cpu != nil` and no error propagates

#### Scenario: CPU throws, memory still publishes

- GIVEN a CPU fake throwing on call 0
- WHEN 1 step runs
- THEN `memory != nil`

### Requirement: MM-8 Off-main provider reads (Layer: Application) — R5.3

`readCounts()` MUST run off the main thread; only the `MemorySnapshot` crosses to the main actor.

#### Scenario: Off-main read

- GIVEN a memory fake recording `Thread.isMainThread`
- WHEN the loop runs one iteration
- THEN the recorded flag is `false`

### Requirement: MM-9 Mach memory adapter (Layer: Infrastructure) — R4.1, R4.3, 6.3; research C7, C9, C12, R2, R3

`MachMemoryProvider` MUST read `host_statistics64(HOST_VM_INFO64)` on `mach_host_self()` into a caller-owned struct (no `vm_deallocate`), passing a field count computed from `MemoryLayout`, and MUST fail with a typed error when the kernel returns a non-success status or a count that does not cover `internal_page_count`. Page size MUST come from `host_page_size()`; the globals `vm_kernel_page_size` and `vm_page_size` MUST NOT be referenced (zero-warning Swift 6 build). `total` MUST be `ProcessInfo.processInfo.physicalMemory`. The adapter MUST work under App Sandbox.

#### Scenario: Sandboxed shape (`.integration`)

- GIVEN the real adapter inside the sandboxed test host
- WHEN `readCounts()` is read and the snapshot computed
- THEN total > 0, total == physicalMemory, pageSize ∈ {4096, 16384}, free count > 0
- AND every component ≤ total and app + wired + compressed ≤ used ≤ total

#### Scenario: Truncated response rejected

- GIVEN a returned field count smaller than the count that includes `internal_page_count`
- WHEN the response is validated
- THEN the read fails with the typed error instead of returning truncated counts

#### Scenario: Repeated reads (`.integration`)

- GIVEN the real adapter
- WHEN `readCounts()` is called twice
- THEN both calls succeed

### Requirement: MM-10 PRD alignment (Layer: none — product documentation)

`PRD.md` MUST carry the R4.2 replacement text from the proposal, MUST note in R4.3 that the page size is read via `host_page_size()`, and 6.2 `MemorySnapshot.used` MUST read Total − Free − Cached.

#### Scenario: PRD text

- GIVEN the amended `PRD.md`
- WHEN R4.2, R4.3 and 6.2 are read
- THEN they match MM-2 and MM-3 and no longer state `Used = App + Wired + Compressed` or `Free = free_count`
