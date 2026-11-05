#if os(iOS)
import SwiftUI
import UIKit

extension MediaMiniPlayerLayout {
    /// Measures a geometry reader inside the host's safe area. The reader's
    /// size already reflects the space proposed by the host. A host can
    /// provide the top of its tab bar in global coordinates.
    public static func safeArea(in geometry: GeometryProxy, bottomBoundary: CGFloat? = nil) -> CGRect {
        let bottom = min(geometry.size.height,
                         bottomBoundary.map { $0 - geometry.frame(in: .global).minY } ?? geometry.size.height)
        return CGRect(origin: .zero, size: CGSize(width: geometry.size.width, height: max(0, bottom)))
    }
}

/// Adds a drag to a live mini-player without changing the identity of its content.
public struct MediaMiniPlayerDock<Content: View>: View {
    @Binding private var corner: MediaMiniPlayerCorner
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isDragging = false
    @State private var offset: CGSize = .zero
    @State private var isDismissing = false

    private let layout: MediaMiniPlayerLayout
    private let allowsDragging: Bool
    private let reducesMotion: Bool
    private let onDismiss: (() -> Void)?
    private let moveActionTitle: LocalizedStringKey
    private let content: (CGSize) -> Content

    public init(corner: Binding<MediaMiniPlayerCorner>, layout: MediaMiniPlayerLayout,
                allowsDragging: Bool = true, reducesMotion: Bool = false,
                onDismiss: (() -> Void)? = nil,
                moveActionTitle: LocalizedStringKey = "Move mini-player to next corner",
                @ViewBuilder content: @escaping (CGSize) -> Content) {
        _corner = corner
        self.layout = layout
        self.allowsDragging = allowsDragging
        self.reducesMotion = reducesMotion
        self.onDismiss = onDismiss
        self.moveActionTitle = moveActionTitle
        self.content = content
    }

    public var body: some View {
        let frame = layout.frame(at: corner, offset: offset)
        content(frame.size)
            .frame(width: frame.width, height: frame.height)
            .contentShape(.rect(cornerRadius: 14))
            .simultaneousGesture(movement)
            .allowsHitTesting(!isDismissing)
            .accessibilityAction(named: Text(moveActionTitle), moveToNextCorner)
            .opacity(isDismissing ? 0 : 1)
            .position(x: frame.midX + (isDismissing && !motionReduced ? layout.bounds.width : 0), y: frame.midY)
            .onChange(of: isDragging) { _, active in
                if !active && offset != .zero { settle(at: corner) }
            }
            .onChange(of: allowsDragging) { _, allowed in
                if !allowed { offset = .zero }
            }
    }

    private var motionReduced: Bool { reduceMotion || reducesMotion }

    private var movement: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($isDragging) { _, active, _ in active = allowsDragging && !isDismissing }
            .onChanged { drag in
                guard allowsDragging, !isDismissing else { return }
                offset = drag.translation
            }
            .onEnded { drag in
                guard allowsDragging, !isDismissing else { return }
                if let onDismiss, layout.shouldDismiss(from: corner, offset: drag.translation,
                                                       predicted: drag.predictedEndTranslation) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: motionReduced ? 0.12 : 0.20), completionCriteria: .logicallyComplete) {
                        isDismissing = true
                    } completion: {
                        onDismiss()
                    }
                } else {
                    settle(at: layout.snapCorner(from: corner, offset: drag.translation,
                                                 predicted: drag.predictedEndTranslation))
                }
            }
    }

    private func settle(at target: MediaMiniPlayerCorner) {
        if target != corner { UISelectionFeedbackGenerator().selectionChanged() }
        withAnimation(motionReduced ? nil : .easeOut(duration: 0.56)) {
            corner = target
            offset = .zero
        }
    }

    private func moveToNextCorner() {
        let corners = MediaMiniPlayerCorner.allCases
        guard let current = corners.firstIndex(of: corner) else { return }
        settle(at: corners[(current + 1) % corners.count])
    }
}
#endif
