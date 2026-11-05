import MediaUI
import SwiftUI

struct DemoHeading: View {
    let title: String
    let subtitle: String

    init(_ title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(MediaLayout.titleFont).accessibilityAddTraits(.isHeader)
            Text(subtitle).font(MediaLayout.metadataFont).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DemoScrollPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MediaLayout.sectionSpacing) { content }
                .padding(.horizontal, MediaLayout.pageInset)
                #if os(macOS)
                .padding(.top, MediaLayout.browseTopInset + 44)
                #else
                .padding(.top, MediaLayout.browseTopInset)
                #endif
                .padding(.bottom, MediaLayout.sectionSpacing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DemoVideoSection: View {
    let title: String?
    let videos: [DemoVideo]
    let portrait: Bool
    let open: (DemoVideo) -> Void

    init(_ title: String?, videos: [DemoVideo], portrait: Bool = false, open: @escaping (DemoVideo) -> Void) {
        self.title = title
        self.videos = videos
        self.portrait = portrait
        self.open = open
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MediaLayout.sectionContentSpacing) {
            if let title {
                Text(title).font(MediaLayout.sectionTitle).accessibilityAddTraits(.isHeader)
            }
            if videos.isEmpty {
                Text("Nothing here yet.").font(MediaLayout.metadataFont).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: portrait ? MediaLayout.portraitColumns : MediaLayout.videoColumns,
                          alignment: .leading, spacing: MediaLayout.rowGap) {
                    ForEach(videos) { video in
                        DemoVideoCard(video: video, portrait: portrait && video.isShort, open: { open(video) })
                    }
                }
            }
        }
    }
}

/// The production card stack, thumbnail badges and channel metadata use fixture artwork here.
private struct DemoVideoCard: View {
    let video: DemoVideo
    let portrait: Bool
    let open: () -> Void
    #if os(tvOS)
    @FocusState private var focused: Bool
    #endif

    var body: some View {
        #if os(tvOS)
        MediaCardStack {
            Button(action: open) { artwork }
                .buttonStyle(.plain)
                .focused($focused)
                .tvMediaPostCardFocus(focused, outline: .white)
                .accessibilityLabel(video.title)
                .accessibilityIdentifier("demo.play.\(video.id)")
        } metadata: {
            metadata {
                NavigationLink(value: DemoRoute.channel(video.channel)) {
                    TVMediaCardAvatarLabel { avatarArtwork }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(video.channel.name)")
            }
        }
        #else
        Button(action: open) {
            MediaCardStack { artwork } metadata: {
                metadata { MediaCardAvatar { avatarArtwork } }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("demo.play.\(video.id)")
        .mediaCardAvatarAction {
            NavigationLink(value: DemoRoute.channel(video.channel)) { MediaCardAvatarHitArea() }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(video.channel.name)")
        }
        #endif
    }

    private var artwork: some View {
        MediaArtworkFrame(
            ratio: portrait ? MediaCardMetrics.portraitAspect : MediaCardMetrics.landscapeAspect,
            cornerRadius: MediaLayout.cardRadius
        ) {
            video.artwork.resizable().aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } badges: {
            MediaArtworkBadges {
                if video.isLive { MediaLiveBadge() }
            } bottomTrailing: {
                if video.isLive { MediaViewerBadge(video.viewers) }
                else { MediaDurationBadge(video.duration) }
            }
        }
    }

    private var avatarArtwork: some View {
        video.channel.image.resizable().aspectRatio(contentMode: .fill)
    }

    private func metadata<Avatar: View>(@ViewBuilder avatar: () -> Avatar) -> some View {
        MediaCardMetadata(avatar: avatar) {
            MediaCardTitle(video.title, font: MediaLayout.cardTitle)
        } details: {
            MediaCardByline(video.channel.name, font: MediaLayout.metadataFont)
            MediaCardByline(video.metadata, font: MediaLayout.metadataFont).foregroundStyle(.secondary)
        }
    }
}

struct DemoChannelAvatar: View {
    let channel: DemoChannel

    var body: some View {
        MediaCardAvatar { channel.image.resizable().aspectRatio(contentMode: .fill) }
            .accessibilityHidden(true)
    }
}

struct DemoSearch: View {
    let videos: [DemoVideo]
    let open: (DemoVideo) -> Void
    @State private var query = ""

    private var results: [DemoVideo] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if term.isEmpty { return videos }
        return videos.filter {
            [$0.title, $0.channel.name, $0.channel.category].contains { $0.localizedCaseInsensitiveContains(term) }
        }
    }

    var body: some View {
        DemoScrollPage {
            DemoHeading("Search", subtitle: "Find videos, channels and categories")
            TextField("Search sample content", text: $query)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                .accessibilityIdentifier("demo.search.field")
            if results.isEmpty {
                MediaStatusView(title: "No results", message: "Try a different search.", symbol: "magnifyingglass")
            } else {
                DemoVideoSection(query.isEmpty ? "Browse videos" : "Results", videos: results, open: open)
            }
        }
        .navigationTitle("Search")
    }
}

struct DemoChannelPage: View {
    let channel: DemoChannel
    let mode: DemoMode
    let followed: Bool
    let toggleFollowed: () -> Void
    let open: (DemoVideo) -> Void
    @State private var scope = "Home"
    @State private var following: Bool?

    private var scopes: [String] {
        mode == .video ? ["Home", "Videos", "Shorts", "Posts"] : ["Home", "Replays", "Clips", "Posts"]
    }
    private var channelVideos: [DemoVideo] {
        let videos = DemoCatalog.all.filter { $0.channel == channel }
        switch scope {
        case "Videos": return videos.filter { !$0.isShort && !$0.isLive }
        case "Replays": return videos.filter { $0.kind == .replay }
        case "Shorts", "Clips": return videos.filter(\.isShort)
        default: return videos
        }
    }

    var body: some View {
        DemoScrollPage {
            MediaArtworkFrame(ratio: 4, cornerRadius: MediaLayout.cardRadius) {
                channel.image.resizable().aspectRatio(contentMode: .fill).clipped()
            } badges: { EmptyView() }
            MediaChannelHeader(wide: true) {
                DemoChannelAvatar(channel: channel)
            } information: {
                HStack {
                    DemoHeading(channel.name, subtitle: channel.category)
                    MediaChannelStarButton(
                        selected: following ?? followed, label: mode == .video ? "Subscribe" : "Follow"
                    ) {
                        following = !(following ?? followed)
                        toggleFollowed()
                    }
                }
            }
            MediaScopePicker(items: scopes, selection: scope, title: { $0 },
                             horizontalInset: MediaLayout.pageInset, surface: .white.opacity(0.12),
                             selectedSurface: mode.tint) { scope = $0 }
            if scope == "Posts" || scope == "Home" { DemoCommunityCard(channel: channel) }
            if scope != "Posts" {
                DemoVideoSection(scope == "Home" ? "Latest" : scope, videos: channelVideos,
                                 portrait: scope == "Shorts" || scope == "Clips", open: open)
            }
        }
        .navigationTitle(channel.name)
    }
}

struct DemoPostPage: View {
    let channel: DemoChannel
    let liked: Bool
    let toggleLike: () -> Void
    @State private var reacted: Bool?

    var body: some View {
        DemoScrollPage {
            DemoHeading("Behind the scenes", subtitle: "\(channel.name) · 2 hours ago")
            Text("What should we play next? Tell us your favorite moment from the latest session.")
                .font(.body)
            Button {
                reacted = !(reacted ?? liked)
                toggleLike()
            } label: {
                Label((reacted ?? liked) ? "129" : "128", systemImage: (reacted ?? liked) ? "hand.thumbsup.fill" : "hand.thumbsup")
            }
            .accessibilityLabel((reacted ?? liked) ? "Remove like" : "Like post")
            DemoDiscussion(live: false)
        }
        .navigationTitle("Post")
    }
}

struct DemoDiscussion: View {
    let live: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: MediaLayout.sectionContentSpacing) {
            Text(live ? "Live chat" : "Comments").font(MediaLayout.sectionTitle).accessibilityAddTraits(.isHeader)
            ForEach(Array(DemoCatalog.messages.enumerated()), id: \.offset) { _, message in
                if live {
                    MediaChatMessage(author: message.0, message: message.1,
                                     authorColor: .cyan, textScale: 1)
                } else {
                    MediaCommentLayout {
                        Image(systemName: "person.crop.circle.fill").foregroundStyle(.secondary)
                    } content: {
                        VStack(alignment: .leading, spacing: 4) {
                            MediaCommentByline { Text(message.0).font(.headline) } timestamp: {
                                Text("Today").font(.caption).foregroundStyle(.secondary)
                            }
                            Text(message.1).font(.body)
                        }
                    }
                }
            }
        }
    }
}
