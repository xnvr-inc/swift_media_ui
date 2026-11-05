#if os(tvOS)
import UIKit

public enum PlaybackChatOverlayLayout {
    private static func sizingBounds(in bounds: CGRect, safeAreaInsets: UIEdgeInsets) -> CGRect {
        let safe = bounds.inset(by: safeAreaInsets)
        return CGRect(x: safe.minX, y: safe.minY + 32, width: max(0, safe.width), height: max(0, safe.height - 212))
    }

    private static func placementBounds(in bounds: CGRect) -> CGRect {
        let inset = min(TVMediaLayout.Spacing.xs, max(0, min(bounds.width, bounds.height) / 2))
        return bounds.insetBy(dx: inset, dy: inset)
    }

    public static func geometry(for frame: CGRect, in bounds: CGRect, safeAreaInsets: UIEdgeInsets) -> ChatOverlayGeometry {
        var geometry = ChatOverlayGeometry(frame: frame, in: sizingBounds(in: bounds, safeAreaInsets: safeAreaInsets))
        let position = ChatOverlayGeometry(frame: frame, in: placementBounds(in: bounds))
        geometry.x = position.x
        geometry.y = position.y
        return geometry
    }

    public static func adjustedFrame(in bounds: CGRect, safeAreaInsets: UIEdgeInsets, geometry: ChatOverlayGeometry?) -> CGRect {
        guard let geometry else { return frame(in: bounds, safeAreaInsets: safeAreaInsets) }
        // Retain saved panel sizes, but let position endpoints use the video edges.
        let size = geometry.frame(in: sizingBounds(in: bounds, safeAreaInsets: safeAreaInsets), minimumSize: CGSize(width: 340, height: 180)).size
        let available = placementBounds(in: bounds)
        let width = min(size.width, available.width)
        let height = min(size.height, available.height)
        return CGRect(x: available.minX + max(0, available.width - width) * CGFloat(min(1, max(0, geometry.x))),
                      y: available.minY + max(0, available.height - height) * CGFloat(min(1, max(0, geometry.y))),
                      width: width, height: height)
    }
    public static func frame(in bounds: CGRect, safeAreaInsets: UIEdgeInsets) -> CGRect {
        let safe = bounds.inset(by: safeAreaInsets)
        let available = placementBounds(in: bounds)
        let width = min(480, max(340, safe.width * 0.28), safe.width, available.width)
        let top = safe.minY + 64
        let bottom = min(safe.maxY, bounds.minY + bounds.height * 0.67)
        let height = max(0, min(430, safe.height * 0.48, bottom - top))
        return CGRect(x: min(safe.maxX, available.maxX) - width, y: top, width: width, height: height)
    }
}

@MainActor open class TVMediaChatOverlay: UIView {
    private let authorColor: UIColor
    private let scrollView = PlaybackChatScrollView()
    private let emptyLabel = UILabel()
    private let loadingShimmer = TVMediaShimmer()
    private var isLoading = false
    private let sizingLabel = UILabel()
    private var messageLabels: [UILabel] = []
    private var messages: [MediaChatEntry] = []
    private var artworkCatalog: [String: URL] = [:]
    private var artworkImages: [URL: CGImage] = [:]
    private var requestedArtwork = Set<URL>()
    private var visibleArtwork = Set<URL>()
    private var measuredMessages: [UUID: (text: NSAttributedString, height: CGFloat)] = [:]
    private var measuredWidth: CGFloat = 0
    private var measuredScale: CGFloat = 0
    private var measuredLineLimit = 0
    public var textScale: CGFloat = 1 { didSet { setNeedsLayout() } }

    public init(frame: CGRect = .zero, fill: UIColor, authorColor: UIColor) {
        self.authorColor = authorColor
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isHidden = true
        backgroundColor = fill
        layer.cornerRadius = TVMediaLayout.Corner.card
        layer.borderWidth = 1
        layer.borderColor = UIColor.white.withAlphaComponent(0.14).cgColor
        clipsToBounds = true

        scrollView.isUserInteractionEnabled = false
        scrollView.isScrollEnabled = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.contentInset = UIEdgeInsets(top: TVMediaLayout.Spacing.md, left: 0, bottom: TVMediaLayout.Spacing.md, right: 0)
        addSubview(scrollView)

        emptyLabel.font = .systemFont(ofSize: 24)
        emptyLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        emptyLabel.numberOfLines = 3
        scrollView.addSubview(emptyLabel)
        loadingShimmer.isHidden = true
        loadingShimmer.isAccessibilityElement = true
        scrollView.addSubview(loadingShimmer)
        sizingLabel.lineBreakMode = .byTruncatingTail
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func update(emptyMessage: String, loading: Bool, loadingLabel: String, messages: [MediaChatEntry],
                       inlineArtwork: [String: URL] = [:]) {
        emptyLabel.text = emptyMessage
        isLoading = loading
        loadingShimmer.accessibilityLabel = loadingLabel
        self.messages = Array(messages.suffix(60))
        let retainedIDs = Set(self.messages.map(\.id))
        measuredMessages = measuredMessages.filter { retainedIDs.contains($0.key) }
        if artworkCatalog != inlineArtwork {
            artworkCatalog = inlineArtwork
            measuredMessages.removeAll(keepingCapacity: true)
        }
        updateArtwork()
        while messageLabels.count < self.messages.count {
            let label = UILabel()
            label.lineBreakMode = .byTruncatingTail
            label.accessibilityIdentifier = "player.chat.message"
            scrollView.addSubview(label)
            messageLabels.append(label)
        }
        setNeedsLayout()
    }

    private func updateArtwork() {
        visibleArtwork = Set(messages.flatMap { MediaInlineArtwork.matches(in: $0.text, catalog: artworkCatalog).map(\.1) })
        requestedArtwork.formIntersection(visibleArtwork)
        artworkImages = artworkImages.filter { visibleArtwork.contains($0.key) }
        for url in visibleArtwork where artworkImages[url] == nil && requestedArtwork.insert(url).inserted {
            Task { [weak self] in
                guard let image = await MediaInlineArtworkCache.shared.image(url),
                      let self, visibleArtwork.contains(url) else { return }
                artworkImages[url] = image
                measuredMessages.removeAll(keepingCapacity: true)
                setNeedsLayout()
            }
        }
    }

    private func appendMessage(_ message: String, to text: NSMutableAttributedString, font: UIFont) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        var start = message.startIndex
        for (range, url) in MediaInlineArtwork.matches(in: message, catalog: artworkCatalog) {
            guard let image = artworkImages[url] else { continue }
            text.append(NSAttributedString(string: String(message[start..<range.lowerBound]), attributes: attributes))
            let attachment = NSTextAttachment()
            attachment.image = UIImage(cgImage: image)
            let scale = font.pointSize / CGFloat(max(image.width, image.height))
            attachment.bounds = CGRect(x: 0, y: font.descender * 0.6, width: CGFloat(image.width) * scale,
                                       height: CGFloat(image.height) * scale)
            text.append(NSAttributedString(attachment: attachment))
            start = range.upperBound
        }
        text.append(NSAttributedString(string: String(message[start...]), attributes: attributes))
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        let scale = min(1.6, max(0.8, textScale))
        let width = max(0, bounds.width - TVMediaLayout.Spacing.md * 2)
        let availableHeight = max(0, bounds.height - scrollView.contentInset.top - scrollView.contentInset.bottom)
        let font = UIFont.systemFont(ofSize: MediaLayout.cardTitleSize * scale)
        let lineLimit = availableHeight < ceil(font.lineHeight * 2) ? 1 : 2
        if measuredWidth != width || measuredScale != scale || measuredLineLimit != lineLimit {
            measuredMessages.removeAll(keepingCapacity: true)
            measuredWidth = width
            measuredScale = scale
            measuredLineLimit = lineLimit
        }
        sizingLabel.font = font
        sizingLabel.numberOfLines = lineLimit
        var usedHeight: CGFloat = 0
        emptyLabel.isHidden = !messages.isEmpty || isLoading
        loadingShimmer.isHidden = !messages.isEmpty || !isLoading
        for (index, label) in messageLabels.enumerated() {
            label.isHidden = index >= messages.count
            guard index < messages.count else { label.attributedText = nil; continue }
            let message = messages[index]
            let row: (text: NSAttributedString, height: CGFloat)
            if let cached = measuredMessages[message.id] { row = cached }
            else {
                let text = NSMutableAttributedString(string: message.author,
                    attributes: [.font: UIFont.systemFont(ofSize: MediaLayout.cardTitleSize * scale, weight: .semibold), .foregroundColor: authorColor])
                appendMessage("  " + message.text, to: text, font: font)
                sizingLabel.attributedText = text
                row = (text, ceil(sizingLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
                measuredMessages[message.id] = row
            }
            label.font = font
            label.accessibilityLabel = message.author + "  " + message.text
            label.numberOfLines = lineLimit
            label.frame = CGRect(x: TVMediaLayout.Spacing.md, y: usedHeight, width: width, height: row.height)
            if label.attributedText?.isEqual(to: row.text) != true { label.attributedText = row.text }
            usedHeight += row.height + (index == messages.count - 1 ? 0 : TVMediaLayout.Spacing.xs)
        }
        if !loadingShimmer.isHidden {
            usedHeight = 14
            loadingShimmer.frame = CGRect(x: TVMediaLayout.Spacing.md, y: 0, width: min(width, 160), height: usedHeight)
        } else if messages.isEmpty {
            usedHeight = ceil(emptyLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            emptyLabel.frame = CGRect(x: TVMediaLayout.Spacing.md, y: 0, width: width, height: usedHeight)
        }
        scrollView.contentSize = CGSize(width: bounds.width, height: usedHeight)
        // Insets belong to the scrolling content; the viewport still reaches every edge.
        scrollView.contentOffset = CGPoint(x: 0, y: max(-scrollView.contentInset.top, usedHeight - bounds.height + scrollView.contentInset.bottom))
    }
}

@MainActor private final class PlaybackChatScrollView: UIScrollView {
    override var canBecomeFocused: Bool { false }
}
#endif
