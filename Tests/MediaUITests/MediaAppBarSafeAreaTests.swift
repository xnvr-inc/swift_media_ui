#if os(iOS)
import XCTest
@testable import MediaUI

/// Once the app bar has dissolved the page hides it and adds its height to the
/// safe area, so the content stays put while the system scroll edge effect, which
/// is as tall as the bar's bottom edge, shrinks to the status bar's inset.
@available(iOS 26, *)
@MainActor
final class MediaAppBarSafeAreaTests: XCTestCase {
    private var window: UIWindow?

    private func makeStack(size: CGSize = CGSize(width: 393, height: 852)) -> (UINavigationController, UIViewController, MediaAppBarDriver) {
        let page = UIViewController()
        let navigation = UINavigationController(rootViewController: page)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        navigation.view.layoutIfNeeded()
        self.window = window
        let driver = MediaAppBarDriver()
        driver.page = page
        driver.appeared(in: navigation.navigationBar)
        return (navigation, page, driver)
    }

    private func scroll(_ driver: MediaAppBarDriver, to distance: CGFloat) {
        _ = driver.scrolled(
            to: MediaScrollSample(distance: distance, maximumDistance: 2_000, viewportHeight: 800),
            expansions: 0
        )
    }

    override func tearDown() async throws {
        window?.isHidden = true
        window = nil
    }

    func testBarStaysWhileItIsDissolving() {
        let (navigation, page, driver) = makeStack()
        scroll(driver, to: 20)
        XCTAssertFalse(navigation.navigationBar.isHidden)
        XCTAssertEqual(page.additionalSafeAreaInsets.top, 0)
    }

    func testBarIsHiddenAndItsHeightKeptOnceGone() {
        let (navigation, page, driver) = makeStack()
        let height = navigation.navigationBar.bounds.height
        XCTAssertGreaterThan(height, 0)
        let inset = page.view.safeAreaInsets.top
        scroll(driver, to: 60)
        XCTAssertTrue(navigation.navigationBar.isHidden)
        XCTAssertEqual(page.additionalSafeAreaInsets.top, height)
        navigation.view.layoutIfNeeded()
        XCTAssertEqual(page.view.safeAreaInsets.top, inset, accuracy: 0.5, "The page must not move")
    }

    func testBarReturnsWithTheTopOfThePage() {
        let (navigation, page, driver) = makeStack()
        scroll(driver, to: 60)
        scroll(driver, to: 10)
        XCTAssertFalse(navigation.navigationBar.isHidden)
        XCTAssertEqual(page.additionalSafeAreaInsets.top, 0)
    }

    func testLeavingThePageGivesTheBarBack() {
        let (navigation, page, driver) = makeStack()
        scroll(driver, to: 60)
        driver.disappeared()
        XCTAssertFalse(navigation.navigationBar.isHidden)
        XCTAssertEqual(page.additionalSafeAreaInsets.top, 0)
    }

    func testDisablingGivesTheBarBack() {
        let (navigation, page, driver) = makeStack()
        scroll(driver, to: 60)
        driver.isEnabled = false
        XCTAssertFalse(navigation.navigationBar.isHidden)
        XCTAssertEqual(page.additionalSafeAreaInsets.top, 0)
    }

    func testOtherAdditionsToTheSafeAreaSurvive() {
        let (_, page, driver) = makeStack()
        page.additionalSafeAreaInsets.top = 10
        scroll(driver, to: 60)
        driver.disappeared()
        XCTAssertEqual(page.additionalSafeAreaInsets.top, 10)
    }

    func testBarThatSomethingElseHidesIsLeftAlone() {
        let (navigation, page, driver) = makeStack()
        navigation.navigationBar.isHidden = true
        scroll(driver, to: 60)
        XCTAssertEqual(page.additionalSafeAreaInsets.top, 0)
        driver.disappeared()
        XCTAssertTrue(navigation.navigationBar.isHidden)
    }
}
#endif
