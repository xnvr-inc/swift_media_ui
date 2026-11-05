import AVFoundation
import MediaUI
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

enum DemoMode: String, CaseIterable, Identifiable {
    case video, live

    var id: Self { self }
    var title: String { self == .video ? "Video" : "Live Platform" }
    var description: String {
        switch self {
        case .video: "Videos, subscriptions, Shorts and watch history."
        case .live: "Live channels, categories, replays and chat."
        }
    }
    var tint: Color { self == .video ? .red : .blue }
    var tabs: [DemoTab] {
        self == .video ? [.home, .subscriptions, .shorts, .my] : [.home, .my, .live, .categories]
    }
}

enum DemoTab: String, Identifiable {
    case home, subscriptions, shorts, my, live, categories

    var id: Self { self }
    var title: String {
        switch self {
        case .home: "Home"
        case .subscriptions: "Subscriptions"
        case .shorts: "Shorts"
        case .my: "MY"
        case .live: "LIVE"
        case .categories: "Categories"
        }
    }
    var symbol: String {
        switch self {
        case .home: "house"
        case .subscriptions: "play.rectangle.on.rectangle"
        case .shorts: "play.square.stack"
        case .my: "person.crop.circle"
        case .live: "dot.radiowaves.left.and.right"
        case .categories: "square.grid.2x2"
        }
    }
}

struct DemoChannel: Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let symbol: String
    let art: String
    var image: Image { DemoAssets.image(art) }
}

struct DemoVideo: Identifiable, Hashable {
    enum Kind { case video, live, replay, short }

    let id: String
    let title: String
    let channel: DemoChannel
    let kind: Kind
    let art: String
    let viewers: Int

    var duration: String { "0:18" }
    var isShort: Bool { kind == .short }
    var isLive: Bool { kind == .live }
    var metadata: String {
        if isLive { return "\(viewers.formatted()) watching · \(channel.category)" }
        return "\(viewers.formatted()) views · \(kind == .replay ? "Replay" : "Sample video")"
    }

    var artwork: Image { DemoAssets.image(art) }

    var source: MediaPlaybackSource? {
        guard let url = DemoAssets.url(art, extension: "mp4") else { return nil }
        guard art == "Tidal", let low = DemoAssets.url("Tidal180", extension: "mp4") else {
            return MediaPlaybackSource(url: url, title: title, id: id)
        }
        let standard = MediaPlaybackQuality(id: "360", title: "360p")
        let compact = MediaPlaybackQuality(id: "180", title: "180p")
        return MediaPlaybackSource(id: id, title: title, qualities: [standard, compact]) { quality in
            AVPlayerItem(url: quality == compact ? low : url)
        }
    }
}

enum DemoCatalog {
    static let motion = DemoChannel(id: "motion", name: "Motion Lab", category: "Design", symbol: "waveform.path", art: "Tidal")
    static let afterhours = DemoChannel(id: "afterhours", name: "Afterhours Studio", category: "Music", symbol: "headphones", art: "Night")
    static let drift = DemoChannel(id: "drift", name: "Drift Room", category: "Just Chatting", symbol: "bubble.left.and.bubble.right", art: "Current")
    static let channels = [motion, afterhours, drift]
    static let tidal = DemoVideo(id: "tidal", title: "Tidal Field", channel: motion, kind: .video, art: "Tidal", viewers: 3_450)
    static let amber = DemoVideo(id: "amber", title: "Amber Drift", channel: motion, kind: .replay, art: "Amber", viewers: 2_840)
    static let night = DemoVideo(id: "night", title: "Night Signal", channel: afterhours, kind: .live, art: "Night", viewers: 1_428)
    static let current = DemoVideo(id: "current", title: "Slow Current", channel: drift, kind: .live, art: "Current", viewers: 782)
    static let pulse = DemoVideo(id: "pulse", title: "Blue Pulse", channel: afterhours, kind: .short, art: "Pulse", viewers: 912)
    static let trail = DemoVideo(id: "trail", title: "Copper Trail", channel: drift, kind: .short, art: "Trail", viewers: 638)
    static let live = [night, current]
    static let shorts = [pulse, trail]
    static let all = [tidal, amber, night, current, pulse, trail]

    static func feed(_ mode: DemoMode) -> [DemoVideo] {
        mode == .video ? [tidal, amber, pulse, trail] : [night, current, amber, pulse, trail]
    }

    static let messages = [
        ("Mina", "The colors in this one are incredible."),
        ("Kai", "Watching from the other side of the world."),
        ("Jules", "Can we keep the second stream open too?"),
        ("Rin", "That transition was my favorite part."),
    ]
}

enum DemoAssets {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    static func url(_ name: String, extension ext: String) -> URL? {
        bundle.url(forResource: name, withExtension: ext, subdirectory: "Samples")
    }

    static func image(_ name: String) -> Image {
        if let url = url(name, extension: "jpg") {
            #if os(macOS)
            if let image = NSImage(contentsOf: url) { return Image(nsImage: image) }
            #else
            if let image = UIImage(contentsOfFile: url.path) { return Image(uiImage: image) }
            #endif
        }
        return Image(systemName: "play.rectangle")
    }

    static var wordmark: Image { Image("XnvrWordmark", bundle: bundle) }
}
