import Testing
@testable import system_monitor

@Suite("MetricHistory ring buffer")
struct MetricHistoryTests {

    // cpu-metrics — "Drop oldest beyond capacity"
    @Test func appendingBeyondCapacityDropsTheOldestValue() {
        var history = MetricHistory(capacity: 3)

        history.append(1)
        history.append(2)
        history.append(3)
        history.append(4)

        #expect(history.ordered == [2, 3, 4])
        #expect(history.count == 3)
    }

    @Test func valuesAreOrderedOldestToNewestBeforeOverflow() {
        var history = MetricHistory(capacity: 3)

        history.append(0.1)
        history.append(0.2)

        #expect(history.ordered == [0.1, 0.2])
        #expect(history.count == 2)
        #expect(history.last == 0.2)
    }

    // cpu-metrics — "Suffix and empty"
    @Test func suffixReturnsTheNewestValuesOldestToNewest() {
        var history = MetricHistory(capacity: 120)
        for index in 0..<70 {
            history.append(Double(index))
        }

        let suffix = history.suffix(60)

        #expect(suffix.count == 60)
        #expect(suffix.first == 10)
        #expect(suffix.last == 69)
        #expect(history.count == 70)
    }

    @Test func suffixLongerThanTheContentReturnsEverythingStored() {
        var history = MetricHistory(capacity: 120)
        history.append(0.5)
        history.append(0.75)

        #expect(history.suffix(60) == [0.5, 0.75])
    }

    // cpu-metrics — "Suffix and empty"
    @Test func emptyHistoryHasNoOrderedValuesAndNoSuffix() {
        let history = MetricHistory(capacity: 120)

        #expect(history.ordered == [])
        #expect(history.suffix(60) == [])
        #expect(history.count == 0)
        #expect(history.isEmpty)
        #expect(history.last == nil)
    }

    // cpu-metrics — "Capacity one"
    @Test func capacityOneKeepsOnlyTheMostRecentValue() {
        var history = MetricHistory(capacity: 1)

        history.append(5)
        history.append(6)

        #expect(history.ordered == [6])
        #expect(history.count == 1)
        #expect(history.last == 6)
    }

    @Test func wrappedHistoriesWithTheSameContentAreEqual() {
        var wrapped = MetricHistory(capacity: 2)
        wrapped.append(1)
        wrapped.append(2)
        wrapped.append(3)

        var fresh = MetricHistory(capacity: 2)
        fresh.append(2)
        fresh.append(3)

        #expect(wrapped == fresh)
    }

    @Test func historiesWithDifferentContentAreNotEqual() {
        var left = MetricHistory(capacity: 2)
        left.append(1)

        var right = MetricHistory(capacity: 2)
        right.append(2)

        #expect(left != right)
    }
}
