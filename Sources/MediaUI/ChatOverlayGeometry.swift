import CoreGraphics
import Foundation

public enum ChatOverlayPosition: String, CaseIterable, Identifiable {
    case topLeading, top, topTrailing, leading, center, trailing, bottomLeading, bottom, bottomTrailing
    public var id: String { rawValue }
    public var x: Double { switch self { case .topLeading, .leading, .bottomLeading: 0; case .top, .center, .bottom: 0.5; default: 1 } }
    public var y: Double { switch self { case .topLeading, .top, .topTrailing: 0; case .leading, .center, .trailing: 0.5; default: 1 } }
    public var title: String {
        switch self {
        case .topLeading: "왼쪽 위"
        case .top: "가운데 위"
        case .topTrailing: "오른쪽 위"
        case .leading: "왼쪽 가운데"
        case .center: "가운데"
        case .trailing: "오른쪽 가운데"
        case .bottomLeading: "왼쪽 아래"
        case .bottom: "가운데 아래"
        case .bottomTrailing: "오른쪽 아래"
        }
    }
    public var symbol: String {
        switch self {
        case .topLeading: "arrow.up.left"
        case .top: "arrow.up"
        case .topTrailing: "arrow.up.right"
        case .leading: "arrow.left"
        case .center: "circle"
        case .trailing: "arrow.right"
        case .bottomLeading: "arrow.down.left"
        case .bottom: "arrow.down"
        case .bottomTrailing: "arrow.down.right"
        }
    }
}

public struct ChatOverlayGeometry: Codable, Equatable {
    public static let widthRange = 0.15...0.75
    public static let heightRange = 0.2...0.8
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var textScale: Double = 1

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }

    public init(frame: CGRect, in bounds: CGRect) {
        width = Double(frame.width / max(1, bounds.width))
        height = Double(frame.height / max(1, bounds.height))
        x = Double((frame.minX - bounds.minX) / max(1, bounds.width - frame.width))
        y = Double((frame.minY - bounds.minY) / max(1, bounds.height - frame.height))
    }

    public var isValid: Bool {
        [x, y, width, height, textScale].allSatisfy(\.isFinite) && (0...1).contains(x) && (0...1).contains(y)
            && width > 0 && width <= 1 && height > 0 && height <= 1 && (0.8...1.6).contains(textScale)
    }

    public func frame(in bounds: CGRect, minimumSize: CGSize) -> CGRect {
        let w = min(bounds.width, max(minimumSize.width, bounds.width * CGFloat(width)))
        let h = min(bounds.height, max(minimumSize.height, bounds.height * CGFloat(height)))
        return CGRect(x: bounds.minX + max(0, bounds.width - w) * CGFloat(min(1, max(0, x))),
                      y: bounds.minY + max(0, bounds.height - h) * CGFloat(min(1, max(0, y))), width: max(0, w), height: max(0, h))
    }

    public mutating func setPosition(_ position: ChatOverlayPosition) { x = position.x; y = position.y }

    public func moved(by translation: CGSize, in bounds: CGRect, minimumSize: CGSize) -> Self {
        let frame = frame(in: bounds, minimumSize: minimumSize)
        var result = self
        result.x = min(1, max(0, x + Double(translation.width / max(1, bounds.width - frame.width))))
        result.y = min(1, max(0, y + Double(translation.height / max(1, bounds.height - frame.height))))
        return result
    }

    public func resized(by translation: CGSize, in bounds: CGRect, minimumSize: CGSize = .zero) -> Self {
        let original = frame(in: bounds, minimumSize: minimumSize)
        var result = self
        result.width = min(Self.widthRange.upperBound, max(Self.widthRange.lowerBound, Double((original.width + translation.width) / max(1, bounds.width))))
        result.height = min(Self.heightRange.upperBound, max(Self.heightRange.lowerBound, Double((original.height + translation.height) / max(1, bounds.height))))
        let size = result.frame(in: bounds, minimumSize: minimumSize).size
        result.x = min(1, max(0, Double((original.minX - bounds.minX) / max(1, bounds.width - size.width))))
        result.y = min(1, max(0, Double((original.minY - bounds.minY) / max(1, bounds.height - size.height))))
        return result
    }
}
