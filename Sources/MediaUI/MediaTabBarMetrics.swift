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
/// `out = slope · glass + bias` for each channel, a neutral gray rather than the
/// accent color. Measured on iOS 27.2: `1.13 · glass − 0.20` in light mode and
/// `0.87 · glass − 0.07` in dark mode. That layer is not public, so the bar reaches
/// the same darkening with two blend modes over the glass: a multiply by a gray,
/// then a subtract (`plusDarker`) of a constant. A slope above one has no blend
/// mode; light mode takes the subtraction alone, which keeps a glass value from
/// mid-gray to white within 0.04 of the system's.
enum MediaTabBarHighlight {
    /// A multiply by `multiply`, then a subtraction of `subtract`, on each channel.
    struct Darkening: Equatable {
        var multiply: CGFloat
        var subtract: CGFloat

        /// The highlight over a glass channel value in 0...1.
        func response(_ glass: CGFloat) -> CGFloat {
            min(max(multiply * glass - subtract, 0), 1)
        }
    }

    /// The system's matrix, kept to measure ``darkening(isDark:)`` against.
    static func system(isDark: Bool) -> (slope: CGFloat, bias: CGFloat) {
        isDark ? (0.87, -0.07) : (1.13, -0.20)
    }

    static func darkening(isDark: Bool) -> Darkening {
        isDark ? Darkening(multiply: 0.89, subtract: 0.07) : Darkening(multiply: 1, subtract: 0.10)
    }
}
