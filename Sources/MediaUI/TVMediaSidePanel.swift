#if os(tvOS)
import SwiftUI
import UIKit

private extension EnvironmentValues {
    @Entry var tvPanelNavigationScope: UUID?
}

/// Retain a list's live control when the focus engine has no downward destination.
public struct TVListFocusRetention: UIViewRepresentable {
    public init() {}

    public func makeUIView(context: Context) -> Anchor { Anchor() }
    public func updateUIView(_ view: Anchor, context: Context) {}

    public final class Anchor: UIView {
        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            NotificationCenter.default.addObserver(self, selector: #selector(focusUpdated(_:)),
                                                   name: UIFocusSystem.didUpdateNotification, object: nil)
        }
        required init?(coder: NSCoder) { nil }

        @objc private func focusUpdated(_ notification: Notification) {
            guard let window, window.isKeyWindow, !UIAccessibility.isVoiceOverRunning,
                  let context = notification.userInfo?[UIFocusSystem.focusUpdateContextUserInfoKey] as? UIFocusUpdateContext,
                  context.nextFocusedItem == nil, context.focusHeading == .down,
                  let previous = context.previouslyFocusedItem,
                  let coordinateSpace = previous.focusItemContainer?.coordinateSpace,
                  let system = UIFocusSystem.focusSystem(for: window) else { return }
            let frame = window.convert(previous.frame, from: coordinateSpace)
            guard convert(bounds, to: window).contains(CGPoint(x: frame.midX, y: frame.midY)) else { return }
            Task { @MainActor [weak self] in
                guard self?.window === window, system.focusedItem == nil, previous.canBecomeFocused else { return }
                system.requestFocusUpdate(to: previous)
                system.updateFocusIfNeeded()
            }
        }
    }
}

public struct TVReadingScroll<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reader = TVReadingScrollAnchor.Reader()
    let focus: FocusState<Bool>.Binding
    var isFocusable = true
    var moveAbove: () -> Void = {}
    var moveBelow: () -> Void = {}
    var moveLeft: () -> Void = {}
    @ViewBuilder let content: () -> Content

    public init(focus: FocusState<Bool>.Binding, isFocusable: Bool = true, moveAbove: @escaping () -> Void = {},
                moveBelow: @escaping () -> Void = {}, moveLeft: @escaping () -> Void = {},
                @ViewBuilder content: @escaping () -> Content) {
        self.focus = focus
        self.isFocusable = isFocusable
        self.moveAbove = moveAbove
        self.moveBelow = moveBelow
        self.moveLeft = moveLeft
        self.content = content
    }

    public var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { TVReadingScrollAnchor(reader: reader) }
        }
        .contentMargins([.horizontal, .bottom], TVPanelMetrics.contentInset, for: .scrollContent)
        .focusable(isFocusable)
        .focused(focus)
        .focusEffectDisabled()
        .onMoveCommand(perform: focus.wrappedValue ? { move($0, canLeaveReadingArea: true) } : nil)
        .tvPanelInput(focused: focus.wrappedValue, touchBehavior: .scroll) { move($0, canLeaveReadingArea: false) }
        .onChange(of: focus.wrappedValue) { reader.clearDestination() }
        .background { TVListFocusRetention().allowsHitTesting(false) }
    }

    private func move(_ direction: MoveCommandDirection, canLeaveReadingArea: Bool) {
        if direction == .left { moveLeft(); return }
        if direction == .right {
            if canLeaveReadingArea { (UIApplication.shared as? MediaTVPanelApplication)?.enterVisiblePanelButtons() }
            return
        }
        guard let scroll = reader.scrollView else { return }
        let top = -scroll.adjustedContentInset.top
        let bottom = max(top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        let current = reader.currentDestination ?? scroll.contentOffset.y
        let step = scroll.bounds.height * 0.6
        let next: CGFloat
        switch direction {
        case .up:
            if current <= top + 1 {
                if canLeaveReadingArea, scroll.contentOffset.y <= top + 1 { moveAbove() }
                return
            }
            next = max(top, current - step)
        case .down:
            if current >= bottom - 1 {
                if canLeaveReadingArea, scroll.contentOffset.y >= bottom - 1 { moveBelow() }
                return
            }
            next = min(bottom, current + step)
        default:
            return
        }
        (UIApplication.shared as? MediaTVPanelApplication)?.recordPanelDiagnostic("tv-panel-scroll", values: [
            "direction": direction == .up ? "up" : "down", "offset": scroll.contentOffset.y, "target": next
        ])
        (UIApplication.shared as? MediaTVPanelApplication)?.prepareForPanelScroll()
        reader.scroll(to: next, animated: !reduceMotion)
    }
}

/// Keep SwiftUI's lazy content and use its existing scroll view for remote reading.
private struct TVReadingScrollAnchor: UIViewRepresentable {
    final class Reader {
        weak var scrollView: UIScrollView?
        private var destination: CGFloat?
        private var scrollingUntil: ContinuousClock.Instant?

        var currentDestination: CGFloat? {
            guard let scrollingUntil, .now < scrollingUntil else { return nil }
            return destination
        }

        func scroll(to y: CGFloat, animated: Bool) {
            guard let scrollView else { return }
            destination = y
            scrollingUntil = animated ? .now.advanced(by: .milliseconds(250)) : nil
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: y), animated: animated)
        }

        func clearDestination() {
            destination = nil
            scrollingUntil = nil
        }
    }

    let reader: Reader

    func makeUIView(context: Context) -> Anchor { Anchor(reader: reader) }
    func updateUIView(_ view: Anchor, context: Context) {}

    final class Anchor: UIView {
        private let reader: Reader

        init(reader: Reader) {
            self.reader = reader
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView {
                    reader.scrollView = scroll
                    return
                }
                ancestor = view.superview
            }
        }
    }
}

public extension View {
    func onTVPanelMove(focused: @autoclosure @escaping () -> Bool, handlesDownPress: Bool = false,
                       touchBehavior: TVPanelTouchBehavior = .directional,
                       focusButton: (() -> Void)? = nil,
                       allowsReadingEntry: Bool = true, navigationID: AnyHashable? = nil,
                       perform action: ((MoveCommandDirection) -> Void)?) -> some View {
        onMoveCommand(perform: action)
            .tvPanelInput(focused: focused(), handlesDownPress: handlesDownPress,
                          touchBehavior: touchBehavior, focusButton: focusButton,
                          allowsReadingEntry: allowsReadingEntry, navigationID: navigationID, perform: action)
    }

    func tvPanelInput(focused: @autoclosure @escaping () -> Bool, handlesDownPress: Bool = false,
                      touchBehavior: TVPanelTouchBehavior = .directional,
                      focusButton: (() -> Void)? = nil,
                      allowsReadingEntry: Bool = true, navigationID: AnyHashable? = nil,
                      perform action: ((MoveCommandDirection) -> Void)?) -> some View {
        background {
            if focused() || focusButton != nil {
                TVPanelPressArea(move: action, handlesDownPress: handlesDownPress,
                                 touchBehavior: touchBehavior, focused: focused,
                                 focusButton: focusButton, allowsReadingEntry: allowsReadingEntry,
                                 navigationID: navigationID).allowsHitTesting(false)
            }
        }
    }

    func tvPanelSurface(surface: Color, readingFocused: Bool) -> some View {
        modifier(TVPanelSurface(surface: surface, readingFocused: readingFocused))
    }
}

private struct TVPanelSurface: ViewModifier {
    @Environment(\.mediaTVFocusOutline) private var focusOutline
    let surface: Color
    let readingFocused: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24)
        return content.background(surface.opacity(0.42), in: shape)
            .clipShape(shape)
            .mediaGlass(in: shape)
            .overlay {
                if readingFocused {
                    shape.strokeBorder(focusOutline, lineWidth: 2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .modifier(TVPanelNavigationScope())
    }
}

private struct TVPanelNavigationScope: ViewModifier {
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .background { TVPanelPressArea(isBoundary: true).allowsHitTesting(false) }
            .environment(\.tvPanelNavigationScope, id)
    }
}

public enum TVPanelTouchBehavior { case scroll, directional }

public enum TVPanelSwipe {
    public static func direction(for translation: CGVector, behavior: TVPanelTouchBehavior) -> MoveCommandDirection? {
        let horizontal = abs(translation.dx)
        let vertical = abs(translation.dy)
        let minimumTravel: CGFloat = 96
        let axisRatio: CGFloat = 1.35
        if behavior == .directional, horizontal >= minimumTravel && horizontal >= vertical * axisRatio {
            return translation.dx < 0 ? .left : .right
        }
        if vertical >= minimumTravel && vertical >= horizontal * axisRatio {
            return translation.dy < 0 ? .up : .down
        }
        return nil
    }
}

/// Register the panel boundary or the currently focused control's move action.
struct TVPanelPressArea: UIViewRepresentable {
    @Environment(\.tvPanelNavigationScope) private var scope
    var move: ((MoveCommandDirection) -> Void)? = nil
    var handlesDownPress = false
    var touchBehavior: TVPanelTouchBehavior = .directional
    var focused: () -> Bool = { false }
    var focusButton: (() -> Void)?
    var allowsReadingEntry = true
    var navigationID: AnyHashable?
    var isBoundary = false

    func makeUIView(context: Context) -> Anchor {
        let view = Anchor()
        updateUIView(view, context: context)
        return view
    }
    func updateUIView(_ view: Anchor, context: Context) {
        view.move = move
        view.handlesDownPress = handlesDownPress
        view.touchBehavior = touchBehavior
        view.inputFocused = focused
        view.focusButton = focusButton
        view.scope = scope
        view.isBoundary = isBoundary
        view.allowsReadingEntry = allowsReadingEntry
        view.navigationID = navigationID
    }

    final class Anchor: UIView {
        var move: ((MoveCommandDirection) -> Void)?
        var handlesDownPress = false
        var touchBehavior: TVPanelTouchBehavior = .directional
        var inputFocused: () -> Bool = { false }
        var focusButton: (() -> Void)?
        var scope: UUID?
        var isBoundary = false
        var allowsReadingEntry = true
        var navigationID: AnyHashable?
        var handlesTouch: Bool { inputFocused() && (move != nil || focusButton != nil) }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let app = UIApplication.shared as? MediaTVPanelApplication else { return }
            if window == nil { app.panelInputRegions.remove(self) }
            else { app.panelInputRegions.add(self) }
        }

        func acceptsInput(in eventWindow: UIWindow?) -> Bool {
            guard let window, window.isKeyWindow else { return false }
            return eventWindow == nil || eventWindow === window
        }

        func containsFocus(for eventWindow: UIWindow?) -> Bool {
            guard isBoundary, acceptsInput(in: eventWindow), let window, !bounds.isEmpty,
                  let itemFrame = Self.focusedFrame(in: window) else { return false }
            return convert(bounds, to: window).contains(CGPoint(x: itemFrame.midX, y: itemFrame.midY))
        }

        static func focusedFrame(in window: UIWindow) -> CGRect? {
            guard let item = UIFocusSystem.focusSystem(for: window)?.focusedItem else { return nil }
            if let view = item as? UIView { return view.convert(view.bounds, to: window) }
            if let space = item.focusItemContainer?.coordinateSpace {
                return window.convert(item.frame, from: space)
            }
            return nil
        }

        func visibleButtonFrame(in window: UIWindow, within panel: CGRect) -> CGRect? {
            guard focusButton != nil, self.window === window, !bounds.isEmpty else { return nil }
            let frame = convert(bounds, to: window)
            guard panel.insetBy(dx: -1, dy: -1).contains(frame) else { return nil }
            var ancestor = superview
            while let view = ancestor, view !== window {
                if view is UIScrollView,
                   !view.convert(view.bounds, to: window).insetBy(dx: -1, dy: -1).contains(frame) { return nil }
                ancestor = view.superview
            }
            return frame
        }

        var enclosingScrollView: UIScrollView? {
            var ancestor = superview
            while let view = ancestor {
                if let scroll = view as? UIScrollView { return scroll }
                ancestor = view.superview
            }
            return nil
        }
    }
}

/// Place the panel over the current screen without changing the underlying layout proposal.
public struct TVSidePanel<Base: View, Panel: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    @State private var showsFocus = false
    @State private var presentationID = UUID()
    let isPresented: Bool
    let readingFocused: Bool
    let surface: Color
    let dismiss: () -> Void
    let onDismissed: () -> Void
    @ViewBuilder let base: () -> Base
    @ViewBuilder let panel: () -> Panel

    public init(isPresented: Bool, readingFocused: Bool = false, surface: Color, dismiss: @escaping () -> Void,
                onDismissed: @escaping () -> Void = {}, @ViewBuilder base: @escaping () -> Base,
                @ViewBuilder panel: @escaping () -> Panel) {
        self.isPresented = isPresented
        self.readingFocused = readingFocused
        self.surface = surface
        self.dismiss = dismiss
        self.onDismissed = onDismissed
        self.base = base
        self.panel = panel
    }

    public var body: some View {
        base()
            .disabled(isPresented || visible)
            .accessibilityHidden(isPresented || visible)
            .overlay {
                GeometryReader { geometry in
                    if visible {
                        Color.black.opacity(0.32).ignoresSafeArea()
                            .accessibilityHidden(true).transition(.opacity)
                        panel()
                            .frame(width: TVPanelMetrics.width(in: geometry.size.width))
                            .frame(height: TVPanelMetrics.height(in: geometry.size.height))
                            .tvPanelSurface(surface: surface, readingFocused: readingFocused && showsFocus)
                            .environment(\.tvPanelShowsFocus, showsFocus)
                            .focusSection()
                            .accessibilityAddTraits(.isModal)
                            .onExitCommand(perform: dismiss)
                            .padding(TVPanelMetrics.outerInset)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                            .transition(reduceMotion ? .opacity : .offset(x: TVPanelMetrics.width(in: geometry.size.width) + TVPanelMetrics.outerInset))
                    }
                }.ignoresSafeArea()
            }
            .onChange(of: isPresented, initial: true) { _, presented in
                guard visible != presented else { return }
                let id = UUID()
                presentationID = id
                showsFocus = false
                withAnimation(.easeInOut(duration: TVPanelMetrics.duration(reducedMotion: reduceMotion))) {
                    visible = presented
                } completion: {
                    guard presentationID == id else { return }
                    if presented && visible { showsFocus = true }
                    if !presented && !visible { onDismissed() }
                }
            }
    }
}

#endif
