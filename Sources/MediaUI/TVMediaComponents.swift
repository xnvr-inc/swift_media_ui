#if os(tvOS)
import UIKit

// MARK: - LIVE 배지

public final class TVMediaViewerBadge: UIView {
    private let iconView = UIImageView(image: UIImage(systemName: "person.fill"))
    private let countLabel = UILabel()

    public init(fill: UIColor, text: UIColor = .white) {
        super.init(frame: .zero)
        backgroundColor = fill
        layer.cornerRadius = TVMediaLayout.Corner.badge
        layer.masksToBounds = true
        isAccessibilityElement = true

        iconView.tintColor = text
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        countLabel.font = TVMediaLayout.Typography.badge
        countLabel.textColor = text
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),
            countLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: MediaViewerBadgeMetrics.iconSpacing),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
        ])
    }

    public required init?(coder: NSCoder) { fatalError() }

    public func configure(count: Int) {
        isHidden = count <= 0
        countLabel.text = count.koreanCount()
        accessibilityLabel = "시청자 \(count)명"
    }
}

// MARK: - 포커스 효과 유틸
//
// 카드 포커스는 스케일과 테두리만 사용한다. 그림자 글로우는 인접 콘텐츠와
// 상단 스크롤 엣지에 색 번짐을 만들기 때문에 사용하지 않는다.

@MainActor public struct TVMediaFocusEffect {
    public let accent: UIColor
    public let surface: UIColor
    public let focusedSurface: UIColor

    public init(accent: UIColor, surface: UIColor, focusedSurface: UIColor) {
        self.accent = accent
        self.surface = surface
        self.focusedSurface = focusedSurface
    }

    public func applyBrowse(to cell: UICollectionViewCell, artwork: UIView, focused: Bool) {
        cell.transform = focused ? CGAffineTransform(scaleX: 1.04, y: 1.04) : .identity
        cell.contentView.backgroundColor = .clear
        cell.contentView.layer.borderWidth = 0
        cell.layer.shadowOpacity = 0
        artwork.layer.borderWidth = focused ? 3 : 0
        artwork.layer.borderColor = accent.cgColor
    }

    /// 카드 표준 포커스 — 확대와 테두리
    public func apply(to cell: UICollectionViewCell, focused: Bool) {
        if focused {
            cell.transform = CGAffineTransform(scaleX: 1.10, y: 1.10)
            cell.contentView.backgroundColor = focusedSurface
            cell.contentView.layer.borderColor = accent.cgColor
            cell.contentView.layer.borderWidth = 4
            cell.layer.shadowOpacity = 0
            cell.layer.shadowRadius = 0
        } else {
            cell.transform = .identity
            cell.contentView.backgroundColor = surface
            cell.contentView.layer.borderWidth = 0
            cell.layer.shadowOpacity = 0
        }
    }

    /// 오프라인/비활성 카드도 같은 포커스 색상을 사용한다.
    public func applyOffline(to cell: UICollectionViewCell, focused: Bool) {
        if focused {
            cell.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
            cell.contentView.layer.borderColor = accent.cgColor
            cell.contentView.layer.borderWidth = 4
            cell.layer.shadowOpacity = 0
            cell.layer.shadowRadius = 0
        } else {
            cell.transform = .identity
            cell.contentView.layer.borderWidth = 0
            cell.layer.shadowOpacity = 0
        }
    }

    /// 보더 포커스 — 검색 진입 / 최근 검색어 칩 같은 비-카드 요소용
    public func applyBorder(to view: UIView, focused: Bool) {
        if focused {
            view.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            view.layer.borderColor = accent.cgColor
            view.layer.borderWidth = 3
            view.layer.shadowOpacity = 0
            view.layer.shadowRadius = 0
        } else {
            view.transform = .identity
            view.layer.borderWidth = 0
            view.layer.shadowOpacity = 0
        }
    }
}

// MARK: - 헤더 컨테이너 (재사용 가능)

/// 화면 최상단 헤더 — 큰 타이틀 + 작은 서브타이틀.
/// LIVE / MY / 탐색 화면에서 공통으로 사용.
public final class TVMediaSectionHeader: UIView {

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    public init(title: String, subtitle: String, titleFont: UIFont = TVMediaLayout.Typography.hero,
                text: UIColor = .white, secondaryText: UIColor = .lightGray) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.textColor = text
        titleLabel.font = titleFont
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        subtitleLabel.text = subtitle
        subtitleLabel.textColor = secondaryText
        subtitleLabel.font = TVMediaLayout.Typography.subhead
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    public required init?(coder: NSCoder) { fatalError() }

    public func setTitle(_ text: String) {
        titleLabel.text = text
    }

    public func setSubtitle(_ text: String) {
        subtitleLabel.text = text
    }
}

// MARK: - 토스트 (하단 슬라이드 인)

/// 화면 하단에 짧게 나타났다 사라지는 메시지.
/// 모달 alert를 대체. 사용처: 오프라인 BJ 선택, 재생 실패 등.
public final class TVMediaToast: UIView {

    private let label = UILabel()

    public static func show(in parent: UIView, message: String, duration: TimeInterval = 2.0, fill: UIColor, text: UIColor = .white) {
        let toast = TVMediaToast(message: message, fill: fill, text: text)
        parent.addSubview(toast)

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: parent.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: parent.safeAreaLayoutGuide.bottomAnchor, constant: -60),
        ])

        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 30)
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            toast.alpha = 1
            toast.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: .curveEaseIn) {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 30)
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }

    private init(message: String, fill: UIColor, text: UIColor) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        backgroundColor = fill
        layer.cornerRadius = TVMediaLayout.Corner.button
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 16

        label.text = message
        label.textColor = text
        label.font = TVMediaLayout.Typography.body
        label.textAlignment = .center
        // v4.4: 19+ 인증 안내 같은 멀티라인 메시지 지원
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 36),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -36),
        ])
    }

    public required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Loading skeletons

public class TVMediaShimmer: UIView {
    public override class var layerClass: AnyClass { CAGradientLayer.self }
    private var gradient: CAGradientLayer { layer as! CAGradientLayer }
    private let silhouette = CAShapeLayer()

    public init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        layer.mask = silhouette
        NotificationCenter.default.addObserver(self, selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        updateShimmer()
    }

    public required init?(coder: NSCoder) { fatalError() }

    public override var isHidden: Bool { didSet { updateShimmer() } }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        updateShimmer()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        silhouette.frame = bounds
        silhouette.path = maskPath()
        CATransaction.commit()
    }

    public func maskPath() -> CGPath {
        UIBezierPath(roundedRect: bounds, cornerRadius: min(TVMediaLayout.Browse.thumbnailCorner, bounds.height / 2)).cgPath
    }

    @objc private func reduceMotionChanged(_ notification: Notification) { updateShimmer() }

    private func updateShimmer() {
        let base = UIColor.white.withAlphaComponent(MediaShimmerDefaults.baseOpacity).cgColor
        guard window != nil, !isHidden, !UIAccessibility.isReduceMotionEnabled else {
            gradient.removeAnimation(forKey: "shimmer")
            gradient.colors = [base, base, base]
            return
        }
        guard gradient.animation(forKey: "shimmer") == nil else { return }
        let highlightOpacity = MediaShimmerDefaults.baseOpacity + (1 - MediaShimmerDefaults.baseOpacity) * MediaShimmerDefaults.highlightOpacity
        let highlight = UIColor.white.withAlphaComponent(highlightOpacity).cgColor
        gradient.colors = [base, highlight, base]
        gradient.locations = [0, 0.35, 0.7]
        let sweep = CABasicAnimation(keyPath: "locations")
        sweep.fromValue = [-0.7, -0.35, 0]
        sweep.toValue = [1, 1.35, 1.7]
        sweep.duration = MediaShimmerDefaults.duration
        sweep.repeatCount = .infinity
        gradient.add(sweep, forKey: "shimmer")
    }
}

/// Collection backgrounds reserve space for the shapes of the next cards without adding focus targets.
public final class TVMediaLoadingSkeleton: TVMediaShimmer {
    public var card: MediaSkeletonCard = .media { didSet { setNeedsLayout() } }
    public var topInset: CGFloat = 0 { didSet { if oldValue != topInset { setNeedsLayout() } } }
    public var sideInset = TVMediaLayout.Layout.contentSideMargin { didSet { setNeedsLayout() } }
    public var rows = 2 { didSet { setNeedsLayout() } }

    public override func maskPath() -> CGPath {
        let path = UIBezierPath()
        let available = bounds.width - 2 * sideInset
        guard available > 0 else { return path.cgPath }
        let columns: Int
        let minimum: CGFloat
        switch card {
        case .category: (columns, minimum) = (8, 176)
        case .media: (columns, minimum) = (MediaLayout.videoColumnCount, 0)
        case .portrait: (columns, minimum) = (MediaLayout.portraitColumnCount, 0)
        case .profile: (columns, minimum) = (8, 216)
        case .post: (columns, minimum) = (3, 440)
        }
        let width = card == .media
            ? TVMediaLayout.Browse.mediaWidth(in: bounds.width, sideInset: sideInset)
            : TVMediaGridWidth.fitting(available + 2 * TVMediaLayout.Layout.contentSideMargin, columns: columns, minimumWidth: minimum)
        let count = min(columns, Int((available + TVMediaLayout.Spacing.md) / (width + TVMediaLayout.Spacing.md)))
        let thumbnailHeight = width / card.aspectRatio
        let height: CGFloat
        switch card {
        case .post: height = 180
        case .profile: height = 220
        case .media: height = TVMediaLayout.Browse.mediaSize(width: width).height
        case .portrait: height = width / MediaCardMetrics.portraitAspect + MediaLayout.browseMetadataHeight
        case .category: height = TVMediaLayout.Browse.categorySize(width: width).height
        }
        for row in 0..<rows {
            let y = topInset + CGFloat(row) * (height + TVMediaLayout.Spacing.lg)
            for column in 0..<count {
                let x = sideInset + CGFloat(column) * (width + TVMediaLayout.Spacing.md)
                switch card {
                case .profile:
                    let diameter = min(width, TVMediaLayout.Browse.profileDiameter)
                    path.append(UIBezierPath(ovalIn: CGRect(x: x + (width - diameter) / 2, y: y, width: diameter, height: diameter)))
                    path.addBar(x: x + width * 0.2, y: y + diameter + 16, width: width * 0.6)
                case .post:
                    path.append(UIBezierPath(ovalIn: CGRect(x: x, y: y, width: 32, height: 32)))
                    path.addBar(x: x + 44, y: y + 8, width: width * 0.3)
                    path.addBar(x: x, y: y + 52, width: width * 0.85)
                    path.addBar(x: x, y: y + 84, width: width * 0.6)
                case .media, .portrait, .category:
                    path.append(UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: thumbnailHeight),
                                             cornerRadius: TVMediaLayout.Browse.thumbnailCorner))
                    path.addBar(x: x, y: y + thumbnailHeight + 16, width: width * 0.72)
                    path.addBar(x: x, y: y + thumbnailHeight + 46, width: width * 0.45)
                }
            }
        }
        return path.cgPath
    }
}

private extension UIBezierPath {
    func addBar(x: CGFloat, y: CGFloat, width: CGFloat) {
        append(UIBezierPath(roundedRect: CGRect(x: x, y: y, width: width, height: 14), cornerRadius: 7))
    }
}

// MARK: - 공용 오류 상태 뷰 (v5 신규)

/// 데이터 로드 실패 시 화면 중앙에 표시 — 아이콘 + 안내 문구(+ 보조 문구) + 포커스 가능한 "다시 시도" 버튼.
/// HOME / 탐색 / MY 탭에서 공통 사용. 레이아웃은 MyViewController.showEmptyState()와 동일 구조.
/// VC에서 centerX/centerY로 배치하고, preferredFocusEnvironments로 버튼에 포커스를 보낸다.
public final class TVMediaErrorState: UIView {

    /// "다시 시도" 선택 시 호출. 연타 방지를 위해 첫 선택 시 버튼이 비활성화된다.
    public var onRetry: (() -> Void)?

    private let retryButton: ErrorRetryButton

    // MyViewController.showEmptyState()와 동일 확정값 — DS 토큰 없음 (디자인 명세 §4-4)
    private static let errorIconSize: CGFloat = 80
    private static let errorContainerMaxWidth: CGFloat = 720
    private static let errorTitleSubtitleGap: CGFloat = 8

    public init(accent: UIColor, icon: String, title: String, subtitle: String? = nil,
                text: UIColor = .white, secondaryText: UIColor = .lightGray, iconTint: UIColor = .gray) {
        var btnConfig = UIButton.Configuration.filled()
        btnConfig.baseBackgroundColor = accent
        btnConfig.baseForegroundColor = text
        btnConfig.contentInsets = TVMediaLayout.ButtonInsets.cta
        btnConfig.cornerStyle = .fixed
        btnConfig.background.cornerRadius = TVMediaLayout.Corner.button
        btnConfig.attributedTitle = AttributedString("다시 시도", attributes: AttributeContainer([
            .font: TVMediaLayout.Typography.cardTitle
        ]))
        retryButton = ErrorRetryButton(configuration: btnConfig)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = iconTint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = text
        titleLabel.font = TVMediaLayout.Typography.subsection
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        // 포커스 보더가 버튼의 둥근 배경을 따라가도록
        retryButton.layer.cornerRadius = TVMediaLayout.Corner.button
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.addTarget(self, action: #selector(retryTapped), for: .primaryActionTriggered)
        addSubview(retryButton)

        // 서브타이틀은 MY 탭처럼 조치 안내가 필요한 화면만 사용
        var buttonTopAnchor = titleLabel.bottomAnchor
        if let subtitle = subtitle {
            let subtitleLabel = UILabel()
            subtitleLabel.text = subtitle
            subtitleLabel.textColor = secondaryText
            subtitleLabel.font = TVMediaLayout.Typography.body
            subtitleLabel.textAlignment = .center
            subtitleLabel.numberOfLines = 2
            subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(subtitleLabel)
            NSLayoutConstraint.activate([
                subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Self.errorTitleSubtitleGap),
                subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
                subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
            buttonTopAnchor = subtitleLabel.bottomAnchor
        }

        NSLayoutConstraint.activate([
            widthAnchor.constraint(lessThanOrEqualToConstant: Self.errorContainerMaxWidth),

            iconView.topAnchor.constraint(equalTo: topAnchor),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Self.errorIconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.errorIconSize),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: TVMediaLayout.Spacing.md),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            retryButton.topAnchor.constraint(equalTo: buttonTopAnchor, constant: TVMediaLayout.Spacing.lg),
            retryButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            retryButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    public required init?(coder: NSCoder) { fatalError() }

    /// 오류 뷰 표시 직후 포커스가 "다시 시도" 버튼으로 가도록
    public override var preferredFocusEnvironments: [UIFocusEnvironment] { [retryButton] }

    @objc private func retryTapped() {
        // 연타 방지 — 재시도 시 뷰 자체가 제거/재표시되므로 재활성화는 불필요
        retryButton.isEnabled = false
        onRetry?()
    }
}

/// TVMediaErrorState 전용 "다시 시도" 버튼 — 포커스 시 TVMediaFocusEffect.applyBorder 적용
private final class ErrorRetryButton: UIButton {
    override var canBecomeFocused: Bool { true }

    override func didUpdateFocus(in context: UIFocusUpdateContext,
                                with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { [weak self] in
            guard let self = self else { return }
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
            self.layer.borderColor = UIColor.white.cgColor
            self.layer.borderWidth = self.isFocused ? 3 : 0
        }
    }
}
public extension Int {
    /// 시청자수 한국식 포맷: 12345 → "1.2만", 980 → "980"
    func koreanCount() -> String {
        if self >= 10000 {
            return String(format: "%.1f만", Double(self) / 10000)
        }
        return "\(self)"
    }
}
// MARK: - 그리드 카드 너비

public enum TVMediaGridWidth {
    public static func fitting(_ availableWidth: CGFloat, columns: Int, minimumWidth: CGFloat) -> CGFloat {
        var count = columns
        while count > 1 {
            let width = (availableWidth - 2 * TVMediaLayout.Layout.contentSideMargin
                         - CGFloat(count - 1) * TVMediaLayout.Spacing.md) / CGFloat(count)
            if width >= minimumWidth { return floor(width) }
            count -= 1
        }
        return floor(max(0, availableWidth - 2 * TVMediaLayout.Layout.contentSideMargin))
    }
}
#endif
