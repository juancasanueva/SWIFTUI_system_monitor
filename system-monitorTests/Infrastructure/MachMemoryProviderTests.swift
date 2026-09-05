import Darwin
import Foundation
import Testing
@testable import system_monitor

// memory-metrics — MM-9 "Truncated response rejected".
//
// `host_statistics64` takes its field count as an in-out parameter: it writes
// back how many `integer_t` fields it actually filled, which can be fewer than
// the struct holds. Reading `internal_page_count` out of a short reply would
// return whatever the caller-owned struct was initialised with, so the count is
// validated through a static seam that needs no Mach call to test.
@Suite("MachMemoryProvider field count validation")
struct MachMemoryProviderTests {

    /// Number of `integer_t` fields the whole `vm_statistics64` struct holds.
    private var fullFieldCount: mach_msg_type_number_t {
        mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
    }

    @Test func requiredFieldCountReachesJustPastInternalPageCount() throws {
        let offset = try #require(
            MemoryLayout<vm_statistics64_data_t>.offset(of: \.internal_page_count)
        )
        let expected = mach_msg_type_number_t(offset / MemoryLayout<integer_t>.stride + 1)

        #expect(MachMemoryProvider.requiredFieldCount == expected)
    }

    @Test func requiredFieldCountFitsInsideTheFullStruct() {
        #expect(MachMemoryProvider.requiredFieldCount > 0)
        #expect(MachMemoryProvider.requiredFieldCount <= fullFieldCount)
    }

    @Test func aCountThatExactlyCoversInternalPageCountIsAccepted() throws {
        try MachMemoryProvider.validate(returnedCount: MachMemoryProvider.requiredFieldCount)
    }

    @Test func theFullStructCountIsAccepted() throws {
        try MachMemoryProvider.validate(returnedCount: fullFieldCount)
    }

    @Test func aCountOneFieldShortIsRejected() {
        let short = MachMemoryProvider.requiredFieldCount - 1

        #expect(throws: MachMemoryProvider.ReadError.truncatedStatistics(short)) {
            try MachMemoryProvider.validate(returnedCount: short)
        }
    }

    @Test func anEmptyReplyIsRejected() {
        #expect(throws: MachMemoryProvider.ReadError.truncatedStatistics(0)) {
            try MachMemoryProvider.validate(returnedCount: 0)
        }
    }
}
