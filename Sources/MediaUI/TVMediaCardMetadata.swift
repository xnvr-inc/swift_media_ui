#if os(tvOS)
import UIKit

/// A thumbnail and its channel photo are independent remote targets.
open class TVPlayableMediaCell: UICollectionViewCell {
    public let playbackButton = UIButton(type: .custom)
    private var play: (() -> Void)?

    open override var canBecomeFocused: Bool { false }
    open override var preferredFocusEnvironments: [UIFocusEnvironment] { [playbackButton] }

    public func installPlaybackButton(over artwork: UIView) {
        playbackButton.translatesAutoresizingMaskIntoConstraints = false
        playbackButton.addAction(UIAction { [weak self] _ in self?.play?() }, for: .primaryActionTriggered)
        contentView.addSubview(playbackButton)
        NSLayoutConstraint.activate([
            playbackButton.leadingAnchor.constraint(equalTo: artwork.leadingAnchor),
            playbackButton.trailingAnchor.constraint(equalTo: artwork.trailingAnchor),
            playbackButton.topAnchor.constraint(equalTo: artwork.topAnchor),
            playbackButton.bottomAnchor.constraint(equalTo: artwork.bottomAnchor),
        ])
    }

    public func setPlaybackAction(title: String, action: @escaping () -> Void) {
        playbackButton.accessibilityLabel = title
        play = action
    }

    open override func prepareForReuse() {
        super.prepareForReuse()
        play = nil
        playbackButton.accessibilityLabel = nil
        playbackButton.accessibilityIdentifier = nil
    }
}

private final class TVMediaAvatarButton: UIButton {
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.layer.borderWidth = self.isFocused ? 3 : 0
        }
    }
}

public final class TVMediaCardMetadata: UIStackView {
    public let artwork = UIImageView()
    private let artworkButton = TVMediaAvatarButton(type: .custom)
    private let artworkFocusGuide = UIFocusGuide()
    private var openChannel: (() -> Void)?
    private let titleLabel = UILabel()
    private let bylineLabel = UILabel()
    private let titleFont: UIFont
    private var artworkDimensions: [NSLayoutConstraint] = []

    public var title: String? {
        didSet {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = MediaCardMetrics.titleLineSpacing
            paragraph.lineBreakMode = .byTruncatingTail
            titleLabel.attributedText = title.map {
                NSAttributedString(string: $0, attributes: [.font: titleFont, .paragraphStyle: paragraph])
            }
        }
    }

    public init(titleFont: UIFont, titleColor: UIColor, bylineFont: UIFont, bylineColor: UIColor,
                focusOutline: UIColor) {
        self.titleFont = titleFont
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .top
        spacing = MediaCardMetrics.avatarToTextSpacing

        let diameter = MediaCardMetrics.avatarDiameter
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = diameter / 2
        artwork.tintColor = bylineColor
        artwork.isAccessibilityElement = false
        artwork.translatesAutoresizingMaskIntoConstraints = false
        artworkButton.layer.cornerRadius = diameter / 2
        artworkButton.layer.borderColor = focusOutline.cgColor
        artworkButton.addAction(UIAction { [weak self] _ in self?.openChannel?() }, for: .primaryActionTriggered)
        artworkButton.addSubview(artwork)
        addArrangedSubview(artworkButton)
        NSLayoutConstraint.activate([
            artwork.leadingAnchor.constraint(equalTo: artworkButton.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: artworkButton.trailingAnchor),
            artwork.topAnchor.constraint(equalTo: artworkButton.topAnchor),
            artwork.bottomAnchor.constraint(equalTo: artworkButton.bottomAnchor),
        ])
        artworkDimensions = [
            artworkButton.widthAnchor.constraint(equalToConstant: diameter),
            artworkButton.heightAnchor.constraint(equalToConstant: diameter),
        ]
        NSLayoutConstraint.activate(artworkDimensions)

        titleLabel.font = titleFont
        titleLabel.textColor = titleColor
        titleLabel.numberOfLines = MediaCardMetrics.titleLineLimit
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        bylineLabel.font = bylineFont
        bylineLabel.textColor = bylineColor
        bylineLabel.lineBreakMode = .byTruncatingTail
        bylineLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let text = UIStackView(arrangedSubviews: [titleLabel, bylineLabel])
        text.axis = .vertical
        text.spacing = MediaCardMetrics.metadataSpacing
        addArrangedSubview(text)

        addLayoutGuide(artworkFocusGuide)
        artworkFocusGuide.preferredFocusEnvironments = [artworkButton]
        artworkFocusGuide.isEnabled = false
        NSLayoutConstraint.activate([
            artworkFocusGuide.leadingAnchor.constraint(equalTo: artworkButton.trailingAnchor),
            artworkFocusGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
            artworkFocusGuide.topAnchor.constraint(equalTo: artworkButton.topAnchor),
            artworkFocusGuide.bottomAnchor.constraint(equalTo: artworkButton.bottomAnchor),
        ])
    }

    public required init(coder: NSCoder) { fatalError() }

    public func setByline(_ text: String, showsArtwork: Bool) {
        bylineLabel.text = text
        if !showsArtwork { NSLayoutConstraint.deactivate(artworkDimensions) }
        artworkButton.isHidden = !showsArtwork
        if showsArtwork { NSLayoutConstraint.activate(artworkDimensions) }
    }

    public func setArtworkAction(label: String, identifier: String, action: (() -> Void)?) {
        openChannel = action
        artworkButton.accessibilityLabel = label
        artworkButton.accessibilityIdentifier = identifier
        artworkButton.isEnabled = action != nil
        artworkFocusGuide.isEnabled = action != nil
        artworkButton.isAccessibilityElement = action != nil
    }
}

open class TVMediaBylineView: UIStackView {
    public let artwork = UIImageView()
    private let name = UILabel()
    private var artworkDimensions: [NSLayoutConstraint] = []

    public init(font: UIFont, textColor: UIColor, artworkTint: UIColor,
                avatarDiameter: CGFloat = MediaCardMetrics.inlineAvatarDiameter) {
        super.init(frame: .zero)
        axis = .horizontal
        alignment = .center
        spacing = MediaCardMetrics.bylineSpacing
        artwork.contentMode = .scaleAspectFill
        artwork.clipsToBounds = true
        artwork.layer.cornerRadius = avatarDiameter / 2
        artwork.tintColor = artworkTint
        artwork.isAccessibilityElement = false
        artwork.translatesAutoresizingMaskIntoConstraints = false
        name.font = font
        name.textColor = textColor
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addArrangedSubview(artwork)
        addArrangedSubview(name)
        artworkDimensions = [
            artwork.widthAnchor.constraint(equalToConstant: avatarDiameter),
            artwork.heightAnchor.constraint(equalToConstant: avatarDiameter),
        ]
        NSLayoutConstraint.activate(artworkDimensions)
    }

    public required init(coder: NSCoder) { fatalError() }

    public func setContent(_ text: String, showsArtwork: Bool) {
        name.text = text
        if !showsArtwork { NSLayoutConstraint.deactivate(artworkDimensions) }
        artwork.isHidden = !showsArtwork
        if showsArtwork { NSLayoutConstraint.activate(artworkDimensions) }
    }
}
#endif
