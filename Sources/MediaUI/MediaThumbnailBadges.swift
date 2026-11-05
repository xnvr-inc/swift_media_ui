import SwiftUI

public enum MediaLiveBadgeMetrics {
    public static let fill = Color(red: 242 / 255, green: 60 / 255, blue: 60 / 255)
    public static let cornerRadius: CGFloat = 6
    #if os(tvOS)
    public static let height: CGFloat = 26
    public static let horizontalInset: CGFloat = 10
    public static let artworkInset = MediaCardMetrics.badgeInset
    #else
    public static let horizontalInset: CGFloat = 7
    #endif
}

public struct MediaLiveBadge: View {
    public init() {}

    public var body: some View {
        Text("LIVE")
            #if os(macOS)
            .font(.system(size: 10, weight: .heavy))
            .tracking(0.6)
            #else
            .font(MediaLayout.badgeFont.bold())
            #endif
            .foregroundStyle(.white)
            .padding(.horizontal, MediaLiveBadgeMetrics.horizontalInset)
            #if os(tvOS)
            .frame(height: MediaLiveBadgeMetrics.height)
            #else
            .padding(.vertical, 4)
            #endif
            .background(MediaLiveBadgeMetrics.fill, in: .rect(cornerRadius: MediaLiveBadgeMetrics.cornerRadius))
            .accessibilityLabel("실시간 방송")
    }
}

public struct MediaDurationBadge: View {
    private let duration: String
    private let fill: Color

    public init(_ duration: String, fill: Color = .black.opacity(0.85)) {
        self.duration = duration
        self.fill = fill
    }

    public var body: some View {
        if !duration.isEmpty {
            MediaBadge(fill: fill) {
                Text(verbatim: duration).font(MediaLayout.badgeFont.monospacedDigit())
            }
        }
    }
}

enum MediaViewerBadgeMetrics {
    static let iconSpacing: CGFloat = 3
}

public struct MediaViewerBadge: View {
    private let count: Int
    private let fill: Color

    public init(_ count: Int, fill: Color = .black.opacity(0.75)) {
        self.count = count
        self.fill = fill
    }

    public var body: some View {
        MediaBadge(fill: fill) {
            HStack(spacing: MediaViewerBadgeMetrics.iconSpacing) {
                Image(systemName: "person.fill").accessibilityHidden(true)
                Text("\(count.formatted())명")
            }
            .font(MediaLayout.badgeFont)
        }
        .accessibilityLabel("\(count.formatted())명 시청 중")
    }
}

public struct MediaClipBadge<Artwork: View>: View {
    private let fill: Color
    private let name: String
    private let artwork: Artwork
    @ScaledMetric(relativeTo: .subheadline) private var avatarDiameter = MediaLayout.clipBadgeAvatarSize

    public init(name: String, fill: Color = .black.opacity(0.72), @ViewBuilder artwork: () -> Artwork) {
        self.fill = fill
        self.name = name
        self.artwork = artwork()
    }

    public var body: some View {
        MediaBadge(fill: fill, cornerRadius: 6, horizontalPadding: 7) {
            MediaByline {
                MediaBylineAvatar(diameter: avatarDiameter) { artwork }
            } title: {
                Text(verbatim: name).font(.caption.weight(.semibold))
            }
        }
    }
}
