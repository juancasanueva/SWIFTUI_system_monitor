import Foundation
import Testing
@testable import system_monitor

// settings — ST-4 "Observable settings state".
//
// The suite is never `@MainActor`; every main-actor member is awaited from a
// nonisolated test (convention 2). `FakeSettingsStore` records load and save
// counts, the persisted values and the thread each save ran on, so the
// assertions below describe what `SettingsState` really did rather than what it
// exposes.
@Suite("SettingsState", .timeLimit(.minutes(1)))
struct SettingsStateTests {

    /// A store seeded with the ST-4 fixture: 2 s and the single MEM module.
    private func seededStore(throwOnSave: Set<Int> = []) -> FakeSettingsStore {
        FakeSettingsStore(
            stored: Settings(samplingInterval: .seconds(2), menuBarModules: [.memory]),
            throwOnSave: throwOnSave
        )
    }

    /// A store seeded with both modules, used by the visibility and reorder
    /// cases where a single-module list would trip the last-module guard.
    private func bothModulesStore(throwOnSave: Set<Int> = []) -> FakeSettingsStore {
        FakeSettingsStore(
            stored: Settings(samplingInterval: .seconds(1), menuBarModules: [.cpu, .memory]),
            throwOnSave: throwOnSave
        )
    }

    // settings — ST-4 "Loads on init": construction reads the store exactly
    // once and writes nothing back.
    @Test func initLoadsFromTheStoreWithoutSaving() async {
        let store = seededStore()

        let state = await SettingsState(store: store)

        #expect(await state.samplingInterval == .seconds(2))
        #expect(await state.menuBarModules == [.memory])
        #expect(await state.settings == Settings(samplingInterval: .seconds(2), menuBarModules: [.memory]))
        #expect(store.loadCount == 1)
        #expect(store.saveCount == 0)
        #expect(await state.lastSaveError == nil)
    }

    // settings — ST-4 "Persists on mutation".
    @Test func setIntervalExposesAndPersistsTheNewValue() async throws {
        let store = seededStore()
        let state = await SettingsState(store: store)

        await state.setInterval(.seconds(3))

        #expect(await state.samplingInterval == .seconds(3))
        #expect(store.saveCount == 1)
        let saved = try #require(store.saved.last)
        #expect(saved.samplingInterval == .seconds(3))
        #expect(saved.menuBarModules == [.memory])
    }

    // settings — ST-4 "Unchanged mutation does not persist": the guard is on
    // the whole value, so a repeat of the same interval never reaches the store.
    @Test func repeatingTheSameIntervalDoesNotSaveAgain() async {
        let store = seededStore()
        let state = await SettingsState(store: store)

        await state.setInterval(.seconds(3))
        await state.setInterval(.seconds(3))

        #expect(store.saveCount == 1)
        #expect(await state.samplingInterval == .seconds(3))
    }

    // settings — ST-4 "Mutation is clamped": ST-1 runs before persistence, so
    // an out-of-range request is stored clamped, not rejected.
    @Test func anOutOfRangeIntervalIsClampedBeforeItIsPersisted() async throws {
        let store = seededStore()
        let state = await SettingsState(store: store)

        await state.setInterval(.milliseconds(100))

        #expect(await state.samplingInterval == .milliseconds(500))
        let saved = try #require(store.saved.last)
        #expect(saved.samplingInterval == .milliseconds(500))
    }

    // settings — ST-4 "Mutation is clamped", upper bound: the second half of
    // the clamp, so a passing implementation cannot hardcode the lower one.
    @Test func anIntervalAboveTheMaximumIsClampedToFiveSeconds() async throws {
        let store = seededStore()
        let state = await SettingsState(store: store)

        await state.setInterval(.seconds(9))

        #expect(await state.samplingInterval == .seconds(5))
        let saved = try #require(store.saved.last)
        #expect(saved.samplingInterval == .seconds(5))
    }

    // settings — ST-4 "Save failure keeps the in-memory value": the failure is
    // recorded, never thrown, and never rolls the value back.
    @Test func aFailedSaveKeepsTheValueAndRecordsTheError() async throws {
        let store = seededStore(throwOnSave: [0])
        let state = await SettingsState(store: store)

        await state.setInterval(.seconds(3))

        #expect(await state.samplingInterval == .seconds(3))
        let recorded = try #require(await state.lastSaveError)
        #expect(recorded is FakeSettingsStore.ScriptedError)
        #expect(store.saveCount == 1)
        #expect(store.saved.isEmpty)
    }

    // settings — ST-4 "Save failure keeps the in-memory value": the next
    // successful save clears the recorded error.
    @Test func aLaterSuccessfulSaveClearsTheRecordedError() async {
        let store = seededStore(throwOnSave: [0])
        let state = await SettingsState(store: store)

        await state.setInterval(.seconds(3))
        #expect(await state.lastSaveError != nil)

        await state.setInterval(.seconds(4))

        #expect(await state.lastSaveError == nil)
        #expect(await state.samplingInterval == .seconds(4))
        #expect(store.saveCount == 2)
        #expect(store.saved.map(\.samplingInterval) == [.seconds(4)])
    }

    // settings — ST-4 "Hiding a module persists".
    @Test func hidingAModulePersistsTheShorterList() async throws {
        let store = bothModulesStore()
        let state = await SettingsState(store: store)

        await state.setModule(.memory, visible: false)

        #expect(await state.menuBarModules == [.cpu])
        let saved = try #require(store.saved.last)
        #expect(saved.menuBarModules == [.cpu])
        #expect(store.saveCount == 1)
    }

    // settings — ST-4: showing a hidden module appends it at the end and is
    // idempotent, which is the other branch of `setModule(_:visible:)`.
    @Test func showingAHiddenModuleAppendsItAndIsIdempotent() async {
        let store = seededStore()
        let state = await SettingsState(store: store)

        await state.setModule(.cpu, visible: true)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saveCount == 1)

        await state.setModule(.cpu, visible: true)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saveCount == 1)
    }

    // settings — ST-4 "Last module cannot be hidden": the refusal is total —
    // no value change, no save, and `canHide` reports it up front.
    @Test func theLastVisibleModuleIsRefusedAndNothingIsPersisted() async {
        let store = FakeSettingsStore(
            stored: Settings(samplingInterval: .seconds(1), menuBarModules: [.cpu])
        )
        let state = await SettingsState(store: store)

        #expect(await state.canHide(.cpu) == false)

        await state.setModule(.cpu, visible: false)

        #expect(await state.menuBarModules == [.cpu])
        #expect(store.saveCount == 0)
    }

    // settings — ST-4: `canHide` is true only while more than one module is
    // visible, so the form can disable exactly the right toggle.
    @Test func canHideIsTrueOnlyWhileASecondModuleIsVisible() async {
        let state = await SettingsState(store: bothModulesStore())

        #expect(await state.canHide(.memory) == true)

        await state.setModule(.memory, visible: false)

        #expect(await state.canHide(.cpu) == false)
    }

    // settings — ST-4 "Reorder persists".
    @Test func moveUpReordersAndPersists() async throws {
        let store = bothModulesStore()
        let state = await SettingsState(store: store)

        await state.moveUp(.memory)

        #expect(await state.menuBarModules == [.memory, .cpu])
        let saved = try #require(store.saved.last)
        #expect(saved.menuBarModules == [.memory, .cpu])
        #expect(store.saveCount == 1)
    }

    // settings — ST-4 "Reorder persists", the opposite direction plus the edge
    // guard: a move that cannot happen changes nothing and saves nothing.
    @Test func moveDownReordersAndAnEdgeMoveIsANoOp() async {
        let store = bothModulesStore()
        let state = await SettingsState(store: store)

        await state.moveDown(.cpu)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saveCount == 1)

        await state.moveUp(.memory)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saveCount == 1)
    }

    // settings — ST-4: `observe` receives every committed value exactly once,
    // synchronously, and only after the store has been asked to save it.
    @Test func observersReceiveEachCommitOnceAndAfterTheSave() async {
        let store = bothModulesStore()
        let state = await SettingsState(store: store)
        let received = ClockProbe<[Settings]>([])
        let saveCountsAtNotification = ClockProbe<[Int]>([])

        await state.observe { settings in
            received.mutate { $0.append(settings) }
            saveCountsAtNotification.mutate { $0.append(store.saveCount) }
        }

        await state.setInterval(.seconds(3))
        await state.setInterval(.seconds(3))
        await state.moveUp(.memory)

        #expect(received.value.count == 2)
        #expect(received.value.map(\.samplingInterval) == [.seconds(3), .seconds(3)])
        #expect(received.value.map(\.menuBarModules) == [[.cpu, .memory], [.memory, .cpu]])
        // Each notification saw the save that produced it already counted.
        #expect(saveCountsAtNotification.value == [1, 2])
    }

    // settings — ST-4: a failed save still notifies, because the in-memory
    // value did change and the cadence controller must follow it.
    @Test func observersAreNotifiedEvenWhenTheSaveFailed() async {
        let store = seededStore(throwOnSave: [0])
        let state = await SettingsState(store: store)
        let received = ClockProbe<[Duration]>([])

        await state.observe { settings in
            received.mutate { $0.append(settings.samplingInterval) }
        }

        await state.setInterval(.seconds(3))

        #expect(received.value == [.seconds(3)])
        #expect(await state.lastSaveError != nil)
    }

    // settings — ST-4 (convention 13): every mutation goes through the main
    // actor, so the store never sees a background thread.
    @Test func everySaveHappensOnTheMainThread() async {
        let store = bothModulesStore()
        let state = await SettingsState(store: store)

        await state.setInterval(.seconds(3))
        await state.setModule(.memory, visible: false)

        #expect(store.savedOnMainThread.count == 2)
        #expect(store.savedOnMainThread.allSatisfy { $0 })
    }

    // MARK: - ST-7 end to end

    /// A long script so the restarting loop never runs out of distinct samples.
    private func climbingSamples(steps: Int = 400) -> [CPUTickSample] {
        (0..<steps).map { step in
            TickFixtures.sample(
                coreCount: 2,
                user: UInt32(step * 50),
                system: 0,
                idle: UInt32(step * 50),
                nice: 0
            )
        }
    }

    @MainActor
    private func makeSampler(
        state: MetricsState,
        provider: FakeCPUProvider,
        interval: Duration,
        clock: any Clock<Duration>
    ) -> MetricsSampler {
        MetricsSampler(
            state: state,
            cpuProvider: provider,
            memoryProvider: FakeMemoryProvider(counts: [MemoryFixtures.eightGiB]),
            diskProvider: FakeDiskProvider(
                throughput: [],
                capacities: [DiskFixtures.referenceCapacity]
            ),
            networkProvider: FakeNetworkProvider(counters: []),
            topologyProvider: FakeCoreTopologyProvider(result: TickFixtures.performanceFirstTopology),
            interval: interval,
            clock: clock
        )
    }

    // settings — ST-7 "Interval change is applied to the sampler".
    //
    // The full path: the form calls `setInterval`, the state commits and
    // notifies, the cadence controller resolves CM-1 and calls
    // `apply(interval:)`, and the loop restarts once. No view touches the
    // sampler, and every step is observed on the manual clock.
    @Test func anIntervalChangeReachesTheRunningSamplerThroughTheCadenceController() async {
        let state = await MetricsState()
        let store = FakeSettingsStore(
            stored: Settings(samplingInterval: .seconds(1), menuBarModules: [.cpu, .memory])
        )
        let settings = await SettingsState(store: store)
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: FakeCPUProvider(samples: climbingSamples()),
            interval: .seconds(1),
            clock: clock
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)

        await sampler.start()
        await clock.awaitSleepCount(1)
        await controller.panelDidOpen()
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        // Parked on the configured 1 s gap; nothing has restarted yet.
        let sleepsBefore = clock.sleepCount
        #expect(clock.pendingDeadlines == [.milliseconds(1100)])
        #expect(await state.cpuHistory.count == 1)

        await settings.setInterval(.seconds(3))
        await clock.awaitSleepCount(sleepsBefore + 1)

        #expect(clock.sleepCount == sleepsBefore + 1)
        #expect(clock.pendingDeadlines == [.milliseconds(200)])
        #expect(await sampler.interval == .seconds(3))

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(sleepsBefore + 2)

        // The gap after the restart's startup gap is the newly configured 3 s.
        #expect(clock.pendingDeadlines == [.milliseconds(3200)])
        #expect(await state.cpuHistory.count == 2)
        #expect(store.saved.last?.samplingInterval == .seconds(3))

        await sampler.stop()
    }
}
