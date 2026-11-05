import SwiftUI

public struct MediaGlassContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: () -> Content

    public init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    public var body: some View {
        if #available(iOS 26, macOS 26, tvOS 26, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}

public extension View {
    @ViewBuilder func mediaGlass<Outline: Shape>(
        in outline: Outline, tint: Color? = nil, interactive: Bool = false
    ) -> some View {
        if #available(iOS 26, macOS 26, tvOS 26, *) {
            glassEffect(.regular.tint(tint).interactive(interactive), in: outline)
        } else {
            background(.regularMaterial, in: outline)
        }
    }

    @ViewBuilder func mediaGlassButton() -> some View {
        if #available(iOS 26, macOS 26, tvOS 26, *) {
            buttonStyle(.glass).buttonBorderShape(.capsule)
        } else {
            buttonStyle(.bordered)
        }
    }
}

public extension View {
    func mediaGlass(cornerRadius: CGFloat = 18, interactive: Bool = false, tint: Color? = nil) -> some View {
        mediaGlass(in: RoundedRectangle(cornerRadius: cornerRadius), tint: tint, interactive: interactive)
    }
}
