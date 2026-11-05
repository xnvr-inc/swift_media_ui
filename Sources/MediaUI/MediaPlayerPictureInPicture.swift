#if os(iOS)
import AVKit
import SwiftUI

@MainActor
final class MediaPlayerPictureInPicture: NSObject, ObservableObject,
    AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    @Published private(set) var isAvailable = false
    @Published private(set) var isActive = false
    @Published private(set) var isStarting = false
    @Published private(set) var isPresentingComposite = false

    let canvas = MediaPiPCanvas(frame: .zero)
    var isUsingComposite: Bool { isActive && composite != nil }
    var featuredID: String?
    private var sessions: [MediaPlayerSession] = []
    private var selectedID: String?
    private var layers: [String: AVPlayerLayer] = [:]
    private var outputs: [String: MediaPiPVideoOutput] = [:]
    private var inline: AVPictureInPictureController?
    private var inlineID: String?
    private var composite: AVPictureInPictureController?
    private var availability: NSKeyValueObservation?
    private var renderTask: Task<Void, Never>?
    private var restore: (() -> Void)?
    private let compositor = MediaPiPCompositor()
    private nonisolated let playback = PlaybackState()

    func register(_ layer: AVPlayerLayer, for id: String) {
        layers[id] = layer
        if id == selectedID { configureInline() }
    }

    func updateSessions(_ sessions: [MediaPlayerSession]) {
        self.sessions = sessions
        let ids = Set(sessions.map(\.id))
        layers = layers.filter { ids.contains($0.key) }
        for id in Array(outputs.keys) where !ids.contains(id) {
            outputs.removeValue(forKey: id)?.detach()
        }
        if sessions.isEmpty || (composite == nil && inlineID.map { !ids.contains($0) } == true) {
            stop()
        }
    }

    func select(_ id: String?) {
        selectedID = id
        configureInline()
    }

    private func configureInline() {
        guard !isActive, !isStarting else { return }
        availability?.invalidate()
        isAvailable = false
        guard AVPictureInPictureController.isPictureInPictureSupported(),
              let selectedID, let layer = layers[selectedID],
              let controller = AVPictureInPictureController(playerLayer: layer) else {
            inline = nil
            inlineID = nil
            return
        }
        inline = controller
        inlineID = selectedID
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
        if isActive {
            (composite ?? inline)?.stopPictureInPicture()
            return
        }
        guard isAvailable, !isStarting else { return }
        self.restore = restore
        isStarting = true
        if sessions.count < 2 {
            startInline()
            return
        }

        renderTask = Task { [weak self] in
            for _ in 0..<20 {
                guard !Task.isCancelled, await self?.prepareComposite() != true else { return }
                try? await Task.sleep(for: .milliseconds(67))
            }
            guard !Task.isCancelled else { return }
            self?.resetComposite()
            self?.startInline()
        }
    }

    private func prepareComposite() async -> Bool {
        guard await render(), !Task.isCancelled else { return false }
        if composite == nil {
            let controller = AVPictureInPictureController(
                contentSource: .init(sampleBufferDisplayLayer: canvas.displayLayer, playbackDelegate: self)
            )
            controller.delegate = self
            controller.requiresLinearPlayback = true
            composite = controller
            isPresentingComposite = true
        }
        guard let composite, composite.isPictureInPicturePossible else { return false }
        composite.startPictureInPicture()
        return true
    }

    private func render() async -> Bool {
        guard !sessions.isEmpty else { return false }
        var frames: [MediaPiPFrame] = []
        for session in sessions {
            let player = session.player
            guard let item = player.currentItem else { return false }
            if outputs[session.id]?.item !== item {
                outputs.removeValue(forKey: session.id)?.detach()
                outputs[session.id] = MediaPiPVideoOutput(item: item)
            }
            guard let frame = outputs[session.id]?.read(at: player.currentTime(), playing: player.rate != 0)
            else { return false }
            frames.append(frame)
        }
        let paused = !sessions.contains(where: \.wantsPlayback)
        if playback.setPaused(paused) { composite?.invalidatePlaybackState() }
        let featuredIndex = sessions.firstIndex { $0.id == featuredID }
        guard let sample = await compositor.render(frames, featuredIndex: featuredIndex),
              !Task.isCancelled else { return false }
        let layer = canvas.displayLayer
        if layer.status == .failed { layer.flush() }
        if layer.isReadyForMoreMediaData { layer.enqueue(sample) }
        return true
    }

    private func startInline() {
        guard let inline, inline.isPictureInPicturePossible else {
            isStarting = false
            configureInline()
            return
        }
        inline.startPictureInPicture()
    }

    private func resetComposite() {
        renderTask?.cancel()
        renderTask = nil
        composite?.delegate = nil
        composite?.stopPictureInPicture()
        composite = nil
        for output in outputs.values { output.detach() }
        outputs.removeAll()
        canvas.displayLayer.flushAndRemoveImage()
        isPresentingComposite = false
    }

    func stop() {
        resetComposite()
        inline?.delegate = nil
        inline?.stopPictureInPicture()
        inline = nil
        inlineID = nil
        restore = nil
        availability?.invalidate()
        availability = nil
        isActive = false
        isStarting = false
        isAvailable = false
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self, self.composite === controller || self.inline === controller else { return }
            self.isActive = true
            self.isStarting = false
            self.isPresentingComposite = false
            if self.composite === controller {
                self.renderTask?.cancel()
                self.renderTask = Task { [weak self] in
                    while !Task.isCancelled, self?.isActive == true {
                        _ = await self?.render()
                        try? await Task.sleep(for: .milliseconds(67))
                    }
                }
            }
        }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        Task { @MainActor [weak self] in
            guard let self, self.composite === controller || self.inline === controller else { return }
            self.isActive = false
            self.isStarting = false
            self.resetComposite()
            self.restore = nil
            self.configureInline()
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if self.composite === controller {
                self.resetComposite()
                self.startInline()
            } else if self.inline === controller {
                self.isStarting = false
                self.configureInline()
            }
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.composite === controller || self.inline === controller
            else { completionHandler(false); return }
            self.restore?()
            completionHandler(true)
        }
    }

    nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
        Task { @MainActor [weak self] in
            guard let self, self.composite === controller else { return }
            for session in self.sessions { session.setPlaying(playing) }
            _ = self.playback.setPaused(!playing)
            controller.invalidatePlaybackState()
        }
    }

    nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
        playback.isPaused
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {}

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void
    ) { completionHandler() }

    private final class PlaybackState: @unchecked Sendable {
        private let lock = NSLock()
        private var paused = true

        var isPaused: Bool { lock.withLock { paused } }

        func setPaused(_ value: Bool) -> Bool {
            lock.withLock {
                let changed = paused != value
                paused = value
                return changed
            }
        }
    }
}

@MainActor final class MediaPiPCanvas: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }
    var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }

    override init(frame: CGRect) {
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

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
}

struct MediaPiPCompositeSurface: UIViewRepresentable {
    let canvas: MediaPiPCanvas

    func makeUIView(context: Context) -> MediaPiPCanvas { canvas }
    func updateUIView(_ view: MediaPiPCanvas, context: Context) {}
}
#endif
