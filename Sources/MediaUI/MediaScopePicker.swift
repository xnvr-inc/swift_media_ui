import SwiftUI
#if os(tvOS)
import UIKit
#endif

public struct MediaScopePicker<Item: Hashable>: View {
    private let horizontalInset: CGFloat
    private let surface: Color
    private let selectedSurface: Color
    private let font: Font
    private let items: [Item]
    private let selection: Item
    private let identifier: String?
    private let title: (Item) -> String
    private let asset: (Item) -> String?
    private let select: (Item) -> Void

    public init(items: [Item], selection: Item, title: @escaping (Item) -> String,
                horizontalInset: CGFloat, surface: Color, selectedSurface: Color, font: Font = MediaLayout.metadataFont,
                identifier: String? = nil, asset: @escaping (Item) -> String? = { _ in nil }, select: @escaping (Item) -> Void) {
        self.horizontalInset = horizontalInset
        self.surface = surface
        self.selectedSurface = selectedSurface
        self.font = font
        self.items = items
        self.selection = selection
        self.identifier = identifier
        self.title = title
        self.asset = asset
        self.select = select
    }

    public var body: some View {
        #if os(tvOS)
        TVScopeRail(titles: items.map(title), selected: items.firstIndex(of: selection) ?? 0,
                    images: items.map { asset($0).flatMap { UIImage(named: $0) } },
                    identifier: identifier, horizontalInset: horizontalInset,
                    surface: UIColor(surface), selectedSurface: UIColor(selectedSurface)) { index in
            select(items[index])
        }
        .frame(maxWidth: .infinity)
        .frame(height: TVMediaLayout.Browse.pillRowHeight)
        .padding(.horizontal, -horizontalInset)
        .focusSection()
        #else
        let bar = MediaScopeBar(items: items, selection: selection, horizontalInset: horizontalInset) { item, selected in
            Button { select(item) } label: {
                Label {
                    Text(title(item))
                } icon: {
                    if let icon = asset(item) {
                        Image(icon).resizable().renderingMode(.template).scaledToFit()
                            .frame(width: MediaControlMetrics.choiceIconSize, height: MediaControlMetrics.choiceIconSize).accessibilityHidden(true)
                    }
                }
                .font(font)
                .foregroundStyle(.white)
                .mediaChoiceChip(fill: selected ? selectedSurface : surface)
            }
            .buttonStyle(.plain)
        }
        if let identifier { bar.accessibilityIdentifier(identifier) }
        else { bar }
        #endif
    }
}

#if os(tvOS)
private struct TVScopeRail: UIViewRepresentable {
    let titles: [String]
    let selected: Int
    let images: [UIImage?]
    let identifier: String?
    let horizontalInset: CGFloat
    let surface: UIColor
    let selectedSurface: UIColor
    let select: (Int) -> Void

    func makeUIView(context: Context) -> TVMediaScopeBar {
        TVMediaScopeBar(horizontalInset: horizontalInset, surface: surface, selectedSurface: selectedSurface)
    }

    func updateUIView(_ view: TVMediaScopeBar, context: Context) {
        view.configure(titles: titles, selected: selected, identifier: identifier, images: images, select: select)
    }
}
#endif
