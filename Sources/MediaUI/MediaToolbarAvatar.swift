import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// Hold the rendered image with its source so an account switch cannot show the previous photo.
public struct MediaToolbarAvatar {
    public let url: URL
    public let image: CGImage

    @MainActor public static func load(_ url: URL, revalidate: Bool = false) async -> MediaToolbarAvatar? {
        let request = URLRequest(url: url, cachePolicy: revalidate ? .reloadRevalidatingCacheData : .useProtocolCachePolicy)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 128,
              ] as CFDictionary) else { return nil }
        let side = MediaLayout.headerAvatarSize
        let renderer = ImageRenderer(content: Image(decorative: thumbnail, scale: 1)
            .resizable().scaledToFill().frame(width: side, height: side).clipShape(Circle()))
        renderer.scale = 3
        guard let image = renderer.cgImage else { return nil }
        return MediaToolbarAvatar(url: url, image: image)
    }
}


/// An app supplies the profile identifier; this cache stores only the small
/// rendered image and its URL, independently of account/session data.
@MainActor public struct MediaToolbarAvatarCache {
    private struct Entry: Codable {
        let url: URL
        let png: Data
    }
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) { self.defaults = defaults }

    public static var system: Self { Self(defaults: .standard) }

    public func read(_ profile: UUID) -> MediaToolbarAvatar? {
        guard let data = defaults.data(forKey: key(profile)),
              let entry = try? PropertyListDecoder().decode(Entry.self, from: data),
              let source = CGImageSourceCreateWithData(entry.png as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        return MediaToolbarAvatar(url: entry.url, image: image)
    }

    public func write(_ avatar: MediaToolbarAvatar, for profile: UUID) {
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, avatar.image, nil)
        guard CGImageDestinationFinalize(destination),
              let data = try? PropertyListEncoder().encode(Entry(url: avatar.url, png: png as Data)) else { return }
        defaults.set(data, forKey: key(profile))
    }

    public func remove(_ profile: UUID) { defaults.removeObject(forKey: key(profile)) }

    private func key(_ profile: UUID) -> String { "media.toolbar-avatar.v1." + profile.uuidString }
}
