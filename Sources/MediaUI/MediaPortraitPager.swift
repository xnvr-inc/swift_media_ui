import AVFoundation
import SwiftUI

#if os(iOS)
public struct MediaPortraitPager<Item: Identifiable, Page: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let items: [Item]
    private let selection: Item.ID
    private let size: CGSize
    private let accessibilityLabel: String
    private let accessibilityIdentifier: String
    private let select: (Item.ID) -> Void
    private let nextAtEnd: () -> Void
    private let page: (Item) -> Page

    public init(items: [Item], selection: Item.ID, size: CGSize, accessibilityLabel: String,
                accessibilityIdentifier: String, select: @escaping (Item.ID) -> Void,
                nextAtEnd: @escaping () -> Void, @ViewBuilder page: @escaping (Item) -> Page) {
        self.items = items
        self.selection = selection
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityIdentifier = accessibilityIdentifier
        self.select = select
        self.nextAtEnd = nextAtEnd
        self.page = page
    }
    @State private var offset: CGFloat = 0
    @GestureState private var isDragging = false

    private var motion: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.9)
    }

    public var body: some View {
        if let index = currentIndex { pages(around: index) }
    }

    private var currentIndex: Int? { items.firstIndex { $0.id == selection } }

    private func pages(around index: Int) -> some View {
        let first = max(0, index - 1)
        let last = min(items.count - 1, index + 1)
        return ZStack {
            ForEach(Array(items[first...last])) { video in
                let position = video.id == selection ? 0 : (video.id == items[first].id ? -1 : 1)
                page(video)
                    .allowsHitTesting(position == 0)
                    .accessibilityHidden(position != 0)
                    .offset(y: CGFloat(position) * size.height + offset)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 8)
                .updating($isDragging) { _, state, _ in state = true }
                .onChanged { value in
                    let distance = value.translation
                    guard offset != 0 || abs(distance.height) > abs(distance.width) else { return }
                    let neighbor = index + (distance.height < 0 ? 1 : -1)
                    let limit = items.indices.contains(neighbor) ? size.height : min(48, size.height * 0.1)
                    let delta = items.indices.contains(neighbor) ? distance.height : distance.height * 0.2
                    offset = min(limit, max(-limit, delta))
                }
                .onEnded { value in
                    let y = value.translation.height
                    let predicted = value.predictedEndTranslation.height
                    let vertical = abs(y) > abs(value.translation.width)
                    let distance = abs(y) >= min(110, size.height * 0.23)
                    let flick = abs(y) >= 24 && abs(predicted) >= 130 && y * predicted > 0
                    settle(by: vertical && (distance || flick) ? (y < 0 ? 1 : -1) : 0)
                }
        )
        .onChange(of: isDragging) {
            if !isDragging && offset != 0 { withAnimation(motion) { offset = 0 } }
        }
        .overlay {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel)
                .accessibilityIdentifier(accessibilityIdentifier)
                .accessibilityAdjustableAction { direction in
                    if direction == .increment { settle(by: 1) }
                    if direction == .decrement { settle(by: -1) }
                }
                .allowsHitTesting(false)
        }
    }

    private func settle(by delta: Int) {
        withAnimation(motion) {
            offset = 0
            guard let currentIndex else { return }
            let target = currentIndex + delta
            if delta != 0, items.indices.contains(target) {
                select(items[target].id)
            } else if delta > 0 {
                nextAtEnd()
            }
        }
    }
}

public struct MediaPortraitPlaybackButton: View {
    private let player: AVPlayer
    private let isCurrent: () -> Bool

    public init(player: AVPlayer, isCurrent: @escaping () -> Bool) {
        self.player = player
        self.isCurrent = isCurrent
    }
    @State private var pausedByTap = false

    public var body: some View {
        Button {
            guard isCurrent(), player.currentItem != nil else { return }
            pausedByTap = player.rate != 0
            if pausedByTap { player.pause() } else { player.play() }
        } label: {
            ZStack {
                Color.clear
                if pausedByTap {
                    Image(systemName: "play.fill").font(.largeTitle)
                        .padding(20).background(.black.opacity(0.55), in: Circle())
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pausedByTap ? "재생" : "일시 정지")
        .onReceive(player.publisher(for: \.rate)) { if $0 > 0 { pausedByTap = false } }
    }
}

public struct MediaPortraitSnap: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        } else {
            content.scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        }
    }
}

#endif
