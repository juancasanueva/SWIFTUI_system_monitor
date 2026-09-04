import Foundation
import Testing
@testable import system_monitor

// core-topology — "Real-hardware verification"
//
// These tests exercise the real Mach, sysctl and IORegistry adapters from
// inside the sandboxed test host. They assert shape, not specific hardware
// values, so they hold on any Mac the project is built on.
@Suite("Infrastructure adapters against the real host", .tags(.integration))
struct MachIntegrationTests {

    private let sysctl = SysctlReader()

    @Test func logicalCPUCountMatchesTheProcessInfoCount() throws {
        let logical = try #require(sysctl.logicalCPUCount)

        #expect(logical > 0)
        #expect(logical == ProcessInfo.processInfo.processorCount)
    }

    @Test func namedIntegerReadReturnsTheSameValueAsTheConvenienceAccessor() throws {
        let named = try #require(sysctl.integer("hw.logicalcpu"))

        #expect(named == sysctl.logicalCPUCount)
    }

    @Test func anUnknownSysctlNameReadsAsNil() {
        #expect(sysctl.integer("hw.this.sysctl.does.not.exist") == nil)
    }

    @Test func performanceLevelCountIsAtLeastOneWhenPublished() throws {
        let levels = try #require(sysctl.performanceLevelCount)

        #expect(levels >= 1)
    }

    @Test func perLevelCountsAddUpToTheLogicalCPUCount() throws {
        let levels = try #require(sysctl.performanceLevelCount)
        let logical = try #require(sysctl.logicalCPUCount)

        var sum = 0
        for level in 0..<levels {
            sum += try #require(
                sysctl.logicalCPUCount(perfLevel: level),
                "hw.perflevel\(level).logicalcpu is missing while hw.nperflevels is \(levels)"
            )
        }

        #expect(sum == logical)
    }

    @Test func machReportsOneTickEntryPerLogicalCore() throws {
        let sample = try MachCPUProvider().readTicks()
        let logical = try #require(sysctl.logicalCPUCount)

        #expect(sample.coreCount > 0)
        #expect(sample.coreCount == logical)
    }

    @Test func machTicksNeverGoBackwardsAndKeepAdvancing() async throws {
        let provider = MachCPUProvider()
        let first = try provider.readTicks()
        try await Task.sleep(for: .milliseconds(120))
        let second = try provider.readTicks()

        try #require(first.coreCount == second.coreCount)

        for index in first.cores.indices {
            let before = first.cores[index]
            let after = second.cores[index]
            #expect(after.user >= before.user, "user ticks went backwards on core \(index)")
            #expect(after.system >= before.system, "system ticks went backwards on core \(index)")
            #expect(after.idle >= before.idle, "idle ticks went backwards on core \(index)")
            #expect(after.nice >= before.nice, "nice ticks went backwards on core \(index)")
        }

        let advanced = zip(first.cores, second.cores).contains { $1.total > $0.total }
        #expect(advanced, "no core accumulated ticks over 120 ms, the reads are not live")
    }

    // core-topology — "Integration shape check"
    @Test func topologySizeMatchesTheMachCoreCount() throws {
        let topology = IORegistryCoreTopologyProvider().topology()
        let sample = try MachCPUProvider().readTicks()

        #expect(topology.coreCount == sample.coreCount)
    }

    @Test func topologyIsEitherFullyResolvedOrFullyUnknown() {
        let topology = IORegistryCoreTopologyProvider().topology()

        if topology.isSplit {
            #expect(topology.levels.contains(.unknown) == false)
        } else {
            #expect(topology.levels.allSatisfy { $0 == .unknown })
        }
    }

    @Test func repeatedResolutionsAgree() {
        let provider = IORegistryCoreTopologyProvider()

        #expect(provider.topology() == provider.topology())
    }

    // core-topology — "Integration shape check", Apple Silicon branch
    @Test(.enabled(if: SysctlReader().performanceLevelCount == 2))
    func perLevelCountsMatchTheSysctlValuesOnAppleSilicon() throws {
        let topology = IORegistryCoreTopologyProvider().topology()
        let performance = try #require(sysctl.logicalCPUCount(perfLevel: 0))
        let efficiency = try #require(sysctl.logicalCPUCount(perfLevel: 1))

        #expect(topology.levels.count { $0 == .performance } == performance)
        #expect(topology.levels.count { $0 == .efficiency } == efficiency)
        #expect(topology.levels.contains(.unknown) == false)
        #expect(topology.isSplit)
    }
}
