#if os(iOS)
import SwiftUI
import UIKit

public enum MediaReadingSheetLayout {
    /// Fits a horizontal player above a sheet with at least half the viewport available for reading.
    public static func playerHeight(in viewport: CGSize) -> CGFloat {
        min(viewport.width / MediaCardMetrics.landscapeAspect, viewport.height / 2)
    }
}

/// An edge-attached reading sheet for a full-screen SwiftUI or over-full-screen UIKit presentation.
public struct MediaReadingSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGFloat = 0
    private let surface: Color
    private let heightBelowPlayer: CGFloat?
    private let close: (() -> Void)?
    private let content: Content

    public init(surface: Color, heightBelowPlayer: CGFloat? = nil, close: (() -> Void)? = nil,
                @ViewBuilder content: () -> Content) {
        self.surface = surface
        self.heightBelowPlayer = heightBelowPlayer
        self.close = close
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            let height = min(heightBelowPlayer.flatMap { $0 > 0 ? $0 : nil } ?? geometry.size.height * 2 / 3,
                             geometry.size.height)
            let shape = UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.38 * max(0, 1 - offset / max(1, height)))
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    Capsule()
                        .fill(.secondary.opacity(0.45))
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                        .frame(height: 20)
                        .accessibilityHidden(true)
                    content
                }
                .frame(maxWidth: .infinity)
                .frame(height: height, alignment: .top)
                .clipShape(shape)
                .background {
                    shape.fill(surface).ignoresSafeArea(.container, edges: [.horizontal, .bottom])
                }
                .background {
                    ReadingSheetPan(changed: { offset = max(0, $0) }, ended: { distance, velocity in
                        if distance >= min(height / 4, 120) || (distance > 16 && velocity > 900) {
                            closeSheet()
                        } else {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { offset = 0 }
                        }
                    })
                }
                .offset(y: offset)
                .accessibilityAction(.escape, closeSheet)
                .accessibilityAction(named: Text("닫기"), closeSheet)
            }
        }
        .presentationBackground(.clear)
    }

    private func closeSheet() {
        if let close { close() } else { dismiss() }
    }
}

private struct ReadingSheetPan: UIViewRepresentable {
    let changed: (CGFloat) -> Void
    let ended: (CGFloat, CGFloat) -> Void

    func makeUIView(context: Context) -> Attachment { Attachment() }

    func updateUIView(_ attachment: Attachment, context: Context) {
        attachment.changed = changed
        attachment.ended = ended
    }

    static func dismantleUIView(_ attachment: Attachment, coordinator: ()) {
        attachment.detach()
    }

    final class Attachment: UIView, UIGestureRecognizerDelegate {
        var changed: ((CGFloat) -> Void)?
        var ended: ((CGFloat, CGFloat) -> Void)?
        private let pan = UIPanGestureRecognizer()
        private weak var scroll: UIScrollView?
        private var wasBouncing: Bool?

        init() {
            super.init(frame: .zero)
            isUserInteractionEnabled = false
            accessibilityElementsHidden = true
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            pan.addTarget(self, action: #selector(pulled(_:)))
        }

        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard pan.view !== window else { return }
            detach()
            window?.addGestureRecognizer(pan)
        }

        func detach() {
            restoreBounce()
            pan.view?.removeGestureRecognizer(pan)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard bounds.contains(touch.location(in: self)) else { return false }
            scroll = verticalScroll(under: touch.view)
            // The scroll view retains drags that start below its top edge.
            guard let scroll else { return true }
            return scroll.contentOffset.y <= -scroll.adjustedContentInset.top + 1
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let velocity = pan.velocity(in: window)
            return velocity.y > abs(velocity.x)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            other === scroll?.panGestureRecognizer
        }

        private func verticalScroll(under view: UIView?) -> UIScrollView? {
            var ancestor = view
            while let view = ancestor, view !== window {
                if let scroll = view as? UIScrollView, scroll.isScrollEnabled {
                    let inset = scroll.adjustedContentInset
                    let contentHeight = scroll.contentSize.height + inset.top + inset.bottom
                    if scroll.alwaysBounceVertical || contentHeight > scroll.bounds.height + 1 { return scroll }
                }
                ancestor = view.superview
            }
            return nil
        }

        @objc private func pulled(_ gesture: UIPanGestureRecognizer) {
            let distance = gesture.translation(in: window).y
            switch gesture.state {
            case .began:
                wasBouncing = scroll?.bounces
                scroll?.bounces = false
                changed?(distance)
            case .changed:
                changed?(distance)
            case .ended:
                restoreBounce()
                ended?(distance, gesture.velocity(in: window).y)
            case .cancelled, .failed:
                restoreBounce()
                ended?(0, 0)
            default:
                break
            }
        }

        private func restoreBounce() {
            if let wasBouncing { scroll?.bounces = wasBouncing }
            wasBouncing = nil
            scroll = nil
        }
    }
}
#endif
