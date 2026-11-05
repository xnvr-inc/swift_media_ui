#if os(tvOS)
import UIKit

/// A stable video canvas. Only the tile is focusable in the overview.
@MainActor open class TVMediaPlaybackTile: UIControl {
    private let surface: UIView
    private let selectedColor: UIColor
    private let focusedColor: UIColor
    public var captionText: String? {
        get { caption.text }
        set { caption.text = newValue }
    }
    public var onFocus: (() -> Void)?
    public var onOpen: (() -> Void)?
    /// Handles a held Select press on a focused overview tile.
    public var onLongPress: (() -> Void)? {
        didSet { selectHold.isEnabled = isOverview && onLongPress != nil }
    }
    public var isFocusEnabled = true
    public var isOverview = false {
        didSet {
            surface.isUserInteractionEnabled = !isOverview
            caption.isHidden = !isOverview || !showsCaption
            isAccessibilityElement = isOverview
            layer.cornerRadius = isOverview ? TVMediaLayout.Corner.card : 0
            selectTap.isEnabled = isOverview
            selectHold.isEnabled = isOverview && onLongPress != nil
        }
    }
    public var showsCaption = true { didSet { caption.isHidden = !isOverview || !showsCaption } }
    public var referenceSize: CGSize = .zero { didSet { setNeedsLayout() } }
    private let canvas = UIView()
    private let caption = UILabel()
    private lazy var selectTap: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(tapSelect))
        recognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        recognizer.allowedTouchTypes = []
        recognizer.require(toFail: selectHold)
        recognizer.isEnabled = false
        return recognizer
    }()
    private lazy var selectHold: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(holdSelect(_:)))
        recognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        recognizer.allowedTouchTypes = []
        recognizer.isEnabled = false
        return recognizer
    }()

    public init(surface: UIView, selectedColor: UIColor, focusedColor: UIColor = .white,
                captionFill: UIColor = .black.withAlphaComponent(0.65)) {
        self.surface = surface
        self.selectedColor = selectedColor
        self.focusedColor = focusedColor
        super.init(frame: .zero)
        backgroundColor = .black
        clipsToBounds = true
        addSubview(canvas)
        canvas.addSubview(surface)
        caption.font = TVMediaLayout.Typography.cardTitle
        caption.textColor = focusedColor
        caption.backgroundColor = captionFill
        caption.layer.cornerRadius = TVMediaLayout.Corner.badge
        caption.clipsToBounds = true
        caption.textAlignment = .center
        caption.isUserInteractionEnabled = false
        addSubview(caption)
        addTarget(self, action: #selector(open), for: .primaryActionTriggered)
        addGestureRecognizer(selectHold)
        addGestureRecognizer(selectTap)
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    open override var canBecomeFocused: Bool { isOverview && isFocusEnabled }

    open override var isSelected: Bool { didSet { updateBorder() } }

    open override func layoutSubviews() {
        super.layoutSubviews()
        let size = referenceSize.width > 0 ? referenceSize : bounds.size
        guard size.width > 0, size.height > 0 else { return }
        // Keep the existing full-size preroll, chat and AVKit geometry inside each video.
        canvas.bounds = CGRect(origin: .zero, size: size)
        canvas.center = CGPoint(x: bounds.midX, y: bounds.midY)
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        canvas.transform = CGAffineTransform(scaleX: scale, y: scale)
        surface.frame = canvas.bounds
        let inset = min(TVMediaLayout.Spacing.sm, bounds.width * 0.05)
        let height = min(40, max(20, bounds.height * 0.15))
        caption.font = .systemFont(ofSize: min(22, max(14, height * 0.55)), weight: .semibold)
        caption.frame = CGRect(x: inset, y: bounds.height - height - inset,
                               width: max(0, bounds.width - inset * 2), height: height)
    }

    open override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations({ self.updateBorder() }, completion: nil)
        if context.nextFocusedView === self { onFocus?() }
    }

    private func updateBorder() {
        layer.borderWidth = isOverview && (isSelected || isFocused) ? MediaMultiviewMetrics.focusBorderWidth : 0
        layer.borderColor = (isFocused ? focusedColor : selectedColor).cgColor
        accessibilityTraits = isSelected ? [.button, .selected] : [.button]
    }

    @objc private func open() { onOpen?() }

    @objc private func tapSelect() {
        guard isFocused else { return }
        sendActions(for: .primaryActionTriggered)
    }

    @objc private func holdSelect(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, isFocused else { return }
        onLongPress?()
    }
}
#endif
