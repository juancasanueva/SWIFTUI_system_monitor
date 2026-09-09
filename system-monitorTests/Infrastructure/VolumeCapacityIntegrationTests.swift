import Foundation
import Testing
@testable import system_monitor

// disk-metrics — DM-13 "Sandboxed shape", "Provider delegates".
//
// These run the real reader inside the sandboxed test host, which is what
// proves the boot volume's resource values are reachable under App Sandbox
// without a security-scoped bookmark. They assert shape and internal
// consistency, never specific hardware values.
@Suite("VolumeCapacityReader against the real boot volume", .tags(.integration), .timeLimit(.minutes(1)))
struct VolumeCapacityIntegrationTests {

    // disk-metrics — DM-13 "Sandboxed shape"
    @Test func theBootVolumeReportsAConsistentPairAboveTheRawAvailableSpace() throws {
        let capacity = try VolumeCapacityReader().read()

        let values = try URL(fileURLWithPath: "/").resourceValues(
            forKeys: [.volumeAvailableCapacityKey]
        )
        let rawAvailable = try #require(values.volumeAvailableCapacity)

        #expect(capacity.total > 0)
        #expect(capacity.free > 0)
        #expect(capacity.free <= capacity.total)
        #expect(capacity.free >= UInt64(rawAvailable))
    }

    @Test func theTotalMatchesTheVolumeTotalCapacityResourceValue() throws {
        let capacity = try VolumeCapacityReader().read()

        let values = try URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey])
        let total = try #require(values.volumeTotalCapacity)

        #expect(capacity.total == UInt64(total))
    }

    @Test func repeatedReadsAgreeOnTheTotal() throws {
        let reader = VolumeCapacityReader()

        let first = try reader.read()
        let second = try reader.read()

        #expect(first.total == second.total)
        #expect(second.free > 0)
    }

    // disk-metrics — DM-13 "Provider delegates"
    @Test func theProviderDelegatesCapacityToTheComposedReader() throws {
        let reader = VolumeCapacityReader()
        let provider = IOKitDiskProvider(capacity: reader)

        let delegated = try provider.readCapacity()
        let direct = try reader.read()

        #expect(delegated.total == direct.total)
        #expect(delegated.total > 0)
        #expect(delegated.free > 0)
    }

    @Test func theProviderReadsTheBootVolumeThroughItsDefaultReader() throws {
        let delegated = try IOKitDiskProvider().readCapacity()
        let direct = try VolumeCapacityReader().read()

        #expect(delegated.total == direct.total)
    }

    /// The reader's own error reaches the caller unchanged, so the composition
    /// adds no error vocabulary of its own on the capacity path.
    @Test func theProviderRethrowsTheReadersErrorUnchanged() {
        let missingVolume = URL(fileURLWithPath: "/System/Volumes/no-such-volume-here")
        let provider = IOKitDiskProvider(capacity: VolumeCapacityReader(volumeURL: missingVolume))

        let expected = VolumeCapacityReader.ReadError.resourceValues(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoSuchFileError
        )

        #expect(throws: expected) {
            try provider.readCapacity()
        }
    }

    /// The adapter satisfies the Domain port, which is what the composition
    /// root injects in phase 5.
    @Test func theAdapterIsUsableThroughTheDiskMetricsProviderPort() throws {
        let port: any DiskMetricsProvider = IOKitDiskProvider(capacity: VolumeCapacityReader())

        let capacity = try port.readCapacity()
        let throughput = try port.readThroughput()

        #expect(capacity.total > 0)
        #expect(throughput.driverCount >= 1)
    }
}
