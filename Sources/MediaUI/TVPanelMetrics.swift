#if os(tvOS)
import Foundation

public enum TVPanelMetrics {
    public static let outerInset: CGFloat = 24
    public static let contentInset: CGFloat = 24

    public static func width(in containerWidth: CGFloat) -> CGFloat {
        floor(containerWidth / 3)
    }

    public static func height(in containerHeight: CGFloat) -> CGFloat {
        max(0, containerHeight - 2 * outerInset)
    }

    public static func duration(reducedMotion: Bool) -> TimeInterval {
        reducedMotion ? 0.18 : 0.32
    }
}
#endif
