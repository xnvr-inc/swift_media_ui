import Foundation

public enum MediaMiniPlayerCorner: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var isRight: Bool { self == .topRight || self == .bottomRight }
    var isBottom: Bool { self == .bottomLeft || self == .bottomRight }

    func center(in bounds: CGRect, size: CGSize) -> CGPoint {
        CGPoint(x: isRight ? bounds.maxX - size.width / 2 : bounds.minX + size.width / 2,
                y: isBottom ? bounds.maxY - size.height / 2 : bounds.minY + size.height / 2)
    }
}

/// Places the entire mini-player, with any number of video tiles, inside a safe viewport.
public struct MediaMiniPlayerLayout {
    public let bounds: CGRect
    public let size: CGSize

    public init(safeArea: CGRect, preferredSize: CGSize, horizontalInset: CGFloat, bottomInset: CGFloat) {
        let side = min(max(0, horizontalInset), safeArea.width / 2)
        bounds = CGRect(x: safeArea.minX + side, y: safeArea.minY,
                        width: max(0, safeArea.width - 2 * side), height: max(0, safeArea.height - max(0, bottomInset)))
        let scale = min(1, bounds.width / max(1, preferredSize.width), bounds.height / max(1, preferredSize.height))
        size = CGSize(width: preferredSize.width * scale, height: preferredSize.height * scale)
    }

    public func frame(at corner: MediaMiniPlayerCorner, offset: CGSize = .zero) -> CGRect {
        let anchor = corner.center(in: bounds, size: size)
        let x = min(bounds.maxX - size.width, max(bounds.minX, anchor.x - size.width / 2 + offset.width))
        let y = min(bounds.maxY - size.height, max(bounds.minY, anchor.y - size.height / 2 + offset.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    public func closestCorner(from corner: MediaMiniPlayerCorner, offset: CGSize) -> MediaMiniPlayerCorner {
        let frame = frame(at: corner, offset: offset)
        let dx = frame.midX - bounds.midX
        let dy = frame.midY - bounds.midY
        // A viewport can fit the player exactly on one axis. Keep that axis
        // anchored so the player stays at the chosen edge when space returns.
        let right = abs(dx) < 0.001 ? corner.isRight : dx > 0
        let bottom = abs(dy) < 0.001 ? corner.isBottom : dy > 0
        switch (right, bottom) {
        case (false, false): return .topLeft
        case (true, false): return .topRight
        case (false, true): return .bottomLeft
        case (true, true): return .bottomRight
        }
    }

    func shouldDismiss(from corner: MediaMiniPlayerCorner, offset: CGSize, predicted: CGSize) -> Bool {
        corner.isRight && offset.width > abs(offset.height) * 1.5
            && (offset.width >= 90 || (offset.width >= 24 && predicted.width >= 160))
    }
}
