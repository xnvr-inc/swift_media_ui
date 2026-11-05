import SwiftUI

/// A full-width action in a grouped settings form that opens another surface.
public struct MediaSettingsNavigationRow: View {
    private enum Destination {
        case action(() -> Void)
        case link(URL)
    }

    private let title: String
    private let systemImage: String?
    private let destination: Destination

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.destination = .action(action)
    }

    public init(_ title: String, systemImage: String? = nil, destination: URL) {
        self.title = title
        self.systemImage = systemImage
        self.destination = .link(destination)
    }

    public var body: some View {
        Group {
            switch destination {
            case .action(let action):
                Button(action: action) { label }
            case .link(let url):
                Link(destination: url) { label }
            }
        }
        #if os(macOS)
        .buttonStyle(MacTextButtonStyle())
        #elseif os(iOS)
        .buttonStyle(.plain)
        #endif
    }

    private var label: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .frame(width: 18)
                    .accessibilityHidden(true)
            }
            Text(title)
            Spacer(minLength: 12)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .accessibilityHidden(true)
        }
        .foregroundStyle(.white)
        #if os(iOS)
        .frame(maxWidth: .infinity, minHeight: MediaControlMetrics.touchTarget, alignment: .leading)
        #else
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        #endif
        .contentShape(Rectangle())
    }
}

#if os(iOS)
/// Native Form action with the service's accent, without a navigation affordance.
public struct MediaSettingsTextAction: View {
    private let title: String
    private let tint: Color?
    private let action: () -> Void

    public init(_ title: String, tint: Color? = nil, action: @escaping () -> Void) {
        self.title = title
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        if let tint { Button(title, action: action).tint(tint) }
        else { Button(title, action: action) }
    }
}
#endif
