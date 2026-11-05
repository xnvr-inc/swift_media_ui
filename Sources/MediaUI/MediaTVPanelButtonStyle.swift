#if os(tvOS)
import SwiftUI

public extension EnvironmentValues {
    @Entry var tvPanelShowsFocus = true
    @Entry var mediaTVFocusOutline = Color.white
}

/// Brand colors for the standard Apple TV control states.
public struct MediaTVControlPalette {
    public let surface: Color
    public let selectedSurface: Color
    public let focusedSurface: Color
    public let lightFocus: Color
    public let lightFocusText: Color
    public let text: Color
    public let focusOutline: Color

    public init(surface: Color = .white.opacity(0.10), selectedSurface: Color = .white.opacity(0.22),
                focusedSurface: Color, lightFocus: Color = .white, lightFocusText: Color,
                text: Color = .white, focusOutline: Color = .white) {
        self.surface = surface
        self.selectedSurface = selectedSurface
        self.focusedSurface = focusedSurface
        self.lightFocus = lightFocus
        self.lightFocusText = lightFocusText
        self.text = text
        self.focusOutline = focusOutline
    }
}

public struct MediaTVPanelButtonStyle: ButtonStyle {
    let palette: MediaTVControlPalette
    var capsule = false
    var selected = false
    var lightFocus = false
    var dimWhenDisabled = true
    var fillsRow = false

    public init(palette: MediaTVControlPalette, capsule: Bool = false, selected: Bool = false, lightFocus: Bool = false,
                dimWhenDisabled: Bool = true, fillsRow: Bool = false) {
        self.palette = palette
        self.capsule = capsule
        self.selected = selected
        self.lightFocus = lightFocus
        self.dimWhenDisabled = dimWhenDisabled
        self.fillsRow = fillsRow
    }

    public func makeBody(configuration: Configuration) -> some View {
        TVPanelButtonLabel(configuration: configuration, palette: palette, capsule: capsule, selected: selected, lightFocus: lightFocus,
                           dimWhenDisabled: dimWhenDisabled, fillsRow: fillsRow)
    }

    private struct TVPanelButtonLabel: View {
        @Environment(\.isFocused) private var hasFocus
        @Environment(\.tvPanelShowsFocus) private var showsFocus
        @Environment(\.isEnabled) private var enabled
        let configuration: Configuration
        let palette: MediaTVControlPalette
        let capsule: Bool
        let selected: Bool
        let lightFocus: Bool
        let dimWhenDisabled: Bool
        let fillsRow: Bool

        private var focused: Bool { hasFocus && showsFocus }

        private var fill: Color {
            if focused { return lightFocus ? palette.lightFocus : palette.focusedSurface }
            if selected { return palette.selectedSurface }
            return capsule || fillsRow ? palette.surface : .clear
        }

        var body: some View {
            let shape = capsule ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: MediaLayout.browseArtworkRadius))
            configuration.label
                .labelStyle(TVCompactLabelStyle())
                .foregroundStyle(focused && lightFocus ? palette.lightFocusText : palette.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(minWidth: capsule ? 48 : nil, minHeight: fillsRow ? 72 : capsule ? 48 : nil)
                .frame(maxWidth: fillsRow ? .infinity : nil, alignment: .leading)
                .mediaTVPanelControl(in: shape, fill: fill,
                                     stroke: focused ? palette.focusOutline : .clear,
                                     pressed: configuration.isPressed, enabled: enabled || !dimWhenDisabled)
        }
    }
}

/// A plain icon that retains remote focus without drawing a ring or scaling its container.
public struct TVMediaSubtleIconButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        IconLabel(label: configuration.label, pressed: configuration.isPressed)
    }

    private struct IconLabel: View {
        @Environment(\.isFocused) private var focused
        @Environment(\.isEnabled) private var enabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let label: Configuration.Label
        let pressed: Bool

        var body: some View {
            label
                .scaleEffect(focused && !reduceMotion ? TVMediaPostCardFocusMetrics.scale : 1)
                .opacity(!enabled ? MediaControlMetrics.disabledOpacity : pressed ? MediaControlMetrics.pressedOpacity : focused ? 1 : 0.82)
                .animation(reduceMotion ? nil : .easeInOut(duration: TVMediaPostCardFocusMetrics.duration), value: focused)
        }
    }
}

private struct TVCompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
    }
}
#endif
