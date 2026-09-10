import AppKit
import Testing
@testable import system_monitor

// menu-bar-widget — MBW-15 "About window": the header shows the app's own
// icon, resolved from the bundled asset catalog rather than from the
// application-icon accessor, which falls back to the generic icon whenever
// Launch Services has not registered the process.
@Suite("About icon", .timeLimit(.minutes(1)))
struct AboutIconTests {

    @Test @MainActor func theAboutIconIsTheBundledAppIcon() throws {
        let icon = AboutView.icon

        #expect(icon.name() == "AppIcon")
        #expect(icon.size.width > 0)
        #expect(Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil)
    }
}
