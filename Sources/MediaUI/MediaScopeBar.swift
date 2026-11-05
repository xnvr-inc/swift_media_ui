import SwiftUI

/// The viewport reaches past the page gutter while the options align with the body.
public struct MediaScopeBar<Item: Hashable, Option: View>: View {
    private let items: [Item]
    private let selection: Item
    private let horizontalInset: CGFloat
    private let option: (Item, Bool) -> Option
    @FocusState private var focused: Item?

    public init(items: [Item], selection: Item, horizontalInset: CGFloat = 0,
                @ViewBuilder option: @escaping (Item, Bool) -> Option) {
        self.items = items
        self.selection = selection
        self.horizontalInset = horizontalInset
        self.option = option
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        option(item, item == selection)
                            .accessibilityAddTraits(item == selection ? .isSelected : [])
                            .focused($focused, equals: item)
                            .id(item)
                    }
                }
                #if os(tvOS)
                .padding(.vertical, 8)
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, horizontalInset, for: .scrollContent)
            .padding(.horizontal, -horizontalInset)
            .onChange(of: selection, initial: true) { _, value in proxy.scrollTo(value, anchor: .center) }
            #if os(tvOS)
            .focusSection()
            #else
            .onChange(of: focused) { _, value in
                if let value { proxy.scrollTo(value, anchor: .center) }
            }
            #endif
        }
    }
}
