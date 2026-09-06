import Foundation
import Synchronization

/// A `Clock` whose time only moves when the test says so (CM-3).
///
/// It replaces wall-clock waiting and polling in every loop-level test: the
/// sampler sleeps on this clock, the test parks it with `awaitSleepCount(_:)`
/// and then moves time with `advance(by:)`. `Sendable` without `@unchecked`
/// because the only stored property is a `let` `Mutex`, so the sampler's
/// detached loop and the test thread share it safely.
///
/// `advance(by:)` resumes only the sleepers parked at that moment, so a single
/// large advance never replays iterations the loop did not run: the loop
/// registers its next sleep only after it has run. Ten iterations are therefore
/// ten `advance(by: interval)` calls, each followed by `awaitSleepCount(_:)`,
/// never one `advance(by: 10 * interval)`.
nonisolated final class ManualClock: Clock {

    /// An offset from the clock's zero point. Comparing offsets is all the
    /// sampler needs, and it makes deadlines readable in assertions.
    nonisolated struct Instant: InstantProtocol, Sendable, Hashable, Comparable {
        let offset: Swift.Duration

        func advanced(by duration: Swift.Duration) -> Instant {
            Instant(offset: offset + duration)
        }

        func duration(to other: Instant) -> Swift.Duration {
            other.offset - offset
        }

        static func < (lhs: Instant, rhs: Instant) -> Bool {
            lhs.offset < rhs.offset
        }
    }

    /// A task parked in `sleep(until:tolerance:)`, keyed by id so cancellation
    /// can find and remove exactly its own continuation.
    nonisolated private struct Sleeper: Sendable {
        let id: Int
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    /// A test parked in `awaitSleepCount(_:)`.
    nonisolated private struct CountWaiter: Sendable {
        let threshold: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    nonisolated private struct State: Sendable {
        var now = Instant(offset: .zero)
        var sleepers: [Sleeper] = []
        /// Ids cancelled before their sleeper managed to register.
        var cancelled: Set<Int> = []
        var sleepCount = 0
        var nextID = 0
        var countWaiters: [CountWaiter] = []
    }

    /// How a `sleep` call resolved once the lock was released. Resuming a
    /// continuation inside `withLock` would run arbitrary code under the lock.
    nonisolated private enum Resolution: Sendable {
        case park
        case resumeNow
        case cancelled
    }

    private let state: Mutex<State>

    init() {
        self.state = Mutex(State())
    }

    var now: Instant {
        state.withLock { $0.now }
    }

    var minimumResolution: Swift.Duration { .zero }

    /// Number of sleeps entered so far; the rendezvous point used by tests.
    var sleepCount: Int {
        state.withLock { $0.sleepCount }
    }

    /// Offsets of the currently parked sleepers, sorted.
    var pendingDeadlines: [Swift.Duration] {
        state.withLock { $0.sleepers.map(\.deadline.offset).sorted() }
    }

    /// Parks the caller until `advance(by:)` reaches `deadline`.
    ///
    /// Cancellation is checked before anything is registered; a task cancelled
    /// while parked is removed by id and resumed throwing `CancellationError`,
    /// and an id cancelled before its registration throws at registration. Every
    /// resume happens outside `withLock`.
    func sleep(until deadline: Instant, tolerance: Swift.Duration? = nil) async throws {
        try Task.checkCancellation()

        let id = state.withLock { state -> Int in
            let id = state.nextID
            state.nextID += 1
            return id
        }

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let (resolution, waiters) = state.withLock { state -> (Resolution, [CountWaiter]) in
                    if state.cancelled.remove(id) != nil {
                        return (.cancelled, [])
                    }

                    state.sleepCount += 1
                    let due = state.countWaiters.filter { $0.threshold <= state.sleepCount }
                    state.countWaiters.removeAll { $0.threshold <= state.sleepCount }

                    guard deadline > state.now else {
                        return (.resumeNow, due)
                    }

                    state.sleepers.append(
                        Sleeper(id: id, deadline: deadline, continuation: continuation)
                    )
                    return (.park, due)
                }

                for waiter in waiters {
                    waiter.continuation.resume()
                }

                switch resolution {
                case .park:
                    break
                case .resumeNow:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                }
            }
        } onCancel: {
            let sleeper = state.withLock { state -> Sleeper? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else {
                    // The sleeper has not registered yet; mark the id so its
                    // registration resumes throwing instead of parking forever.
                    state.cancelled.insert(id)
                    return nil
                }
                return state.sleepers.remove(at: index)
            }

            sleeper?.continuation.resume(throwing: CancellationError())
        }
    }

    /// Moves `now` forward and resumes every sleeper it reached, in deadline
    /// order. Sleepers registered afterwards are untouched.
    func advance(by duration: Swift.Duration) {
        let due = state.withLock { state -> [Sleeper] in
            state.now = state.now.advanced(by: duration)
            let reached = state.now

            let due = state.sleepers
                .filter { $0.deadline <= reached }
                .sorted { $0.deadline < $1.deadline }
            state.sleepers.removeAll { $0.deadline <= reached }
            return due
        }

        for sleeper in due {
            sleeper.continuation.resume()
        }
    }

    /// Returns once `sleepCount` has reached `count`, immediately if it already
    /// has. The deterministic replacement for polling a running loop.
    func awaitSleepCount(_ count: Int) async {
        await withCheckedContinuation { continuation in
            let reached = state.withLock { state -> Bool in
                guard state.sleepCount < count else { return true }
                state.countWaiters.append(
                    CountWaiter(threshold: count, continuation: continuation)
                )
                return false
            }

            if reached {
                continuation.resume()
            }
        }
    }
}
