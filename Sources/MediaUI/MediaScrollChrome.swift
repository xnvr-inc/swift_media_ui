import SwiftUI

/// Geometry of an app bar that leaves with the page's content.
///
/// Mirrors the Flutter `XnvrScrollAwayHeader`: the bar is the first thing in the
/// scroll content, so it follows the list one-to-one, dissolves within the first
/// `fadeDistance` points of travel and takes no input once it is gone. It returns
/// only as the page itself returns to its top.
public enum MediaScrollAwayAppBarMetrics {
    /// Travel over which the bar dissolves.
    public static let fadeDistance: CGFloat = 40
    /// Blur radius the Flutter header reaches at the end of its travel.
    public static let maximumBlurRadius: CGFloat = 8

    /// How far the bar has travelled up for a page scrolled `distance` from its
    /// resting top, never beyond the bar's own `height`.
    public static func shift(atDistance distance: CGFloat, barHeight: CGFloat) -> CGFloat {
        min(max(distance, 0), max(barHeight, 0))
    }

    /// Dissolve progress, 0 at rest and 1 once the bar has travelled `fadeDistance`.
    public static func progress(forShift shift: CGFloat) -> CGFloat {
        min(max(shift / fadeDistance, 0), 1)
    }

    /// Opacity of the bar after travelling `shift`.
    public static func opacity(forShift shift: CGFloat) -> CGFloat {
        1 - progress(forShift: shift)
    }

    /// Blur radius of the bar after travelling `shift`, for renderers that can blur it.
    public static func blurRadius(forShift shift: CGFloat) -> CGFloat {
        0.01 + maximumBlurRadius * progress(forShift: shift)
    }

    /// Whether the bar is gone: it has left, so it takes no taps or focus.
    public static func isGone(forShift shift: CGFloat, barHeight: CGFloat) -> Bool {
        shift > 0 && ((barHeight > 0 && shift >= barHeight) || shift >= fadeDistance)
    }
}

/// When a minimized tab bar should expand again, as a page scrolls.
///
/// Mirrors the Flutter tab bar policy (`GlassTabBarMinimizeController`): the bar
/// shrinks while scrolling down and expands on a reverse scroll, when the page
/// is back at its top and when the page stops being scrollable. Only the user's
/// own scrolling counts as a reverse scroll; rubber-banding at the far edge,
/// jumps and content changes do not.
public struct MediaTabBarExpansionPolicy: Equatable {
    /// Upward travel since the last reversal that counts as a deliberate reverse
    /// scroll, the Flutter `kExpandThreshold`.
    public static let reverseDistance: CGFloat = 12
    /// Distance from the resting top that counts as being at the top.
    public static let topTolerance: CGFloat = 0.5
    /// Scrollable range below which a page counts as not scrollable, the Flutter
    /// `kMinScrollableExtent`.
    public static let minimumScrollableDistance: CGFloat = 40

    private var last: CGFloat = 0
    private var reverseTravel: CGFloat = 0
    private var expandedForReverse = false
    private var wasScrollable = false
    private var lastRaw: CGFloat = 0

    public init() {}

    /// Feeds the page's scroll `distance` from its resting top and returns
    /// whether the tab bar should expand now. It asks once per reverse scroll,
    /// once on arriving at the top and once when the page stops scrolling.
    ///
    /// - Parameters:
    ///   - maximumDistance: The farthest the page can scroll. A distance beyond
    ///     it is rubber-banding at the far edge, which moves without the user
    ///     reversing anything, so those samples never count, whatever the page's
    ///     extent does meanwhile.
    ///   - viewportHeight: A change larger than half of it is a jump, such as a
    ///     restored position, not a scroll.
    ///   - isUserScrolling: Whether the user's finger or its momentum moves the
    ///     page. Programmatic movement never counts as a reverse scroll, but
    ///     reaching the top always expands.
    public mutating func expands(
        atDistance rawDistance: CGFloat,
        maximumDistance: CGFloat = .greatestFiniteMagnitude,
        viewportHeight: CGFloat = .greatestFiniteMagnitude,
        isUserScrolling: Bool = true
    ) -> Bool {
        let maximum = max(maximumDistance, 0)
        let distance = min(max(rawDistance, 0), maximum)
        let scrollable = maximum >= Self.minimumScrollableDistance
        defer {
            last = distance
            lastRaw = rawDistance
            wasScrollable = scrollable
        }
        // A page that stops scrolling must not leave the bar minimized. The
        // reverse and top rules below still apply to a short page afterwards.
        if wasScrollable && !scrollable {
            reverseTravel = 0
            expandedForReverse = true
            return true
        }
        let atTop = distance <= Self.topTolerance
        if atTop {
            reverseTravel = 0
            guard last > Self.topTolerance else { return false }
            expandedForReverse = true
            return true
        }
        // Pushed further past the far edge the user is still moving down, so the
        // next reverse scroll is a new one. A position beyond a range that shrank
        // is not that, and neither is a previous position beyond the current range:
        // the content changed under the page, which is not the user reversing.
        if rawDistance > maximum, rawDistance > lastRaw, isUserScrolling { expandedForReverse = false }
        guard rawDistance <= maximum,
              last <= maximum,
              isUserScrolling,
              abs(distance - last) <= viewportHeight * 0.5
        else {
            reverseTravel = 0
            return false
        }
        if distance > last {
            reverseTravel = 0
            expandedForReverse = false
            return false
        }
        guard distance < last else { return false }
        reverseTravel += last - distance
        guard reverseTravel >= Self.reverseDistance, !expandedForReverse else { return false }
        expandedForReverse = true
        return true
    }
}

#if os(iOS)
import Observation
import UIKit

public extension View {
    /// Shrinks the tab bar to its compact form while the page scrolls down, so
    /// content gets the room. It expands again on reverse scroll, at the top of
    /// the page, after 12 points of the user's own reverse scroll, and when it is
    /// tapped. That tap only expands the bar and does not
    /// select a tab, so a repeat selection of the current tab needs a second tap.
    /// VoiceOver keeps the full bar. Apply it to the `TabView`; pages report their
    /// scrolling through `mediaScrollAwayAppBar(_:)`. Earlier systems keep the
    /// standard tab bar.
    @ViewBuilder func mediaMinimizingTabBar() -> some View {
        if #available(iOS 26, *) {
            modifier(MediaMinimizingTabBar())
        } else {
            self
        }
    }

    /// Lets the app bar leave with the content like the Flutter page header: it
    /// follows the page's own scrolling, dissolves within the first 40 points and
    /// returns only as the page returns to its top. The page's content inset stays
    /// fixed. Apply it to a tab's root page, inside its `NavigationStack`, where
    /// it follows the page's primary vertical scroll view (the first one the page
    /// reports). The page also tells a `mediaMinimizingTabBar()` when to expand.
    /// While `isEnabled` is `false`, for example during a search, or while
    /// VoiceOver is running, the app bar stays. Earlier systems keep the standard bar.
    @ViewBuilder func mediaScrollAwayAppBar(_ isEnabled: Bool = true) -> some View {
        if #available(iOS 26, *) {
            modifier(MediaScrollAwayAppBar(isEnabled: isEnabled))
        } else {
            self
        }
    }
}

/// Lets a page ask the tab bar to expand. The system minimizes the bar while
/// scrolling down, but offers no way to expand it from code; holding the
/// behavior at `.never` for a moment does that.
@available(iOS 26, *)
@MainActor @Observable
private final class MediaTabBarMinimizer {
    /// Long enough for the system to take the expansion, short enough that a
    /// scroll down right after it still shrinks the bar.
    private static let hold: Duration = .milliseconds(250)

    private(set) var behavior: TabBarMinimizeBehavior = .onScrollDown
    @ObservationIgnored private var isHolding = false

    func expand() {
        guard !isHolding else { return }
        isHolding = true
        behavior = .never
        Task { [weak self] in
            try? await Task.sleep(for: Self.hold)
            self?.behavior = .onScrollDown
            self?.isHolding = false
        }
    }
}

@available(iOS 26, *)
private struct MediaTabBarMinimizerKey: EnvironmentKey {
    static let defaultValue: MediaTabBarMinimizer? = nil
}

@available(iOS 26, *)
private extension EnvironmentValues {
    var mediaTabBarMinimizer: MediaTabBarMinimizer? {
        get { self[MediaTabBarMinimizerKey.self] }
        set { self[MediaTabBarMinimizerKey.self] = newValue }
    }
}

@available(iOS 26, *)
private struct MediaMinimizingTabBar: ViewModifier {
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @State private var minimizer = MediaTabBarMinimizer()

    func body(content: Content) -> some View {
        content
            .tabBarMinimizeBehavior(voiceOver ? .never : minimizer.behavior)
            .environment(\.mediaTabBarMinimizer, minimizer)
    }
}

/// What the page reports about its scrolling, in points from its resting top.
@available(iOS 26, *)
private struct MediaScrollSample: Equatable {
    var distance: CGFloat
    var maximumDistance: CGFloat
    var viewportHeight: CGFloat
}

@available(iOS 26, *)
private struct MediaScrollAwayAppBar: ViewModifier {
    let isEnabled: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.mediaTabBarMinimizer) private var minimizer
    @State private var driver = MediaAppBarDriver()

    func body(content: Content) -> some View {
        content
            .background(MediaAppBarAnchor(driver: driver))
            .onScrollGeometryChange(for: MediaScrollSample.self) { geometry in
                MediaScrollSample(
                    distance: geometry.contentOffset.y + geometry.contentInsets.top,
                    maximumDistance: max(
                        geometry.contentSize.height + geometry.contentInsets.bottom
                            + geometry.contentInsets.top - geometry.containerSize.height,
                        0
                    ),
                    viewportHeight: geometry.containerSize.height
                )
            } action: { _, sample in
                if driver.scrolled(to: sample) { minimizer?.expand() }
            }
            .onScrollPhaseChange { _, phase in
                // `.tracking` is a finger resting on the page before it moves, and
                // `.animating` is the app scrolling it: neither is the user scrolling.
                driver.isUserScrolling = phase == .interacting || phase == .decelerating
            }
            .onChange(of: isEnabled && !voiceOver, initial: true) { _, scrollsAway in
                driver.isEnabled = scrollsAway
            }
    }
}

/// Moves the hosting navigation bar's content with the page's scroll distance.
/// It lives outside SwiftUI state so a scroll frame never re-evaluates the page.
@available(iOS 26, *)
@MainActor
private final class MediaAppBarDriver {
    /// What a view looked like before this driver changed it.
    private final class Original {
        let alpha: CGFloat
        let sublayerTransform: CATransform3D
        let isUserInteractionEnabled: Bool

        init(_ view: UIView) {
            alpha = view.alpha
            sublayerTransform = view.layer.sublayerTransform
            isUserInteractionEnabled = view.isUserInteractionEnabled
        }
    }

    weak var navigationBar: UINavigationBar?
    private var distance: CGFloat = 0
    private var expansion = MediaTabBarExpansionPolicy()
    /// Whether the page owns the bar. The navigation bar is shared with the
    /// pages pushed over this one, so a page that is off screen, or still being
    /// revealed by a transition, never writes to it.
    private var isOnScreen = false
    /// Whether a transition is bringing the page back. Its dissolve owns the bar
    /// until the transition ends, so a scroll sample in between leaves it alone.
    private var isRevealing = false
    /// Identifies the transition that is revealing the page, so the completion of
    /// an earlier one cannot undo a later appearance.
    private var revealToken = 0
    /// Whether the user's finger, or its momentum, is moving the page.
    var isUserScrolling = false
    private let touched = NSMapTable<UIView, Original>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    var isEnabled = true {
        didSet { if isEnabled != oldValue { apply() } }
    }

    /// Takes the page's new scroll sample. Returns whether the tab bar should expand.
    func scrolled(to sample: MediaScrollSample) -> Bool {
        // Rubber-banding above the top must not push the bar down.
        let next = max(sample.distance, 0)
        if next != distance {
            distance = next
            apply()
        }
        return expansion.expands(
            atDistance: sample.distance,
            maximumDistance: sample.maximumDistance,
            viewportHeight: sample.viewportHeight,
            isUserScrolling: isUserScrolling
        )
    }

    func attach(_ bar: UINavigationBar?) {
        guard bar !== navigationBar else { return }
        reset()
        navigationBar = bar
        apply()
    }

    func appeared(in bar: UINavigationBar?) {
        endReveal()
        isOnScreen = true
        attach(bar)
        apply()
    }

    func disappeared() {
        endReveal()
        isOnScreen = false
        reset()
    }

    /// Starts a transition that brings the page back. Returns the token that its
    /// dissolve and its completion present.
    func beginReveal() -> Int {
        revealToken += 1
        isRevealing = true
        return revealToken
    }

    /// Ends the transition `token` started: the page owns the bar, or, when the
    /// transition was cancelled, gives it back. A later appearance or
    /// disappearance has already ended the transition, and this does nothing.
    func finishReveal(_ token: Int, cancelled: Bool, in bar: UINavigationBar?) {
        guard token == revealToken else { return }
        if cancelled { disappeared() } else { appeared(in: bar) }
    }

    private func endReveal() {
        revealToken += 1
        isRevealing = false
    }

    /// Dissolves the bar's content to where this page leaves it, inside the
    /// animation of a transition that brings the page back, so the bar of the
    /// page that is leaving is not cut off. The page owns the bar once the
    /// transition has finished; a cancelled one restores the bar by itself.
    func dissolve(in bar: UINavigationBar?, token: Int) {
        guard token == revealToken, isEnabled, let bar else { return }
        if bar !== navigationBar {
            reset()
            navigationBar = bar
        }
        let height = bar.bounds.height
        let shift = MediaScrollAwayAppBarMetrics.shift(atDistance: distance, barHeight: height)
        for item in items {
            remember(item)
            item.alpha = MediaScrollAwayAppBarMetrics.opacity(forShift: shift)
        }
    }

    /// The bar's own frame feeds the page's top inset, so moving the bar itself
    /// would resize the page's content. Its content moves instead, never the
    /// system background that owns the scroll edge effect.
    private var items: [UIView] {
        navigationBar?.subviews.filter { !String(describing: type(of: $0)).contains("Background") } ?? []
    }

    private func remember(_ item: UIView) {
        if touched.object(forKey: item) == nil { touched.setObject(Original(item), forKey: item) }
    }

    /// Puts every view this driver changed back as it was, for example when the
    /// page leaves the screen.
    func reset() {
        for item in touched.keyEnumerator().allObjects.compactMap({ $0 as? UIView }) {
            guard let original = touched.object(forKey: item) else { continue }
            item.layer.sublayerTransform = original.sublayerTransform
            item.alpha = original.alpha
            item.isUserInteractionEnabled = original.isUserInteractionEnabled
        }
        touched.removeAllObjects()
    }

    func apply() {
        guard let navigationBar, isEnabled else { return reset() }
        // An off-screen page never writes to the bar, and one being revealed
        // leaves it to the dissolve of its transition.
        guard isOnScreen else {
            if !isRevealing { reset() }
            return
        }
        let height = navigationBar.bounds.height
        let shift = MediaScrollAwayAppBarMetrics.shift(atDistance: distance, barHeight: height)
        let gone = MediaScrollAwayAppBarMetrics.isGone(forShift: shift, barHeight: height)
        for item in items {
            remember(item)
            // A sublayer transform, not the view's own: UIKit sets the item's
            // frame when it lays the bar out, which cancels a view transform.
            item.layer.sublayerTransform = CATransform3DMakeTranslation(0, -shift, 0)
            item.alpha = MediaScrollAwayAppBarMetrics.opacity(forShift: shift)
            item.isUserInteractionEnabled = !gone
        }
    }
}

@available(iOS 26, *)
private struct MediaAppBarAnchor: UIViewControllerRepresentable {
    let driver: MediaAppBarDriver

    func makeUIViewController(context: Context) -> Anchor { Anchor(driver: driver) }
    func updateUIViewController(_ controller: Anchor, context: Context) {}

    final class Anchor: UIViewController {
        let driver: MediaAppBarDriver

        init(driver: MediaAppBarDriver) {
            self.driver = driver
            super.init(nibName: nil, bundle: nil)
            view.isUserInteractionEnabled = false
        }

        @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            driver.attach(navigationController?.navigationBar)
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            let driver = driver
            let bar = navigationController?.navigationBar
            guard let coordinator = transitionCoordinator else { return driver.appeared(in: bar) }
            // The bar still shows the page that is leaving, so it only dissolves
            // along with the transition; the page owns the bar once it is over.
            let token = driver.beginReveal()
            coordinator.animate(alongsideTransition: { _ in
                driver.dissolve(in: bar, token: token)
            }, completion: { [weak self] context in
                driver.finishReveal(
                    token,
                    cancelled: context.isCancelled,
                    in: self?.navigationController?.navigationBar
                )
            })
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            driver.appeared(in: navigationController?.navigationBar)
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            driver.disappeared()
        }
    }
}
#endif
