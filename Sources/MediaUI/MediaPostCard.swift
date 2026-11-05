import SwiftUI
#if os(macOS)
import AppKit
#elseif os(tvOS)
import UIKit
#endif

/// The display values a post feed supplies. Opening a post and loading its
/// full contents stay with the app.
public struct MediaPostCardData {
    public let author: String
    public let avatar: URL?
    public let title: String
    public let body: String
    public let images: [URL]
    public let attachmentTitle: String?
    public let hasPoll: Bool
    public let isNotice: Bool
    public let isPinned: Bool
    public let views: String?
    public let likes: String
    public let isLiked: Bool
    public let comments: String?

    public init(author: String, avatar: URL?, title: String = "", body: String,
                images: [URL] = [], attachmentTitle: String? = nil, hasPoll: Bool = false,
                isNotice: Bool = false, isPinned: Bool = false,
                views: String? = nil, likes: String? = nil, isLiked: Bool = false, comments: String? = nil) {
        self.author = author
        self.avatar = avatar
        self.title = title
        self.body = body
        self.images = images
        self.attachmentTitle = attachmentTitle
        self.hasPoll = hasPoll
        self.isNotice = isNotice
        self.isPinned = isPinned
        self.views = views.flatMap { $0.isEmpty ? nil : $0 }
        self.likes = MediaLikeCount.display(likes)
        self.isLiked = isLiked
        self.comments = comments.flatMap { $0.isEmpty ? nil : $0 }
    }
}

public enum MediaPostCardMetrics {
    public static let cornerRadius = MediaLayout.cardRadius
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 12
    static let avatarSize: CGFloat = 32
    static let bylineSpacing: CGFloat = 2
    static let excerptLines = 3
    static let noticeIconScale: CGFloat = 0.72
    static let previewAspect: CGFloat = 16.0 / 9

    #if os(macOS) || os(tvOS)
    /// Native collection layouts use this estimate before creating visible
    /// cells. Preview geometry is independent of the downloaded image size.
    public static func estimatedHeight(for post: MediaPostCardData, width: CGFloat, showsPublication: Bool) -> CGFloat {
        #if os(macOS)
        let heading = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let body = NSFont.systemFont(ofSize: 12)
        let caption = NSFont.preferredFont(forTextStyle: .caption1)
        #else
        let heading = UIFont.systemFont(ofSize: MediaLayout.cardTitleSize, weight: .semibold)
        let body = UIFont.systemFont(ofSize: MediaLayout.metadataSize)
        let caption = UIFont.systemFont(ofSize: 18, weight: .medium)
        #endif
        let innerWidth = max(1, width - 2 * inset)
        let publicationHeight = showsPublication ? bylineSpacing + textHeight("0", font: caption, width: innerWidth, lines: 1) : 0
        var height = 2 * inset + max(avatarSize, textHeight("0", font: heading, width: innerWidth, lines: 1) + publicationHeight)
        if !post.title.isEmpty || post.isNotice || post.isPinned {
            let marks = CGFloat((post.isNotice ? 1 : 0) + (post.isPinned ? 1 : 0))
            height += spacing + textHeight(post.title, font: heading, width: innerWidth - marks * (heading.pointSize + 8), lines: 2)
        }
        if !post.body.isEmpty { height += spacing + textHeight(post.body, font: body, width: innerWidth, lines: excerptLines) }
        if !post.images.isEmpty { height += spacing + innerWidth / previewAspect }
        if let attachment = post.attachmentTitle {
            height += spacing + textHeight(attachment, font: body, width: innerWidth - body.pointSize - 8, lines: 2)
        }
        if post.hasPoll { height += spacing + textHeight("0", font: body, width: innerWidth, lines: 1) }
        height += spacing + textHeight("0", font: caption, width: innerWidth, lines: 1)
        return ceil(height)
    }

    #if os(macOS)
    private typealias NativeFont = NSFont
    #else
    private typealias NativeFont = UIFont
    #endif

    private static func textHeight(_ text: String, font: NativeFont, width: CGFloat, lines: Int) -> CGFloat {
        #if os(macOS)
        let line = ceil(font.ascender - font.descender + font.leading)
        #else
        let line = ceil(font.lineHeight)
        #endif
        let measured = (text as NSString).boundingRect(
            with: CGSize(width: max(1, width), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil
        ).height
        return min(CGFloat(lines) * line, max(line, ceil(measured)))
    }
    #endif
}

/// The same card content for SwiftUI buttons and native focusable TV cells.
/// The publication view can supply a live timestamp and accessibility detail.
public struct MediaPostCard<Publication: View>: View {
    private let post: MediaPostCardData
    private let surface: Color
    private let likedTint: Color
    private let publication: Publication

    public init(_ post: MediaPostCardData, surface: Color, likedTint: Color = .red,
                @ViewBuilder publication: () -> Publication) {
        self.post = post
        self.surface = surface
        self.likedTint = likedTint
        self.publication = publication()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: MediaPostCardMetrics.cornerRadius)
        VStack(alignment: .leading, spacing: MediaPostCardMetrics.spacing) {
            MediaPostByline(author: post.author, avatar: post.avatar, surface: surface) { publication }
            if !post.title.isEmpty || post.isNotice || post.isPinned { title }
            if !post.body.isEmpty {
                Text(verbatim: post.body).lineLimit(MediaPostCardMetrics.excerptLines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let image = post.images.first { preview(image) }
            if let attachment = post.attachmentTitle {
                Label(attachment, systemImage: "paperclip").lineLimit(2)
            }
            if post.hasPoll { Label("투표", systemImage: "chart.bar.xaxis") }
            metrics
        }
        .font(MediaLayout.metadataFont)
        .multilineTextAlignment(.leading)
        .padding(MediaPostCardMetrics.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: shape)
        .contentShape(shape)
    }

    private var title: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(verbatim: post.title).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            if post.isNotice {
                Image(systemName: "megaphone.fill")
                    .scaleEffect(MediaPostCardMetrics.noticeIconScale)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("공지")
            }
            if post.isPinned { Image(systemName: "pin.fill").foregroundStyle(.yellow).accessibilityLabel("고정 게시글") }
        }
        .font(MediaLayout.cardTitle)
    }

    private func preview(_ url: URL) -> some View {
        artwork(url, symbol: "photo")
            .aspectRatio(MediaPostCardMetrics.previewAspect, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: MediaPostCardMetrics.cornerRadius))
            .overlay(alignment: .bottomTrailing) {
                if post.images.count > 1 {
                    Label("\(post.images.count)", systemImage: "photo.on.rectangle")
                        .font(MediaLayout.badgeFont)
                        .padding(8)
                        .background(.black.opacity(0.85), in: Capsule())
                        .padding(8)
                        .accessibilityLabel("이미지 \(post.images.count)장")
                }
            }
    }

    private func artwork(_ url: URL?, symbol: String) -> some View {
        surface.overlay {
            MediaLoadingArtwork(url: url) {
                Image(systemName: symbol).foregroundStyle(.secondary)
            }
        }.clipped().accessibilityHidden(true)
    }

    private var metrics: some View {
        HStack(spacing: 16) {
            if let views = post.views { metric(views, label: "조회", icon: "eye") }
            metric(post.likes, label: "좋아요", icon: post.isLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                .foregroundStyle(post.isLiked ? likedTint : .primary)
            if let comments = post.comments { metric(comments, label: "댓글", icon: "bubble") }
        }
        .font(MediaLayout.captionFont)
    }

    private func metric(_ value: String, label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(verbatim: value)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

#if os(tvOS)
public enum TVMediaPostCardFocusMetrics {
    public static let scale: CGFloat = 1.04
    public static let outlineWidth: CGFloat = 3
    public static let duration: TimeInterval = 0.18
}

/// Paint focus over the actual card. No wrapper padding is added to a grid cell.
public struct TVMediaPostCardButtonStyle: ButtonStyle {
    private let outline: Color
    public init(outline: Color) { self.outline = outline }

    public func makeBody(configuration: Configuration) -> some View {
        FocusLabel(label: configuration.label, outline: outline)
    }

    private struct FocusLabel: View {
        @Environment(\.isFocused) private var focused
        let label: Configuration.Label
        let outline: Color

        var body: some View {
            label.tvMediaPostCardFocus(focused, outline: outline)
        }
    }
}

public extension View {
    func tvMediaPostCardFocus(_ focused: Bool, outline: Color) -> some View {
        modifier(TVMediaPostCardFocusAppearance(focused: focused, outline: outline))
    }
}

private struct TVMediaPostCardFocusAppearance: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let focused: Bool
    let outline: Color

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: MediaPostCardMetrics.cornerRadius)
                .strokeBorder(focused ? outline : .clear, lineWidth: TVMediaPostCardFocusMetrics.outlineWidth)
                .allowsHitTesting(false).accessibilityHidden(true)
        }
        .scaleEffect(focused && !reduceMotion ? TVMediaPostCardFocusMetrics.scale : 1)
        .animation(reduceMotion ? nil : .easeInOut(duration: TVMediaPostCardFocusMetrics.duration), value: focused)
    }
}
#endif
