import AVFoundation
import XCTest
@testable import MediaUI

final class MediaPlayerTests: XCTestCase {
    @MainActor
    func testAddingExistingSourceSelectsWithoutReplacingAndClosingKeepsOtherSession() {
        let first = stub("first")
        let second = stub("second")
        let player = MediaPlayerController(sources: [first, second])
        let secondSession = player.sessions.last

        player.add(first)
        XCTAssertEqual(player.sourceIDs, ["first", "second"])
        XCTAssertEqual(player.selectedID, "first")
        player.feature("second")
        XCTAssertEqual(player.featuredID, "second")
        player.close("second")

        XCTAssertEqual(player.sourceIDs, ["first"])
        XCTAssertEqual(player.selectedID, "first")
        XCTAssertNil(player.featuredID)
        XCTAssertNil(secondSession?.player.currentItem)
        player.closeAll()
        XCTAssertNil(player.selectedID)
    }

    @MainActor
    func testVolumeAndMuteApplyIndependently() throws {
        let controller = MediaPlayerController(sources: [stub("first"), stub("second")])
        let first = try XCTUnwrap(controller.sessions.first)
        let second = try XCTUnwrap(controller.sessions.last)
        second.setVolume(0.45)
        second.toggleMute()
        first.setVolume(.infinity)
        XCTAssertEqual(first.player.volume, 1)
        XCTAssertFalse(first.player.isMuted)
        XCTAssertEqual(second.player.volume, 0.45, accuracy: 0.001)
        XCTAssertTrue(second.player.isMuted)
        controller.closeAll()
    }

    @MainActor
    func testVolumePresetAppliesToEveryPlayerAndPreservesMute() throws {
        let controller = MediaPlayerController(sources: [stub("first"), stub("second")])
        let second = try XCTUnwrap(controller.sessions.last)
        second.toggleMute()
        controller.setAllVolumes(0.5)
        XCTAssertEqual(controller.sessions.map(\.player.volume), [0.5, 0.5])
        XCTAssertTrue(second.player.isMuted)
        controller.select("second")
        XCTAssertEqual(second.player.volume, 0.5)
        controller.closeAll()
    }

    @MainActor
    func testClosingDuringSourceResolutionCancelsLoad() async throws {
        let requested = expectation(description: "Started resolving")
        let cancelled = expectation(description: "Cancelled resolver")
        let source = MediaPlaybackSource(id: "slow", title: "Slow") { _ in
            requested.fulfill()
            do {
                try await Task.sleep(for: .seconds(20))
            } catch {
                cancelled.fulfill()
                throw error
            }
            throw CancellationError()
        }
        let controller = MediaPlayerController(sources: [source])
        let session = try XCTUnwrap(controller.sessions.first)
        controller.resume()
        await fulfillment(of: [requested], timeout: 2)
        controller.close("slow")
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertNil(session.player.currentItem)
        XCTAssertFalse(session.isLoading)
    }

    @MainActor
    private func stub(_ id: String) -> MediaPlaybackSource {
        MediaPlaybackSource(id: id, title: id) { _ in throw CancellationError() }
    }
}

extension MediaPlayerTests {
    @MainActor
    func testFailedQualityLeavesPlayableItemAndSuccessfulSwitchUsesSamePlayer() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.mp4")
        try await writeTestVideo(to: url)

        let high = MediaPlaybackQuality(id: "high", title: "High")
        let unavailable = MediaPlaybackQuality(id: "unavailable", title: "Unavailable")
        let source = MediaPlaybackSource(id: "test", title: "Test", qualities: [high, unavailable]) { quality in
            let resolvedURL = quality == unavailable ? directory.appendingPathComponent("missing.mp4") : url
            return AVPlayerItem(url: resolvedURL)
        }
        let controller = MediaPlayerController(sources: [source])
        let session = try XCTUnwrap(controller.sessions.first)
        defer { controller.closeAll() }

        controller.resume()
        try await waitUntil { !session.isLoading }
        let first = try XCTUnwrap(session.player.currentItem)
        XCTAssertEqual(first.status, .readyToPlay)
        try await waitUntil { session.player.currentTime().seconds > 0 }

        session.load(unavailable)
        try await waitUntil { session.failed }
        XCTAssertTrue(session.player.currentItem === first)
        XCTAssertNil(session.quality)

        session.setPlaying(false)
        session.load(high)
        try await waitUntil { !session.isLoading }
        XCTAssertFalse(session.failed)
        XCTAssertEqual(session.quality, high)
        XCTAssertNotNil(session.player.currentItem)
        XCTAssertFalse(session.player.currentItem === first)
        XCTAssertFalse(session.wantsPlayback)
    }

    @MainActor
    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(5)
        while !condition() {
            guard ContinuousClock.now < deadline else { throw CocoaError(.coderInvalidValue) }
            try await Task.sleep(for: .milliseconds(25))
        }
    }

    private func writeTestVideo(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64,
            kCVPixelBufferHeightKey as String: 64,
        ])
        writer.add(input)
        guard writer.startWriting() else { throw try XCTUnwrap(writer.error) }
        writer.startSession(atSourceTime: .zero)

        var buffer: CVPixelBuffer?
        let pool = try XCTUnwrap(adaptor.pixelBufferPool)
        XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer), kCVReturnSuccess)
        let pixelBuffer = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(base, 0, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        for frame in 0..<30 {
            let deadline = ContinuousClock.now + .seconds(3)
            while !input.isReadyForMoreMediaData {
                guard ContinuousClock.now < deadline else { throw CocoaError(.fileWriteUnknown) }
                try await Task.sleep(for: .milliseconds(5))
            }
            XCTAssertTrue(adaptor.append(pixelBuffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 15)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
    }
}
