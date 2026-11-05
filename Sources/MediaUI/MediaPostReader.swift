import SwiftUI

public enum MediaPostReaderMetrics {
    public static let sectionSpacing: CGFloat = 24
    public static let articleSpacing: CGFloat = 12
    public static let maximumContentWidth: CGFloat = 820
    public static let attachmentSize = CGSize(width: 560, height: 420)
    public static let commentAttachmentSize = CGSize(width: 240, height: 180)
    #if os(tvOS)
    public static let inset: CGFloat = 40
    public static let commentsHeading: Font = MediaLayout.subsectionTitle
    #else
    public static let inset: CGFloat = 24
    public static let commentsHeading: Font = .title3.bold()
    #endif
}

public struct MediaPostReaderContent<Content: View>: View {
    private let horizontalInset: CGFloat
    private let content: Content

    public init(horizontalInset: CGFloat = MediaPostReaderMetrics.inset, @ViewBuilder content: () -> Content) {
        self.horizontalInset = horizontalInset
        self.content = content()
    }

    public var body: some View {
        LazyVStack(alignment: .leading, spacing: MediaPostReaderMetrics.sectionSpacing) {
            content
        }
        .frame(maxWidth: MediaPostReaderMetrics.maximumContentWidth, alignment: .leading)
        .padding(.horizontal, horizontalInset)
        .padding(.vertical, MediaPostReaderMetrics.inset)
        .frame(maxWidth: .infinity)
    }
}

#if !os(tvOS)
public struct MediaPostReaderSheet<Content: View>: View {
    private let surface: Color
    private let identifier: String
    private let closeIdentifier: String
    private let close: () -> Void
    private let content: Content

    public init(surface: Color, identifier: String, closeIdentifier: String,
                close: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.surface = surface
        self.identifier = identifier
        self.closeIdentifier = closeIdentifier
        self.close = close
        self.content = content()
    }

    public var body: some View {
        ScrollView { content }
            .accessibilityIdentifier(identifier)
            .background { surface.ignoresSafeArea() }
            .preferredColorScheme(.dark)
            .navigationTitle("")
            #if os(macOS)
            .ignoresSafeArea(.container, edges: .vertical)
            .overlay(alignment: .topTrailing) {
                MacGlassCloseButton(identifier: closeIdentifier, action: close).padding(16)
            }
            .frame(minWidth: 640, minHeight: 640)
            #else
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            #endif
    }
}
#endif

/// Byline and reading order shared by post cards and full articles.
public struct MediaPostByline<Publication: View>: View {
    private let author: String
    private let avatar: URL?
    private let surface: Color
    private let publication: Publication
    @ScaledMetric(relativeTo: .body) private var avatarSize = MediaPostCardMetrics.avatarSize

    public init(author: String, avatar: URL?, surface: Color, @ViewBuilder publication: () -> Publication) {
        self.author = author
        self.avatar = avatar
        self.surface = surface
        self.publication = publication()
    }

    public var body: some View {
        HStack(spacing: 8) {
            surface.overlay {
                MediaLoadingArtwork(url: avatar) {
                    Image(systemName: "person.crop.circle").foregroundStyle(.secondary)
                }
            }
            .frame(width: avatarSize, height: avatarSize).clipShape(Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: MediaPostCardMetrics.bylineSpacing) {
                Text(verbatim: author).font(MediaLayout.cardTitle).lineLimit(1)
                publication.font(MediaLayout.captionFont).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }
}

/// Standard order inside the reading sheet: author, article, reactions, footer.
public struct MediaPostArticle<Publication: View, Content: View, Reactions: View, Footer: View>: View {
    private let byline: MediaPostByline<Publication>
    private let title: String?
    private let titleIdentifier: String
    private let content: Content
    private let reactions: Reactions
    private let footer: Footer

    public init(author: String, avatar: URL?, surface: Color, title: String? = nil, titleIdentifier: String = "media.post.title",
                @ViewBuilder publication: () -> Publication, @ViewBuilder content: () -> Content,
                @ViewBuilder reactions: () -> Reactions, @ViewBuilder footer: () -> Footer) {
        byline = MediaPostByline(author: author, avatar: avatar, surface: surface, publication: publication)
        self.title = title
        self.titleIdentifier = titleIdentifier
        self.content = content()
        self.reactions = reactions()
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MediaPostReaderMetrics.articleSpacing) {
            byline
            if let title, !title.isEmpty {
                Text(verbatim: title).font(MediaLayout.sectionTitle)
                    .accessibilityAddTraits(.isHeader).accessibilityIdentifier(titleIdentifier)
            }
            content
            reactions
            footer
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct MediaPostArticleImage: View {
    private let url: URL
    private let label: String
    private let maximumSize: CGSize

    public init(_ url: URL, label: String, maximumSize: CGSize = MediaPostReaderMetrics.attachmentSize) {
        self.url = url
        self.label = label
        self.maximumSize = maximumSize
    }

    public var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                ViewThatFits(in: [.horizontal, .vertical]) {
                    image.fixedSize()
                    image.resizable().scaledToFit()
                }
            case .failure:
                Label("이미지를 불러오지 못했어요", systemImage: "photo").foregroundStyle(.secondary)
            default:
                MediaSkeleton(label: "이미지 불러오는 중") {
                    RoundedRectangle(cornerRadius: MediaLayout.cardRadius).aspectRatio(16 / 9, contentMode: .fit)
                }
            }
        }
        .frame(maxWidth: maximumSize.width, maxHeight: maximumSize.height, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: MediaLayout.cardRadius))
        .accessibilityLabel(label)
    }
}
