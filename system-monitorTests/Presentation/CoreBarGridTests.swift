import Testing
@testable import system_monitor

// cpu-card — "Per-core bars grouped P then E"
@Suite("CoreBarGrid row wrapping")
struct CoreBarGridTests {

    private func cores(_ count: Int, level: PerformanceLevel = .performance) -> [CoreUsage] {
        (0..<count).map { index in
            CoreUsage(index: index, usage: Double(index) / Double(max(count, 1)), level: level)
        }
    }

    @Test func noRowHoldsMoreThanEightBars() {
        #expect(CoreBarGrid.maxPerRow == 8)
    }

    // cpu-card — "16 P-cores wrap"
    @Test func sixteenCoresWrapIntoTwoFullRows() {
        let rows = CoreBarGrid.rows(for: cores(16))

        #expect(rows.count == 2)
        #expect(rows.map(\.count) == [8, 8])
    }

    // cpu-card — "8 P + 4 E"
    @Test func twelveCoresWrapIntoAFullRowAndARemainder() {
        let rows = CoreBarGrid.rows(for: cores(12))

        #expect(rows.map(\.count) == [8, 4])
    }

    @Test func fourCoresFitOnASingleRow() {
        let rows = CoreBarGrid.rows(for: cores(4))

        #expect(rows.count == 1)
        #expect(rows.map(\.count) == [4])
    }

    @Test func exactlyEightCoresStayOnOneRow() {
        let rows = CoreBarGrid.rows(for: cores(8))

        #expect(rows.map(\.count) == [8])
    }

    @Test func noCoresProduceNoRows() {
        #expect(CoreBarGrid.rows(for: []).isEmpty)
    }

    @Test func wrappingPreservesTheSnapshotOrder() {
        let source = cores(12)
        let rows = CoreBarGrid.rows(for: source)
        let flattened = rows.flatMap { $0 }

        #expect(flattened.map(\.index) == source.map(\.index))
        #expect(rows[0].map(\.index) == Array(0...7))
        #expect(rows[1].map(\.index) == Array(8...11))
    }

    @Test func wrappingKeepsEveryCoreExactlyOnce() {
        let source = cores(20, level: .efficiency)
        let rows = CoreBarGrid.rows(for: source)

        #expect(rows.map(\.count) == [8, 8, 4])
        #expect(rows.flatMap { $0 } == source)
    }
}
