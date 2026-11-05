#if os(tvOS)
import SwiftUI
import UIKit

/// The reader owns the scroll viewport. A direction click chooses the next
/// action within the current comment or the adjacent comment before revealing it.
public enum TVMediaCommentDestination<Action> {
    case focus(Action)
    case reveal(Action)
    case reader
    case sort
    case introduction
    case unchanged
}

public enum TVMediaDiscussionNavigation {
    public static func destination<Action: Equatable>(from action: Action, direction: MoveCommandDirection,
                                                      rows: [[Action]], prefersReply: Bool,
                                                      parentReply: Action? = nil, hasSort: Bool) -> TVMediaCommentDestination<Action> {
        guard let index = rows.firstIndex(where: { $0.contains(action) }) else { return .unchanged }
        let row = rows[index]
        switch direction {
        case .right:
            if let last = row.last, last != action { return .focus(last) }
            return hasSort ? .sort : .unchanged
        case .left:
            if let first = row.first, first != action { return .focus(first) }
            return .reader
        case .down:
            guard rows.indices.contains(index + 1),
                  let next = prefersReply ? rows[index + 1].last : rows[index + 1].first else { return .unchanged }
            return .reveal(next)
        case .up:
            guard index > 0 else { return .introduction }
            let previous = rows[index - 1]
            if !prefersReply, let parentReply, previous.last == parentReply { return .reveal(parentReply) }
            if let next = prefersReply ? previous.last : previous.first { return .reveal(next) }
            return .unchanged
        default:
            return .unchanged
        }
    }

    /// Focus inside the visible panel without letting the system recenter
    /// the scroll view. Only reveal an action that falls outside the viewport.
    @MainActor public static func moveFocus<ID: Hashable>(_ id: ID, in scroll: ScrollViewProxy,
                                                         rowID: String? = nil, fallback: () -> Void) async {
        let app = UIApplication.shared as? MediaTVPanelApplication
        if app?.focusVisibleDiscussionAction(id, revealIfNeeded: true) == true { return }
        app?.prepareForPanelScroll()
        // A lazy stack knows the row ID before it mounts the button inside it.
        if let rowID {
            scroll.scrollTo(rowID)
            await Task.yield()
            guard !Task.isCancelled else { return }
        }
        if app?.focusVisibleDiscussionAction(id, revealIfNeeded: true) == true { return }
        scroll.scrollTo(id)
        await Task.yield()
        guard !Task.isCancelled else { return }
        if app?.focusVisibleDiscussionAction(id, revealIfNeeded: true) != true { fallback() }
    }
}
#endif
