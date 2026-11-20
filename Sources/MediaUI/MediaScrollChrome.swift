import SwiftUI

/// Thresholds for an app bar that leaves with the page's content.
public enum MediaScrollAwayAppBarMetrics {
    /// Distance from the resting top that hides the bar. It must exceed the
    /// bar height by more than `revealDistance`, because hiding shrinks the top
    /// inset by that height and the measured distance drops with it.
    public static let hideDistance: CGFloat = 72
    /// Distance from the resting top at or below which the bar returns.
    public static let revealDistance: CGFloat = 4

    /// Whether the bar is hidden for a page scrolled `distance` from its
    /// resting top. The bar returns only near the top, so scrolling back up
    /// through the middle of the page keeps it hidden.
    public static func hidesBar(atDistance distance: CGFloat, currentlyHidden: Bool) -> Bool {
        currentlyHidden ? distance > revealDistance : distance > hideDistance
    }
}

#if os(iOS)
public extension View {
    /// Shrinks the tab bar to its compact form while the page scrolls down, so
    /// content gets the room. The system expands it again at the top of the
    /// page or when it is tapped. That tap only expands the bar and does not
    /// select a tab, so a repeat selection of the current tab needs a second tap.
    /// Apply it to the `TabView`. Earlier systems keep the standard tab bar.
    @ViewBuilder func mediaMinimizingTabBar() -> some View {
        if #available(iOS 26, *) {
            tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }

    /// Lets the app bar leave with the content: it hides once the page has
    /// scrolled past the bar and comes back only when the page returns to its
    /// top. Apply it to a tab's root page, inside its `NavigationStack`.
    /// While `isEnabled` is `false`, for example during a search, the bar
    /// stays. Earlier systems keep the standard bar.
    @ViewBuilder func mediaScrollAwayAppBar(_ isEnabled: Bool = true) -> some View {
        if #available(iOS 26, *) {
            modifier(MediaScrollAwayAppBar(isEnabled: isEnabled))
        } else {
            self
        }
    }
}

@available(iOS 26, *)
private struct MediaScrollAwayAppBar: ViewModifier {
    let isEnabled: Bool
    @State private var hidden = false

    func body(content: Content) -> some View {
        content
            .toolbarVisibility(isEnabled && hidden ? .hidden : .automatic, for: .navigationBar)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, distance in
                let next = MediaScrollAwayAppBarMetrics.hidesBar(atDistance: distance, currentlyHidden: hidden)
                guard next != hidden else { return }
                withAnimation(.smooth(duration: 0.28)) { hidden = next }
            }
    }
}
#endif
