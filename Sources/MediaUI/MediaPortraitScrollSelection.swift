import SwiftUI

#if os(iOS)
@available(iOS 18.0, *)
public struct MediaPortraitPhoneSelection<ID: Hashable>: ViewModifier {
    private let ids: [ID]
    private let selection: ID
    private let select: (ID) -> Void
    let isDisplayed: Bool
    let size: CGSize
    @Binding var scrolling: Bool

    public init(ids: [ID], selection: ID, isDisplayed: Bool, size: CGSize,
                scrolling: Binding<Bool>, select: @escaping (ID) -> Void) {
        self.ids = ids
        self.selection = selection
        self.isDisplayed = isDisplayed
        self.size = size
        self.select = select
        _scrolling = scrolling
    }

    private struct Viewport: Equatable {
        let size: CGSize
        let topInset: CGFloat
        let bottomInset: CGFloat
    }

    public func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: size, initial: true) { align(proxy) }
                .onChange(of: isDisplayed) { align(proxy) }
                .onScrollGeometryChange(for: Viewport?.self) { geometry in
                    guard geometry.contentSize.height > 0 else { return nil }
                    return Viewport(size: geometry.containerSize, topInset: geometry.contentInsets.top,
                                    bottomInset: geometry.contentInsets.bottom)
                } action: { _, viewport in
                    if viewport != nil { align(proxy) }
                }
                .onScrollPhaseChange { old, new, context in
                    scrolling = new == .interacting || new == .decelerating
                    guard isDisplayed, new == .idle, old == .decelerating || old == .interacting else { return }
                    let geometry = context.geometry
                    let pageHeight = geometry.contentSize.height / CGFloat(max(1, ids.count))
                    guard pageHeight > 0 else { return }
                    let offset = max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                    let index = min(ids.count - 1, Int((offset / pageHeight).rounded()))
                    if ids.indices.contains(index) { select(ids[index]) }
                }
                .onChange(of: selection) { align(proxy) }
        }
    }

    private func align(_ proxy: ScrollViewProxy) {
        guard isDisplayed else { return }
        proxy.scrollTo(selection, anchor: .top)
    }
}
#elseif os(macOS)
@available(macOS 15.0, *)
public struct MediaPortraitMacSelection<ID: Hashable & Sendable>: ViewModifier {
    private let selection: ID
    private let select: (ID) -> Void
    let isDisplayed: Bool
    @State private var position: ScrollPosition

    public init(selection: ID, isDisplayed: Bool, select: @escaping (ID) -> Void) {
        self.selection = selection
        self.select = select
        self.isDisplayed = isDisplayed
        _position = State(initialValue: ScrollPosition(id: selection, anchor: .top))
    }

    public func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .scrollPosition($position, anchor: .center)
                .task(id: isDisplayed) {
                    guard isDisplayed else { return }
                    // The initial ScrollPosition value is a binding seed, not
                    // evidence that the native scroll view moved to that row.
                    proxy.scrollTo(selection, anchor: .top)
                }
                .onChange(of: position.viewID(type: ID.self)) { _, id in
                    if isDisplayed, position.isPositionedByUser, let id { select(id) }
                }
                .onChange(of: selection) { _, id in
                    if position.viewID(type: ID.self) != id { proxy.scrollTo(id, anchor: .top) }
                }
        }
    }
}
#endif
