import CoreGraphics
import Foundation

/// Geometry and motion of the compact tab bar.
///
/// Mirrors the Flutter `XnvrFlutterTabBar` without an accessory: a glass pill that
/// fills the row less its margins, and shrinks to a pill of icons while the page
/// scrolls down. Labels leave first, the pill narrows to one slot per tab and
/// settles in the middle, and the height scales down. The bar reserves the same
/// height in every state, so the content's clearance never jumps.
public enum MediaTabBarMetrics {
    /// Duration of the shrink and of the expansion, the Flutter `_duration`.
    public static let duration: TimeInterval = 0.38
    /// Height of the full pill, the standard iOS 26 tab bar.
    public static let barHeight: CGFloat = 62
    /// Space between the pill and the bottom of the area the bar reserves.
    public static let gap: CGFloat = 8
    /// Space at each side of the full pill.
    public static let margin: CGFloat = 20
    /// Height of the shrunken pill relative to the full one.
    public static let compactScale: CGFloat = 0.76
    /// Width of one tab in the shrunken pill.
    public static let compactSlot: CGFloat = 56
    /// Space between the shrunken pill's edge and its first and last tab.
    public static let compactInset: CGFloat = 6
    /// Space between the full pill's edge and its first and last tab.
    public static let expandedInset: CGFloat = 4
    /// Share of the progress over which the labels leave.
    public static let labelFadeSpan: CGFloat = 0.65
    /// Size of the box a tab's icon fits, in every state, the Flutter icon theme size.
    public static let iconSize: CGFloat = 24
    /// Height of the area the bar reserves in every state.
    public static var reservedHeight: CGFloat { barHeight + gap }

    /// The Flutter `Curves.easeOutCubic`, the cubic Bézier (0.215, 0.61, 0.355, 1),
    /// applied to the linear progress of the transition. Flutter applies it to the
    /// controller's value in both directions: the shrink decelerates and the
    /// expansion, which runs it backwards, accelerates.
    public static func eased(_ linear: CGFloat) -> CGFloat {
        let t = min(max(linear, 0), 1)
        guard t > 0, t < 1 else { return t }
        // The same bisection as Flutter's `Cubic.transform`.
        func bezier(_ first: CGFloat, _ second: CGFloat, _ m: CGFloat) -> CGFloat {
            3 * first * (1 - m) * (1 - m) * m + 3 * second * (1 - m) * m * m + m * m * m
        }
        var start: CGFloat = 0
        var end: CGFloat = 1
        while true {
            let middle = (start + end) / 2
            let estimate = bezier(0.215, 0.355, middle)
            if abs(t - estimate) < 0.001 { return bezier(0.61, 1, middle) }
            if estimate < t { start = middle } else { end = middle }
        }
    }

    /// Width of the shrunken pill: one slot per tab, never wider than the full pill.
    public static func compactWidth(tabCount: Int, expandedWidth: CGFloat) -> CGFloat {
        min(CGFloat(max(tabCount, 0)) * compactSlot + 2 * compactInset, max(expandedWidth, 0))
    }

    /// Where the pill and its tabs are for a bar `width` wide.
    public struct Layout: Equatable {
        /// The pill, in a space `width` wide and ``MediaTabBarMetrics/reservedHeight`` high.
        public var pill: CGRect
        /// Space between the pill's edge and its first and last tab.
        public var inset: CGFloat
        /// Width of one tab's slot.
        public var slotWidth: CGFloat
        /// Width of the highlight behind the selected tab.
        public var highlightWidth: CGFloat
        /// Opacity, and share of its height, that a tab's label keeps.
        public var labelFade: CGFloat

        /// The middle of the slot at a visual `position`, counted from the leading
        /// edge and fractional while the highlight moves, in the pill's own space.
        public func slotCenter(at position: CGFloat) -> CGFloat {
            inset + slotWidth * (position + 0.5)
        }

        /// The highlight's leading edge at a visual `position`: centered on the slot,
        /// and kept inside the pill when the highlight is wider than a slot, which a
        /// row of many tabs in a narrow host makes it.
        public func highlightOrigin(at position: CGFloat) -> CGFloat {
            let lowest = inset
            let highest = max(pill.width - inset - highlightWidth, lowest)
            return min(max(slotCenter(at: position) - highlightWidth / 2, lowest), highest)
        }

        /// The highlight's frame at a visual `position`, in the pill's own space.
        public func highlightFrame(at position: CGFloat) -> CGRect {
            CGRect(
                x: highlightOrigin(at: position), y: inset,
                width: highlightWidth, height: max(pill.height - 2 * inset, 0)
            )
        }

        /// The highlight's outline at a visual `position`, in the pill's own space: a
        /// capsule that never leaves the pill's glass. The pill shrunk by its inset is
        /// a capsule too, and a highlight at least as wide as it is tall, kept between
        /// the insets, is inside it. A narrower one, in a slot of a crowded row, has
        /// a smaller cap radius than the pill and its corners would reach past the
        /// pill's caps, where a blend has no glass behind it; it is cut to that capsule.
        public func highlightPath(at position: CGFloat) -> CGPath {
            let frame = highlightFrame(at: position)
            guard !frame.isEmpty else { return CGMutablePath() }
            let outline = Self.capsule(frame)
            guard frame.width < frame.height else { return outline }
            let inner = CGRect(
                x: inset, y: inset,
                width: max(pill.width - 2 * inset, 0), height: max(pill.height - 2 * inset, 0)
            )
            return outline.intersection(Self.capsule(inner))
        }

        private static func capsule(_ rect: CGRect) -> CGPath {
            let radius = min(rect.width, rect.height) / 2
            return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        }
    }

    /// The layout of a bar `width` wide, with `tabCount` tabs, once the
    /// transition has reached the eased `progress` (0 expanded, 1 shrunken).
    public static func layout(width: CGFloat, tabCount: Int, progress: CGFloat) -> Layout {
        let p = min(max(progress, 0), 1)
        let count = CGFloat(max(tabCount, 1))
        let expandedWidth = max(width - 2 * margin, 0)
        let compact = compactWidth(tabCount: tabCount, expandedWidth: expandedWidth)
        let pillWidth = lerp(expandedWidth, compact, p)
        let pillHeight = barHeight * lerp(1, compactScale, p)
        let pillLeft = lerp(margin, (width - compact) / 2, p)
        let inset = lerp(expandedInset, compactInset, p)
        let highlight = lerp((expandedWidth - 2 * expandedInset) / count, compactSlot, p)
        return Layout(
            pill: CGRect(x: pillLeft, y: reservedHeight - gap - pillHeight, width: pillWidth, height: pillHeight),
            inset: inset,
            slotWidth: (pillWidth - 2 * inset) / count,
            highlightWidth: min(max(highlight, 0), max(pillWidth - 2 * inset, 0)),
            labelFade: 1 - min(1, p / labelFadeSpan)
        )
    }

    private static func lerp(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat {
        from + (to - from) * t
    }
}

/// How the selected tab's highlight darkens the glass beneath it.
///
/// The system tab bar draws the highlight on a backdrop layer with a color matrix,
/// `out = slope · glass + bias` on each color channel, and does not paint the
/// accent color: the glass shows through, darker, and keeps its hue. Measured on
/// iOS 27.2: `1.13 · glass − 0.20` in light mode and `0.87 · glass − 0.07` in dark
/// mode. That layer is not public, so the bar applies the same coefficients with
/// blend modes over the glass: a `colorBurn` (slope above one) or a `multiply`
/// (slope below one) by a gray, which is the same factor on every channel, then
/// a `plusDarker` subtraction of the rest. Only the coefficients are the system's;
/// they depend on the color scheme alone, not on Increase Contrast or Reduce
/// Transparency, which change the glass beneath but not the matrix applied here.
enum MediaTabBarHighlight {
    /// The system's matrix, `slope · glass − subtract`, on each channel.
    struct Darkening: Equatable {
        var slope: CGFloat
        var subtract: CGFloat

        /// The gray a `colorBurn` (slope above one) or a `multiply` (below one)
        /// uses, or `nil` when the slope is one.
        var firstGray: CGFloat? {
            if slope > 1 { return 1 / slope }
            if slope < 1 { return slope }
            return nil
        }

        /// What the `plusDarker` subtracts after the first blend. A burn by `1 / slope`
        /// computes `slope · glass − (slope − 1)`, clamped at zero, so it already
        /// carries `slope − 1` of the bias; a multiply carries none.
        var remainder: CGFloat {
            max(subtract - max(slope - 1, 0), 0)
        }

        /// The highlight over a glass channel value in 0...1, stage by stage as the
        /// blend modes clamp it.
        func response(_ glass: CGFloat) -> CGFloat {
            let g = min(max(glass, 0), 1)
            let first: CGFloat
            if slope > 1 {
                first = max(1 - (1 - g) * slope, 0)
            } else {
                first = slope * g
            }
            return min(max(first - remainder, 0), 1)
        }
    }

    static func darkening(isDark: Bool) -> Darkening {
        isDark ? Darkening(slope: 0.87, subtract: 0.07) : Darkening(slope: 1.13, subtract: 0.20)
    }
}
