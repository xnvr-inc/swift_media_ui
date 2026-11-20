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
/// Mirrors the Flutter tab bar policy: the bar shrinks while scrolling down and
/// expands on reverse scroll and when the page is back at its top.
public struct MediaTabBarExpansionPolicy: Equatable {
    /// Upward travel that counts as a deliberate reverse scroll.
    public static let reverseDistance: CGFloat = 24
    /// Distance from the resting top that counts as being at the top.
    public static let topTolerance: CGFloat = 0.5

    private var last: CGFloat = 0
    private var reverseTravel: CGFloat = 0
    private var expandedForReverse = false

    public init() {}

    /// Feeds the page's scroll `distance` from its resting top and returns
    /// whether the tab bar should expand now. It asks once per reverse scroll
    /// and once on arriving at the top.
    public mutating func expands(atDistance distance: CGFloat) -> Bool {
        defer { last = distance }
        let atTop = distance <= Self.topTolerance
        if atTop { reverseTravel = 0 }
        if atTop && last > Self.topTolerance {
            expandedForReverse = true
            return true
        }
        if distance > last {
            reverseTravel = 0
            expandedForReverse = false
            return false
        }
        guard distance < last, !atTop else { return false }
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
    /// the page and when it is tapped. That tap only expands the bar and does not
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
    /// fixed. Apply it to a tab's root page, inside its `NavigationStack`. The page
    /// also tells a `mediaMinimizingTabBar()` when to expand.
    /// While `isEnabled` is `false`, for example during a search, or while
    /// VoiceOver is running, the bar stays. Earlier systems keep the standard bar.
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
    private(set) var behavior: TabBarMinimizeBehavior = .onScrollDown
    @ObservationIgnored private var restore: Task<Void, Never>?

    func expand() {
        behavior = .never
        restore?.cancel()
        restore = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.behavior = .onScrollDown
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

@available(iOS 26, *)
private struct MediaScrollAwayAppBar: ViewModifier {
    let isEnabled: Bool
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.mediaTabBarMinimizer) private var minimizer
    @State private var driver = MediaAppBarDriver()

    func body(content: Content) -> some View {
        content
            .background(MediaAppBarAnchor(driver: driver))
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, distance in
                if driver.scrolled(to: distance) { minimizer?.expand() }
            }
            .onChange(of: isEnabled && !voiceOver, initial: true) { _, scrollsAway in
                driver.isEnabled = scrollsAway
            }
    }
}

/// Moves the hosting navigation bar's items with the page's scroll distance. It
/// lives outside SwiftUI state so a scroll frame never re-evaluates the page.
@available(iOS 26, *)
@MainActor
private final class MediaAppBarDriver {
    weak var navigationBar: UINavigationBar?
    private var distance: CGFloat = 0
    private var expansion = MediaTabBarExpansionPolicy()
    var isEnabled = true {
        didSet { if isEnabled != oldValue { apply() } }
    }

    /// Takes the page's new scroll distance. Returns whether the tab bar should expand.
    func scrolled(to rawDistance: CGFloat) -> Bool {
        // Rubber-banding above the top must not push the bar down.
        let next = max(rawDistance, 0)
        guard next != distance else { return false }
        distance = next
        apply()
        return expansion.expands(atDistance: next)
    }

    func attach(_ bar: UINavigationBar?) {
        guard bar !== navigationBar else { return }
        reset()
        navigationBar = bar
        apply()
    }

    /// The bar's own frame feeds the page's top inset, so moving the bar itself
    /// would resize the page's content. Its items move instead, never the
    /// system background that owns the scroll edge effect.
    private var items: [UIView] {
        navigationBar?.subviews.filter { !String(describing: type(of: $0)).contains("Background") } ?? []
    }

    /// Puts the bar back, for example when the page leaves the screen.
    func reset() {
        for item in items {
            item.transform = .identity
            item.alpha = 1
            item.isUserInteractionEnabled = true
        }
    }

    func apply() {
        guard let navigationBar else { return }
        guard isEnabled else { return reset() }
        let height = navigationBar.bounds.height
        let shift = MediaScrollAwayAppBarMetrics.shift(atDistance: distance, barHeight: height)
        let gone = MediaScrollAwayAppBarMetrics.isGone(forShift: shift, barHeight: height)
        for item in items {
            item.transform = CGAffineTransform(translationX: 0, y: -shift)
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
            driver.attach(navigationController?.navigationBar)
            driver.apply()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            driver.reset()
        }
    }
}
#endif
