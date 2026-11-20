import XCTest
@testable import MediaUI

/// Mirrors the Flutter tab bar policy: the bar expands on reverse scroll and at
/// the top, and only asks once for each.
final class MediaTabBarExpansionPolicyTests: XCTestCase {
    private func feed(_ policy: inout MediaTabBarExpansionPolicy, _ distances: [CGFloat]) -> [CGFloat] {
        distances.filter { policy.expands(atDistance: $0) }
    }

    func testScrollingDownNeverExpandsTheBar() {
        var policy = MediaTabBarExpansionPolicy()
        XCTAssertEqual(feed(&policy, [0, 10, 40, 120, 400, 900]), [])
    }

    func testReverseScrollExpandsOnceAfterTheReverseDistance() {
        var policy = MediaTabBarExpansionPolicy()
        _ = feed(&policy, [0, 200, 600])
        // 8 pt at a time: the 24 pt threshold is crossed at 576 and asked for only once.
        XCTAssertEqual(feed(&policy, [592, 584, 576, 568, 560, 552]), [576])
    }

    func testAShortBackAndForthDoesNotExpand() {
        var policy = MediaTabBarExpansionPolicy()
        _ = feed(&policy, [0, 300])
        XCTAssertEqual(feed(&policy, [290, 280, 295, 310, 300, 292]), [])
    }

    func testScrollingDownAgainRearmsTheReverseExpansion() {
        var policy = MediaTabBarExpansionPolicy()
        _ = feed(&policy, [0, 600])
        XCTAssertEqual(feed(&policy, [570]), [570])
        XCTAssertEqual(feed(&policy, [620, 590, 560]), [590])
    }

    func testArrivingAtTheTopExpandsTheBar() {
        var policy = MediaTabBarExpansionPolicy()
        _ = feed(&policy, [0, 30])
        XCTAssertEqual(feed(&policy, [18, 0]), [0])
    }

    func testRestingAtTheTopDoesNotKeepAskingToExpand() {
        var policy = MediaTabBarExpansionPolicy()
        _ = feed(&policy, [0, 100])
        XCTAssertEqual(feed(&policy, [0, 0, 0]), [0])
    }

    func testRubberBandingAtTheTopDoesNotExpandWhileAlreadyThere() {
        var policy = MediaTabBarExpansionPolicy()
        XCTAssertEqual(feed(&policy, [0, 0, 0]), [])
    }
}
