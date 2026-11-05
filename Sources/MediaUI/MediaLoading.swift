import SwiftUI

public enum MediaShimmerDefaults {
    public static let baseOpacity = 0.09
    public static let highlightOpacity = 0.16
    public static let duration = MediaSkeletonMetrics.sweepDuration
}

/// A single moving highlight, masked by the geometry of the pending content.
public struct MediaSkeleton<Mask: View>: View {
    var label: String? = nil
    var base = Color.primary.opacity(MediaShimmerDefaults.baseOpacity)
    var highlight = Color.primary.opacity(MediaShimmerDefaults.highlightOpacity)
    @ViewBuilder let mask: () -> Mask

    public init(label: String? = nil, base: Color = .primary.opacity(MediaShimmerDefaults.baseOpacity),
                highlight: Color = .primary.opacity(MediaShimmerDefaults.highlightOpacity),
                @ViewBuilder mask: @escaping () -> Mask) {
        self.label = label
        self.base = base
        self.highlight = highlight
        self.mask = mask
    }

    public var body: some View {
        mask().mediaSkeleton(label, fill: base, highlight: highlight)
    }
}

public struct MediaLoadingStatus: View {
    let label: String
    var compact = false

    public init(label: String, compact: Bool = false) {
        self.label = label
        self.compact = compact
    }

    public var body: some View {
        VStack(spacing: 8) {
            MediaSkeleton { Capsule().frame(width: compact ? 40 : 120, height: compact ? 6 : 10) }
            if !compact {
                Text(label).font(.callout).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .allowsHitTesting(false)
    }
}

public enum MediaSkeletonCard: Equatable {
    case media, portrait, category, profile, post

    public var aspectRatio: CGFloat {
        switch self {
        case .category: 300.0 / 401
        case .portrait: MediaCardMetrics.portraitAspect
        default: MediaCardMetrics.landscapeAspect
        }
    }

    @ViewBuilder public func mask(corner: CGFloat) -> some View {
        switch self {
        case .profile:
            VStack(spacing: 10) {
                Circle().frame(width: MediaLayout.avatarSize, height: MediaLayout.avatarSize)
                Capsule().frame(width: 68, height: 10)
            }.frame(maxWidth: .infinity, minHeight: 132, alignment: .top)
        case .post:
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().frame(width: 22, height: 22)
                    Capsule().frame(width: 76, height: 10)
                }
                Capsule().frame(height: 12)
                Capsule().frame(maxWidth: 140).frame(height: 9)
            }.padding(12)
        case .media, .portrait, .category:
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: corner).aspectRatio(aspectRatio, contentMode: .fit)
                Capsule().frame(maxWidth: 160).frame(height: 13)
                Capsule().frame(maxWidth: 96).frame(height: 10)
            }
        }
    }
}

public struct MediaLoadingGrid: View {
    let label: String
    let columns: [GridItem]
    var card: MediaSkeletonCard = .media
    var count = 6
    var spacing: CGFloat = 24
    let corner: CGFloat
    let fill: Color
    let highlight: Color

    public init(label: String, columns: [GridItem], card: MediaSkeletonCard = .media,
                count: Int = 6, spacing: CGFloat = MediaLayout.rowGap, corner: CGFloat = MediaLayout.cardRadius,
                fill: Color = .primary.opacity(MediaShimmerDefaults.baseOpacity),
                highlight: Color = .primary.opacity(MediaShimmerDefaults.highlightOpacity)) {
        self.label = label
        self.columns = columns
        self.card = card
        self.count = count
        self.spacing = spacing
        self.corner = corner
        self.fill = fill
        self.highlight = highlight
    }

    public var body: some View {
        MediaSkeleton(label: label, base: fill, highlight: highlight) {
            // All shapes in the loading grid share one highlight.
            LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                ForEach(0..<count, id: \.self) { _ in card.mask(corner: corner) }
            }
        }
    }
}

/// Keep failure and missing-artwork placeholders distinct from a pending image.
public struct MediaLoadingArtwork<Placeholder: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    @ViewBuilder let placeholder: () -> Placeholder

    public init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder
    }

    public var body: some View {
        MediaAsyncArtwork(url: url, contentMode: contentMode) {
            MediaSkeleton { Rectangle() }
        } placeholder: {
            placeholder()
        }
    }
}
