import SwiftUI

public enum MediaChannelHeaderMetrics {
    public static func avatarSize(wide: Bool) -> CGFloat { wide ? 140 : 76 }
    public static func columnGap(wide: Bool) -> CGFloat { wide ? 28 : 16 }
    public static let informationGap: CGFloat = 12
    public static let sectionGap: CGFloat = 24
    static let coverAspectRatio: CGFloat = 6.2
    #if os(tvOS)
    static let accessoryWidth: CGFloat = 72
    static let accessoryPaintedHeight: CGFloat = 38
    #else
    static let accessoryWidth: CGFloat = 54
    static let accessoryPaintedHeight: CGFloat = 28
    #endif
}

/// Channel navigation already has a name and often a profile image. This layout
/// lets known content stay in place while the remaining details load.
public struct MediaChannelHeader<Avatar: View, Information: View>: View {
    let wide: Bool
    let avatar: Avatar
    let information: Information

    public init(wide: Bool, @ViewBuilder avatar: () -> Avatar, @ViewBuilder information: () -> Information) {
        self.wide = wide
        self.avatar = avatar()
        self.information = information()
    }

    public var body: some View {
        let size = MediaChannelHeaderMetrics.avatarSize(wide: wide)
        HStack(alignment: .top, spacing: MediaChannelHeaderMetrics.columnGap(wide: wide)) {
            avatar.frame(width: size, height: size).clipShape(Circle())
            VStack(alignment: .leading, spacing: MediaChannelHeaderMetrics.informationGap) { information }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct MediaChannelLoadingMetadata: View {
    let fill: Color
    public init(fill: Color) { self.fill = fill }

    public var body: some View {
        MediaSkeleton(base: fill) {
            VStack(alignment: .leading, spacing: MediaChannelHeaderMetrics.informationGap) {
                Capsule().frame(maxWidth: 208).frame(height: MediaLayout.metadataSizeForChannelLoading)
                Capsule().frame(maxWidth: 340).frame(height: MediaLayout.metadataSizeForChannelLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityHidden(true)
    }
}

/// Mirror the scope bar and first home shelf at the same width as real cards.
public struct MediaChannelLoadingShelf: View {
    let label: String
    let cardWidth: CGFloat
    let cardGap: CGFloat
    let fill: Color
    let pageInset: CGFloat

    public init(label: String, cardWidth: CGFloat, cardGap: CGFloat, fill: Color, pageInset: CGFloat = MediaLayout.pageInset) {
        self.label = label
        self.cardWidth = cardWidth
        self.cardGap = cardGap
        self.fill = fill
        self.pageInset = pageInset
    }

    public var body: some View {
        MediaSkeleton(label: label, base: fill, highlight: .white.opacity(0.12)) {
            VStack(alignment: .leading, spacing: MediaChannelHeaderMetrics.sectionGap) {
                scope
                VStack(alignment: .leading, spacing: 16) {
                    Capsule().frame(width: sectionWidth, height: sectionHeight)
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: cardGap) {
                            ForEach(0..<5) { index in card(index).frame(width: cardWidth) }
                        }
                        .padding(.vertical, 8)
                    }
                    .scrollIndicators(.hidden)
                    .contentMargins(.horizontal, pageInset, for: .scrollContent)
                    .padding(.horizontal, -pageInset)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .allowsHitTesting(false)
    }

    private var scope: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach([0.76, 1.0, 0.93, 0.9, 1.14], id: \.self) { factor in
                    Capsule().frame(width: scopeWidth * factor, height: scopeHeight)
                }
            }
            #if os(tvOS)
            .padding(.vertical, 8)
            #else
            .frame(minHeight: MediaControlMetrics.touchTarget)
            #endif
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, pageInset, for: .scrollContent)
        .padding(.horizontal, -pageInset)
    }

    private func card(_ index: Int) -> some View {
        MediaCardStack {
            RoundedRectangle(cornerRadius: artworkRadius)
                .aspectRatio(MediaCardMetrics.landscapeAspect, contentMode: .fit)
        } metadata: {
            VStack(alignment: .leading, spacing: MediaCardMetrics.metadataSpacing) {
                Capsule().frame(width: cardWidth * (index.isMultiple(of: 2) ? 0.83 : 0.68), height: titleHeight)
                Capsule().frame(width: cardWidth * 0.51, height: titleHeight)
                Capsule().frame(width: cardWidth * 0.37, height: MediaLayout.metadataSizeForChannelLoading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    #if os(tvOS)
    private let scopeWidth: CGFloat = 96
    private let scopeHeight: CGFloat = 48
    private let titleHeight: CGFloat = 20
    private let sectionHeight: CGFloat = 25
    private let sectionWidth: CGFloat = 180
    private let artworkRadius = MediaLayout.browseArtworkRadius
    #else
    private let scopeWidth: CGFloat = 68
    private let scopeHeight: CGFloat = 30
    private let titleHeight: CGFloat = 12
    private let sectionHeight: CGFloat = 16
    private let sectionWidth: CGFloat = 104
    private let artworkRadius = MediaLayout.cardRadius
    #endif
}

private extension MediaLayout {
    static var metadataSizeForChannelLoading: CGFloat {
        #if os(tvOS)
        17
        #else
        9
        #endif
    }
}

/// Optional artwork and one identity row shared by the channel and station pages.
public struct MediaChannelHero<Title: View, Information: View, Accessory: View>: View {
    private let cover: URL?
    private let avatar: URL?
    private let surface: Color
    private let wide: Bool
    private let loading: Bool
    private let fill: Color
    private let title: Title
    private let information: Information
    private let accessory: Accessory

    public init(cover: URL?, avatar: URL?, surface: Color, wide: Bool, loading: Bool = false,
                skeletonFill: Color = .white.opacity(0.08), @ViewBuilder title: () -> Title,
                @ViewBuilder information: () -> Information, @ViewBuilder accessory: () -> Accessory) {
        self.cover = cover
        self.avatar = avatar
        self.surface = surface
        self.wide = wide
        self.loading = loading
        self.fill = skeletonFill
        self.title = title()
        self.information = information()
        self.accessory = accessory()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: MediaChannelHeaderMetrics.sectionGap) {
            if let cover {
                artwork(cover, symbol: "photo")
                    .aspectRatio(MediaChannelHeaderMetrics.coverAspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: MediaLayout.cardRadius))
                    .accessibilityIdentifier("media.channel.cover")
            }
            MediaChannelHeader(wide: wide) {
                if avatar == nil && loading { MediaSkeleton(base: fill) { Circle() } }
                else { artwork(avatar, symbol: "person.crop.circle") }
            } information: {
                title.font(MediaChannelHeaderMetrics.titleFont(wide: wide))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, MediaChannelHeaderMetrics.accessoryWidth + MediaChannelHeaderMetrics.informationGap)
                    .overlay(alignment: .trailing) { accessory }
                information
                if loading { MediaChannelLoadingMetadata(fill: fill) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func artwork(_ url: URL?, symbol: String) -> some View {
        surface.overlay {
            MediaLoadingArtwork(url: url) {
                Image(systemName: symbol).foregroundStyle(.secondary)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}

public extension MediaChannelHeaderMetrics {
    static func titleFont(wide: Bool) -> Font { wide ? MediaLayout.titleFont : MediaLayout.sectionTitle }
}

/// Same star pill for a subscription or a favorite. Services own the action and state.
public struct MediaChannelStarButton: View {
    private let selected: Bool
    private let label: String
    private let action: () -> Void

    public init(selected: Bool, label: String, action: @escaping () -> Void) {
        self.selected = selected
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: selected ? "star.fill" : "star")
                .font(MediaLayout.metadataFont.weight(.semibold))
                .foregroundStyle(selected ? Color.yellow : Color.white)
                .frame(width: MediaChannelHeaderMetrics.accessoryWidth, height: MediaChannelHeaderMetrics.accessoryPaintedHeight)
                .background(.white.opacity(0.12), in: Capsule())
                .frame(minHeight: MediaControlMetrics.touchTarget)
                .contentShape(Rectangle())
        }
        #if os(tvOS)
        .buttonStyle(TVMediaSubtleIconButtonStyle()).focusEffectDisabled()
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

}
