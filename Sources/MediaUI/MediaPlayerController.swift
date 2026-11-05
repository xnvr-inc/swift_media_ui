import AVFoundation
import Observation

/// Coordinates the videos in a MediaPlayer. The same controller can receive new
/// sources while the player is on screen.
@MainActor @Observable
public final class MediaPlayerController {
    public private(set) var selectedID: String?
    public private(set) var featuredID: String?
    public var sourceIDs: [String] { sessions.map(\.id) }
    private(set) var sessions: [MediaPlayerSession] = []
    private var isPresented = false

    public init(sources: [MediaPlaybackSource] = []) {
        for source in sources { add(source) }
        selectedID = sessions.first?.id
    }

    public func add(_ source: MediaPlaybackSource) {
        if !sourceIDs.contains(source.id) {
            let session = MediaPlayerSession(source: source)
            if !sessions.isEmpty { session.setVolume(0.3) }
            sessions.append(session)
            if isPresented { session.resume() }
        }
        selectedID = source.id
    }

    public func select(_ id: String) {
        guard sourceIDs.contains(id) else { return }
        selectedID = id
    }

    /// Sets every current source to the same gain in the range 0...1.
    public func setAllVolumes(_ volume: Float) {
        for session in sessions { session.setVolume(volume) }
    }

    public func feature(_ id: String?) {
        if let id {
            guard sourceIDs.contains(id) else { return }
            selectedID = id
        }
        featuredID = id
    }

    public func close(_ id: String) {
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        sessions.remove(at: index).stop()
        if selectedID == id { selectedID = sessions.last?.id }
        if featuredID == id || sessions.count < 2 { featuredID = nil }
    }

    public func closeAll() {
        for session in sessions { session.stop() }
        sessions.removeAll()
        selectedID = nil
        featuredID = nil
    }

    func resume() {
        isPresented = true
        for session in sessions { session.resume() }
    }

    func suspend() {
        isPresented = false
        for session in sessions { session.suspend() }
    }

    var selected: MediaPlayerSession? { sessions.first { $0.id == selectedID } }
}

@MainActor @Observable
final class MediaPlayerSession: Identifiable {
    nonisolated let id: String
    let source: MediaPlaybackSource
    let player = AVPlayer()
    private(set) var quality: MediaPlaybackQuality?
    private(set) var isLoading = false
    private(set) var failed = false
    private(set) var wantsPlayback = true
    private(set) var volume: Float = 1
    private(set) var isMuted = false

    @ObservationIgnored private var isPresented = false
    @ObservationIgnored private var lastRequest: MediaPlaybackQuality?
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var statusObservation: NSKeyValueObservation?
    @ObservationIgnored private var endObservation: NSObjectProtocol?
    #if os(macOS)
    @ObservationIgnored private var nativeControls: [NSKeyValueObservation] = []
    #endif

    init(source: MediaPlaybackSource) {
        self.id = source.id
        self.source = source
        #if os(macOS)
        nativeControls = [
            player.observe(\.timeControlStatus, options: .new) { [weak self] player, _ in
                Task { @MainActor in
                    guard let self, self.isPresented, !self.isLoading else { return }
                    self.wantsPlayback = player.timeControlStatus != .paused
                }
            },
            player.observe(\.volume, options: .new) { [weak self] player, _ in
                Task { @MainActor in self?.volume = player.volume }
            },
            player.observe(\.isMuted, options: .new) { [weak self] player, _ in
                Task { @MainActor in self?.isMuted = player.isMuted }
            }
        ]
        #endif
    }

    func resume() {
        isPresented = true
        if player.currentItem == nil && !failed { load(lastRequest) }
        applyPlaybackIntent()
    }

    func suspend() {
        isPresented = false
        player.pause()
    }

    func retry() { load(lastRequest) }

    func load(_ requested: MediaPlaybackQuality? = nil) {
        guard !isLoading else { return }
        guard requested == nil || source.qualities.contains(where: { $0 == requested }) else { return }
        lastRequest = requested
        isLoading = true
        failed = false
        loadTask = Task { [weak self, source] in
            do {
                let item = try await source.makeItem(requested)
                guard try await item.asset.load(.isPlayable) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                guard !Task.isCancelled else { return }
                self?.install(item, quality: requested)
            } catch {
                guard !Task.isCancelled else { return }
                self?.isLoading = false
                self?.failed = true
            }
        }
    }

    private func install(_ item: AVPlayerItem, quality requested: MediaPlaybackQuality?) {
        let previous = player.currentItem
        let previousTime = player.currentTime()
        player.pause()
        replaceItem(item)
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self, self.player.currentItem === item, self.isLoading else { return }
                switch item.status {
                case .readyToPlay:
                    self.statusObservation?.invalidate()
                    self.statusObservation = nil
                    self.quality = requested
                    self.isLoading = false
                    self.observeEnd(of: item)
                    self.seekAfterReplacement(to: previousTime)
                    self.applyPlaybackIntent()
                case .failed:
                    self.replaceItem(previous)
                    self.isLoading = false
                    self.failed = true
                    if let previous {
                        self.observeEnd(of: previous)
                        self.seekAfterReplacement(to: previousTime)
                        self.applyPlaybackIntent()
                    }
                default:
                    break
                }
            }
        }
    }

    private func replaceItem(_ item: AVPlayerItem?) {
        statusObservation?.invalidate()
        statusObservation = nil
        removeEndObservation()
        player.replaceCurrentItem(with: item)
    }

    private func observeEnd(of item: AVPlayerItem) {
        endObservation = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard self?.player.currentItem === item else { return }
                self?.wantsPlayback = false
            }
        }
    }

    private func removeEndObservation() {
        if let endObservation { NotificationCenter.default.removeObserver(endObservation) }
        endObservation = nil
    }

    private func seekAfterReplacement(to position: CMTime) {
        guard position.seconds.isFinite, position.seconds > 0, let duration = finiteDuration else { return }
        player.seek(to: CMTime(seconds: min(duration, position.seconds), preferredTimescale: 600))
    }

    var finiteDuration: Double? {
        guard let duration = player.currentItem?.duration.seconds, duration.isFinite, duration > 0 else { return nil }
        return duration
    }

    func seek(by seconds: Double) {
        guard let duration = finiteDuration, player.currentTime().seconds.isFinite else { return }
        let target = min(duration, max(0, player.currentTime().seconds + seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }

    func setPlaying(_ playing: Bool) {
        wantsPlayback = playing
        if playing, let duration = finiteDuration, player.currentTime().seconds >= duration {
            player.seek(to: .zero)
        }
        applyPlaybackIntent()
    }

    private func applyPlaybackIntent() {
        if wantsPlayback && isPresented { player.play() } else { player.pause() }
    }

    func setVolume(_ value: Float) {
        guard value.isFinite else { return }
        volume = min(1, max(0, value))
        player.volume = volume
    }

    func toggleMute() {
        isMuted.toggle()
        player.isMuted = isMuted
    }

    func stop() {
        suspend()
        loadTask?.cancel()
        loadTask = nil
        replaceItem(nil)
        isLoading = false
    }

    deinit {
        loadTask?.cancel()
        if let endObservation { NotificationCenter.default.removeObserver(endObservation) }
    }
}
