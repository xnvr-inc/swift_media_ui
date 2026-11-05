import SwiftUI
#if os(iOS)
import UIKit
#endif

public enum MediaCardMetrics {
    public static let landscapeAspect: CGFloat = 16.0 / 9
    public static let portraitAspect: CGFloat = 9.0 / 16
    public static let titleLineLimit = 2
    public static let titleLineSpacing: CGFloat = 4
    public static let bylineSpacing: CGFloat = 6
    public static let artworkToMetadata: CGFloat = 12

    #if os(tvOS)
    public static let badgeInset: CGFloat = 12
    public static let metadataSpacing: CGFloat = 6
    public static let avatarToTextSpacing: CGFloat = 16
    public static let avatarDiameter: CGFloat = 54
    public static let inlineAvatarDiameter: CGFloat = 20
    #else
    public static let badgeInset: CGFloat = 8
    public static let metadataSpacing: CGFloat = 4
    public static let avatarToTextSpacing: CGFloat = 12
    #if os(macOS)
    public static let avatarDiameter: CGFloat = 32
    public static let inlineAvatarDiameter: CGFloat = 12
    #else
    public static let avatarDiameter: CGFloat = 34
    public static let inlineAvatarDiameter: CGFloat = 14
    #endif
    #endif
}

extension EnvironmentValues {
    @Entry var mediaCardInShelf = false
    @Entry fileprivate var measuresFullMediaTitle = false
}

public extension View {
    /// Keeps same-width artwork aligned in horizontally scrolling card rows.
    func mediaCardShelfLayout() -> some View {
        environment(\.mediaCardInShelf, true)
    }
}

public struct MediaCardMetadata<Avatar: View, Title: View, Details: View>: View {
    @Environment(\.mediaCardInShelf) private var inShelf
    private let avatar: Avatar
    private let title: Title
    private let details: Details

    public init(@ViewBuilder avatar: () -> Avatar,
                @ViewBuilder title: () -> Title, @ViewBuilder details: () -> Details) {
        self.avatar = avatar()
        self.title = title()
        self.details = details()
    }

    public var body: some View {
        HStack(alignment: .top, spacing: MediaCardMetrics.avatarToTextSpacing) {
            avatar
            ZStack(alignment: .topLeading) {
                if inShelf {
                    text
                        .environment(\.measuresFullMediaTitle, true)
                        .hidden()
                        .accessibilityHidden(true)
                }
                text
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: inShelf)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: MediaCardMetrics.metadataSpacing) {
            title
            details
        }
    }
}

public struct MediaCardAvatar<Artwork: View>: View {
    private let artwork: Artwork

    public init(@ViewBuilder artwork: () -> Artwork) { self.artwork = artwork() }

    public var body: some View {
        MediaBylineAvatar(diameter: MediaCardMetrics.avatarDiameter) { artwork }
            #if os(iOS) || os(macOS)
            .anchorPreference(key: MediaCardAvatarBounds.self, value: .bounds) { $0 }
            #endif
    }
}

#if os(tvOS)
public struct TVMediaCardAvatarLabel<Artwork: View>: View {
    @Environment(\.isFocused) private var focused
    @Environment(\.mediaTVFocusOutline) private var focusOutline
    private let artwork: Artwork

    public init(@ViewBuilder artwork: () -> Artwork) { self.artwork = artwork() }

    public var body: some View {
        MediaCardAvatar { artwork }
            .overlay {
                Circle().strokeBorder(focusOutline, lineWidth: focused ? 3 : 0)
            }
            .contentShape(Circle())
    }
}
#endif

private struct MediaCardAvatarBounds: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

public extension View {
    /// The avatar action sits beside the video control in the accessibility and hit-test tree.
    @ViewBuilder func mediaCardAvatarAction<Control: View>(
        @ViewBuilder _ control: @escaping () -> Control
    ) -> some View {
        #if os(macOS) || os(iOS)
        if MediaCardMetrics.allowsAvatarAction {
            overlayPreferenceValue(MediaCardAvatarBounds.self) { bounds in
                if let bounds {
                    GeometryReader { geometry in
                        let frame = geometry[bounds]
                        control()
                            .frame(width: max(frame.width, MediaControlMetrics.touchTarget),
                                   height: max(frame.height, MediaControlMetrics.touchTarget))
                            .position(x: frame.midX, y: frame.midY)
                    }
                }
            }
            .transformPreference(MediaCardAvatarBounds.self) { $0 = nil }
        } else { self }
        #else
        self
        #endif
    }
}

public struct MediaCardAvatarHitArea: View {
    public init() {}

    public var body: some View { Color.clear.contentShape(Circle()) }
}

private extension MediaCardMetrics {
    static var allowsAvatarAction: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #elseif os(macOS)
        true
        #else
        false
        #endif
    }
}

public struct MediaCardTitle: View {
    @Environment(\.measuresFullMediaTitle) private var measuresFullTitle
    private let title: String
    private let font: Font
    private let reservesSpace: Bool

    public init(_ title: String, font: Font, reservesSpace: Bool = false) {
        self.title = title
        self.font = font
        self.reservesSpace = reservesSpace
    }

    public var body: some View {
        Text(verbatim: title)
            .font(font)
            .foregroundStyle(.primary)
            .lineLimit(MediaCardMetrics.titleLineLimit, reservesSpace: reservesSpace || measuresFullTitle)
            #if os(tvOS)
            .lineSpacing(MediaCardMetrics.titleLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            #endif
    }
}

public struct MediaCardByline: View {
    private let value: String
    private let font: Font

    public init(_ value: String, font: Font) {
        self.value = value
        self.font = font
    }

    public var body: some View {
        if !value.isEmpty {
            Text(verbatim: value)
                .font(font)
                .lineLimit(1)
        }
    }
}
