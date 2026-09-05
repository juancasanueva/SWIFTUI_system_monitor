import CoreGraphics
import Testing
@testable import system_monitor

// memory-card — "Stacked bar"
@Suite("Stacked bar geometry")
struct StackedBarGeometryTests {

    private static let size = CGSize(width: 100, height: 8)

    // memory-card — "Segments sum to Total"
    @Test func fractionsBecomeCumulativeRectsFromLeftToRight() {
        let rects = StackedBarGeometry.rects(fractions: [0.25, 0.5, 0.25], in: Self.size)

        #expect(rects == [
            CGRect(x: 0, y: 0, width: 25, height: 8),
            CGRect(x: 25, y: 0, width: 50, height: 8),
            CGRect(x: 75, y: 0, width: 25, height: 8)
        ])
    }

    // memory-card — "Components exceed Used"
    @Test func theCumulativeWidthIsClampedAtTheDrawingWidth() {
        let rects = StackedBarGeometry.rects(fractions: [0.6, 0.6, 0.3], in: Self.size)

        #expect(rects == [
            CGRect(x: 0, y: 0, width: 60, height: 8),
            CGRect(x: 60, y: 0, width: 40, height: 8),
            CGRect(x: 100, y: 0, width: 0, height: 8)
        ])
        #expect(rects.allSatisfy { $0.maxX <= Self.size.width })
    }

    @Test func aZeroFractionKeepsItsPlaceWithZeroWidth() {
        let rects = StackedBarGeometry.rects(fractions: [0.5, 0, 0.5], in: Self.size)

        #expect(rects.count == 3)
        #expect(rects[1] == CGRect(x: 50, y: 0, width: 0, height: 8))
        #expect(rects[2] == CGRect(x: 50, y: 0, width: 50, height: 8))
    }

    @Test func anUndefinedFractionDrawsNothingWithoutShiftingTheRest() {
        let rects = StackedBarGeometry.rects(fractions: [.nan, 0.5], in: Self.size)

        #expect(rects == [
            CGRect(x: 0, y: 0, width: 0, height: 8),
            CGRect(x: 0, y: 0, width: 50, height: 8)
        ])
    }

    @Test func aNegativeFractionNeverProducesANegativeWidth() {
        let rects = StackedBarGeometry.rects(fractions: [-0.4, 0.25], in: Self.size)

        #expect(rects == [
            CGRect(x: 0, y: 0, width: 0, height: 8),
            CGRect(x: 0, y: 0, width: 25, height: 8)
        ])
    }

    // memory-card — "No snapshot"
    @Test func noFractionsProduceNoRects() {
        #expect(StackedBarGeometry.rects(fractions: [], in: Self.size).isEmpty)
    }

    @Test(arguments: [
        CGSize(width: 0, height: 8),
        CGSize(width: 100, height: 0),
        CGSize(width: -10, height: -1)
    ])
    func aDegenerateDrawingAreaProducesNoRects(size: CGSize) {
        #expect(StackedBarGeometry.rects(fractions: [0.5, 0.5], in: size).isEmpty)
    }
}
