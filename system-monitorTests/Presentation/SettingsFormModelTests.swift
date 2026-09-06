import Foundation
import Testing
@testable import system_monitor

// settings — ST-6 "Settings view controls".
//
// Every derivation the settings form needs is a pure function of a `Settings`
// value plus an injected `Locale`, so the stepper arithmetic, the label text
// and the toggle enablement are tested without rendering a `Form`. The view
// (batch E, task 6.2) only binds these results to controls.
@Suite("Settings form model", .timeLimit(.minutes(1)))
struct SettingsFormModelTests {

    private static let english = Locale(identifier: "en_US")
    private static let german = Locale(identifier: "de_DE")

    /// Locale-legal narrow and non-breaking spaces normalised to plain spaces
    /// (convention 9), so a formatter that emits `U+00A0` still compares equal.
    private static func normalized(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private static func row(
        _ module: MetricModule,
        in settings: Settings
    ) throws -> ModuleRow {
        try #require(SettingsFormModel.moduleRows(for: settings).first { $0.module == module })
    }

    // MARK: - Stepper bounds and step

    // settings — ST-6: the range and step the stepper offers are the product
    // decision (0.5 s–5 s in half seconds), and they match the Domain clamp.
    @Test func theStepperSpansTheClampedRangeInHalfSeconds() {
        #expect(SettingsFormModel.intervalRange == 0.5...5)
        #expect(SettingsFormModel.intervalStep == 0.5)
        #expect(SettingsFormModel.intervalRange.lowerBound == SettingsFormModel.intervalSeconds(Settings(samplingInterval: Settings.minimumInterval)))
        #expect(SettingsFormModel.intervalRange.upperBound == SettingsFormModel.intervalSeconds(Settings(samplingInterval: Settings.maximumInterval)))
    }

    // settings — ST-6: the stepper reads the current value in seconds.
    @Test(arguments: zip(
        [Duration.seconds(1), .milliseconds(2500), .seconds(5)],
        [1.0, 2.5, 5.0]
    ))
    func theIntervalIsExposedInSeconds(interval: Duration, expected: Double) {
        let settings = Settings(samplingInterval: interval)

        #expect(SettingsFormModel.intervalSeconds(settings) == expected)
    }

    // MARK: - ST-6 "Stepper increments in half seconds"

    @Test func incrementingOneSecondYieldsOneAndAHalf() {
        #expect(SettingsFormModel.incremented(.seconds(1)) == .milliseconds(1500))
    }

    // settings — ST-6: a full sweep of the grid, so the step cannot be a
    // hardcoded single answer.
    @Test(arguments: zip(
        [Duration.milliseconds(500), .seconds(1), .milliseconds(2500), .milliseconds(4500)],
        [Duration.seconds(1), .milliseconds(1500), .seconds(3), .seconds(5)]
    ))
    func eachIncrementAddsOneHalfSecond(from: Duration, expected: Duration) {
        #expect(SettingsFormModel.incremented(from) == expected)
    }

    @Test(arguments: zip(
        [Duration.seconds(5), .seconds(3), .milliseconds(1500), .seconds(1)],
        [Duration.milliseconds(4500), .milliseconds(2500), .seconds(1), .milliseconds(500)]
    ))
    func eachDecrementRemovesOneHalfSecond(from: Duration, expected: Duration) {
        #expect(SettingsFormModel.decremented(from) == expected)
    }

    // MARK: - ST-6 "Stepper saturates at the bounds"

    @Test func incrementingAtTheMaximumStaysAtTheMaximum() {
        #expect(SettingsFormModel.incremented(.seconds(5)) == .seconds(5))
        #expect(SettingsFormModel.incremented(.seconds(5)) == Settings.maximumInterval)
    }

    @Test func decrementingAtTheMinimumStaysAtTheMinimum() {
        #expect(SettingsFormModel.decremented(.milliseconds(500)) == .milliseconds(500))
        #expect(SettingsFormModel.decremented(.milliseconds(500)) == Settings.minimumInterval)
    }

    // settings — ST-6: saturation is the Domain clamp, not a special case in
    // the form, so a value already outside the range is pulled back in.
    @Test func anOutOfRangeIntervalIsClampedByTheStep() {
        #expect(SettingsFormModel.incremented(.seconds(9)) == Settings.maximumInterval)
        #expect(SettingsFormModel.decremented(.milliseconds(100)) == Settings.minimumInterval)
    }

    // MARK: - ST-6 "Interval label"

    // settings — "Interval label under en_US"
    @Test func theLabelUsesTheDecimalPointUnderEnglish() {
        let label = SettingsFormModel.intervalLabel(for: .milliseconds(2500), locale: Self.english)

        #expect(Self.normalized(label) == "2.5 s")
    }

    // settings — "Interval label under de_DE": the decimal separator follows
    // the locale, and the unit stays the literal " s" rather than an ICU unit
    // string ("2,5 Sek."), which is what `Measurement.formatted` would give.
    @Test func theLabelUsesTheDecimalCommaUnderGerman() {
        let label = SettingsFormModel.intervalLabel(for: .milliseconds(2500), locale: Self.german)

        #expect(Self.normalized(label) == "2,5 s")
        #expect(label.contains("Sek") == false)
    }

    // settings — ST-6: one fraction digit always, so the label width does not
    // jump between a whole and a half second.
    @Test(arguments: zip(
        [Duration.milliseconds(500), .seconds(1), .seconds(5)],
        ["0.5 s", "1.0 s", "5.0 s"]
    ))
    func everyGridValueKeepsOneFractionDigit(interval: Duration, expected: String) {
        let label = SettingsFormModel.intervalLabel(for: interval, locale: Self.english)

        #expect(Self.normalized(label) == expected)
    }

    // MARK: - ST-6 "Last visible toggle disabled"

    @Test func theOnlyVisibleModuleCannotBeToggledOff() throws {
        let settings = Settings(menuBarModules: [.memory])

        let memory = try Self.row(.memory, in: settings)
        let cpu = try Self.row(.cpu, in: settings)

        #expect(memory.isVisible)
        #expect(memory.canHide == false)
        #expect(memory.isToggleEnabled == false)

        #expect(cpu.isVisible == false)
        #expect(cpu.isToggleEnabled)
    }

    // settings — ST-6: with two visible modules both toggles are live again,
    // which is the other side of the last-module guard.
    @Test func bothTogglesAreEnabledWhileTwoModulesAreVisible() throws {
        let settings = Settings(menuBarModules: [.cpu, .memory])

        #expect(try Self.row(.cpu, in: settings).isToggleEnabled)
        #expect(try Self.row(.memory, in: settings).isToggleEnabled)
    }

    // MARK: - ST-6 "Toggles follow the current order"

    @Test func theRowsFollowTheUserOrderAndPinTheMoveEdges() throws {
        let settings = Settings(menuBarModules: [.memory, .cpu])
        let rows = SettingsFormModel.moduleRows(for: settings)

        #expect(rows.map(\.module) == [.memory, .cpu])
        #expect(rows.allSatisfy { $0.isVisible })

        let memory = try Self.row(.memory, in: settings)
        let cpu = try Self.row(.cpu, in: settings)

        #expect(memory.canMoveUp == false)
        #expect(memory.canMoveDown)
        #expect(cpu.canMoveUp)
        #expect(cpu.canMoveDown == false)
    }

    // settings — ST-6: hidden modules are listed after the visible ones in the
    // default order, so the form always shows every module without inventing
    // a position for one the user cannot reorder yet.
    @Test func hiddenModulesFollowTheVisibleOnesAndCannotMove() throws {
        let settings = Settings(menuBarModules: [.memory])
        let rows = SettingsFormModel.moduleRows(for: settings)

        #expect(rows.map(\.module) == [.memory, .cpu])
        #expect(rows.count == MetricModule.allCases.count)

        let cpu = try Self.row(.cpu, in: settings)

        #expect(cpu.canMoveUp == false)
        #expect(cpu.canMoveDown == false)
    }

    // settings — ST-6: the row identity is the module, so SwiftUI's `ForEach`
    // keeps a row attached to its module across a reorder.
    @Test func eachRowIsIdentifiedByItsModule() throws {
        let settings = Settings(menuBarModules: [.memory, .cpu])
        let rows = SettingsFormModel.moduleRows(for: settings)

        #expect(rows.map(\.id) == [MetricModule.memory.id, MetricModule.cpu.id])
        #expect(Set(rows.map(\.id)).count == rows.count)
    }
}
