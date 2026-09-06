import Foundation
import SwiftUI

/// One module line of the settings form (ST-6).
///
/// A plain value so every enablement rule the form applies is a testable
/// derivation rather than a condition buried in a `Form` body.
nonisolated struct ModuleRow: Sendable, Equatable, Identifiable {

    let module: MetricModule

    /// Whether the module currently appears in the menu bar widget.
    let isVisible: Bool

    /// Whether hiding it is allowed. False for the only visible module, which
    /// is the ST-1 last-module guard seen from the form.
    let canHide: Bool

    /// Whether the row can move one place towards the start of the widget.
    let canMoveUp: Bool

    /// Whether the row can move one place towards the end of the widget.
    let canMoveDown: Bool

    /// A hidden module can always be shown again; a visible one only switches
    /// off while another module stays visible (ST-6 "Last visible toggle
    /// disabled").
    var isToggleEnabled: Bool { !isVisible || canHide }

    var id: String { module.id }
}

/// Pure derivations behind the settings form (ST-6).
///
/// The view binds controls to these results and routes every write through a
/// `SettingsState` intent method, so the form never holds a `Settings` value
/// that has not been through the ST-1 normalisation.
nonisolated enum SettingsFormModel {

    /// Range the interval stepper offers, in seconds. It is the Domain clamp
    /// expressed for the control, so the two can never disagree.
    static let intervalRange: ClosedRange<Double> =
        seconds(Settings.minimumInterval)...seconds(Settings.maximumInterval)

    /// One stepper click, in seconds.
    static let intervalStep: Double = seconds(Settings.intervalStep)

    /// The configured cadence in seconds, for the stepper value.
    static func intervalSeconds(_ settings: Settings) -> Double {
        seconds(settings.samplingInterval)
    }

    /// The stepper label: the seconds value with one fraction digit under the
    /// injected locale, followed by the literal `" s"`.
    ///
    /// Follows the `PercentFormatter.oneDecimal` precedent (convention 9)
    /// rather than `Measurement.formatted`, which renders the localised unit
    /// name ("2.5 sec", "2,5 Sek.") instead of the symbol ST-6 pins.
    static func intervalLabel(for interval: Duration, locale: Locale = .current) -> String {
        let value = seconds(interval).formatted(
            .number
                .precision(.fractionLength(1))
                .locale(locale)
        )
        return "\(value) s"
    }

    /// One step up, saturating at `Settings.maximumInterval`.
    ///
    /// Clamping is delegated to the `Settings` initialiser, so the stepper
    /// cannot saturate at a different bound than the Domain does.
    static func incremented(_ interval: Duration) -> Duration {
        clamped(interval + Settings.intervalStep)
    }

    /// One step down, saturating at `Settings.minimumInterval`.
    static func decremented(_ interval: Duration) -> Duration {
        clamped(interval - Settings.intervalStep)
    }

    /// Visible modules in the user's order, then the hidden ones in the default
    /// order, so the form lists every module and the visible block reads like
    /// the widget itself.
    static func moduleRows(for settings: Settings) -> [ModuleRow] {
        let visible = settings.menuBarModules
        let hidden = MetricModule.menuBarOrder.filter { !visible.contains($0) }

        let visibleRows = visible.enumerated().map { index, module in
            ModuleRow(
                module: module,
                isVisible: true,
                canHide: settings.canHide(module),
                canMoveUp: index > 0,
                canMoveDown: index < visible.count - 1
            )
        }

        let hiddenRows = hidden.map { module in
            ModuleRow(
                module: module,
                isVisible: false,
                canHide: false,
                canMoveUp: false,
                canMoveDown: false
            )
        }

        return visibleRows + hiddenRows
    }

    private static func clamped(_ interval: Duration) -> Duration {
        Settings(samplingInterval: interval).samplingInterval
    }

    /// A `Duration` in seconds. Exact for every 0.5 s step the stepper
    /// produces. Duplicated from the store rather than shared with it, because
    /// Presentation must not reach into Infrastructure.
    private static func seconds(_ interval: Duration) -> Double {
        let components = interval.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

/// Main-actor wiring the settings form applies on top of the pure
/// `SettingsFormModel` derivations (ST-6).
///
/// The stepper is the one control whose action is a composition rather than a
/// single intent: it derives the next value with `SettingsFormModel` and then
/// commits it through `SettingsState`. It lives here, where a test can call it,
/// instead of inside a `Stepper` closure no test can reach — a swap of the two
/// directions would otherwise pass every pure test.
@MainActor
enum SettingsFormIntent {

    /// One stepper click up. Saturates at `Settings.maximumInterval`, and an
    /// unchanged value is not persisted (ST-4).
    static func incrementInterval(_ settings: SettingsState) {
        settings.setInterval(SettingsFormModel.incremented(settings.samplingInterval))
    }

    /// One stepper click down. Saturates at `Settings.minimumInterval`.
    static func decrementInterval(_ settings: SettingsState) {
        settings.setInterval(SettingsFormModel.decremented(settings.samplingInterval))
    }

    /// The row's visibility toggle. Named here for the same reason as the
    /// stepper: the binding's setter is the only place the requested value can
    /// be inverted or dropped, and no pure `ModuleRow` test can reach it.
    ///
    /// The last visible module is protected twice — the view disables this
    /// control through `row.isToggleEnabled`, and `SettingsState.setModule`
    /// refuses the hide anyway (ST-6 "Last visible toggle disabled").
    static func setVisibility(_ row: ModuleRow, visible: Bool, in settings: SettingsState) {
        settings.setModule(row.module, visible: visible)
    }

    /// The up chevron: one position towards the start of the widget.
    ///
    /// A named composition rather than an inline closure so the pairing of
    /// chevron to direction is covered — swapping the two button bodies is
    /// otherwise invisible to every pure test (ST-6 "Move buttons reorder the
    /// widget").
    static func moveUp(_ module: MetricModule, in settings: SettingsState) {
        settings.moveUp(module)
    }

    /// The down chevron: one position towards the end of the widget.
    static func moveDown(_ module: MetricModule, in settings: SettingsState) {
        settings.moveDown(module)
    }
}

/// The settings form hosted by the "Settings" window (ST-5, ST-6).
///
/// Every write goes through a `SettingsState` intent method, never through a
/// `@Bindable` value, so each edit passes the ST-1 normalisation before it is
/// persisted. The view holds no state of its own: what it renders is derived
/// from the current `Settings` value on every pass.
struct SettingsView: View {

    /// Fixed form width in points, so the window does not change size with the
    /// module labels or the save-error text.
    static let formWidth: CGFloat = 360

    /// Floor for the settings window's content height in points.
    ///
    /// The two standard sections measure 244 pt, so this leaves headroom for
    /// the save-error footer and for larger accessibility text without the
    /// window having to resize. `SettingsWindowController` takes whichever is
    /// taller, this floor or the form's own fitting height, because a grouped
    /// `Form` scrolls and would otherwise accept any height the host proposes.
    static let formHeight: CGFloat = 280

    @Environment(SettingsState.self) private var settings

    /// The form's locale, passed explicitly into the pure label derivation.
    /// `SettingsFormModel`'s `.current` default is for tests and previews only.
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section("Sampling interval") {
                Stepper(
                    onIncrement: { SettingsFormIntent.incrementInterval(settings) },
                    onDecrement: { SettingsFormIntent.decrementInterval(settings) }
                ) {
                    Text(
                        SettingsFormModel.intervalLabel(
                            for: settings.samplingInterval,
                            locale: locale
                        )
                    )
                }
            }

            Section("Menu bar modules") {
                ForEach(SettingsFormModel.moduleRows(for: settings.settings)) { row in
                    ModuleSettingsRow(row: row, settings: settings)
                }
            }

            if let failure = settings.lastSaveError {
                Section {
                    Text(failure.localizedDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: Self.formWidth)
    }
}

/// One module line: the visibility toggle plus the two reorder buttons.
///
/// Extracted from `SettingsView.body` so a change to one module only
/// invalidates its own row, and so every enablement rule reads as the
/// `ModuleRow` value it comes from.
private struct ModuleSettingsRow: View {

    let row: ModuleRow

    let settings: SettingsState

    var body: some View {
        HStack {
            Toggle(
                row.module.label,
                isOn: Binding(
                    get: { row.isVisible },
                    set: { SettingsFormIntent.setVisibility(row, visible: $0, in: settings) }
                )
            )
            .disabled(!row.isToggleEnabled)

            Spacer()

            Button {
                SettingsFormIntent.moveUp(row.module, in: settings)
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(!row.canMoveUp)
            .accessibilityLabel("Move Up")
            .help("Move Up")

            Button {
                SettingsFormIntent.moveDown(row.module, in: settings)
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(!row.canMoveDown)
            .accessibilityLabel("Move Down")
            .help("Move Down")
        }
    }
}

/// Window-level wrapper that injects the state the form reads from the
/// environment. `SettingsWindowController` hosts this type, so the window never
/// has to know how `SettingsView` receives its dependencies.
struct SettingsRootView: View {

    let settings: SettingsState

    var body: some View {
        SettingsView()
            .environment(settings)
    }
}

#Preview("Settings") {
    SettingsRootView(
        settings: SettingsState(
            store: UserDefaultsSettingsStore(
                defaults: UserDefaults(suiteName: "SettingsPreview") ?? .standard
            )
        )
    )
}

#Preview("Settings with MEM hidden") {
    SettingsRootView(
        settings: {
            let state = SettingsState(
                store: UserDefaultsSettingsStore(
                    defaults: UserDefaults(suiteName: "SettingsPreviewCPUOnly") ?? .standard
                )
            )
            state.setModule(.memory, visible: false)
            return state
        }()
    )
}
