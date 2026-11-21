import XCTest
@testable import MediaUI

/// The compact tab bar follows the Flutter `XnvrFlutterTabBar` without an accessory.
final class MediaTabBarMetricsTests: XCTestCase {
    private let width: CGFloat = 393

    func testTheConstantsAreTheFlutterOnes() {
        XCTAssertEqual(MediaTabBarMetrics.duration, 0.38)
        XCTAssertEqual(MediaTabBarMetrics.gap, 8)
        XCTAssertEqual(MediaTabBarMetrics.margin, 20)
        XCTAssertEqual(MediaTabBarMetrics.compactScale, 0.76)
        XCTAssertEqual(MediaTabBarMetrics.compactSlot, 56)
        XCTAssertEqual(MediaTabBarMetrics.compactInset, 6)
        XCTAssertEqual(MediaTabBarMetrics.expandedInset, 4)
        XCTAssertEqual(MediaTabBarMetrics.reservedHeight, MediaTabBarMetrics.barHeight + 8)
    }

    func testTheProgressFollowsTheFlutterEaseOutCubicCurve() {
        XCTAssertEqual(MediaTabBarMetrics.eased(0), 0)
        XCTAssertEqual(MediaTabBarMetrics.eased(1), 1)
        XCTAssertEqual(MediaTabBarMetrics.eased(-1), 0)
        XCTAssertEqual(MediaTabBarMetrics.eased(2), 1)
        // Values of Flutter's `Curves.easeOutCubic` (the Bézier 0.215, 0.61, 0.355, 1,
        // solved by the bisection of `Cubic.transform`, which is exact to 0.001 in x).
        XCTAssertEqual(MediaTabBarMetrics.eased(0.25), 0.599, accuracy: 2e-3)
        XCTAssertEqual(MediaTabBarMetrics.eased(0.5), 0.875, accuracy: 2e-3)
        XCTAssertEqual(MediaTabBarMetrics.eased(0.75), 0.976, accuracy: 2e-3)
    }

    func testTheCurveOnlyRisesAndDecelerates() {
        let samples = stride(from: 0.0, through: 1.0, by: 0.05).map { MediaTabBarMetrics.eased(CGFloat($0)) }
        for (earlier, later) in zip(samples, samples.dropFirst()) {
            XCTAssertLessThanOrEqual(earlier, later + 2e-3)
        }
        // It covers more in the first half than in the second.
        XCTAssertGreaterThan(MediaTabBarMetrics.eased(0.5), 0.5 + 0.25)
    }

    func testTheFullPillFillsTheRowLessItsMargins() {
        let layout = MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 0)
        XCTAssertEqual(layout.pill.minX, 20)
        XCTAssertEqual(layout.pill.width, width - 40)
        XCTAssertEqual(layout.pill.height, MediaTabBarMetrics.barHeight)
        // It rests on the gap, at the top of the area the bar reserves.
        XCTAssertEqual(layout.pill.maxY, MediaTabBarMetrics.reservedHeight - MediaTabBarMetrics.gap)
        XCTAssertEqual(layout.inset, 4)
        XCTAssertEqual(layout.slotWidth, (width - 40 - 8) / 4, accuracy: 1e-9)
        XCTAssertEqual(layout.labelFade, 1)
    }

    func testTheShrunkenPillHugsOneSlotPerTabAndIsCentered() {
        let layout = MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 1)
        XCTAssertEqual(layout.pill.width, 4 * 56 + 12)
        XCTAssertEqual(layout.pill.midX, width / 2, accuracy: 1e-9)
        XCTAssertEqual(layout.pill.height, MediaTabBarMetrics.barHeight * 0.76, accuracy: 1e-9)
        XCTAssertEqual(layout.pill.maxY, MediaTabBarMetrics.reservedHeight - MediaTabBarMetrics.gap, accuracy: 1e-9)
        XCTAssertEqual(layout.inset, 6)
        XCTAssertEqual(layout.slotWidth, 56, accuracy: 1e-9)
        XCTAssertEqual(layout.highlightWidth, 56, accuracy: 1e-9)
        XCTAssertEqual(layout.labelFade, 0)
    }

    func testEveryTabKeepsItsIconInTheShrunkenPill() {
        let layout = MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 1)
        let centers = (0..<4).map { layout.slotCenter(at: CGFloat($0)) }
        XCTAssertEqual(centers, [34, 90, 146, 202])
        // The last tab's slot ends inside the pill, one inset from its edge.
        XCTAssertEqual(centers[3] + 28, layout.pill.width - 6, accuracy: 1e-9)
    }

    func testTheHighlightStartsAsOneSlotOfTheFullPillAndEndsOneCompactSlotWide() {
        let expanded = MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 0)
        XCTAssertEqual(expanded.highlightWidth, (width - 40 - 8) / 4, accuracy: 1e-9)
        let middle = MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 0.5)
        XCTAssertEqual(middle.highlightWidth, (expanded.highlightWidth + 56) / 2, accuracy: 1e-9)
    }

    func testLabelsLeaveDuringTheFirstSixtyFivePercentOfTheProgress() {
        XCTAssertEqual(MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 0.325).labelFade, 0.5, accuracy: 1e-9)
        XCTAssertEqual(MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 0.65).labelFade, 0, accuracy: 1e-9)
        XCTAssertEqual(MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: 0.9).labelFade, 0)
    }

    func testThePillMovesAndNarrowsContinuously() {
        let widths = stride(from: 0.0, through: 1.0, by: 0.1).map {
            MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: $0).pill.width
        }
        XCTAssertEqual(widths, widths.sorted(by: >))
    }

    func testManyTabsNeverMakeTheShrunkenPillWiderThanTheFullOne() {
        XCTAssertEqual(MediaTabBarMetrics.compactWidth(tabCount: 10, expandedWidth: 353), 353)
        let layout = MediaTabBarMetrics.layout(width: width, tabCount: 10, progress: 1)
        XCTAssertEqual(layout.pill.width, 353)
        XCTAssertLessThanOrEqual(layout.highlightWidth, layout.pill.width - 2 * layout.inset)
    }

    func testTheReservedHeightDoesNotDependOnTheProgress() {
        for progress in [0, 0.5, 1] as [CGFloat] {
            let layout = MediaTabBarMetrics.layout(width: width, tabCount: 4, progress: progress)
            XCTAssertEqual(layout.pill.maxY + MediaTabBarMetrics.gap, MediaTabBarMetrics.reservedHeight, accuracy: 1e-9)
        }
    }
}
