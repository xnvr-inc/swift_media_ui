#if os(iOS)
import AVKit
import SwiftUI

@MainActor
final class MediaPlayerPictureInPicture: NSObject, ObservableObject, AVPictureInPictureControllerDelegate {
    @Published private(set) var isAvailable = false
    @Published private(set) var isActive = false
    @Published private(set) var isStarting = false

    private var layers: [String: AVPlayerLayer] = [:]
    private var singleSourceID: String?
    private var inline: AVPictureInPictureController?
    private var availability: NSKeyValueObservation?
    private var restore: (() -> Void)?

    func register(_ layer: AVPlayerLayer, for id: String) {
        layers[id] = layer
        if id == singleSourceID { configureInline() }
    }

    func updateSourceIDs(_ ids: [String]) {
        layers = layers.filter { ids.contains($0.key) }
        let newID = ids.count == 1 ? ids.first : nil
        if singleSourceID != newID {
            stop()
            singleSourceID = newID
        }
        configureInline()
    }

    private func configureInline() {
        guard !isActive, !isStarting, AVPictureInPictureController.isPictureInPictureSupported(),
              let singleSourceID, let layer = layers[singleSourceID], inline?.playerLayer !== layer
        else { return }
        stop()
        guard let controller = AVPictureInPictureController(playerLayer: layer) else { return }
        inline = controller
        controller.delegate = self
        availability = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
            [weak self] controller, _ in
            Task { @MainActor in
                guard let self, self.inline === controller else { return }
                self.isAvailable = controller.isPictureInPicturePossible
            }
        }
    }

    func toggle(restore: (() -> Void)?) {
        if isActive { inline?.stopPictureInPicture(); return }
        guard isAvailable, !isStarting, let inline else { return }
        self.restore = restore
        isStarting = true
        inline.startPictureInPicture()
    }

    func stop() {
        availability?.invalidate()
        availability = nil
        inline?.delegate = nil
        inline?.stopPictureInPicture()
        inline = nil
        restore = nil
        isActive = false
        isStarting = false
        isAvailable = false
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self, self.inline === controller else { return }
            self.isActive = true
            self.isStarting = false
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self, self.inline === controller else { return }
            self.isActive = false
            self.isStarting = false
            self.restore = nil
            self.configureInline()
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.inline === controller else { return }
            self.isStarting = false
            self.restore = nil
            self.configureInline()
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.inline === controller else { completionHandler(false); return }
            self.restore?()
            completionHandler(true)
        }
    }
}

@MainActor open class MediaPiPCanvas: UIView {
    public override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    public var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }

    public override init(frame: CGRect) {
        super.init(frame: frame)
        displayLayer.videoGravity = .resizeAspect
        backgroundColor = .black
        var timebase: CMTimebase?
        if CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault,
            sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase) == noErr, let timebase {
            displayLayer.controlTimebase = timebase
            CMTimebaseSetTime(timebase, time: CMClockGetTime(CMClockGetHostTimeClock()))
            CMTimebaseSetRate(timebase, rate: 1)
        }
    }

    public required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

struct MediaPiPCompositeSurface: UIViewRepresentable {
    let canvas: MediaPiPCanvas

    func makeUIView(context: Context) -> MediaPiPCanvas { canvas }
    func updateUIView(_ view: MediaPiPCanvas, context: Context) {}
}
#endif
