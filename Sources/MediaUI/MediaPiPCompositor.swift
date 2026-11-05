#if os(iOS)
import AVFoundation
import CoreImage

/// Retains a video buffer. Treat its contents as read-only while rendering.
public struct MediaPiPFrame: @unchecked Sendable {
  let buffer: CVPixelBuffer
  let transform: CGAffineTransform

  public init(buffer: CVPixelBuffer, transform: CGAffineTransform = .identity) {
    self.buffer = buffer
    self.transform = transform
  }
}

/// CPU rendering keeps the PiP producer independent of foreground-only GPU work.
/// A pool and one in-flight render bound the work to 640×360 at at most 15 fps.
public actor MediaPiPCompositor {
  public static let size = CGSize(width: 640, height: 360)
  private let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
  private let colorSpace = CGColorSpaceCreateDeviceRGB()
  private var pool: CVPixelBufferPool?

  public init() {}

  public func render(_ frames: [MediaPiPFrame], featuredIndex: Int?) -> CMSampleBuffer? {
    render(frames.map(Optional.some), aspectRatios: [], featuredIndex: featuredIndex)
  }

  func render(
    _ frames: [MediaPiPFrame?], aspectRatios: [CGFloat?], featuredIndex: Int?
  ) -> CMSampleBuffer? {
    let images = frames.map { frame in
      frame.map { CIImage(cvPixelBuffer: $0.buffer).transformed(by: $0.transform) }
    }
    guard images.contains(where: { $0 != nil }),
      images.compactMap({ $0 }).allSatisfy({ !$0.extent.isEmpty && !$0.extent.isInfinite })
    else { return nil }
    let aspects = images.enumerated().map { index, image in
      if let size = image?.extent.size { return size.width / size.height }
      return aspectRatios.indices.contains(index)
        ? aspectRatios[index] ?? MediaCardMetrics.landscapeAspect
        : MediaCardMetrics.landscapeAspect
    }
    if pool == nil {
      let attributes: [CFString: Any] = [
        kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey: Int(Self.size.width),
        kCVPixelBufferHeightKey: Int(Self.size.height),
        kCVPixelBufferIOSurfacePropertiesKey: [:],
      ]
      guard CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess
      else { return nil }
    }
    guard let pool else { return nil }
    var buffer: CVPixelBuffer?
    let limits = [kCVPixelBufferPoolAllocationThresholdKey: 3] as CFDictionary
    guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool, limits, &buffer)
      == kCVReturnSuccess, let buffer else { return nil }
    let layout = PlaybackMultiviewLayout(
      count: images.count, size: Self.size, controlsHeight: 0, spacing: 2,
      featuredIndex: featuredIndex, aspectRatios: aspects)
    guard layout.frames.count == images.count, layout.frames.allSatisfy({ !$0.isEmpty }) else { return nil }
    let bounds = CGRect(origin: .zero, size: Self.size)
    var image = CIImage(color: .black).cropped(to: bounds)
    for (index, slotImage) in images.enumerated() {
      guard let source = slotImage else { continue }
      let slot = layout.frames[index]
      let fitted = AVMakeRect(aspectRatio: source.extent.size, insideRect: slot)
      let scale = fitted.width / source.extent.width
      // The shared layout uses UIKit coordinates; Core Image's origin is below.
      let transform = CGAffineTransform(translationX: -source.extent.minX, y: -source.extent.minY)
        .concatenating(CGAffineTransform(scaleX: scale, y: scale))
        .concatenating(CGAffineTransform(translationX: fitted.minX, y: Self.size.height - fitted.maxY))
      image = source.transformed(by: transform).composited(over: image)
    }
    context.render(image, to: buffer, bounds: bounds, colorSpace: colorSpace)
    var format: CMVideoFormatDescription?
    guard CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescriptionOut: &format) == noErr,
      let format else { return nil }
    var timing = CMSampleTimingInfo(
      duration: CMTime(value: 1, timescale: 15),
      presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    guard CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault, imageBuffer: buffer, formatDescription: format,
      sampleTiming: &timing, sampleBufferOut: &sample) == noErr, let sample else { return nil }
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true)
      as? [NSMutableDictionary] {
      attachments.first?[kCMSampleAttachmentKey_DisplayImmediately] = true
    }
    return sample
  }
}

@MainActor final class MediaPiPVideoOutput {
  let item: AVPlayerItem
  let output = AVPlayerItemVideoOutput(pixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  ])
  private var orientationTask: Task<Void, Never>?
  private var transform = CGAffineTransform.identity
  private var frame: CVPixelBuffer?
  private var lastFrameTime = CMTime.invalid
  init(item: AVPlayerItem) {
    self.item = item
    item.add(output)
    orientationTask = Task { [weak self, item] in
      if let track = try? await item.asset.loadTracks(withMediaType: .video).first,
        let transform = try? await track.load(.preferredTransform), !Task.isCancelled {
        self?.transform = transform
      }
    }
  }
  func read(at time: CMTime, playing: Bool) -> MediaPiPFrame? {
    if output.hasNewPixelBuffer(forItemTime: time),
      let buffer = output.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil) {
      frame = buffer
      lastFrameTime = time
    }
    // Do not advertise a frozen mosaic when a source cannot deliver live frames.
    guard let frame,
      !playing || abs((time - lastFrameTime).seconds) < 1.5 else { return nil }
    return MediaPiPFrame(buffer: frame, transform: transform)
  }
  func detach() {
    orientationTask?.cancel()
    item.remove(output)
    frame = nil
  }
}

#endif
