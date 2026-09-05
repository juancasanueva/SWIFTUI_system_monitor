import Foundation
import Testing
@testable import system_monitor

// memory-metrics — MM-9 "Sandboxed shape", "Repeated reads".
//
// These run the real adapter inside the sandboxed test host, which is what
// proves `host_statistics64(HOST_VM_INFO64)` is reachable under App Sandbox.
// They assert shape and internal consistency, not specific hardware values, so
// they hold on any Mac the project is built on.
@Suite("MachMemoryProvider against the real host", .tags(.integration))
struct MachMemoryIntegrationTests {

    @Test func totalMatchesPhysicalMemoryAndTheHardwareSysctl() throws {
        let counts = try MachMemoryProvider().readCounts()
        let hardwareTotal = try #require(SysctlReader().integer("hw.memsize"))

        #expect(counts.totalBytes > 0)
        #expect(counts.totalBytes == ProcessInfo.processInfo.physicalMemory)
        #expect(counts.totalBytes == UInt64(hardwareTotal))
    }

    @Test func pageSizeIsOneOfTheTwoKernelPageSizes() throws {
        let counts = try MachMemoryProvider().readCounts()

        #expect(counts.pageSize == 4_096 || counts.pageSize == 16_384)
    }

    @Test func theHostAlwaysReportsSomeFreePages() throws {
        let counts = try MachMemoryProvider().readCounts()

        #expect(counts.freeCount > 0)
    }

    @Test func noSingleComponentExceedsTheTotal() throws {
        let snapshot = MemoryUsageCalculator.snapshot(from: try MachMemoryProvider().readCounts())

        #expect(snapshot.app <= snapshot.total)
        #expect(snapshot.wired <= snapshot.total)
        #expect(snapshot.compressed <= snapshot.total)
        #expect(snapshot.cached <= snapshot.total)
        #expect(snapshot.free <= snapshot.total)
        #expect(snapshot.used <= snapshot.total)
    }

    @Test func theLabelledComponentsFitInsideUsedWhichFitsInsideTotal() throws {
        let snapshot = MemoryUsageCalculator.snapshot(from: try MachMemoryProvider().readCounts())

        #expect(snapshot.app + snapshot.wired + snapshot.compressed <= snapshot.used)
        #expect(snapshot.used <= snapshot.total)
        #expect(snapshot.fraction >= 0)
        #expect(snapshot.fraction <= 1)
        #expect(snapshot.fraction > 0, "a live host always has memory in use")
    }

    // memory-metrics — MM-9 "Repeated reads"
    @Test func repeatedReadsSucceedAndAgreeOnTheHostConstants() throws {
        let provider = MachMemoryProvider()

        let first = try provider.readCounts()
        let second = try provider.readCounts()

        #expect(first.pageSize == second.pageSize)
        #expect(first.totalBytes == second.totalBytes)
        #expect(second.freeCount > 0)
    }
}
