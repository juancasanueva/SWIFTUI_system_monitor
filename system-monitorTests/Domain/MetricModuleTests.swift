import Testing
@testable import system_monitor

struct MetricModuleTests {

    @Test func menuBarOrderIsCPUThenMemory() {
        #expect(MetricModule.menuBarOrder == [.cpu, .memory])
    }

    @Test func labelsMatchMenuBarAbbreviations() {
        #expect(MetricModule.cpu.label == "CPU")
        #expect(MetricModule.memory.label == "MEM")
    }

    @Test func everyModuleAppearsInMenuBarOrder() {
        for module in MetricModule.allCases {
            #expect(MetricModule.menuBarOrder.contains(module), "\(module) is missing from menuBarOrder")
        }
    }

    @Test func menuBarOrderHasNoDuplicates() {
        #expect(Set(MetricModule.menuBarOrder).count == MetricModule.menuBarOrder.count)
    }
}
