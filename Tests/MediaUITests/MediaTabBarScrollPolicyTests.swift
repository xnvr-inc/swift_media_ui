import XCTest
@testable import MediaUI

/// Mirrors the Flutter tab bar policy (`GlassTabBarMinimizeController`): the bar
/// expands after 12 pt of reverse scroll and at the top, asks once for each, and
/// ignores rubber-banding, jumps and movement the user did not make.
final class MediaTabBarScrollPolicyTests: XCTestCase {
    private func feed(
        _ policy: inout MediaTabBarScrollPolicy,
        _ distances: [CGFloat],
        maximum: CGFloat = .greatestFiniteMagnitude,
        viewport: CGFloat = .greatestFiniteMagnitude,
        user: Bool = true
    ) -> [CGFloat] {
        distances.filter {
            policy.expands(atDistance: $0, maximumDistance: maximum, viewportHeight: viewport, isUserScrolling: user)
        }
    }

    func testReverseDistanceIsTheFlutterExpandThreshold() {
        XCTAssertEqual(MediaTabBarScrollPolicy.reverseDistance, 12)
    }

    func testScrollingDownNeverExpandsTheBar() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertEqual(feed(&policy, [0, 10, 40, 120, 400, 900]), [])
    }

    func testReverseScrollExpandsOnceAfterTheReverseDistance() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 200, 600])
        // 8 pt at a time: the 12 pt threshold is crossed at 584 and asked for only once.
        XCTAssertEqual(feed(&policy, [592, 584, 576, 568, 560, 552]), [584])
    }

    func testAShortBackAndForthDoesNotExpand() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 300])
        XCTAssertEqual(feed(&policy, [296, 290, 300, 310, 305, 300]), [])
    }

    func testScrollingDownAgainRearmsTheReverseExpansion() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 600])
        XCTAssertEqual(feed(&policy, [585, 570]), [570])
        XCTAssertEqual(feed(&policy, [620, 605, 590, 575]), [590])
    }

    func testArrivingAtTheTopExpandsTheBar() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 20])
        XCTAssertEqual(feed(&policy, [14, 0]), [0])
    }

    func testRestingAtTheTopDoesNotKeepAskingToExpand() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 100])
        XCTAssertEqual(feed(&policy, [0, 0, 0]), [0])
    }

    func testRubberBandingAboveTheTopDoesNotAskAgain() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 100])
        XCTAssertEqual(feed(&policy, [0]), [0])
        // Pulled past the top and let go: the offset is negative, then returns to rest.
        XCTAssertEqual(feed(&policy, [-30, -60, -20, 0]), [])
    }

    func testTheReboundAtTheFarEdgeIsNotAReverseScroll() {
        // The page stretches past its end, then springs back to it: the offset
        // falls by far more than 12 pt without the user reversing anything.
        let stretch: [CGFloat] = [1_030, 1_055, 1_040, 1_020, 1_005, 1_000]
        var unclamped = MediaTabBarScrollPolicy()
        _ = feed(&unclamped, [0, 900, 1_000])
        XCTAssertFalse(feed(&unclamped, stretch).isEmpty, "Without the page's extent the rebound reads as a reverse scroll")

        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 900, 1_000], maximum: 1_000)
        XCTAssertEqual(feed(&policy, stretch, maximum: 1_000), [])
    }

    func testAReverseScrollFromTheFarEdgeStillExpands() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 900, 1_030, 1_000], maximum: 1_000)
        XCTAssertEqual(feed(&policy, [996, 988, 980], maximum: 1_000), [988])
    }

    func testMovementTheUserDidNotMakeIsNotAReverseScroll() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 600])
        XCTAssertEqual(feed(&policy, [560, 500, 450], user: false), [])
        // The same samples from the user's own finger expand it.
        var touched = MediaTabBarScrollPolicy()
        _ = feed(&touched, [0, 600])
        XCTAssertEqual(feed(&touched, [560, 500, 450], user: true), [500])
    }

    func testReturningToTheTopExpandsEvenWhenTheMovementIsNotTheUsers() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 400])
        XCTAssertEqual(feed(&policy, [200, 0], user: false), [0])
    }

    func testAJumpIsNotAScroll() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 2_000], viewport: 800)
        // A restored position half a viewport or more away, then a real reverse scroll from there.
        XCTAssertEqual(feed(&policy, [1_000, 996, 984], viewport: 800), [984])
    }

    func testAChangingExtentDuringTheReboundIsStillTheRebound() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 900, 1_000], maximum: 1_000)
        // The list shrinks while the page is stretched past its end: the clamped
        // distance falls from 1,000 to 980 without the user reversing anything.
        XCTAssertFalse(policy.expands(atDistance: 1_040, maximumDistance: 1_000))
        XCTAssertFalse(policy.expands(atDistance: 1_025, maximumDistance: 980))
        XCTAssertFalse(policy.expands(atDistance: 1_000, maximumDistance: 980))
        XCTAssertFalse(policy.expands(atDistance: 980, maximumDistance: 980))
    }

    func testAShrinkArrivingTogetherWithTheClampIsNotAReverseScroll() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 900, 1_000], maximum: 1_000)
        // Momentum carries the page past its end and, in the same sample, the
        // list shrinks so the range is 980: the position falls by 20 pt
        // without the user reversing anything.
        XCTAssertFalse(policy.expands(atDistance: 1_040, maximumDistance: 1_000))
        XCTAssertFalse(policy.expands(atDistance: 980, maximumDistance: 980))
        // A real reverse scroll from there still expands.
        XCTAssertFalse(policy.expands(atDistance: 974, maximumDistance: 980))
        XCTAssertTrue(policy.expands(atDistance: 968, maximumDistance: 980))
    }

    func testAnOvershootAtTheFarEdgeRearmsTheReverseExpansion() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 900, 1_000], maximum: 1_000)
        XCTAssertEqual(feed(&policy, [994, 988], maximum: 1_000), [988])
        // The user flings down past the end and back: the next reverse scroll is
        // a new one, even though the overshoot used up the only downward step.
        XCTAssertEqual(feed(&policy, [1_008, 1_000, 994, 987, 960], maximum: 1_000), [987])
    }

    func testAShrinkAfterAReverseExpansionDoesNotRearmIt() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 900, 1_000], maximum: 1_000)
        XCTAssertEqual(feed(&policy, [994, 988], maximum: 1_000), [988])
        // The list shrinks to a range of 960 while the user keeps moving up: the
        // position is beyond the new range for one sample, but nothing pushed it
        // further down, so the same upward gesture does not ask a second time.
        XCTAssertFalse(policy.expands(atDistance: 980, maximumDistance: 960))
        XCTAssertFalse(policy.expands(atDistance: 960, maximumDistance: 960))
        XCTAssertFalse(policy.expands(atDistance: 948, maximumDistance: 960))
        // Scrolling down and then reversing is a new reverse scroll.
        XCTAssertFalse(policy.expands(atDistance: 958, maximumDistance: 960))
        XCTAssertFalse(policy.expands(atDistance: 952, maximumDistance: 960))
        XCTAssertTrue(policy.expands(atDistance: 946, maximumDistance: 960))
    }

    func testAJumpBeyondTheFarEdgeDoesNotRearmTheReverseExpansion() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 320], maximum: 1_000, viewport: 800)
        XCTAssertEqual(feed(&policy, [310, 300], maximum: 1_000, viewport: 800), [300])
        // The page lands past the far edge, 700 pt away, in the same gesture: a jump
        // is not the user pushing down, so the same upward gesture does not ask again.
        XCTAssertEqual(feed(&policy, [1_008, 1_000, 987, 975], maximum: 1_000, viewport: 800), [])
    }

    func testAShortPageStillExpandsOnReverseAndAtTheTop() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertEqual(feed(&policy, [0, 25, 18, 12, 0], maximum: 25), [12, 0])
    }

    func testAPageThatStopsScrollingExpandsTheBarOnce() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 400], maximum: 800)
        // The content shrinks to 25 pt of scroll range, below the Flutter 40 pt minimum.
        XCTAssertTrue(policy.expands(atDistance: 25, maximumDistance: 25))
        XCTAssertFalse(policy.expands(atDistance: 25, maximumDistance: 25))
        XCTAssertFalse(policy.expands(atDistance: 10, maximumDistance: 25))
    }

    func testAPageThatNeverScrollsNeverAsksToExpand() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertFalse(policy.expands(atDistance: 0, maximumDistance: 25))
        XCTAssertFalse(policy.expands(atDistance: 0, maximumDistance: 25))
    }

    func testAPageThatScrollsAgainRearmsTheShortContentExpansion() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 400], maximum: 800)
        XCTAssertTrue(policy.expands(atDistance: 25, maximumDistance: 25))
        _ = feed(&policy, [60, 300], maximum: 800)
        XCTAssertTrue(policy.expands(atDistance: 25, maximumDistance: 25))
    }

    // MARK: Minimizing

    private func changes(
        _ policy: inout MediaTabBarScrollPolicy,
        _ distances: [CGFloat],
        maximum: CGFloat = .greatestFiniteMagnitude,
        viewport: CGFloat = .greatestFiniteMagnitude,
        user: Bool = true
    ) -> [MediaTabBarChange?] {
        distances.map {
            policy.change(atDistance: $0, maximumDistance: maximum, viewportHeight: viewport, isUserScrolling: user)
        }
    }

    func testMinimizeDistanceIsTheFlutterMinimizeThreshold() {
        XCTAssertEqual(MediaTabBarScrollPolicy.minimizeDistance, 20)
    }

    func testScrollingDownMinimizesAfterTheMinimizeDistance() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertEqual(changes(&policy, [0, 8, 16, 24, 32]), [nil, nil, nil, .minimize, nil])
    }

    func testMinimizingAsksAgainForEveryMinimizeDistanceOfTravel() {
        var policy = MediaTabBarScrollPolicy()
        // The receiver ignores a repeat, so a tap that expanded the bar mid-scroll
        // is followed by another shrink after another 20 pt.
        XCTAssertEqual(changes(&policy, [0, 10, 20, 30, 40, 50, 60]), [nil, nil, .minimize, nil, .minimize, nil, .minimize])
    }

    func testAShortBackAndForthDoesNotMinimize() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertEqual(changes(&policy, [0, 12, 4, 16, 8, 19]), [nil, nil, nil, nil, nil, nil])
    }

    func testAReverseScrollResetsTheDownwardTravel() {
        var policy = MediaTabBarScrollPolicy()
        _ = changes(&policy, [0, 15])
        // 15 pt down, 5 pt up, then 10 pt down is 10 pt of travel since the reversal.
        XCTAssertEqual(changes(&policy, [10, 20]), [nil, nil])
    }

    func testAPageTooShortToScrollNeverMinimizes() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertEqual(changes(&policy, [0, 10, 20, 30, 39], maximum: 39), [nil, nil, nil, nil, nil])
    }

    func testOnlyTheUsersOwnScrollingMinimizes() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertEqual(changes(&policy, [0, 30, 60, 90], user: false), [nil, nil, nil, nil])
    }

    func testAJumpDoesNotMinimize() {
        var policy = MediaTabBarScrollPolicy()
        XCTAssertEqual(changes(&policy, [0, 600, 640], viewport: 800), [nil, nil, .minimize])
    }

    func testReboundAtTheFarEdgeDoesNotMinimize() {
        var policy = MediaTabBarScrollPolicy()
        _ = changes(&policy, [0, 990], maximum: 1_000)
        // 10 pt to the end is not enough, and being pulled past it is not scrolling.
        XCTAssertEqual(changes(&policy, [1_000, 1_040, 1_080], maximum: 1_000), [nil, nil, nil])
    }

    func testReachingTheTopExpandsAndForgetsTheDownwardTravel() {
        var policy = MediaTabBarScrollPolicy()
        _ = changes(&policy, [0, 15])
        XCTAssertEqual(changes(&policy, [0, 15]), [.expand, nil])
    }

    func testAReverseScrollAfterMinimizingExpands() {
        var policy = MediaTabBarScrollPolicy()
        _ = changes(&policy, [0, 12, 24])
        XCTAssertEqual(changes(&policy, [18, 10]), [nil, .expand])
    }

    func testAPageCorrectingItsOwnOffsetIsNotAReverseScroll() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 300, 320, 340])
        // The offset drops by a whole reverse scroll in one sample, as a lazy row's
        // height settles, and the finger keeps moving down the page.
        XCTAssertEqual(feed(&policy, [327, 334, 341, 348]), [])
    }

    func testAFastReverseScrollExpandsOnItsSecondSample() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 300, 320])
        // A flick that covers 14 pt in its first frame is a finger turning round:
        // it keeps going, and the next sample settles it.
        XCTAssertEqual(feed(&policy, [306, 292, 278]), [292])
    }

    func testAFirstFastStepThatIsFollowedByAForwardStepIsForgotten() {
        var policy = MediaTabBarScrollPolicy()
        _ = feed(&policy, [0, 300, 320])
        XCTAssertEqual(feed(&policy, [306, 312, 318, 312]), [])
    }
}
