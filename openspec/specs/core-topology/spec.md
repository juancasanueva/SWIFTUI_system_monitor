# core-topology Specification

## Purpose

Resolve each Mach logical core index to a performance level (`.performance`, `.efficiency`, `.unknown`), verify that mapping per chip at startup, order cores P then E, and degrade to all-`.unknown` whenever the mapping cannot be trusted. Serves PRD R3.3, R3.4, R3.5 (ordering), R3.6.

## Requirements

### Requirement: Topology model and port (Layer: Domain) — 6.1, 6.2

The system MUST define `PerformanceLevel` (`.performance`, `.efficiency`, `.unknown`), `CoreTopology` mapping a core index to a level, and a `CoreTopologyProvider` port returning a `CoreTopology`. All MUST be `nonisolated` and `Sendable`. A topology MUST be either fully resolved (no `.unknown`) or fully `.unknown`.

#### Scenario: Level lookup

- GIVEN a topology `{0: .efficiency, 1: .performance}`
- WHEN the level of index 1 is requested
- THEN `.performance` is returned

#### Scenario: Missing index

- GIVEN the same topology
- WHEN the level of index 7 is requested
- THEN `.unknown` is returned

### Requirement: Cores ordered P then E with index preserved (Layer: Domain) — R3.4, R3.5

`CPUSnapshot.cores` MUST list `.performance` cores first, then `.efficiency`, then `.unknown`, each group in ascending original index. Each `CoreUsage.index` MUST keep its Mach index. Ordering MUST NOT assume E-first or P-first.

#### Scenario: E-first fake topology

- GIVEN 4 cores where 0-1 are `.efficiency` and 2-3 are `.performance`
- WHEN the snapshot is computed
- THEN `cores.map(\.index) == [2, 3, 0, 1]`

#### Scenario: P-first fake topology

- GIVEN 4 cores where 0-1 are `.performance` and 2-3 are `.efficiency`
- WHEN the snapshot is computed
- THEN `cores.map(\.index) == [0, 1, 2, 3]` with levels `[P, P, E, E]`

#### Scenario: All unknown keeps Mach order

- GIVEN 4 cores all `.unknown`
- WHEN the snapshot is computed
- THEN `cores.map(\.index) == [0, 1, 2, 3]`

### Requirement: Level resolution from the hardware description (Layer: Infrastructure) — R3.4

The topology provider MUST derive each core's level from the per-core cluster type published by the system (IORegistry `cluster-type` keyed by logical CPU id). `"P"` maps to `.performance`, `"E"` to `.efficiency`, and any other value (including `"M"`) to `.unknown`. The provider MUST NOT throw.

#### Scenario: Cluster type mapping

- GIVEN cluster types `["P", "E", "M", "X"]`
- WHEN each is mapped
- THEN the levels are `[.performance, .efficiency, .unknown, .unknown]`

### Requirement: Count cross-check (Layer: Infrastructure) — R3.3, R3.4

Before accepting a resolved topology the provider MUST verify all of: `.performance` count equals `hw.perflevel0.logicalcpu`, `.efficiency` count equals `hw.perflevel1.logicalcpu`, and total entries equal the Mach core count. Any mismatch, or any `.unknown` entry, MUST yield a topology with every core `.unknown`. The provider MUST NOT infer levels from counts alone.

#### Scenario: Consistent counts

- GIVEN registry entries 8×"P" + 4×"E", sysctl perflevel0 = 8, perflevel1 = 4, Mach count 12
- WHEN the topology is built
- THEN 8 cores are `.performance` and 4 are `.efficiency`

#### Scenario: P count mismatch

- GIVEN registry entries 6×"P" + 6×"E" and sysctl perflevel0 = 8, perflevel1 = 4
- WHEN the topology is built
- THEN all 12 cores are `.unknown`

#### Scenario: Total mismatch against Mach

- GIVEN registry entries matching sysctl (8 + 4) but a Mach core count of 10
- WHEN the topology is built
- THEN all cores are `.unknown`

#### Scenario: One "M" entry poisons the topology

- GIVEN registry entries 7×"P" + 1×"M" + 4×"E" with sysctl 8/4 and Mach count 12
- WHEN the topology is built
- THEN all cores are `.unknown`

### Requirement: Degradation on unavailable sources (Layer: Infrastructure) — R3.6

When the perflevel sysctls are absent (Intel) or the registry cannot be read, the provider MUST return an all-`.unknown` topology sized to the Mach core count and the application MUST keep sampling.

#### Scenario: No perflevel split

- GIVEN a sysctl reader reporting no `hw.perflevel0.logicalcpu` and a Mach count of 8
- WHEN the topology is built
- THEN 8 cores are `.unknown`

#### Scenario: Registry unreadable

- GIVEN a registry reader that returns no entries
- WHEN the topology is built
- THEN all cores are `.unknown` and no error is thrown

### Requirement: Real-hardware verification (Layer: Infrastructure, `.integration`) — R3.4, PRD 8

On the development machine the real provider MUST produce a topology whose size equals the Mach core count and whose per-level counts equal the sysctl values, from inside the sandboxed test host.

#### Scenario: Integration shape check

- GIVEN the real topology provider, sysctl reader, and Mach tick provider
- WHEN `topology()` and `readTicks()` are called
- THEN `topology.count == ticks.cores.count`
- AND on Apple Silicon the `.performance` and `.efficiency` counts equal perflevel0 and perflevel1
