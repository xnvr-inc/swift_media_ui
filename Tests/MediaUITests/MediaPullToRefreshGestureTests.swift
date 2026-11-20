import XCTest
@testable import MediaUI

final class MediaPullToRefreshGestureTests: XCTestCase {
    typealias Gesture = MediaPullToRefreshGesture

    private func refreshes(_ x: CGFloat, _ y: CGFloat, velocity: CGFloat = 0) -> Bool {
        Gesture.requestsRefresh(translation: CGPoint(x: x, y: y), velocity: CGPoint(x: 0, y: velocity))
    }

    func testALongSlowPullRefreshes() {
        XCTAssertTrue(refreshes(0, 120))
        XCTAssertTrue(refreshes(10, 175))
    }

    func testAShortSlowPullDoesNot() {
        XCTAssertFalse(refreshes(0, 119))
        XCTAssertFalse(refreshes(0, 100, velocity: 400))
    }

    func testAFastFlickRefreshesBelowThePullDistance() {
        XCTAssertTrue(refreshes(0, 108, velocity: 1_200))
        XCTAssertTrue(refreshes(0, 80, velocity: 800))
    }

    func testATinyFlickDoesNot() {
        XCTAssertFalse(refreshes(0, 79, velocity: 3_000))
    }

    func testASidewaysDragDoesNot() {
        XCTAssertFalse(refreshes(200, 150, velocity: 1_500))
    }

    func testUpwardDragDoesNot() {
        XCTAssertFalse(refreshes(0, -150, velocity: -1_500))
    }
}
