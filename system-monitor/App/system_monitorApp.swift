import SwiftUI

@main
struct SystemMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A Settings scene is the only scene so no window opens at launch.
        // The menu bar status item is created by `AppDelegate`.
        // Qualified because the Domain owns a `Settings` value type (ST-1),
        // which otherwise shadows the SwiftUI scene inside this module.
        SwiftUI.Settings {
            EmptyView()
        }
        // Cmd+, must open the window `AppDelegate` owns, not the empty scene
        // above (ST-5 "Both entry points share the window"). Replacing the
        // standard `.appSettings` group retargets the shortcut without deleting
        // the mandatory scene. The title is the context menu's, U+2026 included,
        // so the two entry points read the same.
        //
        // A main-menu key equivalent only fires while the app is active, which
        // an `LSUIElement` app is not until something activates it; the context
        // menu stays the primary entry point. Whether the replacement takes
        // effect on macOS 26 is manual check 8.3, whose fallback is design
        // decision 13 (retarget the `NSApp.mainMenu` item keyed ",").
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings\u{2026}") {
                    appDelegate.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
