import SwiftUI

public struct MediaChatEntry: Identifiable {
    public let id: UUID
    public let author: String
    public let text: String

    public init(id: UUID, author: String, text: String) {
        self.id = id
        self.author = author
        self.text = text
    }
}

public enum MediaDiscussionMetrics {
    public static let chatTextSize: CGFloat = 13
    public static let chatPanelInset: CGFloat = 12
    public static let chatRowSpacing: CGFloat = 4
    public static let touchChatRowSpacing: CGFloat = 6
}

public struct MediaChatMessage: View {
    private let author: String
    private let message: String
    private let authorColor: Color
    private let textScale: CGFloat
    private let lineLimit: Int?
    private let inlineArtwork: [String: URL]

    public init(author: String, message: String, authorColor: Color, textScale: CGFloat, lineLimit: Int? = nil,
                inlineArtwork: [String: URL] = [:]) {
        self.author = author
        self.message = message
        self.authorColor = authorColor
        self.textScale = textScale
        self.lineLimit = lineLimit
        self.inlineArtwork = inlineArtwork
    }

    public var body: some View {
        var attributed = AttributedString(author)
        attributed.font = .system(size: MediaDiscussionMetrics.chatTextSize * textScale, weight: .semibold)
        attributed.foregroundColor = authorColor
        attributed += AttributedString("  " + message)
        return MediaInlineArtworkText(attributed, catalog: inlineArtwork, size: 18 * textScale)
            .font(.system(size: MediaDiscussionMetrics.chatTextSize * textScale))
            .foregroundStyle(.white)
            .lineLimit(lineLimit)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The avatar and body slots allow links and reply actions to retain native semantics.
public struct MediaCommentLayout<Avatar: View, Content: View>: View {
    private let avatar: Avatar
    private let content: Content

    public init(@ViewBuilder avatar: () -> Avatar, @ViewBuilder content: () -> Content) {
        self.avatar = avatar()
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar.frame(width: MediaLayout.readingAvatarSize, height: MediaLayout.readingAvatarSize).clipShape(Circle())
            VStack(alignment: .leading, spacing: 8) { content }
        }
    }
}

/// A service supplies the badges and their colors; the date always comes first.
public struct MediaCommentBadge: Identifiable {
    public let label: String
    public let symbol: String
    public let tint: Color
    public var id: String { symbol }

    public init(_ label: String, symbol: String, tint: Color = .secondary) {
        self.label = label
        self.symbol = symbol
        self.tint = tint
    }
}

public struct MediaCommentByline<Author: View, Timestamp: View>: View {
    private let badges: [MediaCommentBadge]
    private let author: Author
    private let timestamp: Timestamp

    public init(badges: [MediaCommentBadge] = [], @ViewBuilder author: () -> Author,
                @ViewBuilder timestamp: () -> Timestamp) {
        self.badges = badges
        self.author = author()
        self.timestamp = timestamp()
    }

    public var body: some View {
        #if os(tvOS)
        VStack(alignment: .leading, spacing: 2) { author.lineLimit(1); metadata }
        #else
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            author.lineLimit(1)
            metadata.layoutPriority(1)
        }
        #endif
    }

    private var metadata: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            timestamp.lineLimit(1)
            if !badges.isEmpty { MediaCommentBadgeRow(badges) }
        }
        .font(MediaLayout.captionFont)
    }
}


public struct MediaCommentBadgeRow: View {
    private let badges: [MediaCommentBadge]

    public init(_ badges: [MediaCommentBadge]) { self.badges = badges }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            ForEach(badges) { badge in
                Image(systemName: badge.symbol)
                    .foregroundStyle(badge.tint)
                    .fixedSize()
                    .help(badge.label)
                    .accessibilityLabel(badge.label)
            }
        }
        .font(MediaLayout.captionFont)
    }
}

public struct MediaCommentActionRow<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View { HStack(spacing: 16) { content } }
}

public struct MediaCommentActionLabel: View {
    private let symbol: String
    private let count: String
    private let interactive: Bool

    public init(_ symbol: String, count: String, interactive: Bool = true) {
        self.symbol = symbol
        self.count = count
        self.interactive = interactive
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            if !count.isEmpty { Text(verbatim: count).bold().monospacedDigit() }
        }
        #if os(tvOS)
        .font(MediaLayout.captionFont)
        .fixedSize(horizontal: true, vertical: false)
        #elseif os(iOS)
        .frame(minWidth: interactive ? MediaControlMetrics.touchTarget : nil,
               minHeight: interactive ? MediaControlMetrics.touchTarget : nil, alignment: .topLeading)
        #endif
        .contentShape(Rectangle())
    }
}

/// The counters flank the same native like button in each post reader.
public struct MediaPostReactions<Like: View>: View {
    private let views: String?
    private let comments: String?
    private let like: Like

    public init(views: String?, comments: String?, @ViewBuilder like: () -> Like) {
        self.views = views
        self.comments = comments
        self.like = like()
    }

    public var body: some View {
        MediaCommentActionRow {
            if let views, !views.isEmpty {
                MediaCommentActionLabel("eye", count: views, interactive: false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("조회").accessibilityValue(views)
            }
            like
            if let comments, !comments.isEmpty {
                MediaCommentActionLabel("bubble", count: comments, interactive: false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("댓글").accessibilityValue(comments)
            }
        }
        .font(MediaLayout.captionFont)
        .foregroundStyle(.secondary)
    }
}

public struct MediaPostLikeButton: View {
    private let count: String
    private let isLiked: Bool
    private let action: () -> Void

    public init(count: String?, isLiked: Bool, action: @escaping () -> Void) {
        self.count = MediaLikeCount.display(count)
        self.isLiked = isLiked
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MediaCommentActionLabel(isLiked ? "hand.thumbsup.fill" : "hand.thumbsup", count: count)
        }
        .accessibilityLabel(isLiked ? "게시글 좋아요 취소" : "게시글 좋아요")
        .accessibilityValue(count)
        .accessibilityAddTraits(isLiked ? .isSelected : [])
    }
}

public extension View {
    #if os(tvOS)
    func mediaCommentActionStyle(palette: MediaTVControlPalette) -> some View {
        buttonStyle(MediaTVPanelButtonStyle(palette: palette, capsule: true)).focusEffectDisabled()
    }
    #else
    func mediaCommentActionStyle() -> some View { buttonStyle(.plain) }
    #endif
}
