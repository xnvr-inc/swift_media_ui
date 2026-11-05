import XCTest
@testable import MediaUI

final class MediaMiniPlayerLayoutTests: XCTestCase {
    private let layout = MediaMiniPlayerLayout(
        safeArea: CGRect(x: 0, y: 62, width: 402, height: 778),
        preferredSize: CGSize(width: 228, height: 130), horizontalInset: 12, bottomInset: 68)

    func testCornerFramesFitBetweenTheTopSafeAreaAndBottomClearance() {
        XCTAssertEqual(layout.frame(at: .topLeft), CGRect(x: 12, y: 62, width: 228, height: 130))
        XCTAssertEqual(layout.frame(at: .topRight), CGRect(x: 162, y: 62, width: 228, height: 130))
        XCTAssertEqual(layout.frame(at: .bottomLeft), CGRect(x: 12, y: 642, width: 228, height: 130))
        XCTAssertEqual(layout.frame(at: .bottomRight), CGRect(x: 162, y: 642, width: 228, height: 130))
    }

    func testDragTracksTheFingerAndSnapsToTheClosestCorner() {
        let halfway = CGSize(width: -80, height: -310)
        XCTAssertEqual(layout.frame(at: .bottomRight, offset: halfway).origin, CGPoint(x: 82, y: 332))
        XCTAssertEqual(layout.closestCorner(from: .bottomRight, offset: halfway), .topLeft)
        XCTAssertEqual(layout.closestCorner(from: .topLeft, offset: CGSize(width: 100, height: 0)), .topRight)
        XCTAssertEqual(layout.closestCorner(from: .topRight, offset: CGSize(width: 0, height: 400)), .bottomRight)
        XCTAssertEqual(layout.closestCorner(from: .bottomRight, offset: CGSize(width: -100, height: 0)), .bottomLeft)
        XCTAssertEqual(layout.closestCorner(from: .bottomRight, offset: CGSize(width: -75, height: 0)), .bottomRight)
    }

    func testDragStaysInsideTheViewportAndFitsAResizedWindow() {
        let narrow = MediaMiniPlayerLayout(
            safeArea: CGRect(x: 20, y: 24, width: 218, height: 190),
            preferredSize: CGSize(width: 120, height: 240), horizontalInset: 12, bottomInset: 30)
        XCTAssertEqual(narrow.size, CGSize(width: 80, height: 160))
        XCTAssertEqual(narrow.frame(at: .bottomRight, offset: CGSize(width: 200, height: 200)).maxY, 184)
        XCTAssertEqual(narrow.closestCorner(from: .bottomRight, offset: CGSize(width: -300, height: -300)), .bottomLeft)
    }

    func testShortFlickMovesTowardTheReleaseDirection() {
        let upward = CGSize(width: -4, height: -64)
        XCTAssertEqual(layout.snapCorner(from: .bottomRight, offset: upward,
                                         predicted: CGSize(width: -6, height: -90)), .bottomRight)
        XCTAssertEqual(layout.snapCorner(from: .bottomRight, offset: upward,
                                         predicted: CGSize(width: -46, height: -196)), .topRight)
        let downward = CGSize(width: 8, height: 52)
        XCTAssertEqual(layout.snapCorner(from: .topLeft, offset: downward,
                                         predicted: CGSize(width: 129, height: 322)), .bottomLeft)
        XCTAssertEqual(layout.snapCorner(from: .topLeft, offset: downward,
                                         predicted: CGSize(width: 176, height: 322)), .bottomRight)
    }

    func testRightwardDragsFromTheLeftDockMoveThePlayer() {
        let rightward = CGSize(width: 100, height: 3)
        XCTAssertFalse(layout.shouldDismiss(from: .bottomLeft, offset: rightward, predicted: rightward))
        XCTAssertTrue(layout.shouldDismiss(from: .bottomRight, offset: rightward, predicted: rightward))
        XCTAssertFalse(layout.shouldDismiss(from: .bottomRight, offset: CGSize(width: 95, height: 150),
                                            predicted: CGSize(width: 170, height: 220)))
        XCTAssertTrue(layout.shouldDismiss(from: .topRight, offset: CGSize(width: 30, height: 2),
                                           predicted: CGSize(width: 200, height: 4)))
    }
}
