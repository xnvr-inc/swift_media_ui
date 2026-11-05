import SwiftUI
#if os(iOS)
import AVFAudio
#endif

@main
struct MediaUIDemo: App {
    var body: some Scene {
        WindowGroup("Swift Media UI") {
            DemoRoot()
                .preferredColorScheme(.dark)
                #if os(iOS)
                .task {
                    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: .mixWithOthers)
                }
                #endif
                #if os(macOS)
                .frame(minWidth: 820, minHeight: 560)
                #endif
        }
        #if os(macOS)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}
