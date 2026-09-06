import Foundation
import Testing
@testable import system_monitor

/// One interval input and the value ST-1 requires after normalisation, so the
/// initialiser and `withSamplingInterval` run through the same table.
nonisolated struct IntervalClampCase: Sendable, CustomTestStringConvertible {
    let name: String
    let input: Duration
    let expected: Duration

    var testDescription: String { name }

    static let all: [IntervalClampCase] = [
        IntervalClampCase(name: "below the low bound", input: .milliseconds(400), expected: .milliseconds(500)),
        IntervalClampCase(name: "at the low bound", input: .milliseconds(500), expected: .milliseconds(500)),
        IntervalClampCase(name: "in range", input: .milliseconds(2500), expected: .milliseconds(2500)),
        IntervalClampCase(name: "at the high bound", input: .seconds(5), expected: .seconds(5)),
        IntervalClampCase(name: "above the high bound", input: .seconds(6), expected: .seconds(5)),
    ]
}

// settings — ST-1 "Settings value invariants".
@Suite("Settings")
struct SettingsTests {

    // settings — ST-1 "Interval clamped at the low bound", "In-range interval
    // preserved", "Interval clamped at the high bound".
    @Test(arguments: IntervalClampCase.all)
    func theInitialiserClampsTheSamplingIntervalToTheSupportedRange(testCase: IntervalClampCase) {
        let settings = Settings(samplingInterval: testCase.input)

        #expect(settings.samplingInterval == testCase.expected)
    }

    // settings — ST-1: the transition helper enforces the same clamp and leaves
    // the module list untouched.
    @Test(arguments: IntervalClampCase.all)
    func withSamplingIntervalClampsTheSameWayAndKeepsTheModules(testCase: IntervalClampCase) {
        let settings = Settings(samplingInterval: .seconds(1), menuBarModules: [.memory])

        let updated = settings.withSamplingInterval(testCase.input)

        #expect(updated.samplingInterval == testCase.expected)
        #expect(updated.menuBarModules == [.memory])
    }

    // settings — ST-1 "Defaults".
    @Test func defaultsAreOneSecondAndTheDefaultModuleOrder() {
        let settings = Settings()

        #expect(settings.samplingInterval == .seconds(1))
        #expect(settings.menuBarModules == MetricModule.menuBarOrder)
        #expect(Settings.default == settings)
    }

    // settings — ST-1: the published bounds are the ones the UI steps over.
    @Test func theIntervalConstantsPinTheSupportedRange() {
        #expect(Settings.minimumInterval == .milliseconds(500))
        #expect(Settings.maximumInterval == .seconds(5))
        #expect(Settings.intervalStep == .milliseconds(500))
        #expect(Settings.defaultInterval == .seconds(1))
    }

    // settings — ST-1 "Duplicates dropped, order kept".
    @Test func theInitialiserDropsLaterDuplicatesAndKeepsTheCallerOrder() {
        let settings = Settings(menuBarModules: [.memory, .cpu, .memory])

        #expect(settings.menuBarModules == [.memory, .cpu])
    }

    // settings — ST-1 "Empty list normalises to the default order".
    @Test func anEmptyModuleListNormalisesToTheDefaultOrder() {
        let settings = Settings(menuBarModules: [])

        #expect(settings.menuBarModules == MetricModule.menuBarOrder)
    }

    // settings — ST-1 last-module guard: nothing can hide the only module, and
    // a module that is already hidden cannot be hidden again.
    @Test func canHideIsFalseForTheLastVisibleModuleAndForAnAbsentOne() {
        let settings = Settings(menuBarModules: [.memory])

        #expect(settings.canHide(.memory) == false)
        #expect(settings.canHide(.cpu) == false)
    }

    @Test func canHideIsTrueWhileMoreThanOneModuleIsVisible() {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(settings.canHide(.cpu))
        #expect(settings.canHide(.memory))
    }

    @Test func hidingTheLastVisibleModuleReturnsSelf() {
        let settings = Settings(menuBarModules: [.memory])

        #expect(settings.hiding(.memory) == settings)
    }

    @Test func hidingRemovesTheModuleWhileAnotherRemains() {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(settings.hiding(.cpu).menuBarModules == [.memory])
    }

    @Test func showingAppendsAnAbsentModuleAtTheEnd() {
        let settings = Settings(menuBarModules: [.memory])

        #expect(settings.showing(.cpu).menuBarModules == [.memory, .cpu])
    }

    @Test func showingAVisibleModuleIsIdempotent() {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(settings.showing(.cpu) == settings)
    }

    @Test func movingUpSwapsWithThePredecessor() {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(settings.movingUp(.memory).menuBarModules == [.memory, .cpu])
    }

    @Test func movingDownSwapsWithTheSuccessor() {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(settings.movingDown(.cpu).menuBarModules == [.memory, .cpu])
    }

    @Test func movingUpTheFirstModuleReturnsSelf() {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(settings.movingUp(.cpu) == settings)
    }

    @Test func movingDownTheLastModuleReturnsSelf() {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(settings.movingDown(.memory) == settings)
    }

    @Test func movingAnAbsentModuleReturnsSelf() {
        let settings = Settings(menuBarModules: [.memory])

        #expect(settings.movingUp(.cpu) == settings)
        #expect(settings.movingDown(.cpu) == settings)
    }

    // settings — ST-1: `Equatable` compares both stored fields.
    @Test func equalityComparesTheIntervalAndTheOrderedModuleList() {
        let base = Settings(samplingInterval: .seconds(2), menuBarModules: [.memory, .cpu])

        #expect(base == Settings(samplingInterval: .seconds(2), menuBarModules: [.memory, .cpu]))
        #expect(base != Settings(samplingInterval: .seconds(3), menuBarModules: [.memory, .cpu]))
        #expect(base != Settings(samplingInterval: .seconds(2), menuBarModules: [.cpu, .memory]))
    }
}

// settings — ST-2 "Settings store port". The port has no production adapter in
// the Domain, so the Mutex-backed double is what proves the contract.
@Suite("SettingsStore port")
struct SettingsStorePortTests {

    // settings — ST-2 "Fake round trip".
    @Test func theFakeReturnsTheSeededValueAndCountsTheLoad() {
        let seeded = Settings(samplingInterval: .seconds(2), menuBarModules: [.memory])
        let store = FakeSettingsStore(stored: seeded)

        let loaded = store.load()

        #expect(loaded.samplingInterval == .seconds(2))
        #expect(loaded.menuBarModules == [.memory])
        #expect(store.loadCount == 1)
        #expect(store.saveCount == 0)
    }

    // settings — ST-2: an unseeded store still yields a value satisfying ST-1.
    @Test func anUnseededFakeLoadsTheDefaults() {
        let store = FakeSettingsStore()

        #expect(store.load() == Settings())
        #expect(store.loadCount == 1)
    }

    // settings — ST-2 "Scripted save failure": the throw set is zero-based and a
    // throwing call still advances the call counter.
    @Test func theFirstSaveThrowsAndTheSecondRecordsTheValue() throws {
        let store = FakeSettingsStore(throwOnSave: [0])
        let rejected = Settings(samplingInterval: .seconds(3))
        let accepted = Settings(samplingInterval: .seconds(4), menuBarModules: [.memory])

        #expect(throws: FakeSettingsStore.ScriptedError.self) {
            try store.save(rejected)
        }
        try store.save(accepted)

        #expect(store.saved == [accepted])
        #expect(store.saveCount == 2)
        #expect(store.load() == accepted)
    }

    // settings — ST-2 (convention 4): the double records the thread of every
    // save, which is what lets ST-4 prove persistence happens on the main actor.
    @Test func theFakeRecordsWhetherEachSaveRanOnTheMainThread() async throws {
        let store = FakeSettingsStore()

        try await MainActor.run { try store.save(Settings()) }
        try await Task.detached {
            try store.save(Settings(samplingInterval: .seconds(2)))
        }.value

        #expect(store.savedOnMainThread == [true, false])
        #expect(store.saveCount == 2)
    }
}
