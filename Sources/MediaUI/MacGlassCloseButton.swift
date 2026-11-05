import SwiftUI

#if os(macOS)
public struct MacGlassCloseButton: View {
    let identifier: String
    let action: () -> Void
    public init(identifier: String, action: @escaping () -> Void) {
        self.identifier = identifier
        self.action = action
    }

    @ViewBuilder public var body: some View {
        if #available(macOS 26.1, *) {
            button.buttonStyle(.glass(.clear)).buttonBorderShape(.circle).tint(.clear)
        } else if #available(macOS 26, *) {
            button.buttonStyle(.glass).buttonBorderShape(.circle).tint(.clear)
        } else { button.buttonStyle(.bordered) }
    }
    private var button: some View {
        Button(action: action) {
            Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.white)
                .frame(width: 16, height: 16).contentShape(Rectangle())
        }.accessibilityLabel("닫기").accessibilityIdentifier(identifier)
            .keyboardShortcut(.cancelAction).help("닫기")
    }
}
#endif
