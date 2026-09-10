import Foundation
import Testing
@testable import system_monitor

// cpu-metrics — CM-1 "Cadence truth table".
@Suite("SamplingCadence")
struct SamplingCadenceTests {

    /// The three configured intervals the truth table is pinned against: the
    /// low bound, the default, and the high bound of the ST-1 range.
    private static let configuredIntervals: [Duration] = [
        .milliseconds(500),
        .seconds(1),
        .seconds(5),
    ]

    // cpu-metrics — CM-1 "Cadence truth table": the closed column is the idle
    // cadence regardless of what the user configured.
    @Test(arguments: SamplingCadenceTests.configuredIntervals)
    func aClosedPanelAlwaysSamplesAtTheIdleCadence(configured: Duration) {
        let effective = SamplingCadence.effective(configured: configured, panelOpen: false)

        #expect(effective == .seconds(2))
        #expect(effective == SamplingCadence.idleInterval)
    }

    // cpu-metrics — CM-1 "Cadence truth table": the open column is the
    // configured interval, untouched.
    @Test(arguments: SamplingCadenceTests.configuredIntervals)
    func anOpenPanelSamplesAtTheConfiguredInterval(configured: Duration) {
        #expect(SamplingCadence.effective(configured: configured, panelOpen: true) == configured)
    }
}

// menu-bar-widget — MBW-13 support: the doubles consumed by the cadence
// controller and the status item controller record what they were told, so the
// suites that use them assert on a real transition sequence.
@Suite("Panel visibility doubles")
struct PanelVisibilityDoubleTests {

    @Test func theSpyRecordsEveryTransitionInOrder() async {
        let spy = PanelVisibilitySpy()

        await spy.panelDidOpen()
        await spy.panelDidClose()
        await spy.panelDidOpen()

        #expect(await spy.events == [true, false, true])
    }

    @Test func aFreshSpyHasRecordedNothing() async {
        #expect(await PanelVisibilitySpy().events.isEmpty)
    }

    // launch-at-login — LAL-4 support: an enable/disable failure is recorded
    // instead of presented, so the controller test can assert it did not crash.
    @Test func theErrorRecorderCollectsEveryRecordedError() async {
        let recorder = ErrorRecorder()
        let failure = FakeLaunchAtLoginService.ScriptedError()

        await recorder.record(failure)

        #expect(await recorder.errors.count == 1)
        #expect(await recorder.errors.first is FakeLaunchAtLoginService.ScriptedError)
    }
}

// cpu-metrics — CM-1 `SamplingCadenceController` scenarios.
//
// The controller is the only thing that turns a panel transition or a settings
// change into `MetricsSampler.apply(interval:)`. Its cadence decisions are
// asserted on the sampler's stored `interval` while it is stopped, and on the
// `ManualClock`'s sleepers once it is running, so "restarted once" is a counted
// fact rather than a timing guess.
@Suite("SamplingCadenceController", .timeLimit(.minutes(1)))
struct SamplingCadenceControllerTests {

    /// A long script so a restarting loop never runs out of distinct samples.
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

    /// A store seeded with the configured cadence under test.
    private func store(configured: Duration) -> FakeSettingsStore {
        FakeSettingsStore(
            stored: Settings(samplingInterval: configured, menuBarModules: [.cpu, .memory])
        )
    }

    // cpu-metrics — CM-1: a stopped sampler still follows every transition, so
    // the composition root can wire the controller before `start()`.
    @Test func aStoppedSamplerFollowsEveryPanelTransition() async {
        let state = await MetricsState()
        let settings = await SettingsState(store: store(configured: .seconds(1)))
        // Seeded exactly as the composition root does: the closed cadence.
        let sampler = await makeSampler(
            state: state,
            provider: FakeCPUProvider(samples: climbingSamples()),
            interval: SamplingCadence.effective(configured: .seconds(1), panelOpen: false),
            clock: ManualClock()
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)

        #expect(await controller.isPanelOpen == false)
        #expect(await sampler.interval == .seconds(2))

        await controller.panelDidOpen()

        #expect(await controller.isPanelOpen)
        #expect(await sampler.interval == .seconds(1))

        await controller.panelDidClose()

        #expect(await controller.isPanelOpen == false)
        #expect(await sampler.interval == .seconds(2))
        #expect(await sampler.isRunning == false)
    }

    // settings — ST-7 / cpu-metrics — CM-1: while the panel is open the
    // configured interval passes straight through to the sampler.
    @Test func anIntervalChangeWhileOpenReachesTheSampler() async {
        let state = await MetricsState()
        let settings = await SettingsState(store: store(configured: .seconds(1)))
        let sampler = await makeSampler(
            state: state,
            provider: FakeCPUProvider(samples: climbingSamples()),
            interval: .seconds(1),
            clock: ManualClock()
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)

        await controller.panelDidOpen()
        await settings.setInterval(.seconds(3))

        #expect(await sampler.interval == .seconds(3))
    }

    // cpu-metrics — CM-1: the same change while the panel is closed is absorbed
    // by the idle cadence, which is the branch that makes the rule worth having.
    @Test func anIntervalChangeWhileClosedKeepsTheIdleCadence() async {
        let state = await MetricsState()
        let settings = await SettingsState(store: store(configured: .seconds(1)))
        let sampler = await makeSampler(
            state: state,
            provider: FakeCPUProvider(samples: climbingSamples()),
            interval: SamplingCadence.effective(configured: .seconds(1), panelOpen: false),
            clock: ManualClock()
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)

        await settings.setInterval(.seconds(3))

        #expect(await controller.isPanelOpen == false)
        #expect(await sampler.interval == .seconds(2))

        // Opening the panel then adopts the value that was configured meanwhile.
        await controller.panelDidOpen()

        #expect(await sampler.interval == .seconds(3))
    }

    // cpu-metrics — CM-1 "Opening the panel restarts at the configured rate":
    // opening a running loop costs exactly one restart.
    @Test func openingThePanelRestartsARunningLoopExactlyOnce() async {
        let state = await MetricsState()
        let settings = await SettingsState(store: store(configured: .seconds(1)))
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: FakeCPUProvider(samples: climbingSamples()),
            interval: SamplingCadence.effective(configured: .seconds(1), panelOpen: false),
            clock: clock
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        #expect(clock.pendingDeadlines == [.milliseconds(2100)])

        await controller.panelDidOpen()
        await clock.awaitSleepCount(3)

        #expect(clock.sleepCount == 3)
        #expect(clock.pendingDeadlines == [.milliseconds(200)])

        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(4)

        #expect(clock.pendingDeadlines == [.milliseconds(1200)])
        #expect(await state.cpuHistory.count == 2)

        await sampler.stop()
    }

    // cpu-metrics — CM-1: a repeated open is not a transition, so the loop is
    // left alone. Without the guard this would restart and lose a CPU tick.
    @Test func aSecondOpenDoesNotRestartTheLoopAgain() async {
        let state = await MetricsState()
        let settings = await SettingsState(store: store(configured: .seconds(1)))
        let clock = ManualClock()
        let sampler = await makeSampler(
            state: state,
            provider: FakeCPUProvider(samples: climbingSamples()),
            interval: SamplingCadence.effective(configured: .seconds(1), panelOpen: false),
            clock: clock
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)

        await sampler.start()
        await clock.awaitSleepCount(1)
        clock.advance(by: .milliseconds(100))
        await clock.awaitSleepCount(2)

        await controller.panelDidOpen()
        await clock.awaitSleepCount(3)

        await controller.panelDidOpen()

        #expect(clock.sleepCount == 3)
        #expect(clock.pendingDeadlines == [.milliseconds(200)])
        #expect(await controller.isPanelOpen)

        await sampler.stop()
    }

    /// Reports an open through the protocol existential, which only compiles
    /// while the argument really conforms to `PanelVisibilityObserver`.
    @MainActor
    private func reportOpen(to observer: any PanelVisibilityObserver) {
        observer.panelDidOpen()
    }

    // menu-bar-widget — MBW-13 support: the controller is the observer the
    // popover delegate talks to, so the spy and it share one protocol.
    @Test func theControllerAndTheSpyShareThePanelVisibilityObserverProtocol() async {
        let state = await MetricsState()
        let settings = await SettingsState(store: store(configured: .seconds(1)))
        let sampler = await makeSampler(
            state: state,
            provider: FakeCPUProvider(samples: climbingSamples()),
            interval: SamplingCadence.effective(configured: .seconds(1), panelOpen: false),
            clock: ManualClock()
        )
        let controller = await SamplingCadenceController(sampler: sampler, settings: settings)
        let spy = PanelVisibilitySpy()

        await reportOpen(to: controller)
        await reportOpen(to: spy)

        #expect(await controller.isPanelOpen)
        #expect(await spy.events == [true])
        #expect(await sampler.interval == .seconds(1))
    }
}
