#if os(tvOS)
import SwiftUI
import UIKit

open class MediaTVPanelApplication: UIApplication {
    open var panelDiagnosticsEnabled: Bool { false }
    open func recordPanelDiagnostic(_ event: String, values: [String: Any] = [:]) {}

    public var hasSharedPanelFocus: Bool { panelHasFocus(in: nil) }

    let panelInputRegions = NSHashTable<TVPanelPressArea.Anchor>.weakObjects()
    private let panelSwipes = NSMapTable<UITouch, PanelSwipe>.weakToStrongObjects()
    private let heldPresses = NSHashTable<UIPress>.weakObjects()
    private let routedPanelPresses = NSHashTable<UIPress>.weakObjects()
    private var pressRevision: UInt = 0
    private let viewport = TVPanelViewport()
    private var pendingDowns = 0
    private var downScope: UUID?
    private var downTask: Task<Void, Never>?

    private final class PanelSwipe {
        weak var target: TVPanelPressArea.Anchor?
        weak var window: UIWindow?
        weak var focusedItem: (any UIFocusItem)?
        let origin: CGPoint
        var position: CGPoint
        let pressRevision: UInt
        let canMove: Bool

        init(target: TVPanelPressArea.Anchor, window: UIWindow, origin: CGPoint, pressRevision: UInt, canMove: Bool) {
            self.target = target
            self.window = window
            self.focusedItem = UIFocusSystem.focusSystem(for: window)?.focusedItem
            self.origin = origin
            self.position = origin
            self.pressRevision = pressRevision
            self.canMove = canMove
        }
    }

    open override func sendEvent(_ event: UIEvent) {
        if event.type == .scroll, panelMoveTarget(in: nil) != nil {
            recordPanelDiagnostic("tv-panel-scroll-event-suppressed")
            return
        }
        if event.type == .touches, let touches = event.allTouches, !touches.isEmpty,
           touches.allSatisfy({ $0.type == .indirect }) {
            // Suppress the whole sequence before focus navigation or scroll recognizers see it.
            // The click itself arrives separately as a press event.
            let suppressed = touches.filter(consumePanelTouch)
            if suppressed.count == touches.count { return }
        }
        if let presses = event as? UIPressesEvent {
            var handled = 0
            for press in presses.allPresses {
                switch press.phase {
                case .began:
                    if [.upArrow, .leftArrow, .rightArrow, .menu, .select].contains(press.type) {
                        clearPendingDowns()
                    }
                    if press.type == .menu { viewport.release() }
                    heldPresses.add(press)
                    pressRevision &+= 1
                    if panelDiagnosticsEnabled, panelHasFocus(in: nil) {
                        recordPanelDiagnostic("tv-panel-press", values: ["type": press.type.rawValue, "force": press.force])
                    }
                case .ended, .cancelled:
                    heldPresses.remove(press)
                default:
                    break
                }
                if press.phase == .began, let target = panelMoveTarget(in: nil) {
                    if press.type == .downArrow, target.handlesDownPress {
                        // A comment control owns the Down click even when there is no next action.
                        routedPanelPresses.add(press)
                        enqueueDown(from: target)
                    } else if press.type == .rightArrow, target.touchBehavior == .scroll, target.scope != nil {
                        routedPanelPresses.add(press)
                        enterVisiblePanelButtons(from: target)
                    }
                    #if DEBUG && targetEnvironment(simulator)
                    if press.type == .playPause, target.focusButton != nil,
                       CommandLine.arguments.contains("--verify-tv-panel-swipes") {
                        routedPanelPresses.add(press)
                        routePanelSwipe(CGVector(dx: 0, dy: 760), from: target)
                    }
                    if press.type == .playPause, target.handlesDownPress,
                       CommandLine.arguments.contains("--verify-tv-panel-down-burst") {
                        routedPanelPresses.add(press)
                        NSLog("MediaUI down burst starts from %@", String(describing: target.navigationID))
                        for _ in 0..<7 { enqueueDown(from: target) }
                    }
                    #endif
                }
                if routedPanelPresses.contains(press) {
                    handled += 1
                    if press.phase == .ended || press.phase == .cancelled { routedPanelPresses.remove(press) }
                }
            }
            if handled > 0 && handled == presses.allPresses.count { return }
        }
        super.sendEvent(event)
    }

    private func enqueueDown(from source: TVPanelPressArea.Anchor) {
        guard let scope = source.scope else { source.move?(.down); return }
        if downScope != scope {
            clearPendingDowns()
            downScope = scope
        }
        pendingDowns = min(pendingDowns + 1, 8)
        guard downTask == nil else { return }
        downTask = Task { @MainActor [weak self, weak window = source.window] in
            guard let self else { return }
            defer { if !Task.isCancelled { self.clearPendingDowns() } }
            guard let window else { return }
            var previous: TVPanelPressArea.Anchor?
            var previousID: AnyHashable?
            while !Task.isCancelled, self.pendingDowns > 0, self.downScope == scope,
                  let target = await self.nextDownTarget(in: window, scope: scope, after: previous, id: previousID) {
                self.pendingDowns -= 1
                previous = target
                previousID = target.navigationID
                #if DEBUG && targetEnvironment(simulator)
                if CommandLine.arguments.contains("--verify-tv-panel-down-burst") {
                    NSLog("MediaUI down dispatched from %@", String(describing: previousID))
                }
                #endif
                target.move?(.down)
            }
        }
    }

    private func nextDownTarget(in window: UIWindow, scope: UUID, after previous: TVPanelPressArea.Anchor?,
                                id: AnyHashable?) async -> TVPanelPressArea.Anchor? {
        // The source can disappear briefly when a lazy row crosses the viewport.
        // Wait for the actual next focus before consuming another queued click.
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .milliseconds(360))
        repeat {
            if Task.isCancelled { return nil }
            if let target = panelMoveTarget(in: window), target.scope == scope, target.handlesDownPress {
                let changed = id.map { target.navigationID != $0 } ?? (target !== previous)
                if previous == nil || changed || clock.now >= deadline { return target }
            }
            if clock.now >= deadline { return nil }
            try? await Task.sleep(for: .milliseconds(16))
        } while !Task.isCancelled
        return nil
    }

    private func clearPendingDowns() {
        downTask?.cancel()
        downTask = nil
        downScope = nil
        pendingDowns = 0
    }

    func prepareForPanelScroll() { viewport.release() }

    private func consumePanelTouch(_ touch: UITouch) -> Bool {
        if touch.phase == .began,
           let target = panelMoveTarget(in: touch.window), let window = target.window {
            let canMove = !heldPresses.allObjects.contains { $0.phase != .ended && $0.phase != .cancelled }
            let swipe = PanelSwipe(target: target, window: window, origin: touch.location(in: window),
                                   pressRevision: pressRevision, canMove: canMove)
            panelSwipes.setObject(swipe, forKey: touch)
        }
        guard let swipe = panelSwipes.object(forKey: touch) else { return false }
        if touch.phase == .moved, let window = swipe.window {
            swipe.position = touch.location(in: window)
        }
        if touch.phase == .ended || touch.phase == .cancelled {
            panelSwipes.removeObject(forKey: touch)
            if touch.phase == .ended, swipe.canMove, swipe.pressRevision == pressRevision, let window = swipe.window,
               let target = panelMoveTarget(in: window),
               target === swipe.target || (swipe.focusedItem != nil &&
                   UIFocusSystem.focusSystem(for: window)?.focusedItem === swipe.focusedItem) {
                let stillOnNativeControl = target.scope != nil ||
                    UIFocusSystem.focusSystem(for: window)?.focusedItem === swipe.focusedItem
                if stillOnNativeControl {
                    let translation = CGVector(dx: swipe.position.x - swipe.origin.x, dy: swipe.position.y - swipe.origin.y)
                    routePanelSwipe(translation, from: target)
                }
            }
        }
        return true
    }

    private func panelHasFocus(in window: UIWindow?) -> Bool {
        !UIAccessibility.isVoiceOverRunning && (panelMoveTarget(in: window) != nil ||
            panelInputRegions.allObjects.contains { $0.containsFocus(for: window) })
    }

    private func panelMoveTarget(in window: UIWindow?) -> TVPanelPressArea.Anchor? {
        guard !UIAccessibility.isVoiceOverRunning else { return nil }
        let regions = panelInputRegions.allObjects.filter { $0.acceptsInput(in: window) }
        if let boundary = regions.first(where: { $0.containsFocus(for: window) }),
           let window = boundary.window, let frame = TVPanelPressArea.Anchor.focusedFrame(in: window) {
            let center = CGPoint(x: frame.midX, y: frame.midY)
            let button = regions.filter { anchor in
                guard anchor.scope == boundary.scope, anchor.focusButton != nil, !anchor.bounds.isEmpty else { return false }
                let bounds = anchor.convert(anchor.bounds, to: window)
                return frame.height <= bounds.height + 24 && bounds.insetBy(dx: -4, dy: -4).contains(center)
            }.min { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
            if let button { return button }
        }
        return regions.first { $0.focusButton != nil && $0.handlesTouch }
            ?? regions.first { $0.focusButton == nil && $0.handlesTouch }
    }

    private func routePanelSwipe(_ translation: CGVector, from source: TVPanelPressArea.Anchor) {
        let direction = TVPanelSwipe.direction(for: translation, behavior: source.touchBehavior)
        recordPanelDiagnostic("tv-panel-swipe", values: [
            "dx": translation.dx, "dy": translation.dy, "accepted": direction != nil,
            "reading": source.touchBehavior == .scroll
        ])
        guard let direction else { return }
        clearPendingDowns()
        if source.focusButton != nil { moveToVisiblePanelButton(from: source, direction: direction) }
        else { source.move?(direction) }
    }

    func enterVisiblePanelButtons() {
        if let source = panelMoveTarget(in: nil), source.touchBehavior == .scroll {
            enterVisiblePanelButtons(from: source)
        }
    }

    private func enterVisiblePanelButtons(from source: TVPanelPressArea.Anchor) {
        let buttons = visiblePanelButtons(from: source).filter { $0.anchor.allowsReadingEntry }
        guard let top = buttons.min(by: { $0.frame.midY < $1.frame.midY }) else { return }
        let target = buttons.filter { abs($0.frame.midY - top.frame.midY) < min($0.frame.height, top.frame.height) / 2 }
            .max { $0.frame.maxX < $1.frame.maxX }
        if let target { focusPanelButton(target.anchor, from: source) }
    }

    func focusVisibleDiscussionAction<ID: Hashable>(_ id: ID, revealIfNeeded: Bool = false) -> Bool {
        guard let source = panelMoveTarget(in: nil), let window = source.window, let scope = source.scope else { return false }
        if let target = visiblePanelButtons(from: source).first(where: { $0.anchor.navigationID == AnyHashable(id) }) {
            focusPanelButton(target.anchor, from: source)
            return true
        }
        guard revealIfNeeded,
              let target = panelInputRegions.allObjects.first(where: {
                  $0.window === window && $0.scope == scope && $0.navigationID == AnyHashable(id)
                    && $0.focusButton != nil && !$0.bounds.isEmpty
              }), let scroll = target.enclosingScrollView else { return false }
        let frame = scroll.convert(target.bounds, from: target)
        let visible = scroll.bounds.inset(by: UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0))
        let dy = frame.maxY > visible.maxY ? frame.maxY - visible.maxY : min(0, frame.minY - visible.minY)
        let top = -scroll.adjustedContentInset.top
        let bottom = max(top, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        let offset = min(max(scroll.contentOffset.y + dy, top), bottom)
        viewport.release()
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: offset), animated: false)
        scroll.layoutIfNeeded()
        focusPanelButton(target, from: source)
        return true
    }

    private func visiblePanelButtons(from source: TVPanelPressArea.Anchor) -> [(anchor: TVPanelPressArea.Anchor, frame: CGRect)] {
        guard let window = source.window, let scope = source.scope else { return [] }
        let regions = panelInputRegions.allObjects.filter { $0.window === window && $0.scope == scope }
        guard let boundary = regions.first(where: \.isBoundary) else { return [] }
        let panel = boundary.convert(boundary.bounds, to: window).intersection(window.bounds)
        return regions.compactMap { anchor in
            guard let frame = anchor.visibleButtonFrame(in: window, within: panel) else { return nil }
            return (anchor, frame)
        }
    }

    private func moveToVisiblePanelButton(from source: TVPanelPressArea.Anchor, direction: MoveCommandDirection) {
        guard let window = source.window else { return }
        let origin = source.convert(source.bounds, to: window)
        let buttons = visiblePanelButtons(from: source)
        let target = buttons.compactMap { anchor, frame -> (anchor: TVPanelPressArea.Anchor, distance: CGFloat)? in
            guard anchor !== source else { return nil }
            guard let distance = TVPanelFocusGeometry.cost(from: origin, to: frame, direction: direction) else { return nil }
            return (anchor, distance)
        }.min { $0.distance < $1.distance }?.anchor
        recordPanelDiagnostic("tv-panel-button-swipe", values: ["visibleButtons": buttons.count, "targetFound": target != nil])
        if let target { focusPanelButton(target, from: source) }
    }

    private func focusPanelButton(_ target: TVPanelPressArea.Anchor, from source: TVPanelPressArea.Anchor) {
        if let scroll = target.enclosingScrollView ?? source.enclosingScrollView {
            viewport.hold(scroll) { [weak self] offset, restored in
                self?.recordPanelDiagnostic("tv-panel-focus-offset", values: ["offset": offset, "restored": restored])
            }
        }
        target.focusButton?()
    }
}

/// Own the viewport throughout a button focus update. UIKit can attempt to
/// recenter it while focus is animating; correct that write before the next
/// frame or remote press can use the wrong offset.
@MainActor final class TVPanelViewport {
    private var observation: NSKeyValueObservation?
    private var releaseTask: Task<Void, Never>?
    private var correcting = false

    func hold(_ scroll: UIScrollView, onCorrection: @escaping (CGFloat, CGFloat) -> Void) {
        release()
        let expected = scroll.contentOffset
        observation = scroll.observe(\.contentOffset, options: [.new]) { [weak self] view, _ in
            guard Thread.isMainThread else { return }
            MainActor.assumeIsolated {
                guard let self, !self.correcting, view.window != nil else { return }
                let top = -view.adjustedContentInset.top
                let bottom = max(top, view.contentSize.height - view.bounds.height + view.adjustedContentInset.bottom)
                let stable = min(max(expected.y, top), bottom)
                let attempted = view.contentOffset.y
                guard abs(attempted - stable) > 0.5 else { return }
                self.correcting = true
                UIView.performWithoutAnimation {
                    view.setContentOffset(CGPoint(x: view.contentOffset.x, y: stable), animated: false)
                }
                self.correcting = false
                onCorrection(attempted, stable)
            }
        }
        releaseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            self?.release()
        }
    }

    func release() {
        observation?.invalidate()
        observation = nil
        releaseTask?.cancel()
        releaseTask = nil
    }
}

enum TVPanelFocusGeometry {
    static func cost(from origin: CGRect, to target: CGRect, direction: MoveCommandDirection) -> CGFloat? {
        let x = target.midX - origin.midX
        let y = target.midY - origin.midY
        let forward: CGFloat
        let cross: CGFloat
        switch direction {
        case .up: (forward, cross) = (-y, abs(x))
        case .down: (forward, cross) = (y, abs(x))
        case .left: (forward, cross) = (-x, abs(y))
        case .right: (forward, cross) = (x, abs(y))
        default: return nil
        }
        return forward > 2 ? forward + 2 * cross : nil
    }
}
#endif
