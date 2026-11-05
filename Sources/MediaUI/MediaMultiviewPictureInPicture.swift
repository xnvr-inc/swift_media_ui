#if os(iOS)
import AVKit
import SwiftUI

/// An input to an iOS PiP mosaic. Keep the ID stable across player/item changes.
/// For a custom decoder, supply its current decoded frame through `readFrame`.
public struct MediaPiPSource {
  public let id: String
  let player: AVPlayer?
  let aspectRatio: CGFloat?
  let isPlaying: @MainActor () -> Bool
  let setPlaying: @MainActor (Bool) -> Void
  let readFrame: (@MainActor () -> MediaPiPFrame?)?

  public init(
    id: String, player: AVPlayer? = nil, aspectRatio: CGFloat? = nil,
    isPlaying: @escaping @MainActor () -> Bool,
    setPlaying: @escaping @MainActor (Bool) -> Void,
    readFrame: (@MainActor () -> MediaPiPFrame?)? = nil
  ) {
    self.id = id
    self.player = player
    self.aspectRatio = aspectRatio
    self.isPlaying = isPlaying
    self.setPlaying = setPlaying
    self.readFrame = readFrame
  }
}

/// Owns the AVKit session for the whole mosaic. Mount `canvas` inline while
/// `presentsInlineSource` is true. The host supplies playback and scene policy.
@MainActor
public final class MediaMultiviewPictureInPicture: NSObject, ObservableObject,
  AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate
{
  @Published public private(set) var isPossible = false
  @Published public private(set) var isActive = false
  @Published public private(set) var isStarting = false
  @Published public private(set) var isReady = false
  @Published public private(set) var presentsInlineSource = false
  public let canvas: MediaPiPCanvas
  public var onChange: (() -> Void)?
  public var onRestore: (() -> Void)?
  public var onCloseInBackground: (() -> Void)?
  /// Reports the number of slots and the IDs with new frames in the queued mosaic.
  public var onFrameRendered: ((Int, [String]) -> Void)?

  private let automaticallyStartsFromInline: Bool
  private let compositor = MediaPiPCompositor()
  private var sources: [MediaPiPSource] = []
  private var featuredID: String?
  private var outputs: [String: MediaPiPVideoOutput] = [:]
  private var lastFrames: [String: MediaPiPFrame] = [:]
  private var controller: AVPictureInPictureController?
  private var observation: NSKeyValueObservation?
  private var renderTask: Task<Void, Never>?
  private var startTask: Task<Void, Never>?
  private var layoutRevision = 0
  private var preparingForBackground = false
  private var returningInline = false
  private nonisolated let playback = PlaybackState()

  public init(canvas: MediaPiPCanvas? = nil, automaticallyStartsFromInline: Bool = false) {
    self.canvas = canvas ?? MediaPiPCanvas(frame: .zero)
    self.automaticallyStartsFromInline = automaticallyStartsFromInline
  }

  public var canToggle: Bool { isActive || (isReady && controller != nil && !isStarting) }

  public func synchronize(sources: [MediaPiPSource], featuredID: String?) {
    guard !sources.isEmpty, sources.count > 1 || isActive || isStarting else {
      if !self.sources.isEmpty { stop() }
      return
    }
    if sources.map(\.id) != self.sources.map(\.id) || featuredID != self.featuredID {
      layoutRevision += 1
    }
    let ids = Set(sources.map(\.id))
    for id in Array(outputs.keys) where !ids.contains(id) {
      outputs.removeValue(forKey: id)?.detach()
    }
    lastFrames = lastFrames.filter { ids.contains($0.key) }
    self.sources = sources
    self.featuredID = featuredID
    updatePlaybackState()
    guard renderTask == nil else { return }
    renderTask = Task { [weak self] in
      while !Task.isCancelled, self != nil {
        await self?.render()
        try? await Task.sleep(for: .milliseconds(67))
      }
    }
  }

  private func render() async {
    let revision = layoutRevision
    let featuredIndex = sources.firstIndex { $0.id == featuredID }
    var advanced: [String] = []
    let frames = sources.map { source in
      if let frame = readFrame(for: source) {
        if lastFrames[source.id]?.buffer !== frame.buffer { advanced.append(source.id) }
        lastFrames[source.id] = frame
      }
      return lastFrames[source.id]
    }
    guard frames.contains(where: { $0 != nil }) else { setReady(false); return }
    updatePlaybackState()
    let aspects = sources.map(\.aspectRatio)
    guard let sample = await compositor.render(frames, aspectRatios: aspects, featuredIndex: featuredIndex),
      !Task.isCancelled, revision == layoutRevision else { return }
    let layer = canvas.displayLayer
    if layer.status == .failed { layer.flush() }
    guard layer.isReadyForMoreMediaData else { return }
    layer.enqueue(sample)
    onFrameRendered?(frames.count, advanced)
    if controller == nil && AVPictureInPictureController.isPictureInPictureSupported() {
      let controller = AVPictureInPictureController(
        contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
      controller.delegate = self
      controller.requiresLinearPlayback = true
      self.controller = controller
      observation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) {
        [weak self] controller, _ in
        Task { @MainActor in
          guard let self, self.controller === controller else { return }
          let possible = controller.isPictureInPicturePossible
          guard self.isPossible != possible else { return }
          self.isPossible = possible
          self.onChange?()
        }
      }
    }
    setReady(true)
  }

  private func readFrame(for source: MediaPiPSource) -> MediaPiPFrame? {
    guard let player = source.player, let item = player.currentItem else {
      outputs.removeValue(forKey: source.id)?.detach()
      return source.readFrame?()
    }
    // A queue player can replace its item without replacing the player.
    if outputs[source.id]?.item !== item {
      outputs.removeValue(forKey: source.id)?.detach()
      outputs[source.id] = MediaPiPVideoOutput(item: item)
    }
    return outputs[source.id]?.read(at: player.currentTime(), playing: player.rate != 0)
      ?? source.readFrame?()
  }

  private func setReady(_ ready: Bool) {
    guard isReady != ready else { return }
    isReady = ready
    controller?.canStartPictureInPictureAutomaticallyFromInline = ready && automaticallyStartsFromInline
    if ready && preparingForBackground { presentsInlineSource = true }
    onChange?()
  }

  public func toggle() {
    if isActive { returnInline(); return }
    guard canToggle, let controller else { return }
    returningInline = false
    isStarting = true
    presentsInlineSource = true
    startTask = Task { [weak self, weak controller] in
      // AVKit can report availability only after the source has mounted inline.
      for _ in 0..<24 {
        guard let self, let controller, self.controller === controller, !Task.isCancelled else { return }
        if self.isReady && controller.isPictureInPicturePossible {
          self.startTask = nil
          controller.startPictureInPicture()
          return
        }
        try? await Task.sleep(for: .milliseconds(50))
      }
      guard !Task.isCancelled else { return }
      self?.resetStart()
    }
  }

  public func prepareForBackground() {
    guard automaticallyStartsFromInline else { return }
    preparingForBackground = true
    returningInline = false
    if isReady { presentsInlineSource = true }
  }

  public func returnInline() {
    preparingForBackground = false
    returningInline = true
    startTask?.cancel()
    resetStart()
    controller?.stopPictureInPicture()
  }

  private func resetStart() {
    startTask = nil
    isStarting = false
    presentsInlineSource = false
  }

  public func setPlaying(_ playing: Bool) {
    for source in sources { source.setPlaying(playing) }
    updatePlaybackState()
  }

  private func updatePlaybackState() {
    if playback.setPaused(!sources.contains(where: { $0.isPlaying() })) {
      controller?.invalidatePlaybackState()
    }
  }

  public func stop() {
    layoutRevision += 1
    returnInline()
    renderTask?.cancel()
    renderTask = nil
    observation?.invalidate()
    observation = nil
    controller?.delegate = nil
    controller = nil
    for output in outputs.values { output.detach() }
    outputs.removeAll()
    lastFrames.removeAll()
    sources.removeAll()
    isActive = false
    isPossible = false
    canvas.displayLayer.flushAndRemoveImage()
    updatePlaybackState()
    setReady(false)
  }

  public nonisolated func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
    Task { @MainActor [weak self] in
      guard let self, self.controller === controller else { return }
      if self.returningInline { controller.stopPictureInPicture(); return }
      self.isStarting = false
      self.isActive = true
      self.onChange?()
    }
  }

  public nonisolated func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
    Task { @MainActor [weak self] in
      guard let self, self.controller === controller else { return }
      let closedInBackground = self.isActive && !self.returningInline && UIApplication.shared.applicationState == .background
      self.isActive = false
      self.resetStart()
      if self.sources.count < 2 { self.stop() }
      else { self.onChange?() }
      if closedInBackground { self.onCloseInBackground?() }
    }
  }

  public nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error) {
    Task { @MainActor [weak self] in
      guard let self, self.controller === controller else { return }
      self.resetStart()
      self.onChange?()
    }
  }

  public nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
    Task { @MainActor [weak self] in
      guard let self, self.controller === controller else { completionHandler(false); return }
      self.returningInline = true
      self.onRestore?()
      await Task.yield()
      completionHandler(true)
    }
  }

  public nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, setPlaying playing: Bool) {
    Task { @MainActor [weak self] in
      guard let self, self.controller === controller, !self.returningInline else { return }
      self.setPlaying(playing)
    }
  }

  public nonisolated func pictureInPictureControllerTimeRangeForPlayback(_ controller: AVPictureInPictureController) -> CMTimeRange {
    CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
  }

  public nonisolated func pictureInPictureControllerIsPlaybackPaused(_ controller: AVPictureInPictureController) -> Bool {
    playback.isPaused
  }

  public nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
  public nonisolated func pictureInPictureController(_ controller: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion: @escaping () -> Void) { completion() }

  private final class PlaybackState: @unchecked Sendable {
    private let lock = NSLock()
    private var paused = true

    var isPaused: Bool { lock.withLock { paused } }

    func setPaused(_ value: Bool) -> Bool {
      lock.withLock {
        guard paused != value else { return false }
        paused = value
        return true
      }
    }
  }
}
#endif
