import AppKit

/// Composition root of the app.
///
/// Builds the metrics stack — state, adapters, sampler — and the menu bar item,
/// then starts sampling. Every collaborator is retained here for the lifetime of
/// the process; nothing else owns them.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var state: MetricsState?
    private var sampler: MetricsSampler?
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let state = MetricsState()
        let sampler = MetricsSampler(
            state: state,
            cpuProvider: MachCPUProvider(),
            topologyProvider: IORegistryCoreTopologyProvider(sysctl: SysctlReader()),
            interval: .seconds(1)
        )

        self.state = state
        self.sampler = sampler
        statusItemController = StatusItemController(state: state)

        sampler.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        sampler?.stop()
    }
}
