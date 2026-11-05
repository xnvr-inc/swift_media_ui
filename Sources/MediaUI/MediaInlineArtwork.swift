import SwiftUI
import ImageIO

/// Replace only catalogued shortcode tokens. Preserve URLs and unknown text.
public enum MediaInlineArtwork {
    private static let tokens = try! NSRegularExpression(pattern: #"(?i)(?:https?://|www\.)[^\s<>]+|(?<!/)/[^/\s<>]{1,48}/"#)

    public static func matches(in text: String, catalog: [String: URL]) -> [(Range<String.Index>, URL)] {
        guard !catalog.isEmpty else { return [] }
        return tokens.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { match in
                guard let range = Range(match.range, in: text), let url = catalog[String(text[range])] else { return nil }
                return (range, url)
            }
    }
}

/// Reuse decoded images and deduplicate concurrent requests from visible rows.
public actor MediaInlineArtworkCache {
    public static let shared = MediaInlineArtworkCache()
    private let images = NSCache<NSURL, CGImage>()
    private let session = URLSession(configuration: .ephemeral)
    private var pending: [URL: Task<CGImage?, Never>] = [:]

    public init() { images.countLimit = 256 }

    public func image(_ url: URL) async -> CGImage? {
        if let image = images.object(forKey: url as NSURL) { return image }
        if let task = pending[url] { return await task.value }
        guard url.scheme == "https", url.user == nil, url.password == nil, url.host != nil else { return nil }
        let task = Task<CGImage?, Never> { [session] in
            var request = URLRequest(url: url, timeoutInterval: 8)
            request.httpShouldHandleCookies = false
            guard let (data, response) = try? await session.data(for: request),
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  http.url?.scheme == "https", http.url?.host == url.host, data.count <= 1_048_576,
                  let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 96,
            ] as CFDictionary)
        }
        pending[url] = task
        let image = await task.value
        pending[url] = nil
        if let image { images.setObject(image, forKey: url as NSURL) }
        return image
    }
}

/// Preserve attributed links and emphasis when adding inline image glyphs.
public struct MediaInlineArtworkText: View {
    private let content: AttributedString
    private let catalog: [String: URL]
    private let size: CGFloat
    @State private var images: [URL: CGImage] = [:]

    public init(_ content: AttributedString, catalog: [String: URL], size: CGFloat) {
        self.content = content
        self.catalog = catalog
        self.size = size
    }

    public init(_ text: String, catalog: [String: URL], size: CGFloat) {
        self.init(AttributedString(text), catalog: catalog, size: size)
    }

    public var body: some View {
        let plain = String(content.characters)
        let matches = MediaInlineArtwork.matches(in: plain, catalog: catalog).compactMap { range, url -> (Range<AttributedString.Index>, URL)? in
            guard let lower = AttributedString.Index(range.lowerBound, within: content),
                  let upper = AttributedString.Index(range.upperBound, within: content),
                  !content[lower..<upper].runs.contains(where: { $0.link != nil }) else { return nil }
            return (lower..<upper, url)
        }
        let urls = Set(matches.map(\.1))
        rendered(matches)
            .task(id: urls) {
                images = images.filter { urls.contains($0.key) }
                await withTaskGroup(of: (URL, CGImage?).self) { group in
                    for url in urls where images[url] == nil {
                        group.addTask { (url, await MediaInlineArtworkCache.shared.image(url)) }
                    }
                    for await (url, image) in group where !Task.isCancelled {
                        if let image { images[url] = image }
                    }
                }
            }
    }

    private func rendered(_ matches: [(Range<AttributedString.Index>, URL)]) -> Text {
        guard !matches.isEmpty, !images.isEmpty else { return Text(content) }
        var start = content.startIndex
        var text = Text("")
        for (range, url) in matches {
            guard let image = images[url] else { continue }
            text = text + Text(AttributedString(content[start..<range.lowerBound]))
            let scale = CGFloat(max(image.width, image.height)) / max(1, size)
            let label = String(content[range].characters)
            text = text + Text(Image(image, scale: scale, label: Text(verbatim: label)))
            start = range.upperBound
        }
        return text + Text(AttributedString(content[start...]))
    }
}
