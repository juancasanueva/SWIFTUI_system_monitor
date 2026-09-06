import AppKit
import SwiftUI
import Testing
@testable import system_monitor

// settings — ST-6 "Settings view controls", view half.
//
// `SettingsFormModelTests` owns the pure derivations. This suite owns what the
// view adds on top of them: the stepper composes a `SettingsFormModel` step
// with a `SettingsState` intent (a swap of the two directions, or a step that
// never reaches the state, would pass every pure test), and the rendered form
// keeps its fixed width, lists hidden modules too and grows a footer when a
// save fails.
@Suite("Settings view", .timeLimit(.minutes(1)))
struct SettingsViewTests {

    /// The form's fixed width in points: the window is sized by the design,
    /// never by the longest module label.
    private static let formWidth: CGFloat = 360

    @MainActor
    private static func makeState(
        interval: Duration = .seconds(1),
        modules: [MetricModule] = MetricModule.menuBarOrder,
        throwOnSave: Set<Int> = []
    ) -> (state: SettingsState, store: FakeSettingsStore) {
        let store = FakeSettingsStore(
            stored: Settings(samplingInterval: interval, menuBarModules: modules),
            throwOnSave: throwOnSave
        )
        return (SettingsState(store: store), store)
    }

    @MainActor
    private static func fittingSize(for settings: SettingsState) -> CGSize {
        let hostingView = NSHostingView(rootView: SettingsRootView(settings: settings))
        hostingView.layoutSubtreeIfNeeded()
        return hostingView.fittingSize
    }

    // MARK: - Stepper wiring

    // settings — ST-6 "Stepper increments in half seconds": the increment
    // reaches the state and is persisted.
    @Test func theStepperIncrementCommitsOneHalfSecondUp() async {
        let (state, store) = await Self.makeState(interval: .seconds(1))

        await SettingsFormIntent.incrementInterval(state)

        #expect(await state.samplingInterval == .milliseconds(1500))
        #expect(store.saveCount == 1)
        #expect(store.saved.last?.samplingInterval == .milliseconds(1500))
    }

    // settings — ST-6: the decrement is wired to `decremented`, so the two
    // stepper directions cannot be swapped without failing here.
    @Test func theStepperDecrementCommitsOneHalfSecondDown() async {
        let (state, store) = await Self.makeState(interval: .seconds(1))

        await SettingsFormIntent.decrementInterval(state)

        #expect(await state.samplingInterval == .milliseconds(500))
        #expect(store.saved.last?.samplingInterval == .milliseconds(500))
    }

    // settings — ST-6 "Stepper saturates at the bounds": the clamp comes from
    // the Domain, and an unchanged value is never persisted (ST-4).
    @Test func theStepperSaturatesAtTheUpperBoundWithoutPersisting() async {
        let (state, store) = await Self.makeState(interval: .seconds(5))

        await SettingsFormIntent.incrementInterval(state)

        #expect(await state.samplingInterval == .seconds(5))
        #expect(store.saveCount == 0)
    }

    // settings — ST-6 "Stepper saturates at the bounds", lower end.
    @Test func theStepperSaturatesAtTheLowerBoundWithoutPersisting() async {
        let (state, store) = await Self.makeState(interval: .milliseconds(500))

        await SettingsFormIntent.decrementInterval(state)

        #expect(await state.samplingInterval == .milliseconds(500))
        #expect(store.saveCount == 0)
    }

    // MARK: - Rendered form

    // settings — ST-5: the hosted form has a fixed width, so the window the
    // controller sizes from it does not change width with its content.
    @Test func theFormKeepsItsFixedWidth() async {
        let (state, _) = await Self.makeState()

        let size = await Self.fittingSize(for: state)

        #expect(size.width == Self.formWidth)
        #expect(size.height > 0, "the form measured as empty")
    }

    // settings — ST-6 "Toggles follow the current order": a hidden module keeps
    // its row, which is the only way the user can switch it back on. The form
    // therefore measures the same whether a module is visible or not.
    @Test func aHiddenModuleKeepsItsRowSoItCanBeShownAgain() async {
        let (both, _) = await Self.makeState(modules: [.cpu, .memory])
        let (cpuOnly, _) = await Self.makeState(modules: [.cpu])

        let withBothVisible = await Self.fittingSize(for: both)
        let withMemoryHidden = await Self.fittingSize(for: cpuOnly)

        #expect(withBothVisible.height > 0, "the form measured as empty")
        #expect(withMemoryHidden.height == withBothVisible.height)
        #expect(withMemoryHidden.width == withBothVisible.width)
    }

    // settings — ST-4 "Save failure keeps the in-memory value", seen from the
    // form: the failure is surfaced as a footer, so the extra row makes the
    // failed form taller than the identical successful one.
    @Test func aFailedSaveAddsTheErrorFooterToTheForm() async {
        let (failing, _) = await Self.makeState(interval: .seconds(1), throwOnSave: [0])
        let (succeeding, _) = await Self.makeState(interval: .seconds(1))

        await failing.setInterval(.seconds(2))
        await succeeding.setInterval(.seconds(2))

        let failedHeight = await Self.fittingSize(for: failing).height
        let cleanHeight = await Self.fittingSize(for: succeeding).height

        #expect(await failing.lastSaveError != nil)
        #expect(await succeeding.lastSaveError == nil)
        #expect(await failing.samplingInterval == .seconds(2))
        #expect(failedHeight > cleanHeight)
    }
}

// MARK: - Reorder wiring
//
// The two chevrons are the one pair of controls whose wiring no pure test can
// see: `SettingsFormModel` derives `canMoveUp`/`canMoveDown` but never commits,
// and `SettingsStateTests` proves `moveUp`/`moveDown` in isolation. Swapping the
// two button closures would pass both suites, so the compositions are named on
// `SettingsFormIntent` and asserted here, each with the edge case that makes its
// direction observable.
extension SettingsViewTests {

    // settings — ST-6 "Move buttons reorder the widget", up direction.
    @Test func theMoveUpIntentMovesTheModuleTowardsTheStart() async {
        let (state, store) = await Self.makeState(modules: [.cpu, .memory])

        await SettingsFormIntent.moveUp(.memory, in: state)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saved.last?.menuBarModules == [.memory, .cpu])

        // Already first. `movingUp` returns the same value, so the unchanged
        // guard in `commit` swallows it — and a swapped wiring would instead
        // move MEM back down here.
        await SettingsFormIntent.moveUp(.memory, in: state)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saveCount == 1)
    }

    // settings — ST-6 "Move buttons reorder the widget", down direction.
    @Test func theMoveDownIntentMovesTheModuleTowardsTheEnd() async {
        let (state, store) = await Self.makeState(modules: [.cpu, .memory])

        await SettingsFormIntent.moveDown(.cpu, in: state)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saved.last?.menuBarModules == [.memory, .cpu])

        // Already last: refused, and a swapped wiring would move CPU back up.
        await SettingsFormIntent.moveDown(.cpu, in: state)

        #expect(await state.menuBarModules == [.memory, .cpu])
        #expect(store.saveCount == 1)
    }
}

// MARK: - Visibility toggle wiring

extension SettingsViewTests {

    // settings — ST-6 "Last visible toggle disabled": the flag the row carries
    // is what the view applies as `.disabled(!row.isToggleEnabled)`, and it is
    // off for exactly the last visible module. `SettingsState` refuses the hide
    // as well, so the rule survives even if the control were enabled.
    @Test func theLastVisibleModuleToggleIsDisabledAndItsHideIsRefused() async throws {
        let (state, store) = await Self.makeState(modules: [.cpu])
        let rows = SettingsFormModel.moduleRows(for: await state.settings)

        let lastVisible = try #require(rows.first { $0.module == .cpu })
        let hidden = try #require(rows.first { $0.module == .memory })

        #expect(lastVisible.isVisible)
        #expect(lastVisible.isToggleEnabled == false)
        #expect(hidden.isVisible == false)
        #expect(hidden.isToggleEnabled)

        await SettingsFormIntent.setVisibility(lastVisible, visible: false, in: state)

        #expect(await state.menuBarModules == [.cpu])
        #expect(store.saveCount == 0)
    }

    // settings — ST-6 requirement prose, "a visibility toggle per `MetricModule`
    // listed in the current order": the toggle commits the value it was handed,
    // so an inverted binding cannot hide behind the fact that both directions
    // change something.
    @Test func theVisibilityToggleCommitsTheRequestedStateInBothDirections() async throws {
        let (state, store) = await Self.makeState(modules: [.cpu, .memory])

        let visibleRow = try #require(
            SettingsFormModel.moduleRows(for: await state.settings)
                .first { $0.module == .memory }
        )
        await SettingsFormIntent.setVisibility(visibleRow, visible: false, in: state)

        #expect(await state.menuBarModules == [.cpu])

        let hiddenRow = try #require(
            SettingsFormModel.moduleRows(for: await state.settings)
                .first { $0.module == .memory }
        )
        await SettingsFormIntent.setVisibility(hiddenRow, visible: true, in: state)

        #expect(await state.menuBarModules == [.cpu, .memory])
        #expect(store.saveCount == 2)
    }
}
