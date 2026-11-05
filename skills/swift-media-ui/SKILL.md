---
name: swift-media-ui
description: Integrate or maintain the MediaUI Swift package from xnvr-inc/swift_media_ui. Use when adding a source-driven player, native multiview, or shared media controls to an Apple-platform Swift app, or when changing this package's components and playback behavior.
---

# Swift Media UI

Read the [package README](https://github.com/xnvr-inc/swift_media_ui) and inspect the source at the consumer's resolved revision before using an API. For a new integration, depend on the MediaUI product from that repository and select a reviewed version or exact revision. Follow the consumer's dependency and platform policies.

## Integrate a player

- Use `MediaPlayer(url:)` for one directly playable URL. For multiview, pass initial `MediaPlaybackSource` values and `availableSources`. Use `MediaPlayerController` for additions or closures initiated elsewhere in the app.
- Keep the same controller and mounted player when collapsing into a mini-player. Use `showsControls: false` for its compact presentation.
- Use stable content IDs when URLs expire or change. A source factory receives the chosen quality or `nil` for automatic and must return a fresh `AVPlayerItem`. Expose only available qualities. Supply refreshed URLs or prepared assets through the factory.
- Keep accounts, discovery, service APIs, URL extraction, and custom transport in the host. Use the public layout, tile and control components with an existing playback engine when it cannot vend `AVPlayerItem`s. Preserve service-specific behavior when changing an existing integration.
- Put generally reusable controls, session behavior, layouts, and platform handling in MediaUI. Keep product branding, presentation and source resolution with the consuming app.

## Verify changes

- Exercise add, duplicate selection, close and featured layout with at least two media sources. Check that moving or closing one tile preserves the other session and its volume. Exercise a failed quality selection and recovery with a valid source.
- Check keyboard and remote focus on affected platforms. Run `swift test` on macOS, then build the package and test the affected host destinations. Build success and simulator checks are separate from device playback verification.
- On iPhone and iPad, confirm host background playback settings and check PiP entry, return and single-video fallback on a supported device. Report which PiP modes were exercised. Keep the source view mounted while PiP runs.
- Use bundled sample clips or authorized media for public examples and screenshots.
