import SwiftUI

public struct MediaByline<Avatar: View, Title: View>: View {
    private let avatar: Avatar
    private let title: Title

    public init(@ViewBuilder avatar: () -> Avatar, @ViewBuilder title: () -> Title) {
        self.avatar = avatar()
        self.title = title()
    }

    public var body: some View {
        HStack(spacing: MediaCardMetrics.bylineSpacing) {
            avatar
            title.lineLimit(1)
        }
    }
}

public struct MediaBylineAvatar<Artwork: View>: View {
    private let diameter: CGFloat
    private let artwork: Artwork

    public init(diameter: CGFloat = MediaCardMetrics.inlineAvatarDiameter, @ViewBuilder artwork: () -> Artwork) {
        self.diameter = diameter
        self.artwork = artwork()
    }

    public var body: some View {
        Color.clear
            .frame(width: diameter, height: diameter)
            .overlay { artwork }
            .clipShape(Circle())
            .accessibilityHidden(true)
    }
}
