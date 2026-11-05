#if os(tvOS)
import SwiftUI
import UIKit

public extension MediaLiveBadgeMetrics {
    static var uiFill: UIColor { UIColor(fill) }
}

/// UIKit counterpart of MediaLiveBadge with the same label, typography and geometry.
public final class TVMediaLiveBadge: UIView {
    private let titleLabel = UILabel()

    public init() {
        super.init(frame: .zero)
        backgroundColor = MediaLiveBadgeMetrics.uiFill
        layer.cornerRadius = MediaLiveBadgeMetrics.cornerRadius
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityLabel = "실시간 방송"

        titleLabel.text = "LIVE"
        titleLabel.font = TVMediaLayout.Typography.badge
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        let inset = MediaLiveBadgeMetrics.horizontalInset
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
        ])
    }

    public required init?(coder: NSCoder) { nil }
}
#endif
