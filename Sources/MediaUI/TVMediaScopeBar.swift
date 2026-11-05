#if os(tvOS)
import UIKit

/// The category rail used by both UIKit headers and SwiftUI pages on Apple TV.
open class TVMediaScopeBar: UIScrollView {
    private let row = UIStackView()
    private let surface: UIColor
    private let selectedSurface: UIColor
    private var titles: [String] = []
    private var buttons: [TVMediaScopeButton] = []
    private var selected = 0
    private var select: ((Int) -> Void)?
    private var needsSelectionReveal = false

    public var hasFocusedOption: Bool { buttons.contains(where: \.isFocused) }
    public var selectedOption: UIView? { buttons.indices.contains(selected) ? buttons[selected] : nil }

    public init(horizontalInset: CGFloat = 0, surface: UIColor, selectedSurface: UIColor) {
        self.surface = surface
        self.selectedSurface = selectedSurface
        super.init(frame: .zero)
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        row.alignment = .center
        row.spacing = TVMediaLayout.Spacing.xs
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentLayoutGuide.leadingAnchor, constant: horizontalInset),
            row.trailingAnchor.constraint(equalTo: contentLayoutGuide.trailingAnchor, constant: -horizontalInset),
            row.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: frameLayoutGuide.heightAnchor),
        ])
    }

    public required init?(coder: NSCoder) { fatalError() }
    open override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: TVMediaLayout.Browse.pillRowHeight)
    }

    open override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let selectedOption { return [selectedOption] }
        return super.preferredFocusEnvironments
    }

    public func configure(titles: [String], selected: Int, label: String? = nil, identifier: String? = nil,
                          images: [UIImage?] = [], select: @escaping (Int) -> Void) {
        needsSelectionReveal = needsSelectionReveal || self.selected != selected || self.titles != titles
        self.selected = selected
        self.select = select
        accessibilityLabel = label
        accessibilityIdentifier = identifier
        if self.titles != titles {
            self.titles = titles
            buttons.forEach { $0.removeFromSuperview() }
            buttons = titles.indices.map { index in
                let button = TVMediaScopeButton(surface: surface, selectedSurface: selectedSurface)
                button.setContentCompressionResistancePriority(.required, for: .horizontal)
                button.addAction(UIAction { [weak self] _ in self?.select?(index) }, for: .primaryActionTriggered)
                row.addArrangedSubview(button)
                return button
            }
        }
        for (index, button) in buttons.enumerated() {
            button.accessibilityIdentifier = identifier.map { "\($0).\(index)" }
            button.configure(title: titles[index], selected: index == selected,
                             image: images.indices.contains(index) ? images[index] : nil)
        }
        if needsSelectionReveal { setNeedsLayout() }
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        guard needsSelectionReveal, bounds.width > 0, let selectedOption, !selectedOption.bounds.isEmpty else { return }
        needsSelectionReveal = false
        if !hasFocusedOption { reveal(selectedOption) }
    }

    open override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        guard let button = context.nextFocusedView as? TVMediaScopeButton, buttons.contains(button) else { return }
        coordinator.addCoordinatedAnimations { self.reveal(button) }
    }

    private func reveal(_ option: UIView) {
        let frame = option.convert(option.bounds, to: self)
        guard frame.width <= bounds.width, !bounds.contains(frame) else { return }
        scrollRectToVisible(frame, animated: false)
    }
}

/// A pill whose focus enlargement is drawn within its measured control bounds.
public final class TVMediaScopeButton: UIButton {
    private static let focusScale: CGFloat = 1.05
    private static let pillHeight: CGFloat = 40
    private static let horizontalPadding: CGFloat = 16
    private let pill = UIView()
    private let caption = UILabel()
    private let icon = UIImageView()
    private let surface: UIColor
    private let selectedSurface: UIColor

    public init(surface: UIColor, selectedSurface: UIColor) {
        self.surface = surface
        self.selectedSurface = selectedSurface
        super.init(frame: .zero)
        isAccessibilityElement = true
        pill.isUserInteractionEnabled = false
        pill.layer.cornerRadius = Self.pillHeight / 2
        pill.translatesAutoresizingMaskIntoConstraints = false
        caption.font = TVMediaLayout.Typography.subcaption
        caption.lineBreakMode = .byTruncatingTail
        icon.contentMode = .scaleAspectFit
        icon.isHidden = true
        let content = UIStackView(arrangedSubviews: [icon, caption])
        content.alignment = .center
        content.spacing = TVMediaLayout.Spacing.xs
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pill)
        pill.addSubview(content)
        let iconWidth = icon.widthAnchor.constraint(equalToConstant: MediaControlMetrics.choiceIconSize)
        iconWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 1 / Self.focusScale),
            pill.heightAnchor.constraint(equalToConstant: Self.pillHeight),
            content.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: Self.horizontalPadding),
            content.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -Self.horizontalPadding),
            content.centerYAnchor.constraint(equalTo: pill.centerYAnchor),
            iconWidth,
            icon.heightAnchor.constraint(equalToConstant: MediaControlMetrics.choiceIconSize),
        ])
    }

    public required init?(coder: NSCoder) { fatalError() }

    public override var intrinsicContentSize: CGSize {
        let iconSpace = icon.isHidden ? 0 : MediaControlMetrics.choiceIconSize + TVMediaLayout.Spacing.xs
        let width = caption.intrinsicContentSize.width + iconSpace + 2 * Self.horizontalPadding
        return CGSize(width: ceil(width * Self.focusScale), height: ceil(Self.pillHeight * Self.focusScale))
    }

    public override var isHighlighted: Bool {
        didSet { pill.alpha = isHighlighted ? 0.72 : 1 }
    }

    public func configure(title: String, selected: Bool, image: UIImage? = nil) {
        if caption.text != title || icon.image != image {
            caption.text = title
            icon.image = image?.withRenderingMode(.alwaysTemplate)
            icon.isHidden = image == nil
            invalidateIntrinsicContentSize()
        }
        accessibilityLabel = title
        accessibilityTraits = selected ? [.button, .selected] : [.button]
        isSelected = selected
        updateAppearance()
    }

    public override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { self.updateAppearance() }
    }

    private func updateAppearance() {
        let text: UIColor = isFocused ? .black : .white
        caption.textColor = text
        icon.tintColor = text
        pill.backgroundColor = isFocused ? .white : isSelected ? selectedSurface : surface
        pill.transform = isFocused && !UIAccessibility.isReduceMotionEnabled
            ? CGAffineTransform(scaleX: Self.focusScale, y: Self.focusScale) : .identity
    }
}
#endif
