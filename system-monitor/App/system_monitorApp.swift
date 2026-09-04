import SwiftUI

@main
struct SystemMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // A Settings scene is the only scene so no window opens at launch.
        // The menu bar status item is created by `AppDelegate`.
        Settings {
            EmptyView()
        }
    }
}
