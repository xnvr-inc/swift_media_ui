import AVFoundation
import MediaUI
import SwiftUI

@main
struct MediaUIDemo: App {
    private let sources: [MediaPlaybackSource]

    init() {
        #if os(macOS)
        let arguments = CommandLine.arguments.dropFirst().filter { !$0.hasPrefix("-psn_") }
        sources = arguments.isEmpty ? Self.samples() : arguments.map { argument in
            let url = URL(string: argument).flatMap { $0.scheme == nil ? nil : $0 }
                ?? URL(fileURLWithPath: argument)
            return MediaPlaybackSource(url: url, title: url.lastPathComponent)
        }
        #else
        sources = Self.samples()
        #endif
    }

    var body: some Scene {
        WindowGroup("Swift Media UI") {
            MediaPlayer(sources: Array(sources.prefix(1)), availableSources: sources)
                #if os(macOS)
                .frame(minWidth: 680, minHeight: 400)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 900, height: 500)
        #endif
    }

    private static func samples() -> [MediaPlaybackSource] {
        func sample(_ name: String) -> URL? {
            Bundle.module.url(forResource: name, withExtension: "mp4", subdirectory: "Samples")
        }
        guard let tidal = sample("Tidal"), let low = sample("Tidal180"), let amber = sample("Amber") else {
            return []
        }

        let standard = MediaPlaybackQuality(id: "360", title: "360p")
        let compact = MediaPlaybackQuality(id: "180", title: "180p")
        return [
            MediaPlaybackSource(id: "tidal", title: "Tidal Field", qualities: [standard, compact]) { quality in
                AVPlayerItem(url: quality == compact ? low : tidal)
            },
            MediaPlaybackSource(url: amber, title: "Amber Drift", id: "amber"),
        ]
    }
}
