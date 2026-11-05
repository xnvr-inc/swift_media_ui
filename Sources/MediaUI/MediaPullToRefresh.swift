#if os(iOS)
import SwiftUI
import UIKit

public extension View {
  func mediaPullToRefresh(_ refresh: @escaping @MainActor () async -> Void) -> some View {
    background { MediaRefreshControl(refresh: refresh) }
  }
}

private struct MediaRefreshControl: UIViewRepresentable {
  let refresh: @MainActor () async -> Void

  func makeUIView(context: Context) -> Attachment { Attachment() }

  func updateUIView(_ attachment: Attachment, context: Context) {
    attachment.refresh = refresh
    attachment.attach()
  }

  static func dismantleUIView(_ attachment: Attachment, coordinator: ()) {
    attachment.detach()
  }

  final class Attachment: UIView {
    var refresh: (@MainActor () async -> Void)?
    private let control = UIRefreshControl()
    private weak var scrollView: UIScrollView?
    private var task: Task<Void, Never>?
    private var startedAtTop = false

    init() {
      super.init(frame: .zero)
      isUserInteractionEnabled = false
      accessibilityElementsHidden = true
      control.tintColor = .secondaryLabel
      control.addTarget(self, action: #selector(refreshRequested), for: .valueChanged)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToSuperview() {
      super.didMoveToSuperview()
      attach()
    }

    override func didMoveToWindow() {
      super.didMoveToWindow()
      if window != nil { attach() } else { detach() }
    }

    func attach() {
      guard window != nil else { return }
      var ancestor = superview
      while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
      guard let scroll = ancestor as? UIScrollView else { return }
      if scrollView === scroll {
        if scroll.refreshControl == nil { scroll.refreshControl = control }
        return
      }
      detach()
      guard scroll.refreshControl == nil else { return }
      scroll.alwaysBounceVertical = true
      scroll.refreshControl = control
      scroll.panGestureRecognizer.addTarget(self, action: #selector(pulledFeed(_:)))
      scrollView = scroll
    }

    func detach() {
      // SwiftUI can rebuild the attachment while the feed is loading.
      startedAtTop = false
      control.endRefreshing()
      scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(pulledFeed(_:)))
      if scrollView?.refreshControl === control { scrollView?.refreshControl = nil }
      scrollView = nil
    }

    @objc private func pulledFeed(_ gesture: UIPanGestureRecognizer) {
      guard let scrollView else { return }
      switch gesture.state {
      case .began:
        startedAtTop = scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + 2
      case .ended:
        defer { startedAtTop = false }
        let pull = gesture.translation(in: scrollView)
        // The system action can be skipped when the entire feed fits onscreen.
        guard startedAtTop, pull.y >= 120, pull.y > abs(pull.x), !control.isRefreshing, task == nil else { return }
        control.beginRefreshing()
        refreshRequested()
      case .cancelled, .failed:
        startedAtTop = false
      default:
        break
      }
    }

    @objc private func refreshRequested() {
      guard task == nil, let refresh else { return }
      task = Task { [weak self] in
        await refresh()
        self?.control.endRefreshing()
        self?.task = nil
      }
    }
  }
}
#endif
