import Foundation
import Testing
@testable import system_monitor

/// A `Duration` and the `Double` a `UserDefaults` write must hold for it, so
/// the seconds conversion is exercised over the whole 0.5 s grid the UI offers.
nonisolated struct IntervalSecondsCase: Sendable, CustomTestStringConvertible {
    let name: String
    let duration: Duration
    let seconds: Double

    var testDescription: String { name }

    static let all: [IntervalSecondsCase] = [
        IntervalSecondsCase(name: "half a second", duration: .milliseconds(500), seconds: 0.5),
        IntervalSecondsCase(name: "one second", duration: .seconds(1), seconds: 1),
        IntervalSecondsCase(name: "one and a half", duration: .milliseconds(1500), seconds: 1.5),
        IntervalSecondsCase(name: "two and a half", duration: .milliseconds(2500), seconds: 2.5),
        IntervalSecondsCase(name: "five seconds", duration: .seconds(5), seconds: 5),
    ]
}

/// A private `UserDefaults` suite plus the name needed to erase it again.
///
/// Every test gets its own suite (convention 12) so nothing leaks between
/// cases, between runs, or into the test host's own domain. The caller must
/// `defer { suite.remove() }`.
///
/// Deliberately not `Sendable`: `UserDefaults` is not `Sendable` on this SDK,
/// and the only `@unchecked Sendable` this change sanctions is the adapter
/// itself. The helper never leaves the test body that created it.
nonisolated struct SettingsSuite {
    let name: String
    let defaults: UserDefaults

    /// Keys actually persisted in this suite, ignoring everything the global
    /// domain contributes to `dictionaryRepresentation()`.
    var persistedKeys: Set<String> {
        Set(defaults.persistentDomain(forName: name)?.keys ?? [:].keys)
    }

    func remove() {
        defaults.removePersistentDomain(forName: name)
    }
}

private func makeSuite() throws -> SettingsSuite {
    let name = "UserDefaultsSettingsStoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defaults.removePersistentDomain(forName: name)
    return SettingsSuite(name: name, defaults: defaults)
}

// settings — ST-3 "Round trip", "Missing keys", "Corrupt interval",
// "Out-of-range persisted interval", "Unknown module raw values ignored",
// "Only unknown module raw values".
// launch-at-login — LAL-3 "Nothing persisted".
@Suite("UserDefaultsSettingsStore", .timeLimit(.minutes(1)))
struct UserDefaultsSettingsStoreTests {

    // settings — ST-3 "Round trip": the value that goes in comes back out of a
    // second store built over the same suite, so the keys are the only channel.
    @Test func aSavedValueIsLoadedBackUnchanged() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        let saved = Settings(samplingInterval: .seconds(3), menuBarModules: [.memory, .cpu])

        try UserDefaultsSettingsStore(defaults: suite.defaults).save(saved)
        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded == saved)
        #expect(loaded.samplingInterval == .seconds(3))
        #expect(loaded.menuBarModules == [.memory, .cpu])
    }

    // settings — ST-3 "Round trip", second data path: a different interval and
    // a shorter list, so a hardcoded answer cannot satisfy both cases.
    @Test func aSecondValueRoundTripsThroughTheSameKeys() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        let saved = Settings(samplingInterval: .milliseconds(500), menuBarModules: [.cpu])

        try UserDefaultsSettingsStore(defaults: suite.defaults).save(saved)
        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded == saved)
        #expect(loaded.samplingInterval == .milliseconds(500))
        #expect(loaded.menuBarModules == [.cpu])
    }

    // settings — ST-3 "Round trip": saving twice leaves the second value, so
    // the adapter overwrites rather than appends.
    @Test func savingTwiceLeavesTheSecondValue() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        let store = UserDefaultsSettingsStore(defaults: suite.defaults)

        try store.save(Settings(samplingInterval: .seconds(3), menuBarModules: [.memory, .cpu]))
        try store.save(Settings(samplingInterval: .seconds(2), menuBarModules: [.memory]))

        #expect(store.load() == Settings(samplingInterval: .seconds(2), menuBarModules: [.memory]))
    }

    // settings — ST-3 "Missing keys": a fresh install reads nothing and gets
    // the ST-1 defaults, not an error and not an empty module list.
    @Test func anEmptySuiteLoadsTheDefaults() throws {
        let suite = try makeSuite()
        defer { suite.remove() }

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded == Settings())
        #expect(loaded.samplingInterval == Settings.defaultInterval)
        #expect(loaded.menuBarModules == MetricModule.menuBarOrder)
        #expect(suite.persistedKeys.isEmpty, "load() must not write anything")
    }

    // settings — ST-3 "Corrupt interval": a string under the interval key is
    // the wrong type, so that field falls back while the modules survive.
    @Test func aCorruptIntervalFallsBackToTheDefaultWithoutThrowing() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        suite.defaults.set("fast", forKey: UserDefaultsSettingsStore.Key.samplingIntervalSeconds)
        suite.defaults.set(["memory"], forKey: UserDefaultsSettingsStore.Key.menuBarModules)

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded.samplingInterval == .seconds(1))
        #expect(loaded.menuBarModules == [.memory], "a corrupt interval must not discard the module list")
    }

    // settings — ST-3 "Out-of-range persisted interval": a value written by an
    // older build, or by hand, is clamped through the ST-1 initialiser.
    @Test func anOutOfRangePersistedIntervalIsClampedOnLoad() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        suite.defaults.set(9.0, forKey: UserDefaultsSettingsStore.Key.samplingIntervalSeconds)

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded.samplingInterval == .seconds(5))
    }

    // settings — ST-3, the other clamp edge, so the clamp is real and not a
    // ceiling constant.
    @Test func anImplausiblySmallPersistedIntervalIsClampedOnLoad() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        suite.defaults.set(0.1, forKey: UserDefaultsSettingsStore.Key.samplingIntervalSeconds)

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded.samplingInterval == .milliseconds(500))
    }

    // settings — ST-3 "Unknown module raw values ignored": a v2 module written
    // by a newer build is dropped and the known ones are kept in order.
    @Test func unknownModuleRawValuesAreDropped() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        suite.defaults.set(["gpu", "memory"], forKey: UserDefaultsSettingsStore.Key.menuBarModules)

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded.menuBarModules == [.memory])
        #expect(loaded.samplingInterval == Settings.defaultInterval)
    }

    // settings — ST-3 "Only unknown module raw values": dropping everything
    // must not yield an empty widget; ST-1 normalises it to the default order.
    @Test func aListOfOnlyUnknownModulesNormalisesToTheDefaultOrder() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        suite.defaults.set(["gpu"], forKey: UserDefaultsSettingsStore.Key.menuBarModules)

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded.menuBarModules == MetricModule.menuBarOrder)
        #expect(loaded.menuBarModules.isEmpty == false)
    }

    // settings — ST-3 "Corrupt interval": NaN and the infinities are `Double`s,
    // so they pass the type cast that catches `"fast"`. `Duration.seconds(_:)`
    // traps on all three, so they must be rejected before conversion rather
    // than clamped after it.
    @Test(arguments: [Double.nan, .infinity, -.infinity, .signalingNaN])
    func aNonFiniteIntervalFallsBackToTheDefault(stored: Double) throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        suite.defaults.set(stored, forKey: UserDefaultsSettingsStore.Key.samplingIntervalSeconds)

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded.samplingInterval == Settings.defaultInterval)
    }

    // settings — ST-3: a modules key of the wrong type is treated like an
    // absent one rather than crashing the cast.
    @Test func aCorruptModuleListFallsBackToTheDefaultOrder() throws {
        let suite = try makeSuite()
        defer { suite.remove() }
        suite.defaults.set(42, forKey: UserDefaultsSettingsStore.Key.menuBarModules)

        let loaded = UserDefaultsSettingsStore(defaults: suite.defaults).load()

        #expect(loaded.menuBarModules == MetricModule.menuBarOrder)
    }

    // settings — ST-3: the persisted interval is a plain `Double` of seconds,
    // exact for every 0.5 s the stepper can produce, so `defaults read` shows a
    // number a human recognises.
    @Test(arguments: IntervalSecondsCase.all)
    func secondsConvertsTheSupportedIntervalsExactly(testCase: IntervalSecondsCase) {
        #expect(UserDefaultsSettingsStore.seconds(testCase.duration) == testCase.seconds)
    }

    // settings — ST-3: what `seconds(_:)` produces is what lands under the key.
    @Test(arguments: IntervalSecondsCase.all)
    func theSavedIntervalKeyHoldsThatExactDouble(testCase: IntervalSecondsCase) throws {
        let suite = try makeSuite()
        defer { suite.remove() }

        try UserDefaultsSettingsStore(defaults: suite.defaults)
            .save(Settings(samplingInterval: testCase.duration))

        let stored = try #require(
            suite.defaults.object(forKey: UserDefaultsSettingsStore.Key.samplingIntervalSeconds) as? Double
        )
        #expect(stored == testCase.seconds)
    }

    // settings — ST-3: the module list is stored as raw strings, so a newer
    // build reading the same suite can recognise them.
    @Test func theSavedModulesKeyHoldsTheRawValuesInOrder() throws {
        let suite = try makeSuite()
        defer { suite.remove() }

        try UserDefaultsSettingsStore(defaults: suite.defaults)
            .save(Settings(samplingInterval: .seconds(1), menuBarModules: [.memory, .cpu]))

        #expect(
            suite.defaults.stringArray(forKey: UserDefaultsSettingsStore.Key.menuBarModules)
                == ["memory", "cpu"]
        )
    }

    // launch-at-login — LAL-3 "Nothing persisted": the adapter writes exactly
    // two keys, and the login-item status is not one of them. Registration
    // truth lives in `SMAppService`, read live on every access.
    @Test func savingWritesExactlyTheTwoSettingsKeys() throws {
        let suite = try makeSuite()
        defer { suite.remove() }

        try UserDefaultsSettingsStore(defaults: suite.defaults)
            .save(Settings(samplingInterval: .seconds(3), menuBarModules: [.memory, .cpu]))

        #expect(
            suite.persistedKeys == [
                UserDefaultsSettingsStore.Key.samplingIntervalSeconds,
                UserDefaultsSettingsStore.Key.menuBarModules,
            ]
        )
    }

    // launch-at-login — LAL-3 "Nothing persisted": no key in the suite refers
    // to launch at login under any spelling.
    @Test func noPersistedKeyRefersToLaunchAtLogin() throws {
        let suite = try makeSuite()
        defer { suite.remove() }

        try UserDefaultsSettingsStore(defaults: suite.defaults)
            .save(Settings(samplingInterval: .seconds(3), menuBarModules: [.memory, .cpu]))

        let keys = suite.persistedKeys
        #expect(keys.count == 2, "the save wrote something other than the two settings keys")
        for key in keys {
            let lowered = key.lowercased()
            #expect(lowered.contains("login") == false, "\(key) refers to login")
            #expect(lowered.contains("launch") == false, "\(key) refers to launch")
            #expect(lowered.contains("smappservice") == false, "\(key) refers to SMAppService")
        }
    }
}
