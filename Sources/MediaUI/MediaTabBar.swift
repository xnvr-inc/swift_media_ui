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

    /// A tab drawn with an SF Symbol, in its filled variant when it has one, as the
    /// system bar draws them.
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
    /// The bar is drawn to look like the system's. The glass is the system's own
    /// `.regular` glass. The selected tab gets a neutral highlight of darkened glass,
    /// with the system bar's coefficients for light and dark mode (they follow the
    /// color scheme, not Increase Contrast or Reduce Transparency); the accent
    /// colors its icon and label; the other tabs use the label color; and an SF
    /// Symbol is drawn in its filled variant, or as it is when it has none.
    /// A template image from an asset catalog is drawn as supplied. Set the accent
    /// with an explicit `.tint(_:)` color on the `TabView` or above it: the glass
    /// then lightens it in dark mode as it does the system bar's, while the default
    /// accent and a tint set inside a tab's page do not.
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
            .background(MediaTabBarAnchor(height: reserved))
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

/// What the package has added to a tab controller's bottom safe area. The anchors
/// of all its tabs share it, so a host's own inset is kept, and the room goes away
/// again when the last anchor does.
private final class MediaTabBarReservation {
    nonisolated(unsafe) private static var key = 0

    static func of(_ tabs: UITabBarController) -> MediaTabBarReservation {
        if let existing = objc_getAssociatedObject(tabs, &key) as? MediaTabBarReservation { return existing }
        let created = MediaTabBarReservation()
        objc_setAssociatedObject(tabs, &key, created, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return created
    }

    /// The anchors that are alive. A tab that is not selected keeps its anchor, so
    /// switching tabs does not give the room up.
    let anchors = NSHashTable<MediaTabBarAnchorView>.weakObjects()
    /// The room the bar takes, as the latest anchor on screen reports it.
    var height: CGFloat = 0
    /// The part of the controller's inset that is this package's.
    private var applied: CGFloat = 0
    /// Whether the room has been set once, so the first setting does not animate.
    private var hasApplied = false

    func sync(_ tabs: UITabBarController) {
        // A host that replaced the inset with a value smaller than the room added
        // here has taken that room with it: what remains is the host's, and the room
        // is added again if it is still wanted. A replacement that is not smaller
        // cannot be told from the host adding to the inset, and keeps the room.
        if tabs.additionalSafeAreaInsets.bottom < applied { applied = 0 }
        let wanted = anchors.count == 0 ? 0 : height
        let change = wanted - applied
        guard change != 0 else { return }
        let animated = hasApplied && !UIAccessibility.isReduceMotionEnabled
        hasApplied = true
        applied = wanted
        guard animated else {
            tabs.additionalSafeAreaInsets.bottom += change
            return
        }
        // The bar leaves and returns with the page that covers it, so the room it
        // takes changes with the same motion.
        UIView.animate(withDuration: 0.28) {
            tabs.additionalSafeAreaInsets.bottom += change
            tabs.view.layoutIfNeeded()
        }
    }
}

final class MediaTabBarAnchorView: UIView {
    var height: CGFloat = 0
    private weak var tabs: UITabBarController?

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
                // An anchor that moved to another controller leaves the first one.
                if let previous = self.tabs, previous !== tabs {
                    let old = MediaTabBarReservation.of(previous)
                    old.anchors.remove(self)
                    old.sync(previous)
                }
                self.tabs = tabs
                let reservation = MediaTabBarReservation.of(tabs)
                reservation.anchors.add(self)
                reservation.height = height
                reservation.sync(tabs)
                return
            }
            responder = next
        }
    }

    /// The page that carried the anchor is gone for good.
    func dismantle() {
        guard let tabs else { return }
        self.tabs = nil
        let reservation = MediaTabBarReservation.of(tabs)
        reservation.anchors.remove(self)
        reservation.sync(tabs)
    }
}

/// Makes room for the bar in the tab controller's content. The tab content lives in
/// UIKit controllers, which do not take the bar's height from SwiftUI's safe area, so
/// the controller's own safe area carries it, down to every page's scroll view.
private struct MediaTabBarAnchor: UIViewRepresentable {
    let height: CGFloat

    func makeUIView(context: Context) -> MediaTabBarAnchorView { MediaTabBarAnchorView() }

    func updateUIView(_ view: MediaTabBarAnchorView, context: Context) {
        view.height = height
        view.apply()
    }

    static func dismantleUIView(_ view: MediaTabBarAnchorView, coordinator: ()) {
        view.dismantle()
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
    /// How many times the bar was expanded by something other than a page's own
    /// scrolling: a tap, a tab change, the bar coming back. Pages count their
    /// downward travel anew after each, as the Flutter controller does on `expand()`.
    private(set) var manualExpansions = 0
    /// While `false`, for example under VoiceOver, the bar stays full.
    var isEnabled = true {
        didSet { if !isEnabled { isMinimized = false } }
    }

    /// A page's request, from its scrolling.
    func apply(_ change: MediaTabBarChange) {
        switch change {
        case .minimize: if isEnabled { isMinimized = true }
        case .expand: isMinimized = false
        }
    }

    /// An expansion that is not the scrolling's own.
    func expand() {
        isMinimized = false
        manualExpansions += 1
    }
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
            isInteractive: isInteractive,
            tap: { index in
                if index != selectedIndex { selection = items[index].tag }
                if isMinimized {
                    controller.expand()
                } else if index == selectedIndex {
                    reselected()
                }
            }
        )
        // As in Flutter, the controller is linear and the curve applies to its value
        // in both directions, so the shrink decelerates and the expansion, which
        // runs the same curve backwards, accelerates.
        .animation(reduceMotion ? nil : .linear(duration: MediaTabBarMetrics.duration), value: isMinimized)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: selectedIndex)
        .allowsHitTesting(isInteractive)
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
    let isInteractive: Bool
    let tap: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

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
                highlight(layout: layout)
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

    /// The selected tab's highlight: the glass darkened to a neutral gray with the
    /// system bar's coefficients, not tinted with the accent color. The blend
    /// modes act on the glass behind them, which was measured on iOS 27.2 in light
    /// and dark mode with the bar at rest.
    @ViewBuilder private func highlight(layout: MediaTabBarMetrics.Layout) -> some View {
        let darkening = MediaTabBarHighlight.darkening(isDark: colorScheme == .dark)
        let width = layout.highlightWidth
        let height = max(layout.pill.height - 2 * layout.inset, 0)
        ZStack {
            if let gray = darkening.firstGray {
                Capsule().fill(Color(white: gray)).blendMode(darkening.slope > 1 ? .colorBurn : .multiply)
            }
            if darkening.remainder > 0 {
                Capsule().fill(Color(white: 1 - darkening.remainder)).blendMode(.plusDarker)
            }
        }
        .frame(width: width, height: height)
        .offset(x: layout.highlightOrigin(at: visual(position)), y: layout.inset)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private func icon(of item: MediaTabBarItem<Tag>, isSelected: Bool) -> some View {
        switch item.icon {
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .symbolVariant(.fill)
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
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .fixedSize()
                .padding(.top, Self.labelTopPadding)
                .opacity(layout.labelFade)
                .frame(height: (Self.labelTopPadding + Self.labelHeight) * layout.labelFade, alignment: .top)
                .clipped()
        }
        .foregroundStyle(isSelected ? AnyShapeStyle(TintShapeStyle()) : AnyShapeStyle(Color.primary))
        .frame(width: layout.slotWidth, height: layout.pill.height)
        .contentShape(Rectangle())
        .onTapGesture { tap(index) }
        // The system bar shows a tab's large content on a long press when the text
        // size is large; the labels here have a fixed size.
        .accessibilityShowsLargeContentViewer {
            Label { Text(item.title) } icon: { icon(of: item, isSelected: isSelected) }
        }
        .modifier(TabAccessibility(isInteractive: isInteractive, title: item.title, isSelected: isSelected) { tap(index) })
        .offset(x: layout.slotCenter(at: visual(CGFloat(index))) - layout.slotWidth / 2)
    }
}

/// One button per tab, whatever the icon and label are made of. While the bar is
/// not interactive the tab is hidden instead. Hiding an ancestor leaves the
/// replacement button exposed, and flipping a hidden flag on the button or the
/// container back and forth left the tabs stuck as unreachable after a screen
/// had covered the bar and gone again, so the node is replaced, not toggled.
@available(iOS 26, *)
private struct TabAccessibility: ViewModifier {
    let isInteractive: Bool
    let title: String
    let isSelected: Bool
    let tap: () -> Void

    @ViewBuilder func body(content: Content) -> some View {
        if isInteractive {
            content.accessibilityRepresentation {
                Button(title, action: tap)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        } else {
            content.accessibilityHidden(true)
        }
    }
}
#endif
