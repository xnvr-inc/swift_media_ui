import XCTest
@testable import MediaUI

final class MediaScrollAwayAppBarTests: XCTestCase {
    typealias Metrics = MediaScrollAwayAppBarMetrics

    func testBarStaysWhileThePageIsNearItsTop() {
        for distance in [-40, 0, 20, Metrics.hideDistance] {
            XCTAssertFalse(Metrics.hidesBar(atDistance: distance, currentlyHidden: false), "\(distance)")
        }
    }

    func testBarHidesOncePastTheHideDistance() {
        XCTAssertTrue(Metrics.hidesBar(atDistance: Metrics.hideDistance + 1, currentlyHidden: false))
        XCTAssertTrue(Metrics.hidesBar(atDistance: 2_000, currentlyHidden: false))
    }

    func testHiddenBarStaysHiddenWhileScrollingBackUpThroughThePage() {
        for distance in stride(from: Metrics.hideDistance, to: Metrics.revealDistance, by: -4) {
            XCTAssertTrue(Metrics.hidesBar(atDistance: distance, currentlyHidden: true), "\(distance)")
        }
    }

    func testHiddenBarReturnsAtTheTop() {
        XCTAssertFalse(Metrics.hidesBar(atDistance: Metrics.revealDistance, currentlyHidden: true))
        XCTAssertFalse(Metrics.hidesBar(atDistance: 0, currentlyHidden: true))
        XCTAssertFalse(Metrics.hidesBar(atDistance: -60, currentlyHidden: true))
    }

    func testHidingDoesNotRevealTheBarAgainOnItsOwn() {
        // Hiding shrinks the top inset, so the measured distance drops by about
        // the bar height. A bar of up to 56 pt must leave the page above the reveal distance.
        let barHeight: CGFloat = 56
        let afterHiding = Metrics.hideDistance + 1 - barHeight
        XCTAssertTrue(Metrics.hidesBar(atDistance: afterHiding, currentlyHidden: true))
    }
}
