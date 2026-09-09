import Foundation
import Testing
@testable import system_monitor

// disk-metrics — DM-5 "Never read", "Under the minimum", "At the minimum".
//
// The rule is pure over two instants, so the suite scripts them from
// `DiskFixtures.base` instead of waiting on a clock.
@Suite("DiskCapacityCadence")
struct DiskCapacityCadenceTests {

    // disk-metrics — DM-5 "Never read"
    @Test func aCapacityNeverReadAlwaysRefreshes() {
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: nil,
                now: DiskFixtures.instant(0)
            )
        )
    }

    // disk-metrics — DM-5 "Under the minimum"
    @Test func justUnderTheMinimumDoesNotRefresh() {
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: DiskFixtures.instant(0),
                now: DiskFixtures.instant(9.999)
            ) == false
        )
    }

    // disk-metrics — DM-5 "Under the minimum", the same-instant half.
    @Test func theSameInstantDoesNotRefresh() {
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: DiskFixtures.instant(0),
                now: DiskFixtures.instant(0)
            ) == false
        )
    }

    // disk-metrics — DM-5 "At the minimum": the boundary is inclusive.
    @Test func exactlyTheMinimumRefreshes() {
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: DiskFixtures.instant(0),
                now: DiskFixtures.instant(10)
            )
        )
    }

    @Test func wellPastTheMinimumRefreshes() {
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: DiskFixtures.instant(0),
                now: DiskFixtures.instant(45)
            )
        )
    }

    // A clock that moved backwards must not trigger a refresh either: the
    // elapsed duration is negative, which is below the minimum.
    @Test func aBackwardsNowDoesNotRefresh() {
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: DiskFixtures.instant(10),
                now: DiskFixtures.instant(9)
            ) == false
        )
    }

    @Test func theDefaultMinimumIsTenSeconds() {
        #expect(DiskCapacityCadence.minimumInterval == .seconds(10))
    }

    // The caller may override the cadence; the same boundary rule applies.
    @Test func aCustomMinimumIsHonoured() {
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: DiskFixtures.instant(0),
                now: DiskFixtures.instant(2),
                minimum: .seconds(2)
            )
        )
        #expect(
            DiskCapacityCadence.shouldRefresh(
                lastReadAt: DiskFixtures.instant(0),
                now: DiskFixtures.instant(1.999),
                minimum: .seconds(2)
            ) == false
        )
    }
}
