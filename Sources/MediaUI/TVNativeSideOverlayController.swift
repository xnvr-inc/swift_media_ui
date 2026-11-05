#if os(tvOS)
import SwiftUI
import UIKit

@MainActor public protocol TVSideOverlayBackHandler: AnyObject {
    func handlePanelBack() -> Bool
}

/// A native glass inspector that keeps the current screen visible beside it.
public final class TVNativeSideOverlayController: UIViewController, UIViewControllerTransitioningDelegate {
    private let content: UIViewController
    private let onDismiss: (() -> Void)?
    private var reportedDismissal = false
    private var swipeFocusTarget: (any UIFocusItem)?
    private let surface: UIColor
    private let backdrop: UIColor

    public init(content: UIViewController, surface: UIColor, backdrop: UIColor, onDismiss: (() -> Void)? = nil) {
        self.content = content
        self.surface = surface
        self.backdrop = backdrop
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = self
        isModalInPresentation = true
    }
    public required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "tv.side.overlay"
        view.accessibilityViewIsModal = true
        let back = UITapGestureRecognizer(target: self, action: #selector(handleBack))
        back.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
        back.delaysTouchesBegan = true
        view.addGestureRecognizer(back)
        let material: UIVisualEffect
        if #available(tvOS 26, *) { material = UIGlassEffect(style: .regular) }
        else { material = UIBlurEffect(style: .dark) }
        let glass = UIVisualEffectView(effect: material)
        glass.layer.cornerRadius = TVMediaLayout.Corner.modal
        glass.layer.cornerCurve = .continuous
        glass.clipsToBounds = true
        glass.contentView.backgroundColor = surface.withAlphaComponent(0.42)
        glass.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(glass)
        addChild(content)
        content.view.backgroundColor = .clear
        content.view.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView.addSubview(content.view)
        NSLayoutConstraint.activate([
            glass.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glass.topAnchor.constraint(equalTo: view.topAnchor),
            glass.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            content.view.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor),
            content.view.topAnchor.constraint(equalTo: glass.contentView.topAnchor),
            content.view.bottomAnchor.constraint(equalTo: glass.contentView.bottomAnchor),
        ])
        content.didMove(toParent: self)

        let input = TVPanelPressArea.Anchor(frame: .zero)
        input.isUserInteractionEnabled = false
        input.inputFocused = { [weak self] in self?.ownsFocus(in: nil) == true }
        input.move = { [weak self] direction in
            guard let self, let source = UIFocusSystem.focusSystem(for: self)?.focusedItem else { return }
            if let control = source as? any TVPanelHorizontalSwipeControl,
               direction == .left || direction == .right {
                control.adjustFromPanelSwipe(increasing: direction == .right)
            } else {
                self.moveControlFocus(from: source, direction: direction)
            }
        }
        view.addSubview(input)
    }

    public override var preferredFocusEnvironments: [UIFocusEnvironment] {
        if let swipeFocusTarget { return [swipeFocusTarget] }
        return [content]
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    func ownsFocus(in eventWindow: UIWindow?) -> Bool {
        guard let window = viewIfLoaded?.window, window.isKeyWindow,
              eventWindow == nil || eventWindow === window,
              presentedViewController == nil,
              let item = UIFocusSystem.focusSystem(for: window)?.focusedItem else { return false }
        if let focusedView = item as? UIView, focusedView.isDescendant(of: view) { return true }
        let frame: CGRect
        if let space = item.focusItemContainer?.coordinateSpace {
            frame = window.convert(item.frame, from: space)
        } else if let focusedView = item as? UIView {
            frame = focusedView.convert(focusedView.bounds, to: window)
        } else {
            return false
        }
        return view.convert(view.bounds, to: window).contains(CGPoint(x: frame.midX, y: frame.midY))
    }

    public func moveControlFocus(from source: any UIFocusItem, direction: MoveCommandDirection) {
        guard let system = UIFocusSystem.focusSystem(for: self), system.focusedItem === source,
              let origin = panelFrame(of: source) else { return }
        var candidates = view.focusItems(in: view.bounds)
        if let container = source.focusItemContainer {
            candidates += container.focusItems(in: view.convert(view.bounds, to: container.coordinateSpace))
        }
        candidates += nativePanelControls(in: content.view)
        let target = candidates.compactMap { item -> (item: any UIFocusItem, cost: CGFloat)? in
            guard item !== source, item.canBecomeFocused, let frame = panelFrame(of: item),
                  frame.height < view.bounds.height / 2,
                  isVisibleControl(item, frame: frame),
                  let cost = TVPanelFocusGeometry.cost(from: origin, to: frame, direction: direction) else { return nil }
            return (item, cost)
        }.min { $0.cost < $1.cost }?.item
        guard let target else { return }
        swipeFocusTarget = target
        defer { swipeFocusTarget = nil }
        system.requestFocusUpdate(to: self)
        system.updateFocusIfNeeded()
    }

    private func nativePanelControls(in parent: UIView) -> [UIView] {
        parent.subviews.flatMap { child -> [UIView] in
            guard !child.isHidden, child.alpha > 0 else { return [] }
            let controls = nativePanelControls(in: child)
            if child is UIControl || child is UICollectionViewCell { return [child] + controls }
            return controls
        }
    }

    private func panelFrame(of item: any UIFocusItem) -> CGRect? {
        if let item = item as? UIView { return item.convert(item.bounds, to: view) }
        if let space = item.focusItemContainer?.coordinateSpace { return view.convert(item.frame, from: space) }
        return nil
    }

    private func isVisibleControl(_ item: any UIFocusItem, frame: CGRect) -> Bool {
        isVisible(frame, from: (item as? UIView) ?? (item.focusItemContainer?.coordinateSpace as? UIView))
    }

    private func isVisible(_ frame: CGRect, from source: UIView?) -> Bool {
        guard view.bounds.insetBy(dx: -1, dy: -1).contains(frame) else { return false }
        var ancestor = source
        while let candidate = ancestor, candidate !== view {
            if candidate is UIScrollView,
               !candidate.convert(candidate.bounds, to: view).insetBy(dx: -1, dy: -1).contains(frame) { return false }
            ancestor = candidate.superview
        }
        return true
    }

    @objc private func handleBack() {
        guard presentedViewController == nil else { return }
        if (content as? TVSideOverlayBackHandler)?.handlePanelBack() != true {
            dismiss(animated: true)
        }
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || presentingViewController == nil, !reportedDismissal {
            reportedDismissal = true
            onDismiss?()
        }
    }

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        TVNativeSideOverlayPresentationController(presentedViewController: presented, presenting: presenting, color: backdrop)
    }
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        TVSideOverlayTransition(presenting: true)
    }
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        TVSideOverlayTransition(presenting: false)
    }
}

/// Optional control-specific action within the otherwise shared swipe route.
@MainActor public protocol TVPanelHorizontalSwipeControl: AnyObject {
    func adjustFromPanelSwipe(increasing: Bool)
}

private final class TVNativeSideOverlayPresentationController: UIPresentationController {
    private let backdrop = UIView()

    init(presentedViewController: UIViewController, presenting: UIViewController?, color: UIColor) {
        super.init(presentedViewController: presentedViewController, presenting: presenting)
        backdrop.backgroundColor = color
    }
    override var shouldRemovePresentersView: Bool { false }
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let bounds = containerView?.bounds else { return .zero }
        let inset = TVPanelMetrics.outerInset
        let width = TVPanelMetrics.width(in: bounds.width)
        return CGRect(x: bounds.maxX - width - inset, y: bounds.minY + inset,
                      width: width, height: TVPanelMetrics.height(in: bounds.height))
    }
    override func presentationTransitionWillBegin() {
        guard let containerView else { return }
        backdrop.frame = containerView.bounds
        backdrop.alpha = 0
        containerView.insertSubview(backdrop, at: 0)
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in self.backdrop.alpha = 1 })
    }
    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in self.backdrop.alpha = 0 })
    }
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed { backdrop.removeFromSuperview() }
    }
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        backdrop.frame = containerView?.bounds ?? .zero
        if presentedView?.transform == .identity { presentedView?.frame = frameOfPresentedViewInContainerView }
    }
}

private final class TVSideOverlayTransition: NSObject, UIViewControllerAnimatedTransitioning {
    private let presenting: Bool
    init(presenting: Bool) { self.presenting = presenting }
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        TVPanelMetrics.duration(reducedMotion: UIAccessibility.isReduceMotionEnabled)
    }
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = presenting ? .to : .from
        guard let controller = context.viewController(forKey: key), let view = context.view(forKey: presenting ? .to : .from) else {
            context.completeTransition(false); return
        }
        let container = context.containerView
        if presenting {
            view.frame = context.finalFrame(for: controller)
            container.addSubview(view)
        }
        let reduced = UIAccessibility.isReduceMotionEnabled
        let offscreen = CGAffineTransform(translationX: container.bounds.maxX - view.frame.minX, y: 0)
        if presenting { view.transform = reduced ? .identity : offscreen; view.alpha = reduced ? 0 : 1 }
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0, options: [.curveEaseInOut]) {
            view.transform = self.presenting || reduced ? .identity : offscreen
            view.alpha = !self.presenting && reduced ? 0 : 1
        } completion: { _ in
            let completed = !context.transitionWasCancelled
            view.transform = .identity; view.alpha = 1
            if completed && !self.presenting { view.removeFromSuperview() }
            context.completeTransition(completed)
        }
    }
}
#endif
