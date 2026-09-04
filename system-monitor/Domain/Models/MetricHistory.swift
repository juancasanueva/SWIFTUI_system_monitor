import Foundation

/// Fixed-capacity ring buffer of metric samples, oldest to newest.
///
/// Appending is O(1) and drops the oldest value once the buffer is full, so a
/// history can be updated at the sampling cadence without reallocating.
/// Two histories are equal when they expose the same capacity and the same
/// visible values, regardless of where the internal write cursor sits.
nonisolated struct MetricHistory: Sendable, Equatable {

    /// Maximum number of values retained. Always greater than zero.
    let capacity: Int

    /// Values in physical storage order; `head` marks the oldest one.
    private var storage: [Double]

    /// Index of the oldest value once the buffer has wrapped.
    private var head: Int

    /// Number of values currently stored, never above `capacity`.
    private(set) var count: Int

    init(capacity: Int) {
        precondition(capacity > 0, "MetricHistory requires a capacity of at least 1")
        self.capacity = capacity
        self.storage = []
        self.storage.reserveCapacity(capacity)
        self.head = 0
        self.count = 0
    }

    var isEmpty: Bool { count == 0 }

    /// Most recently appended value, or `nil` while the history is empty.
    var last: Double? {
        guard count > 0 else { return nil }
        return storage[(head + count - 1) % capacity]
    }

    /// Appends a value, dropping the oldest one when the buffer is full.
    mutating func append(_ value: Double) {
        if storage.count < capacity {
            storage.append(value)
            count += 1
        } else {
            storage[head] = value
            head = (head + 1) % capacity
        }
    }

    /// All stored values, oldest first.
    var ordered: [Double] {
        guard count > 0 else { return [] }
        guard head > 0 else { return storage }
        return Array(storage[head...]) + Array(storage[..<head])
    }

    /// The newest `maxLength` values, still ordered oldest first.
    ///
    /// Returns fewer values when the history holds fewer than `maxLength`.
    func suffix(_ maxLength: Int) -> [Double] {
        guard maxLength > 0 else { return [] }
        return Array(ordered.suffix(maxLength))
    }

    static func == (lhs: MetricHistory, rhs: MetricHistory) -> Bool {
        lhs.capacity == rhs.capacity && lhs.ordered == rhs.ordered
    }
}
