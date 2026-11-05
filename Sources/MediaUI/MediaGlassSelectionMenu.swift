import SwiftUI

#if !os(tvOS)
public struct MediaGlassSelectionMenu<Item: Hashable>: View {
    private let label: String
    private let items: [Item]
    private let selection: Item
    private let title: (Item) -> String
    private let select: (Item) -> Void

    public init(_ label: String, items: [Item], selection: Item,
                title: @escaping (Item) -> String, select: @escaping (Item) -> Void) {
        self.label = label
        self.items = items
        self.selection = selection
        self.title = title
        self.select = select
    }

    public var body: some View {
        Menu {
            Picker(label, selection: Binding(get: { selection }, set: select)) {
                ForEach(items, id: \.self) { item in
                    Text(title(item)).tag(item)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(title(selection)).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold))
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            #if os(iOS)
            .padding(.vertical, 5)
            .frame(minHeight: 30)
            .mediaGlass(in: Capsule(), interactive: true)
            .frame(minHeight: MediaControlMetrics.touchTarget)
            .contentShape(Rectangle())
            #else
            .padding(.vertical, 7)
            .frame(minHeight: MediaControlMetrics.touchTarget)
            .contentShape(Capsule())
            .mediaGlass(in: Capsule(), interactive: true)
            #endif
        }
        .menuIndicator(.hidden)
        #if os(macOS)
        .menuStyle(.borderlessButton)
        #endif
        .foregroundStyle(.white)
        .accessibilityLabel(label)
        .accessibilityValue(title(selection))
    }
}
#endif
