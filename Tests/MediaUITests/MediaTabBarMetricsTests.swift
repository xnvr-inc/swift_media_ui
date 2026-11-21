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

/// The selected tab's highlight applies the system bar's color matrix with blend
/// modes, which the package cannot use directly.
final class MediaTabBarHighlightTests: XCTestCase {
    private let system: [(isDark: Bool, slope: CGFloat, bias: CGFloat)] = [
        (false, 1.13, -0.20), (true, 0.87, -0.07),
    ]

    func testTheBlendsReproduceTheSystemsMatrixOverTheGlassTheBarSitsOn() {
        for entry in system {
            let darkening = MediaTabBarHighlight.darkening(isDark: entry.isDark)
            for glass in stride(from: 0.15, through: 1.0, by: 0.05) as StrideThrough<CGFloat> {
                let expected = min(max(entry.slope * glass + entry.bias, 0), 1)
                XCTAssertEqual(darkening.response(glass), expected, accuracy: 1e-9, "isDark \(entry.isDark) glass \(glass)")
            }
        }
    }

    func testTheHighlightIsAlwaysDarkerThanTheGlass() {
        for isDark in [false, true] {
            let darkening = MediaTabBarHighlight.darkening(isDark: isDark)
            for glass in stride(from: 0.1, through: 1.0, by: 0.05) as StrideThrough<CGFloat> {
                XCTAssertLessThan(darkening.response(glass), glass, "isDark \(isDark) glass \(glass)")
            }
        }
    }

    func testBlackStaysBlackAndTheResponseNeverLeavesTheRange() {
        for isDark in [false, true] {
            let darkening = MediaTabBarHighlight.darkening(isDark: isDark)
            XCTAssertEqual(darkening.response(0), 0)
            XCTAssertEqual(darkening.response(-1), 0)
            XCTAssertLessThanOrEqual(darkening.response(2), 1)
        }
    }

    func testLightModeBurnsAndDarkModeMultipliesBeforeTheSubtraction() {
        let light = MediaTabBarHighlight.darkening(isDark: false)
        XCTAssertEqual(light.firstGray ?? 0, 1 / 1.13, accuracy: 1e-9)
        XCTAssertEqual(light.remainder, 0.07, accuracy: 1e-9)
        let dark = MediaTabBarHighlight.darkening(isDark: true)
        XCTAssertEqual(dark.firstGray ?? 0, 0.87, accuracy: 1e-9)
        XCTAssertEqual(dark.remainder, 0.07, accuracy: 1e-9)
        XCTAssertNil(MediaTabBarHighlight.Darkening(slope: 1, subtract: 0.1).firstGray)
    }

    func testTheHighlightStaysInsideThePillWhateverTheNumberOfTabs() {
        for (width, count) in [(393, 4), (320, 5), (250, 5), (393, 10)] as [(CGFloat, Int)] {
            for progress in [0, 0.5, 1] as [CGFloat] {
                let layout = MediaTabBarMetrics.layout(width: width, tabCount: count, progress: progress)
                for index in 0..<count {
                    let origin = layout.highlightOrigin(at: CGFloat(index))
                    XCTAssertGreaterThanOrEqual(origin, layout.inset - 1e-9, "\(width) \(count) \(progress) tab \(index)")
                    XCTAssertLessThanOrEqual(origin + layout.highlightWidth, layout.pill.width - layout.inset + 1e-9, "\(width) \(count) \(progress) tab \(index)")
                }
            }
        }
    }

    func testTheHighlightIsCenteredOnItsSlotWhenItFits() {
        let layout = MediaTabBarMetrics.layout(width: 393, tabCount: 4, progress: 1)
        for index in 0..<4 {
            XCTAssertEqual(layout.highlightOrigin(at: CGFloat(index)) + layout.highlightWidth / 2, layout.slotCenter(at: CGFloat(index)), accuracy: 1e-9)
        }
    }

    // MARK: Outline

    /// Whether `point` is inside the capsule that fills `rect`, within `tolerance`.
    private func insideCapsule(_ point: CGPoint, _ rect: CGRect, tolerance: CGFloat = 0.05) -> Bool {
        let radius = min(rect.width, rect.height) / 2
        let core = rect.insetBy(dx: radius, dy: radius)
        let dx = max(core.minX - point.x, 0, point.x - core.maxX)
        let dy = max(core.minY - point.y, 0, point.y - core.maxY)
        return dx * dx + dy * dy <= (radius + tolerance) * (radius + tolerance)
    }

    /// The points on a half-point grid over `path`'s bounding box that it contains.
    private func samples(in path: CGPath) -> [CGPoint] {
        let box = path.boundingBoxOfPath
        guard !box.isNull, !box.isEmpty else { return [] }
        var points: [CGPoint] = []
        for x in stride(from: box.minX, through: box.maxX, by: 0.5) {
            for y in stride(from: box.minY, through: box.maxY, by: 0.5) where path.contains(CGPoint(x: x, y: y)) {
                points.append(CGPoint(x: x, y: y))
            }
        }
        return points
    }

    /// Hosts of every width the bar meets, from a crowded narrow row to a roomy one.
    private let outlineCases: [(width: CGFloat, count: Int)] = [
        (200, 5), (250, 5), (320, 5), (393, 4), (393, 10), (150, 6),
    ]

    func testTheOutlineStaysInsideThePillsCapsuleAtEveryTabAndInBetween() {
        for (width, count) in outlineCases {
            for progress in [0, 0.5, 1] as [CGFloat] {
                let layout = MediaTabBarMetrics.layout(width: width, tabCount: count, progress: progress)
                let pill = CGRect(origin: .zero, size: layout.pill.size)
                // A right-to-left bar shows the same positions mirrored (the last tab
                // first), so sweeping every position covers the trailing cap as well.
                for position in stride(from: 0, through: CGFloat(count - 1), by: 0.5) {
                    let points = samples(in: layout.highlightPath(at: position))
                    XCTAssertFalse(points.isEmpty, "\(width) \(count) \(progress) at \(position)")
                    let outside = points.first { !insideCapsule($0, pill) }
                    XCTAssertNil(outside, "\(width) \(count) \(progress) at \(position)")
                }
            }
        }
    }

    func testAPlainCapsuleInANarrowSlotWouldReachPastTheCap() {
        // The case the outline is cut for: a 200 pt host with five tabs, a 160 pt
        // pill and a 30.4 pt slot, the highlight in the first slot.
        let layout = MediaTabBarMetrics.layout(width: 200, tabCount: 5, progress: 0)
        let frame = layout.highlightFrame(at: 0)
        XCTAssertLessThan(frame.width, frame.height)
        let radius = frame.width / 2
        let plain = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let pill = CGRect(origin: .zero, size: layout.pill.size)
        XCTAssertTrue(samples(in: plain).contains { !insideCapsule($0, pill) })
        XCTAssertFalse(samples(in: layout.highlightPath(at: 0)).contains { !insideCapsule($0, pill) })
    }

    func testTheOutlineIsTheHighlightsCapsuleWhenItFits() {
        let layout = MediaTabBarMetrics.layout(width: 393, tabCount: 4, progress: 1)
        for index in 0..<4 {
            let frame = layout.highlightFrame(at: CGFloat(index))
            XCTAssertGreaterThanOrEqual(frame.width, frame.height)
            let radius = frame.height / 2
            let capsule = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
            XCTAssertEqual(layout.highlightPath(at: CGFloat(index)), capsule)
        }
    }
}
