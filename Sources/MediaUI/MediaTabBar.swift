#if os(iOS)
import Observation
import SwiftUI
import UIKit

/// One tab of the bar that ``SwiftUI/View/mediaMinimizingTabBar(_:selection:isVisible:isInteractive:reselected:)``
/// draws.
public struct MediaTabBarItem<Tag: Hashable>: Identifiable {
    enum Icon {
        case symbol(String)
        case asset(String, Bundle?)
    }

    public let tag: Tag
    public let title: String
    let icon: Icon
    public var id: Tag { tag }

    /// A tab drawn with an SF Symbol, which takes its filled variant while selected.
    public init(tag: Tag, title: String, systemImage: String) {
        self.tag = tag
        self.title = title
        icon = .symbol(systemImage)
    }

    /// A tab drawn with a template image from an asset catalog.
    public init(tag: Tag, title: String, imageName: String, bundle: Bundle? = nil) {
        self.tag = tag
        self.title = title
        icon = .asset(imageName, bundle)
    }
}

public extension View {
    /// Draws the tab bar itself, as a glass pill that shrinks to a pill of icons
    /// while a page scrolls down, so content gets the room. It expands again on a
    /// reverse scroll, at the top of the page, when the tab changes and when it is
    /// tapped, with the Flutter tab bar's geometry and motion. Earlier systems
    /// and the regular width, such as an iPad's, keep the standard tab bar.
    ///
    /// Apply it to the `TabView`, give each tab's content
    /// ``SwiftUI/View/mediaSystemTabBar(_:)`` in place of its own tab bar
    /// visibility, and have each tab's root page report its scrolling through
    /// ``SwiftUI/View/mediaScrollAwayAppBar(_:)``.
    ///
    /// While the bar is shrunk, a tap on another tab selects it and expands the
    /// bar; a tap on the selected tab only expands it, so a repeat selection takes
    /// a second tap. VoiceOver keeps the full bar, and Reduce Motion switches
    /// without animating.
    ///
    /// - Parameters:
    ///   - items: The tabs, in order. Each needs a matching `tag` in the `TabView`.
    ///   - selection: The selected tab, the same binding the `TabView` uses.
    ///   - isVisible: Whether the bar is on screen, for example `false` while a
    ///     page is pushed over the tab's root.
    ///   - isInteractive: Whether the bar takes taps and VoiceOver focus, for
    ///     example `false` while a full-screen cover sits over the tabs.
    ///   - reselected: Called when the selected tab is tapped again on the full bar.
    @ViewBuilder func mediaMinimizingTabBar<Tag: Hashable>(
        _ items: [MediaTabBarItem<Tag>],
        selection: Binding<Tag>,
        isVisible: Bool = true,
        isInteractive: Bool = true,
        reselected: @escaping () -> Void = {}
    ) -> some View {
        if #available(iOS 26, *) {
            modifier(MediaMinimizingTabBar(
                items: items, selection: selection, isVisible: isVisible,
                isInteractive: isInteractive, reselected: reselected
            ))
        } else {
            self
        }
    }

    /// Sets the visibility of the system tab bar for a tab's content. Where
    /// ``SwiftUI/View/mediaMinimizingTabBar(_:selection:isVisible:isInteractive:reselected:)``
    /// draws the bar, the system one stays hidden and the tab's pages get the room
    /// the bar takes at the bottom, so their content ends above it; elsewhere
    /// `visibility` applies.
    func mediaSystemTabBar(_ visibility: Visibility) -> some View {
        modifier(MediaSystemTabBarVisibility(visibility: visibility))
    }
}

private struct MediaSystemTabBarVisibility: ViewModifier {
    let visibility: Visibility
    @Environment(\.mediaReplacesSystemTabBar) private var replaced
    @Environment(\.mediaTabBarReservedHeight) private var reserved

    func body(content: Content) -> some View {
        content
            .toolbar(replaced ? .hidden : visibility, for: .tabBar)
            .background(MediaTabBarReservation(height: reserved))
    }
}

private struct MediaTabBarReservedHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var mediaTabBarReservedHeight: CGFloat {
        get { self[MediaTabBarReservedHeightKey.self] }
        set { self[MediaTabBarReservedHeightKey.self] = newValue }
    }
}

/// Makes room for the bar in the tab controller's content. The tab content lives in
/// UIKit controllers, which do not take the bar's height from SwiftUI's safe area, so
/// the controller's own safe area carries it, down to every page's scroll view.
private struct MediaTabBarReservation: UIViewRepresentable {
    let height: CGFloat

    func makeUIView(context: Context) -> ReservationView { ReservationView() }

    func updateUIView(_ view: ReservationView, context: Context) {
        view.height = height
        view.apply()
    }

    final class ReservationView: UIView {
        var height: CGFloat = 0
        /// Whether the room has been set once, so the first setting does not animate.
        private var hasApplied = false
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            isHidden = true
        }
        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            apply()
        }

        func apply() {
            guard window != nil else { return }
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let controller = next as? UIViewController, let tabs = controller.tabBarController {
                    let animated = hasApplied
                    hasApplied = true
                    guard tabs.additionalSafeAreaInsets.bottom != height else { return }
                    guard animated else {
                        tabs.additionalSafeAreaInsets.bottom = height
                        return
                    }
                    // The bar leaves and returns with the page that covers it, so the
                    // room it takes changes with the same motion.
                    UIView.animate(withDuration: 0.28) {
                        tabs.additionalSafeAreaInsets.bottom = height
                        tabs.view.layoutIfNeeded()
                    }
                    return
                }
                responder = next
            }
        }
    }
}

private struct MediaReplacesSystemTabBarKey: EnvironmentKey {
    static let defaultValue = false
}

private extension EnvironmentValues {
    var mediaReplacesSystemTabBar: Bool {
        get { self[MediaReplacesSystemTabBarKey.self] }
        set { self[MediaReplacesSystemTabBarKey.self] = newValue }
    }
}

/// Whether the bar is shrunk. A page asks it to shrink or expand as it scrolls.
@available(iOS 26, *)
@MainActor @Observable
final class MediaTabBarController {
    private(set) var isMinimized = false
    /// While `false`, for example under VoiceOver, the bar stays full.
    var isEnabled = true {
        didSet { if !isEnabled { isMinimized = false } }
    }

    func apply(_ change: MediaTabBarChange) {
        switch change {
        case .minimize: if isEnabled { isMinimized = true }
        case .expand: isMinimized = false
        }
    }

    func expand() { isMinimized = false }
}

@available(iOS 26, *)
private struct MediaTabBarControllerKey: EnvironmentKey {
    static let defaultValue: MediaTabBarController? = nil
}

@available(iOS 26, *)
extension EnvironmentValues {
    var mediaTabBarController: MediaTabBarController? {
        get { self[MediaTabBarControllerKey.self] }
        set { self[MediaTabBarControllerKey.self] = newValue }
    }
}

@available(iOS 26, *)
private struct MediaMinimizingTabBar<Tag: Hashable>: ViewModifier {
    let items: [MediaTabBarItem<Tag>]
    @Binding var selection: Tag
    let isVisible: Bool
    let isInteractive: Bool
    let reselected: () -> Void
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var controller = MediaTabBarController()

    /// The bar is drawn for the compact width; the regular width, such as an
    /// iPad's, keeps the system tab bar, which floats at the top there.
    private var drawsBar: Bool { sizeClass == .compact }

    private var reservedHeight: CGFloat { drawsBar && isVisible ? MediaTabBarMetrics.reservedHeight : 0 }

    func body(content: Content) -> some View {
        content
            .environment(\.mediaTabBarController, drawsBar ? controller : nil)
            .environment(\.mediaReplacesSystemTabBar, drawsBar)
            .environment(\.mediaTabBarReservedHeight, reservedHeight)
            .overlay(alignment: .bottom) {
                ZStack {
                    if drawsBar && isVisible {
                        MediaTabBarView(
                            items: items, selection: $selection, controller: controller,
                            isInteractive: isInteractive, reselected: reselected
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: isVisible)
                // The bar stays at the bottom of the screen while the keyboard is up.
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            .onChange(of: voiceOver, initial: true) { _, voiceOver in controller.isEnabled = !voiceOver }
            .onChange(of: selection) { controller.expand() }
            .onChange(of: isVisible) { _, isVisible in if isVisible { controller.expand() } }
            .onChange(of: drawsBar) { controller.expand() }
    }
}

@available(iOS 26, *)
private struct MediaTabBarView<Tag: Hashable>: View {
    let items: [MediaTabBarItem<Tag>]
    @Binding var selection: Tag
    let controller: MediaTabBarController
    let isInteractive: Bool
    let reselected: () -> Void
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let selectedIndex = items.firstIndex { $0.tag == selection } ?? 0
        let isMinimized = controller.isMinimized
        MediaTabBarPill(
            items: items,
            progress: isMinimized ? 1 : 0,
            position: CGFloat(selectedIndex),
            isRightToLeft: layoutDirection == .rightToLeft,
            selectedIndex: selectedIndex,
            tap: { index in
                if index != selectedIndex { selection = items[index].tag }
                if isMinimized {
                    controller.expand()
                } else if index == selectedIndex {
                    reselected()
                }
            }
        )
        // The Flutter controller is linear and the curve applies to its value, so
        // the shrink and the expansion share one deceleration.
        .animation(reduceMotion ? nil : .linear(duration: MediaTabBarMetrics.duration), value: isMinimized)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: selectedIndex)
        .allowsHitTesting(isInteractive)
        .accessibilityHidden(!isInteractive)
    }
}

/// The pill. SwiftUI drives `progress` (linear) and `position` (the selected tab,
/// fractional while the highlight moves) through every frame of an animation.
@available(iOS 26, *)
private struct MediaTabBarPill<Tag: Hashable>: View, Animatable {
    let items: [MediaTabBarItem<Tag>]
    var progress: CGFloat
    var position: CGFloat
    let isRightToLeft: Bool
    let selectedIndex: Int
    let tap: (Int) -> Void

    private static var labelHeight: CGFloat { 12 }
    private static var labelTopPadding: CGFloat { 2 }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, position) }
        set { (progress, position) = (newValue.first, newValue.second) }
    }

    /// A tab's place counted from the left, the order the pill is laid out in.
    private func visual(_ position: CGFloat) -> CGFloat {
        isRightToLeft ? CGFloat(items.count - 1) - position : position
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = MediaTabBarMetrics.layout(
                width: proxy.size.width, tabCount: items.count,
                progress: MediaTabBarMetrics.eased(progress)
            )
            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(.tint.opacity(0.22))
                    .frame(width: layout.highlightWidth, height: max(layout.pill.height - 2 * layout.inset, 0))
                    .offset(x: layout.slotCenter(at: visual(position)) - layout.highlightWidth / 2, y: layout.inset)
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    tab(item, at: index, layout: layout)
                }
            }
            .frame(width: layout.pill.width, height: layout.pill.height, alignment: .topLeading)
            .glassEffect(.regular, in: .capsule)
            .accessibilityAddTraits(.isTabBar)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("media.tabBar")
            .offset(x: layout.pill.minX, y: layout.pill.minY)
        }
        .frame(height: MediaTabBarMetrics.reservedHeight)
        // Positions are absolute, so a right-to-left layout only reorders the tabs.
        .environment(\.layoutDirection, .leftToRight)
    }

    @ViewBuilder private func icon(of item: MediaTabBarItem<Tag>, isSelected: Bool) -> some View {
        switch item.icon {
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .symbolVariant(isSelected ? .fill : .none)
                .scaledToFit()
                .frame(width: MediaTabBarMetrics.iconSize, height: MediaTabBarMetrics.iconSize)
        case .asset(let name, let bundle):
            Image(name, bundle: bundle)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: MediaTabBarMetrics.iconSize, height: MediaTabBarMetrics.iconSize)
        }
    }

    private func tab(_ item: MediaTabBarItem<Tag>, at index: Int, layout: MediaTabBarMetrics.Layout) -> some View {
        let isSelected = index == selectedIndex
        // A tap gesture rather than a `Button`: a button inside a replaced
        // accessibility element is exposed twice, once as each.
        return VStack(spacing: 0) {
            icon(of: item, isSelected: isSelected)
            Text(item.title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .fixedSize()
                .padding(.top, Self.labelTopPadding)
                .opacity(layout.labelFade)
                .frame(height: (Self.labelTopPadding + Self.labelHeight) * layout.labelFade, alignment: .top)
                .clipped()
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(TintShapeStyle()) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
        .frame(width: layout.slotWidth, height: layout.pill.height)
        .contentShape(Rectangle())
        .onTapGesture { tap(index) }
        // One button per tab, whatever the icon and label are made of.
        .accessibilityRepresentation {
            Button(item.title) { tap(index) }
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
        .offset(x: layout.slotCenter(at: visual(CGFloat(index))) - layout.slotWidth / 2)
    }
}
#endif
