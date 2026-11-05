#if os(macOS)
import AppKit

public struct MacChatOverlayLayout {
    public let width: CGFloat
    public let height: CGFloat
    public let inset = MediaDiscussionMetrics.chatPanelInset

    public init(videoSize: CGSize) {
        width = max(0, min(320, max(180, videoSize.width * 0.34), videoSize.width - 2 * inset))
        height = max(0, min(340, max(90, videoSize.height * 0.6), videoSize.height - 2 * inset))
    }
}

public struct MacChatMessageLayout {
    public static let spacing = MediaDiscussionMetrics.chatRowSpacing
    public let rowHeight: CGFloat
    public let visibleCount: Int
    public let lineLimit: Int

    public init(availableHeight: CGFloat, textScale: CGFloat) {
        let lineHeight = NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: MediaDiscussionMetrics.chatTextSize * textScale))
        lineLimit = availableHeight < ceil(lineHeight * 2 + 2) ? 1 : 2
        rowHeight = ceil(lineHeight * CGFloat(lineLimit) + 2)
        visibleCount = max(0, min(60, Int((max(0, availableHeight) + Self.spacing) / (rowHeight + Self.spacing))))
    }
}
#endif
