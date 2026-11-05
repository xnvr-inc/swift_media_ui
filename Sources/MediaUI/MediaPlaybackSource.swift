import AVFoundation

/// A quality the source can actually supply. Automatic is represented by nil.
public struct MediaPlaybackQuality: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

/// A stable video identity and a factory for fresh AVPlayerItems.
/// A factory can refresh a signed URL or build an asset with multiple tracks.
public struct MediaPlaybackSource: Identifiable {
    public let id: String
    public let title: String
    public let qualities: [MediaPlaybackQuality]
    let makeItem: @MainActor (MediaPlaybackQuality?) async throws -> AVPlayerItem

    public init(url: URL, title: String = "Video", id: String? = nil) {
        self.init(id: id ?? url.absoluteString, title: title) { _ in AVPlayerItem(url: url) }
    }

    public init(
        id: String,
        title: String,
        qualities: [MediaPlaybackQuality] = [],
        makeItem: @escaping @MainActor (MediaPlaybackQuality?) async throws -> AVPlayerItem
    ) {
        self.id = id
        self.title = title
        self.qualities = qualities
        self.makeItem = makeItem
    }
}
