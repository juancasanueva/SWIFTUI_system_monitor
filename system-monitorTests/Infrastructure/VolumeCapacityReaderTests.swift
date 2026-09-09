import Foundation
import Testing
@testable import system_monitor

// disk-metrics — DM-13 "Missing or negative value rejected".
//
// `URL.resourceValues(forKeys:)` hands back optional properties: a key the
// volume does not publish arrives as `nil` rather than as a thrown error, and
// the signed types Foundation uses for them can in principle carry a negative
// value. Either case must fail loudly instead of collapsing into a 0-byte
// volume, so the conversion is a pure static seam that needs no file-system
// access — and therefore no `.integration` tag — to test.
@Suite("VolumeCapacityReader conversion seam", .timeLimit(.minutes(1)))
struct VolumeCapacityReaderTests {

    @Test func aValidPairMapsBothValuesUnchanged() throws {
        let capacity = try VolumeCapacityReader.capacity(
            total: 494_354_000_000,
            free: 62_286_000_000
        )

        #expect(capacity.total == 494_354_000_000)
        #expect(capacity.free == 62_286_000_000)
    }

    @Test func aDifferentValidPairMapsThroughUnchangedToo() throws {
        let capacity = try VolumeCapacityReader.capacity(total: 1_000_204_886_016, free: 17)

        #expect(capacity.total == 1_000_204_886_016)
        #expect(capacity.free == 17)
    }

    @Test func aFullVolumeReportingZeroFreeIsAccepted() throws {
        let capacity = try VolumeCapacityReader.capacity(total: 494_354_000_000, free: 0)

        #expect(capacity.total == 494_354_000_000)
        #expect(capacity.free == 0)
    }

    @Test func aMissingTotalIsRejected() {
        #expect(throws: VolumeCapacityReader.ReadError.missingKey(.volumeTotalCapacityKey)) {
            try VolumeCapacityReader.capacity(total: nil, free: 1)
        }
    }

    @Test func aMissingFreeIsRejected() {
        let expected = VolumeCapacityReader.ReadError
            .missingKey(.volumeAvailableCapacityForImportantUsageKey)

        #expect(throws: expected) {
            try VolumeCapacityReader.capacity(total: 1, free: nil)
        }
    }

    @Test func aNegativeTotalIsRejected() {
        #expect(throws: VolumeCapacityReader.ReadError.negativeValue(.volumeTotalCapacityKey)) {
            try VolumeCapacityReader.capacity(total: -1, free: 1)
        }
    }

    @Test func aNegativeFreeIsRejected() {
        let expected = VolumeCapacityReader.ReadError
            .negativeValue(.volumeAvailableCapacityForImportantUsageKey)

        #expect(throws: expected) {
            try VolumeCapacityReader.capacity(total: 1, free: -1)
        }
    }

    @Test func aMissingKeyIsReportedBeforeANegativeValue() {
        #expect(throws: VolumeCapacityReader.ReadError.missingKey(.volumeTotalCapacityKey)) {
            try VolumeCapacityReader.capacity(total: nil, free: -1)
        }
    }

    @Test func aPairThatIsNegativeOnBothSidesReportsTheTotalFirst() {
        #expect(throws: VolumeCapacityReader.ReadError.negativeValue(.volumeTotalCapacityKey)) {
            try VolumeCapacityReader.capacity(total: -1, free: -1)
        }
    }
}
