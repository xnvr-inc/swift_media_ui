import XCTest
@testable import MediaUI

/// Mirrors `XnvrScrollAwayHeader` in the Flutter UI: one-to-one travel clamped to
/// the bar, a 40 pt dissolve, and no input once it is gone.
final class MediaScrollAwayAppBarTests: XCTestCase {
    typealias Metrics = MediaScrollAwayAppBarMetrics

    func testBarFollowsThePageOneToOneUpToItsOwnHeight() {
        XCTAssertEqual(Metrics.shift(atDistance: 0, barHeight: 44), 0)
        XCTAssertEqual(Metrics.shift(atDistance: 20, barHeight: 44), 20)
        XCTAssertEqual(Metrics.shift(atDistance: 44, barHeight: 44), 44)
        XCTAssertEqual(Metrics.shift(atDistance: 2_000, barHeight: 44), 44)
    }

    func testRubberBandingAboveTheTopNeverPushesTheBarDown() {
        XCTAssertEqual(Metrics.shift(atDistance: -60, barHeight: 44), 0)
    }

    func testBarReturnsExactlyAsThePageReturnsToItsTop() {
        let shifts = [44, 30, 10, 0].map { Metrics.shift(atDistance: $0, barHeight: 44) }
        XCTAssertEqual(shifts, [44, 30, 10, 0])
    }

    func testBarDissolvesOverTheFadeDistance() {
        XCTAssertEqual(Metrics.fadeDistance, 40)
        XCTAssertEqual(Metrics.opacity(forShift: 0), 1)
        XCTAssertEqual(Metrics.opacity(forShift: 10), 0.75, accuracy: 0.0001)
        XCTAssertEqual(Metrics.opacity(forShift: 20), 0.5, accuracy: 0.0001)
        XCTAssertEqual(Metrics.opacity(forShift: 40), 0)
        XCTAssertEqual(Metrics.opacity(forShift: 400), 0)
    }

    func testBlurRadiusGrowsWithTheDissolve() {
        XCTAssertEqual(Metrics.blurRadius(forShift: 0), 0.01, accuracy: 0.0001)
        XCTAssertEqual(Metrics.blurRadius(forShift: 20), 4.01, accuracy: 0.0001)
        XCTAssertEqual(Metrics.blurRadius(forShift: 40), 8.01, accuracy: 0.0001)
        XCTAssertEqual(Metrics.blurRadius(forShift: 400), 8.01, accuracy: 0.0001)
    }

    func testBarTakesInputUntilItHasLeft() {
        XCTAssertFalse(Metrics.isGone(forShift: 0, barHeight: 44))
        XCTAssertFalse(Metrics.isGone(forShift: 39, barHeight: 44))
        XCTAssertTrue(Metrics.isGone(forShift: 40, barHeight: 44))
        XCTAssertTrue(Metrics.isGone(forShift: 44, barHeight: 44))
    }

    func testBarShorterThanTheFadeDistanceIsGoneOnceItHasLeft() {
        XCTAssertFalse(Metrics.isGone(forShift: 31, barHeight: 32))
        XCTAssertTrue(Metrics.isGone(forShift: 32, barHeight: 32))
    }

    func testBarThatHasNotMovedIsNeverGone() {
        XCTAssertFalse(Metrics.isGone(forShift: 0, barHeight: 0))
        XCTAssertFalse(Metrics.isGone(forShift: 0, barHeight: 44))
    }
}
