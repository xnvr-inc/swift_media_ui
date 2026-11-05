import SwiftUI

public enum MediaSkeletonMetrics {
    public static let sweepDuration = 1.5
}

public extension View {
    func mediaSkeleton(_ label: String? = nil, fill: Color, highlight: Color) -> some View {
        modifier(MediaSkeletonShimmer(label: label, fill: fill, highlight: highlight))
    }
}

private struct MediaSkeletonShimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let label: String?
    let fill: Color
    let highlight: Color

    func body(content: Content) -> some View {
        content
            .foregroundStyle(fill)
            .overlay {
                if !reduceMotion && scenePhase == .active {
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        GeometryReader { geometry in
                            let period = MediaSkeletonMetrics.sweepDuration
                            let progress = context.date.timeIntervalSinceReferenceDate
                                .truncatingRemainder(dividingBy: period) / period
                            let width = geometry.size.width
                            LinearGradient(colors: [.clear, highlight, .clear], startPoint: .leading, endPoint: .trailing)
                                .frame(width: width / 2)
                                .offset(x: width * (1.5 * progress - 0.5))
                        }
                    }
                    .mask { content }
                }
            }
            .allowsHitTesting(false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label ?? "")
            .accessibilityHidden(label == nil)
    }
}

public struct MediaStatusView: View {
    private let title: String
    private let message: String
    private let symbol: String

    public init(title: String, message: String, symbol: String) {
        self.title = title
        self.message = message
        self.symbol = symbol
    }

    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Text(message).foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

public struct MediaRetryView: View {
    private let message: String
    private let retry: () -> Void

    public init(message: String, retry: @escaping () -> Void) {
        self.message = message
        self.retry = retry
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(message).foregroundStyle(.secondary)
            Button("다시 시도", action: retry)
        }
        .padding(.vertical)
    }
}
