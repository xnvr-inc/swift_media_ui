import SwiftUI

public struct MediaArtworkFrame<Artwork: View, Badges: View>: View {
    @Environment(\.mediaCardInShelf) private var inShelf
    private let ratio: CGFloat
    private let cornerRadius: CGFloat
    private let artwork: Artwork
    private let badges: Badges

    public init(ratio: CGFloat, cornerRadius: CGFloat,
                @ViewBuilder artwork: () -> Artwork, @ViewBuilder badges: () -> Badges) {
        self.ratio = ratio
        self.cornerRadius = cornerRadius
        self.artwork = artwork()
        self.badges = badges()
    }

    public var body: some View {
        Color.clear.aspectRatio(ratio, contentMode: .fit)
            .fixedSize(horizontal: false, vertical: inShelf)
            .overlay { artwork }
            .overlay { badges }
            .clipShape(.rect(cornerRadius: cornerRadius))
    }
}

public struct MediaArtworkBadges<TopLeading: View, BottomTrailing: View>: View {
    private let topInset: CGFloat
    private let bottomInset: CGFloat
    private let topLeading: TopLeading
    private let bottomTrailing: BottomTrailing

    public init(topInset: CGFloat = MediaCardMetrics.badgeInset, bottomInset: CGFloat = MediaCardMetrics.badgeInset,
                @ViewBuilder topLeading: () -> TopLeading, @ViewBuilder bottomTrailing: () -> BottomTrailing) {
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.topLeading = topLeading()
        self.bottomTrailing = bottomTrailing()
    }

    public var body: some View {
        Color.clear
            .overlay(alignment: .topLeading) { topLeading.padding(topInset) }
            .overlay(alignment: .bottomTrailing) { bottomTrailing.padding(bottomInset) }
    }
}

public struct MediaBadge<BadgeLabel: View>: View {
    private let fill: Color
    private let cornerRadius: CGFloat
    private let horizontalPadding: CGFloat
    private let label: BadgeLabel

    public init(fill: Color, cornerRadius: CGFloat = 4, horizontalPadding: CGFloat = 6,
                @ViewBuilder label: () -> BadgeLabel) {
        self.fill = fill
        self.cornerRadius = cornerRadius
        self.horizontalPadding = horizontalPadding
        self.label = label()
    }

    public var body: some View {
        label
            .foregroundStyle(.white)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 4)
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}

public struct MediaAsyncArtwork<Loading: View, Placeholder: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let loading: () -> Loading
    private let placeholder: () -> Placeholder

    public init(url: URL?, contentMode: ContentMode = .fill,
                @ViewBuilder loading: @escaping () -> Loading, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.loading = loading
        self.placeholder = placeholder
    }

    public var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: contentMode)
            } else if url != nil, case .empty = phase {
                loading()
            } else {
                placeholder()
            }
        }
    }
}


public struct MediaCardStack<Artwork: View, Metadata: View>: View {
    private let artwork: Artwork
    private let metadata: Metadata

    public init(@ViewBuilder artwork: () -> Artwork, @ViewBuilder metadata: () -> Metadata) {
        self.artwork = artwork()
        self.metadata = metadata()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MediaCardMetrics.artworkToMetadata) {
            artwork
            #if os(tvOS)
            metadata.frame(minHeight: MediaLayout.browseMetadataHeight - MediaCardMetrics.artworkToMetadata,
                           alignment: .topLeading)
            #else
            metadata
            #endif
        }
    }
}
