#if os(macOS)
import SwiftUI

public struct MacSectionHeader: View {
    let title: String
    var count: Int? = nil
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    public init(title: String, count: Int? = nil, subtitle: String? = nil,
                actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.count = count
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(title).font(MediaLayout.sectionTitle).accessibilityAddTraits(.isHeader)
                    if let count { Text(count.formatted()).font(.callout.monospacedDigit()).foregroundStyle(.secondary) }
                }
                if let subtitle { Text(subtitle).font(.callout).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 5) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).accessibilityHidden(true)
                    }
                    .font(.system(size: 13, weight: .medium)).padding(.vertical, 5)
                }
                .buttonStyle(MacTextButtonStyle())
            }
        }
    }
}
#endif
