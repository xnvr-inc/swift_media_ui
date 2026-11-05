import SwiftUI

public enum MediaControlMetrics {
    public static let choiceIconSize: CGFloat = 16
    public static let touchTarget: CGFloat = 44
    public static let pressedOpacity = 0.75
    public static let disabledOpacity = 0.5
}

public struct MediaIconLabel: View {
    private let symbol: String
    private let side: CGFloat
    private let font: Font?

    public init(_ symbol: String, side: CGFloat = MediaControlMetrics.touchTarget, font: Font? = nil) {
        self.symbol = symbol
        self.side = side
        self.font = font
    }

    public var body: some View {
        Image(systemName: symbol)
            .font(font)
            .frame(width: side, height: side)
            .contentShape(Rectangle())
    }
}

public struct MediaPlayerIconButton: View {
    private let title: String
    private let systemImage: String
    private let surface: Color
    private let action: () -> Void

    public init(_ title: String, systemImage: String, surface: Color = .clear, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.surface = surface
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            MediaIconLabel(systemImage)
                .background(surface, in: Circle())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

public struct MediaSectionActionLabel: View {
    private let title: String
    private let symbol: String
    private let trailingSymbol: Bool

    public init(_ title: String, symbol: String = "chevron.right", trailingSymbol: Bool = true) {
        self.title = title
        self.symbol = symbol
        self.trailingSymbol = trailingSymbol
    }

    public var body: some View {
        Group {
            if trailingSymbol {
                HStack(spacing: 6) {
                    Text(title)
                    Image(systemName: symbol).accessibilityHidden(true)
                }
            } else {
                Label(title, systemImage: symbol)
            }
        }
        #if os(tvOS)
        .font(MediaLayout.metadataFont.weight(.semibold))
        .lineLimit(1)
        #endif
    }
}

public struct MediaSortButtonLabel: View {
    public init() {}

    public var body: some View {
        Image(systemName: "line.3.horizontal.decrease")
            #if os(tvOS)
            .font(.system(size: MediaLayout.metadataSize, weight: .semibold))
            #else
            .font(.system(size: MediaControlMetrics.choiceIconSize, weight: .semibold))
            #endif
        #if os(iOS)
        .frame(width: MediaControlMetrics.touchTarget, height: MediaControlMetrics.touchTarget)
        #endif
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

#if !os(tvOS)
public struct MediaSortMenu<Options: View>: View {
    private let title: String
    private let options: Options

    public init(_ title: String, @ViewBuilder options: () -> Options) {
        self.title = title
        self.options = options()
    }

    public var body: some View {
        Menu {
            options
        } label: {
            MediaSortButtonLabel()
        }
        .menuIndicator(.hidden)
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(title)
        #endif
        .accessibilityLabel(title)
    }
}
#endif

public struct MediaActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let surface: Color

    public init(surface: Color) { self.surface = surface }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(8)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: MediaControlMetrics.touchTarget)
            .background(surface, in: Capsule())
            .contentShape(Capsule())
            .opacity(!isEnabled ? MediaControlMetrics.disabledOpacity
                     : configuration.isPressed ? MediaControlMetrics.pressedOpacity : 1)
    }
}

public extension View {
    func mediaMiniPlaybackProgressStyle() -> some View {
        controlSize(.small).tint(.white)
    }

    func mediaChoiceChip(fill: Color, verticalHitPadding: CGFloat = 0) -> some View {
        lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(fill, in: Capsule())
            .padding(.vertical, verticalHitPadding)
            .frame(minWidth: MediaControlMetrics.touchTarget, minHeight: MediaControlMetrics.touchTarget)
            .contentShape(Rectangle())
    }

    #if os(tvOS)
    func mediaTVPanelControl<Outline: Shape>(
        in outline: Outline, fill: Color, stroke: Color, pressed: Bool, enabled: Bool
    ) -> some View {
        background(fill, in: outline)
            .overlay { outline.stroke(stroke, lineWidth: 2) }
            .contentShape(outline)
            .opacity(!enabled ? MediaControlMetrics.disabledOpacity : pressed ? MediaControlMetrics.pressedOpacity : 1)
    }
    #endif
}

#if os(tvOS)
/// The containing card paints focus while the native button handles activation.
public struct MediaUnadornedButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View { configuration.label }
}
#endif

#if os(macOS)
/// An unfilled text or icon action on a dark desktop surface.
public struct MacTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .opacity(!enabled ? MediaControlMetrics.disabledOpacity
                     : configuration.isPressed ? MediaControlMetrics.pressedOpacity : 1)
    }
}
#endif
