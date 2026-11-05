import SwiftUI

/// A video surface and its overlays. Fitted stages size independently of their player.
public struct MediaVideoStage<Content: View>: View {
    private let aspectRatio: CGFloat?
    private let cornerRadius: CGFloat
    private let content: Content

    public init(aspectRatio: CGFloat? = nil, cornerRadius: CGFloat = 0,
                @ViewBuilder content: () -> Content) {
        self.aspectRatio = aspectRatio
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        if let aspectRatio {
            Color.black
                .aspectRatio(aspectRatio, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay { content }
                .clipShape(.rect(cornerRadius: cornerRadius))
        } else {
            ZStack {
                Color.black
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Places video tiles without changing their identity when one becomes featured.
public struct MediaPlaybackTiles<Items: RandomAccessCollection, Tile: View>: View where Items.Element: Identifiable {
    private let items: Items
    private let frames: [CGRect]
    private let tile: (Items.Element) -> Tile

    public init(_ items: Items, frames: [CGRect], @ViewBuilder tile: @escaping (Items.Element) -> Tile) {
        self.items = items
        self.frames = frames
        self.tile = tile
    }

    public var body: some View {
        ForEach(Array(zip(items, frames)), id: \.0.id) { item, frame in
            tile(item)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
    }
}
