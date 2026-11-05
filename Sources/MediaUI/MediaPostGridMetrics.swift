import SwiftUI

public enum MediaPostGridMetrics {
    public static let spacing = MediaLayout.columnGap
    public static let singleColumnMaximumWidth: CGFloat = 640

    public static func columns(in contentWidth: CGFloat) -> Int {
        #if os(iOS)
        return 1
        #else
        let minimum: CGFloat
        let maximum: Int
        #if os(tvOS)
        minimum = 440
        maximum = 3
        #else
        minimum = 280
        maximum = Int.max
        #endif
        guard contentWidth.isFinite else { return 1 }
        return max(1, min(maximum, Int((max(0, contentWidth) + spacing) / (minimum + spacing))))
        #endif
    }

    private static func cardWidth(in contentWidth: CGFloat, columns: Int) -> CGFloat {
        max(1, (contentWidth - CGFloat(columns - 1) * spacing) / CGFloat(columns))
    }

    /// The same width, column assignment, and frames for measured SwiftUI
    /// cards and for collection views that estimate height before reuse.
    public static func waterfall(in width: CGFloat, count: Int, heightAt: (Int, CGFloat) -> CGFloat) -> Waterfall {
        let width = width.isFinite ? max(0, width) : 0
        let columnCount = columns(in: width)
        let cardWidth = cardWidth(in: width, columns: columnCount)
        var columns = Array(repeating: [Int](), count: columnCount)
        var bottoms = Array(repeating: CGFloat.zero, count: columnCount)
        var frames = [CGRect]()
        frames.reserveCapacity(count)
        for index in 0..<count {
            let column = bottoms.indices.min { bottoms[$0] < bottoms[$1] }!
            let frame = CGRect(x: CGFloat(column) * (cardWidth + spacing), y: bottoms[column],
                               width: cardWidth, height: max(1, heightAt(index, cardWidth)))
            frames.append(frame)
            columns[column].append(index)
            bottoms[column] = frame.maxY + spacing
        }
        return Waterfall(cardWidth: cardWidth, columns: columns, frames: frames,
                         size: CGSize(width: width, height: max(0, (bottoms.max() ?? 0) - spacing)))
    }

    public struct Waterfall {
        public let cardWidth: CGFloat
        public let columns: [[Int]]
        public let frames: [CGRect]
        public let size: CGSize
    }
}

#if os(iOS)
public struct MediaPostFeedColumn<Content: View>: View {
    @ViewBuilder private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        LazyVStack(spacing: MediaPostGridMetrics.spacing, content: content)
            .frame(maxWidth: MediaPostGridMetrics.singleColumnMaximumWidth)
            .frame(maxWidth: .infinity)
    }
}
#endif

#if os(macOS) || os(tvOS)
public struct MediaPostWaterfallLayout: Layout {
    public init() {}

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        placements(width: proposal.width ?? 320, subviews: subviews).size
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = placements(width: bounds.width, subviews: subviews)
        for (view, frame) in zip(subviews, layout.frames) {
            view.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                       anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func placements(width: CGFloat, subviews: Subviews) -> MediaPostGridMetrics.Waterfall {
        MediaPostGridMetrics.waterfall(in: width, count: subviews.count) { index, cardWidth in
            subviews[index].sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height
        }
    }
}
#endif
