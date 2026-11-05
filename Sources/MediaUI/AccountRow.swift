import SwiftUI

public enum AccountRowStatus {
    case active
    case needsConnection
}

public struct AccountRowLabel<Avatar: View, SecondaryStyle: ShapeStyle>: View {
    private let name: String
    private let handle: String?
    private let status: AccountRowStatus?
    private let nameFont: Font
    private let metadataFont: Font
    private let secondaryStyle: SecondaryStyle
    private let avatar: Avatar

    public init(name: String, handle: String?, status: AccountRowStatus?,
                nameFont: Font, metadataFont: Font, secondaryStyle: SecondaryStyle,
                @ViewBuilder avatar: () -> Avatar) {
        self.name = name
        self.handle = handle
        self.status = status
        self.nameFont = nameFont
        self.metadataFont = metadataFont
        self.secondaryStyle = secondaryStyle
        self.avatar = avatar()
    }

    public var body: some View {
        HStack(spacing: 16) {
            avatar.frame(width: 48, height: 48).clipShape(Circle()).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: labelSpacing) {
                Text(verbatim: name).font(nameFont)
                if let handle { Text(verbatim: handle).font(metadataFont).foregroundStyle(secondaryStyle) }
            }
            Spacer()
            if let status {
                Label(status == .active ? "사용 중" : "다시 연결 필요",
                      systemImage: status == .active ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .font(metadataFont)
                    #if os(tvOS)
                    .fixedSize(horizontal: true, vertical: false)
                    #endif
            }
        }
        .contentShape(Rectangle())
    }

    private var labelSpacing: CGFloat? {
        #if os(tvOS)
        4
        #else
        nil
        #endif
    }
}

#if !os(tvOS)
public struct AccountFormRow<Selection: View>: View {
    private let name: String
    private let remove: () -> Void
    private let selection: Selection

    public init(name: String, remove: @escaping () -> Void, @ViewBuilder selection: () -> Selection) {
        self.name = name
        self.remove = remove
        self.selection = selection()
    }

    public var body: some View {
        HStack(spacing: 16) {
            selection
            AccountManagementMenu(name: name, remove: remove)
        }
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] }
    }
}

public struct AccountManagementMenu: View {
    private let name: String
    private let remove: () -> Void

    public init(name: String, remove: @escaping () -> Void) {
        self.name = name
        self.remove = remove
    }

    public var body: some View {
        Menu {
            Button("이 기기에서 계정 삭제", role: .destructive, action: remove)
        } label: {
            Image(systemName: "ellipsis.circle")
                #if os(macOS)
                .foregroundStyle(.white)
                #endif
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .buttonStyle(MacTextButtonStyle())
        .fixedSize()
        #endif
        .accessibilityLabel("\(name) 계정 관리")
    }
}
#endif
