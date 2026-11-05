import AVKit
import SwiftUI

/// A native player with a shared session, video picker and transport controls.
@MainActor
public struct MediaPlayer: View {
    @State private var controller: MediaPlayerController
    @State private var isPicking = false
    private let showsControls: Bool
    private let availableSources: [MediaPlaybackSource]
    private let onRestorePictureInPicture: (() -> Void)?
    #if os(tvOS)
    @FocusState private var focusedTile: String?
    #elseif os(iOS)
    @StateObject private var pictureInPicture = MediaPlayerPictureInPicture()
    #endif

    public init(
        controller: MediaPlayerController,
        availableSources: [MediaPlaybackSource] = [],
        showsControls: Bool = true,
        onRestorePictureInPicture: (() -> Void)? = nil
    ) {
        _controller = State(initialValue: controller)
        self.availableSources = availableSources
        self.showsControls = showsControls
        self.onRestorePictureInPicture = onRestorePictureInPicture
    }

    public init(sources: [MediaPlaybackSource], availableSources: [MediaPlaybackSource] = []) {
        self.init(controller: MediaPlayerController(sources: sources), availableSources: availableSources)
    }

    public init(url: URL) {
        self.init(sources: [MediaPlaybackSource(url: url)])
    }

    public var body: some View {
        VStack(spacing: 0) {
            stage
            if showsControls {
                ScrollView(.horizontal) {
                    HStack {
                        if !availableSources.isEmpty {
                            button("Add video", icon: "plus") { isPicking = true }
                        }
                        if let session = controller.selected {
                            controls(for: session)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .scrollIndicators(.hidden)
            }
        }
        .onAppear {
            controller.resume()
            #if os(iOS)
            pictureInPicture.updateSessions(controller.sessions)
            pictureInPicture.select(controller.selectedID)
            #endif
        }
        .onDisappear { controller.suspend() }
        .sheet(isPresented: $isPicking) {
            VStack(alignment: .leading) {
                HStack {
                    Text("Add video").font(.headline)
                    Spacer()
                    Button("Done") { isPicking = false }
                }
                List(availableSources) { source in
                    Button(source.title) {
                        controller.add(source)
                        isPicking = false
                    }
                    .disabled(controller.sourceIDs.contains(source.id))
                }
            }
            .padding()
            #if os(macOS)
            .frame(minWidth: 320, minHeight: 240)
            #endif
        }
        #if os(iOS)
        .onChange(of: controller.sourceIDs) {
            pictureInPicture.updateSessions(controller.sessions)
        }
        .onChange(of: controller.selectedID) {
            pictureInPicture.select(controller.selectedID)
        }
        .onChange(of: controller.featuredID, initial: true) {
            pictureInPicture.featuredID = controller.featuredID
        }
        .onDisappear { pictureInPicture.stop() }
        #endif
    }

    private var stage: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                if controller.sessions.isEmpty {
                    Text("No videos").foregroundStyle(.white)
                } else {
                    let frames = PlaybackMultiviewLayout.stageFrames(
                        count: controller.sessions.count,
                        size: geometry.size,
                        featuredIndex: controller.featuredID.flatMap { controller.sourceIDs.firstIndex(of: $0) }
                    )
                    MediaPlaybackTiles(controller.sessions, frames: frames) { session in
                        tile(for: session)
                    }
                }
                #if os(iOS)
                if pictureInPicture.isPresentingComposite || pictureInPicture.isUsingComposite {
                    MediaPiPCompositeSurface(canvas: pictureInPicture.canvas)
                        .opacity(pictureInPicture.isPresentingComposite ? 1 : 0.01)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                #endif
            }
        }
    }

    private func tile(for session: MediaPlayerSession) -> some View {
        let selected = controller.selectedID == session.id
        #if os(tvOS)
        let focused = focusedTile == session.id
        #else
        let focused = false
        #endif
        return MediaVideoStage {
            #if os(iOS)
            MediaPlayerVideoSurface(player: session.player) { layer in
                pictureInPicture.register(layer, for: session.id)
            }
            #else
            #if os(macOS)
            MediaPlayerVideoSurface(player: session.player, showsControls: showsControls)
            #else
            MediaPlayerVideoSurface(player: session.player)
            #endif
            #endif
            if session.isLoading && session.player.currentItem == nil {
                ProgressView().tint(.white)
            }
            if showsControls && controller.sessions.count > 1 {
                Button {
                    controller.select(session.id)
                } label: {
                    Text(session.source.title)
                        .lineLimit(1)
                        .padding(8)
                        .background(.black.opacity(0.75))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                #if os(tvOS)
                .focused($focusedTile, equals: session.id)
                #endif
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .overlay {
            if (selected || focused) && controller.sessions.count > 1 {
                Rectangle().strokeBorder(
                    .white.opacity(focused ? 1 : 0.65),
                    lineWidth: MediaMultiviewMetrics.focusBorderWidth
                )
                    .allowsHitTesting(false)
            }
        }
    }

    @ViewBuilder private func controls(for session: MediaPlayerSession) -> some View {
        if session.failed {
            Text("Unable to load video").foregroundStyle(.secondary)
            Button("Retry") { session.retry() }.disabled(session.isLoading)
        }
        button(session.wantsPlayback ? "Pause" : "Play",
               icon: session.wantsPlayback ? "pause.fill" : "play.fill") {
            session.setPlaying(!session.wantsPlayback)
        }
        button("Back 10 seconds", icon: "gobackward.10") { session.seek(by: -10) }
            .disabled(session.finiteDuration == nil)
        button("Forward 10 seconds", icon: "goforward.10") { session.seek(by: 10) }
            .disabled(session.finiteDuration == nil)
        if controller.sessions.count > 1 {
            let featured = controller.featuredID == session.id
            button(featured ? "Show grid" : "Enlarge video",
                   icon: featured ? "square.grid.2x2" : "arrow.up.left.and.arrow.down.right") {
                controller.feature(featured ? nil : session.id)
            }
        }
        button(session.isMuted ? "Unmute video" : "Mute video",
               icon: session.isMuted ? "speaker.slash" : "speaker.wave.2") {
            session.toggleMute()
        }
        Menu {
            ForEach([0, 10, 25, 30, 50, 75, 100], id: \.self) { percent in
                let selected = Int((session.volume * 100).rounded()) == percent
                Button {
                    session.setVolume(Float(percent) / 100)
                } label: {
                    if selected { Label("\(percent)%", systemImage: "checkmark") }
                    else { Text("\(percent)%") }
                }
            }
        } label: {
            Label("Video volume \(Int((session.volume * 100).rounded()))%", systemImage: "speaker.wave.2.circle")
                .labelStyle(.iconOnly)
        }
        if !session.source.qualities.isEmpty {
            Menu {
                Button {
                    session.load()
                } label: {
                    if session.quality == nil { Label("Automatic", systemImage: "checkmark") }
                    else { Text("Automatic") }
                }
                ForEach(session.source.qualities) { quality in
                    Button {
                        session.load(quality)
                    } label: {
                        if session.quality == quality { Label(quality.title, systemImage: "checkmark") }
                        else { Text(quality.title) }
                    }
                }
            } label: {
                Label("Quality", systemImage: "gearshape").labelStyle(.iconOnly)
            }
            .disabled(session.isLoading)
        }
        #if os(iOS)
        if pictureInPicture.isAvailable || pictureInPicture.isActive {
            button(pictureInPicture.isActive ? "Close Picture in Picture" : "Picture in Picture",
                   icon: pictureInPicture.isActive ? "pip.exit" : "pip.enter") {
                pictureInPicture.toggle(restore: onRestorePictureInPicture)
            }
            .disabled(pictureInPicture.isStarting)
        }
        #endif
        button("Close video", icon: "xmark") { controller.close(session.id) }
    }

    private func button(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        #if os(tvOS)
        Button(action: action) { Label(title, systemImage: icon).labelStyle(.iconOnly) }
        #else
        MediaPlayerIconButton(title, systemImage: icon, action: action)
        #endif
    }
}

#if os(macOS)
@MainActor private struct MediaPlayerVideoSurface: NSViewRepresentable {
    let player: AVPlayer
    let showsControls: Bool

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = showsControls ? .inline : .none
        view.allowsPictureInPicturePlayback = true
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {
        view.controlsStyle = showsControls ? .inline : .none
        if view.player !== player { view.player = player }
    }
}
#else
@MainActor private struct MediaPlayerVideoSurface: UIViewRepresentable {
    let player: AVPlayer
    var onLayer: ((AVPlayerLayer) -> Void)? = nil

    func makeUIView(context: Context) -> Canvas {
        let view = Canvas()
        view.videoLayer.player = player
        view.videoLayer.videoGravity = .resizeAspect
        let layer = view.videoLayer
        Task { @MainActor in onLayer?(layer) }
        return view
    }

    func updateUIView(_ view: Canvas, context: Context) {
        if view.videoLayer.player !== player { view.videoLayer.player = player }
    }

    final class Canvas: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var videoLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
#endif
