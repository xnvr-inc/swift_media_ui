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
    private let isDisplayed: Bool
    @State private var visibleID: ID?
    @State private var pendingAlignment: ID?

    public init(selection: ID, isDisplayed: Bool, select: @escaping (ID) -> Void) {
        self.selection = selection
        self.select = select
        self.isDisplayed = isDisplayed
        _pendingAlignment = State(initialValue: selection)
    }

    public func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .task(id: isDisplayed) { align(proxy) }
                .onChange(of: selection) { align(proxy) }
                // macOS can change the visible page while isPositionedByUser remains false.
                .onScrollTargetVisibilityChange(idType: ID.self, threshold: 0.5) { ids in
                    guard ids.count == 1, let id = ids.first else { return }
                    visibleID = id
                    guard pendingAlignment == nil || pendingAlignment == id else { return }
                    pendingAlignment = nil
                    if isDisplayed, id != selection { select(id) }
                }
        }
    }

    private func align(_ proxy: ScrollViewProxy) {
        guard isDisplayed else { return }
        pendingAlignment = visibleID == selection ? nil : selection
        if pendingAlignment != nil { proxy.scrollTo(selection, anchor: .top) }
    }
}
#endif
