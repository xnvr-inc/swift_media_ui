import MediaUI
import SwiftUI

@main
struct MediaUIDemo: App {
    #if os(macOS)
    private let sources = CommandLine.arguments.dropFirst().map { argument in
        let url = URL(string: argument).flatMap { $0.scheme == nil ? nil : $0 }
            ?? URL(fileURLWithPath: argument)
        return MediaPlaybackSource(url: url, title: url.lastPathComponent)
    }
    #else
    private let sources: [MediaPlaybackSource] = []
    #endif

    var body: some Scene {
        WindowGroup {
            if let first = sources.first {
                MediaPlayer(sources: [first], availableSources: Array(sources.dropFirst()))
                    #if os(macOS)
                    .frame(minWidth: 620, minHeight: 360)
                    #endif
            } else {
                ContentUnavailableView("Pass a video URL or file path", systemImage: "play.rectangle")
            }
        }
    }
}
