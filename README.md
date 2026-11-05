# Swift Media UI

**Native multiview playback and reusable media UI for iPhone, iPad, Mac, and Apple TV.**

Swift Media UI grew out of a personal app for watching YouTube and other video
services with several videos in view and playback that can continue while
browsing. The reusable player and interface components are available as the
`MediaUI` Swift package. They use Apple SDKs with no third-party dependencies.
Your app handles its own catalog, accounts, and playable media sources.

[Install](#install) · [Run the demo](#run-the-demo) · [Components](#components)

![Multiview with sample live streams on Apple TV](Docs/Images/tvos-live.png)

*Multiview in the bundled Apple TV demo.*

## Playback

- **One video or several.** Open a URL or add videos from a source picker. Enlarge, select, or close a video while the other sessions keep playing.
- **Per-video controls.** Play, pause, seek, mute, or adjust volume for a video. Apply a volume preset to all open videos together.
- **Quality selection.** Let HLS choose a rendition automatically, or show the qualities your source provides. If a switch fails, playback can continue with the previous item.
- **Keep watching while browsing.** Use the in-app mini-player on iPhone and iPad or native Picture in Picture where supported.

## Platform support

Single-video playback and multiview are available on all four platforms.
Supported controls use Liquid Glass on current systems and fall back to
standard materials on earlier supported versions.

| Platform | Minimum OS | Playback outside the main player |
| --- | --- | --- |
| iPhone and iPad | iOS / iPadOS 17 | In-app floating dock; system PiP for one video or a composite of the multiview |
| Mac | macOS 14 | Single-video PiP through the native AVKit controls |
| Apple TV | tvOS 17 | In-app playback with Siri Remote focus and context menus |

## Install

Build the current source with [Xcode 26.1 or later](https://developer.apple.com/xcode/system-requirements)
for the Apple SDK APIs used by the package. The OS versions above are the
deployment targets.

In Xcode, choose **File → Add Package Dependencies**, enter
`https://github.com/xnvr-inc/swift_media_ui.git`, and add **MediaUI** to
your app target. Use the `main` branch to try the features documented here.
Pin a reviewed revision for an app release.

### Play a video

Pass a playable MP4 or HLS URL to the SwiftUI view.

```swift
import MediaUI

MediaPlayer(url: videoURL)
```

### Add multiview

The first list contains the sources that start open. The second list
populates the player's **Add video** picker.

```swift
let first = MediaPlaybackSource(url: firstURL, title: "First video")
let second = MediaPlaybackSource(url: secondURL, title: "Second video")

MediaPlayer(sources: [first], availableSources: [second])
```

Pass a `MediaPlayerController` to add, select, or close videos from elsewhere
in the host UI. Keep the same controller as the player moves, and give each
logical video a stable ID when its URL can change.

### Supply quality options

Use an asynchronous item factory when the provider exposes specific renditions
or issues expiring URLs. The factory receives `nil` for automatic quality.
A failed switch keeps the previous item and offers retry. Seekable video
keeps its position when switching items.

```swift
import AVFoundation
import MediaUI

let hd = MediaPlaybackQuality(id: "720p", title: "720p")
let source = MediaPlaybackSource(id: "episode-1", title: "Episode 1", qualities: [hd]) { quality in
    AVPlayerItem(url: quality == hd ? hdURL : automaticURL)
}
```

## Picture in Picture

On iPhone and iPad, one video uses its AVPlayer layer. In multiview, the
compositor fits decoded frames from the open videos into one PiP window.
A source keeps its place while loading, and a stalled source holds its most
recent frame. The host can keep that PiP session mounted while playing another
video in its main UI and manages how their audio plays together.

For an iOS or iPadOS host, enable **Audio, AirPlay, and Picture in Picture**
under **Background Modes** and configure the audio session for playback.
Keep the PiP player mounted and use `onRestorePictureInPicture` to bring
its screen back into view when appropriate.

## Run the demo

Open [MediaUIDemo.xcodeproj](Examples/MediaUIDemo.xcodeproj). Run
`MediaUIDemo-iOS` on an iPhone or iPad, `MediaUIDemo-macOS` on **My Mac**,
or `MediaUIDemo-tvOS` on Apple TV. The demo uses this checkout of the package
and plays bundled sample clips offline.

In **Settings**, switch between **Video** (subscriptions, shorts, channels,
and watch history) and **Live Platform** (live streams, categories, clips,
and chat). Both experiences use the same player and media components.

<details>
<summary>Screenshots on all four platforms</summary>

The iPhone, iPad, and Apple TV images are simulator captures. The Mac images
are from the native Mac demo.

| Platform | Video | Live Platform |
| --- | --- | --- |
| iPhone | ![Video home on iPhone](Docs/Images/iphone-video.png) | ![Live home on iPhone](Docs/Images/iphone-live.png) |
| iPad | ![Video home on iPad](Docs/Images/ipad-video.png) | ![Live multiview on iPad](Docs/Images/ipad-live.png) |
| Mac | ![Video home on Mac](Docs/Images/macos-video.png) | ![Live home on Mac](Docs/Images/macos-live.png) |
| Apple TV | ![Video home on Apple TV](Docs/Images/tvos-video.png) | ![Live multiview on Apple TV](Docs/Images/tvos-live.png) |

</details>

From the repository root, you can also launch the Mac demo or run the package tests:

```sh
swift run MediaUIDemo --showcase-live --showcase-watch
swift test
```

Use `--showcase-video` for the Video experience, or omit `--showcase-watch`
to start on its home screen. To regenerate the Xcode project with XcodeGen,
run `xcodegen generate` from `Examples/`.

## Components

Use the [library sources](Sources/MediaUI) and [demo](Examples/MediaUIDemo)
to compose a custom player or browsing UI.

| Component | Use it for |
| --- | --- |
| `MediaVideoStage`, `PlaybackMultiviewLayout`, `MediaPlaybackTiles` | A video surface or a grid of independently controlled playback tiles |
| `MediaMiniPlayerDock`, `MediaMiniPlayerLayout` | An iPhone or iPad dock that snaps one or more playing tiles to a safe-area corner; reuse `MediaMiniPlayerMotion.minimizeDuration` when collapsing an expanded player |
| `MediaPiPSource`, `MediaMultiviewPictureInPicture` | Feed AVPlayers or decoded frames to the iPhone and iPad PiP compositor; the host owns the source list, audio mix, and scene behavior |
| `MediaReadingSheet` | An iPhone or iPad reader in a full-screen presentation; use `heightBelowPlayer` or `topEdge` to position it below the player or app bar |
| `TVMediaPlaybackTile` | Remote focus and Select on Apple TV; hold Select for `overviewMenu` or an `onLongPress` action |

The module also includes volume presets, media cards, badges, discussion views,
portrait paging, and Apple TV side panels.

## Codex skill

Copy [skills/swift-media-ui](skills/swift-media-ui) into your Codex skills
directory and use `$swift-media-ui` for help with source factories, focus,
quality recovery, and PiP verification.

```sh
mkdir -p "${CODEX_HOME:-$HOME/.codex}/skills"
cp -R skills/swift-media-ui "${CODEX_HOME:-$HOME/.codex}/skills/"
```

## License

[MIT](LICENSE) · [xnvr](https://xnvr.dev/#open-source)
