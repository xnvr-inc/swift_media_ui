#if os(macOS)
import AppKit
import SwiftUI

/// AppKit moves the existing backing view; SwiftUI state changes only on mouse-up.
public struct MacChatPanelContainer<Content: View>: NSViewRepresentable {
    let panelFrame: CGRect
    let usableBounds: CGRect
    let onCommit: (CGRect) -> Void
    private let content: () -> Content

    public init(panelFrame: CGRect, usableBounds: CGRect, onCommit: @escaping (CGRect) -> Void,
                @ViewBuilder content: @escaping () -> Content) {
        self.panelFrame = panelFrame
        self.usableBounds = usableBounds
        self.onCommit = onCommit
        self.content = content
    }

    public func makeNSView(context: Context) -> MacChatPanelNativeView<Content> {
        MacChatPanelNativeView(rootView: content())
    }

    public func updateNSView(_ view: MacChatPanelNativeView<Content>, context: Context) {
        view.hosting.rootView = content()
        view.configure(frame: panelFrame, usableBounds: usableBounds, onCommit: onCommit)
    }
}

@MainActor public final class MacChatPanelNativeView<Content: View>: NSView {
    public enum DragKind { case move, resize }
    let hosting: NSHostingView<Content>
    private let panel = FlippedPanelView()
    private let moveHandle = ChatPanelMouseHandle()
    private let resizeHandle = ChatPanelMouseHandle()
    private var usableBounds = CGRect.zero
    private var commit: ((CGRect) -> Void)?
    private var drag: (kind: DragKind, point: CGPoint, frame: CGRect)?
    public var panelFrame: CGRect { panel.frame }
    public override var isFlipped: Bool { true }

    public init(rootView: Content) {
        hosting = NSHostingView(rootView: rootView)
        super.init(frame: .zero)
        panel.wantsLayer = true
        hosting.sizingOptions = []
        hosting.autoresizingMask = [.width, .height]
        addSubview(panel)
        panel.addSubview(hosting)
        panel.addSubview(moveHandle)
        panel.addSubview(resizeHandle)
        moveHandle.toolTip = "드래그로 채팅 위치 이동"
        resizeHandle.toolTip = "드래그로 채팅 크기 조절"
        moveHandle.cursor = .openHand
        if #available(macOS 15.0, *) {
            resizeHandle.cursor = .frameResize(position: .bottomRight, directions: .all)
        } else { resizeHandle.cursor = .crosshair }
        resizeHandle.draggingCursor = resizeHandle.cursor
        moveHandle.onDown = { [weak self] in self?.beginDrag(.move, at: $0) }
        resizeHandle.onDown = { [weak self] in self?.beginDrag(.resize, at: $0) }
        for handle in [moveHandle, resizeHandle] {
            handle.onDrag = { [weak self] in self?.updateDrag(to: $0) }
            handle.onUp = { [weak self] in self?.endDrag() }
        }
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    public func configure(frame: CGRect, usableBounds: CGRect, onCommit: @escaping (CGRect) -> Void) {
        self.usableBounds = usableBounds
        commit = onCommit
        if drag == nil { apply(frame) }
    }

    public func beginDrag(_ kind: DragKind, at point: CGPoint) { drag = (kind, point, panel.frame) }

    public func updateDrag(to point: CGPoint) {
        guard let drag else { return }
        // Window coordinates remain fixed while the handle itself moves, and AppKit's Y is upward.
        let translation = CGSize(width: point.x - drag.point.x, height: drag.point.y - point.y)
        let original = ChatOverlayGeometry(frame: drag.frame, in: usableBounds)
        let minimum = CGSize(width: 180, height: 128)
        let value: ChatOverlayGeometry
        switch drag.kind {
        case .move: value = original.moved(by: translation, in: usableBounds, minimumSize: minimum)
        case .resize: value = original.resized(by: translation, in: usableBounds, minimumSize: minimum)
        }
        apply(value.frame(in: usableBounds, minimumSize: minimum))
    }

    public func endDrag() {
        guard let original = drag else { return }
        drag = nil
        if panel.frame != original.frame { commit?(panel.frame) }
    }

    private func apply(_ frame: CGRect) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if panel.frame.size == frame.size { panel.setFrameOrigin(frame.origin) }
        else {
            panel.frame = frame
            hosting.frame = panel.bounds
            moveHandle.frame = CGRect(x: 12, y: 8, width: max(0, frame.width - 64), height: 32)
            resizeHandle.frame = CGRect(x: max(0, frame.width - 30), y: max(0, frame.height - 30), width: 28, height: 28)
        }
        CATransaction.commit()
    }

    public override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === self ? nil : hit
    }
}

private final class FlippedPanelView: NSView { override var isFlipped: Bool { true } }

private final class ChatPanelMouseHandle: NSView {
    var onDown: ((CGPoint) -> Void)?
    var onDrag: ((CGPoint) -> Void)?
    var onUp: (() -> Void)?
    var cursor: NSCursor = .openHand
    var draggingCursor: NSCursor = .closedHand

    override func resetCursorRects() { addCursorRect(bounds, cursor: cursor) }
    override func mouseDown(with event: NSEvent) { draggingCursor.set(); onDown?(event.locationInWindow) }
    override func mouseDragged(with event: NSEvent) { onDrag?(event.locationInWindow) }
    override func mouseUp(with event: NSEvent) { onUp?(); cursor.set() }
}
#endif
