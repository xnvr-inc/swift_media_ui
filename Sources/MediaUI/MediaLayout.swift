import SwiftUI

/// Platform geometry and system text roles used by native media screens.
public enum MediaLayout {
    public static var videoColumns: [GridItem] {
        #if os(tvOS)
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: columnGap, alignment: .top), count: videoColumnCount)
        #else
        adaptiveColumns(minimum: videoMinimum, maximum: videoMaximum)
        #endif
    }
    public static func videoCardWidth(in width: CGFloat) -> CGFloat {
        #if os(tvOS)
        return browseCardWidth(in: width, columns: videoColumnCount)
        #else
        let columns = max(1, floor((width + columnGap) / (videoMinimum + columnGap)))
        return min(videoMaximum, (width - (columns - 1) * columnGap) / columns)
        #endif
    }
    public static var portraitColumns: [GridItem] {
        #if os(tvOS)
        return Array(repeating: GridItem(.flexible(minimum: 0), spacing: columnGap, alignment: .top),
                     count: portraitColumnCount)
        #else
        #if os(macOS)
        let size: (CGFloat, CGFloat) = (155, 230)
        #else
        let size: (CGFloat, CGFloat) = (104, 180)
        #endif
        return [GridItem(.adaptive(minimum: size.0, maximum: size.1), spacing: 10, alignment: .top)]
        #endif
    }
    #if !os(tvOS)
    public static func adaptiveColumns(minimum: CGFloat, maximum: CGFloat = .infinity) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum, maximum: maximum), spacing: columnGap, alignment: .top)]
    }

    public static var categoryColumns: [GridItem] {
        #if os(macOS)
        adaptiveColumns(minimum: 150, maximum: 220)
        #else
        adaptiveColumns(minimum: 135, maximum: 210)
        #endif
    }

    public static var profileColumns: [GridItem] {
        #if os(macOS)
        adaptiveColumns(minimum: 130, maximum: 180)
        #else
        adaptiveColumns(minimum: 100, maximum: 160)
        #endif
    }

    public static let readingAvatarSize: CGFloat = 36
    #endif

    public static let sectionSpacing: CGFloat = 32
    public static let sectionContentSpacing: CGFloat = 16
    public static let cardContentSpacing: CGFloat = 12
    public static let auxiliaryMetadataSpacing: CGFloat = 6
    public static let clipBadgeAvatarSize: CGFloat = {
        #if os(tvOS)
        24
        #elseif os(macOS)
        14
        #else
        16
        #endif
    }()

    /// Space from the native app bar's content edge to the first browse heading.
    public static let browseTopInset: CGFloat = {
        #if os(tvOS)
        24
        #elseif os(macOS)
        32
        #else
        16
        #endif
    }()

    #if !os(tvOS)
    public static var browseInsets: EdgeInsets {
        EdgeInsets(top: browseTopInset, leading: pageInset, bottom: pageInset, trailing: pageInset)
    }
    #endif

    #if os(tvOS)
    public static let headerActionSize: CGFloat = 64
    public static let headerActionIconSize: CGFloat = 28
    public static let headerAvatarSize: CGFloat = 32
    public static let pageInset: CGFloat = 64
    public static let columnGap: CGFloat = 24
    public static let rowGap: CGFloat = 34
    public static let videoColumnCount = 3
    public static let portraitColumnCount = 5
    public static func browseCardWidth(in width: CGFloat, columns: Int) -> CGFloat {
        max(0, (width - CGFloat(columns - 1) * columnGap) / CGFloat(columns))
    }
    public static let cardRadius: CGFloat = 18
    public static let browseArtworkRadius: CGFloat = 12
    public static let browseMetadataHeight: CGFloat = 124
    public static let browseBottomInset: CGFloat = 72
    public static let avatarSize: CGFloat = 140
    public static let titleSize: CGFloat = 48
    public static let subsectionTitleSize: CGFloat = 28
    public static let cardTitleSize: CGFloat = 26
    public static let metadataSize: CGFloat = 23
    public static let readingSize: CGFloat = 24
    public static let badgeSize: CGFloat = 16
    public static let titleFont: Font = .system(size: titleSize, weight: .bold)
    public static let sectionTitle: Font = .system(size: 34, weight: .semibold)
    public static let subsectionTitle: Font = .system(size: subsectionTitleSize, weight: .semibold)
    public static let cardTitle: Font = .system(size: cardTitleSize, weight: .semibold)
    public static let metadataFont: Font = .system(size: metadataSize)
    public static let captionFont: Font = .system(size: 18, weight: .medium)
    public static let readingFont: Font = .system(size: readingSize)
    public static let readingLineSpacing: CGFloat = 5
    public static let readingAuthorFont: Font = .system(size: readingSize, weight: .semibold)
    public static let readingAvatarSize: CGFloat = 40
    public static let badgeFont: Font = .system(size: badgeSize, weight: .bold)
    public static let portraitHeadingIconSize: CGFloat = 44
    #elseif os(macOS)
    public static let toolbarHeight: CGFloat = 35
    public static let headerAvatarSize: CGFloat = 22
    public static let toolbarTitleSize: CGFloat = 16
    public static let primaryTabIconSize: CGFloat = 13
    public static let primaryTabIconSpacing: CGFloat = 3
    public static let pageInset: CGFloat = 32
    public static let columnGap: CGFloat = 20
    public static let rowGap: CGFloat = 28
    public static let videoMinimum: CGFloat = 240
    public static let videoMaximum: CGFloat = 420
    public static let cardRadius: CGFloat = 10
    public static let avatarSize: CGFloat = 88
    public static let titleFont: Font = .system(size: 36, weight: .bold)
    public static let sectionTitle: Font = .system(size: 22, weight: .semibold)
    public static let subsectionTitle: Font = .title2.bold()
    public static let cardTitle: Font = .system(size: 14, weight: .semibold)
    public static let metadataFont: Font = .system(size: 12)
    public static let captionFont: Font = .caption
    public static let badgeFont: Font = .caption.weight(.medium)
    public static let portraitHeadingIconSize: CGFloat = 28
    #else
    public static let toolbarTitle: Font = .headline
    public static let headerAvatarSize: CGFloat = 24
    public static let pageInset: CGFloat = 16
    public static let columnGap: CGFloat = 16
    public static let rowGap: CGFloat = 24
    public static let videoMinimum: CGFloat = 270
    public static let videoMaximum: CGFloat = 480
    public static let cardRadius: CGFloat = 12
    public static let avatarSize: CGFloat = 88
    public static let titleFont: Font = .largeTitle.bold()
    public static let sectionTitle: Font = .title2.bold()
    public static let subsectionTitle: Font = .headline
    public static let cardTitle: Font = .headline
    public static let metadataFont: Font = .subheadline
    public static let captionFont: Font = .caption
    public static let badgeFont: Font = .caption
    public static let portraitHeadingIconSize: CGFloat = 28
    #endif
}

public struct MediaPageTitle: View {
    private let title: String
    private let font: Font

    public init(_ title: String, font: Font = MediaLayout.titleFont) {
        self.title = title
        self.font = font
    }

    public var body: some View {
        Text(verbatim: title).font(font).accessibilityAddTraits(.isHeader)
    }
}
