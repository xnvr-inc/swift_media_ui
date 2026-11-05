import MediaUI
import SwiftUI
#if os(iOS)
import UIKit
#endif

enum DemoRoute: Hashable {
    case search
    case channel(DemoChannel)
    case post(DemoChannel)
}

@MainActor
struct DemoRoot: View {
    @AppStorage("demo.mode") private var mode: DemoMode = .video
    @AppStorage("demo.saved") private var savedIDs = ""
    @AppStorage("demo.watched") private var watchedIDs = ""
    @AppStorage("demo.followed") private var followedIDs = "motion,afterhours"
    @AppStorage("demo.reacted") private var reactedIDs = ""
    @State private var selection = DemoTab.home
    @State private var paths: [DemoTab: [DemoRoute]] = [:]
    @State private var expanded = false
    @State private var settingsPresented = false
    @State private var didLaunch = false
    @State private var pendingShowcaseWatch = false
    @State private var player = MediaPlayerController()

    private var selectedVideo: DemoVideo? { DemoCatalog.all.first { $0.id == player.selectedID } }
    private var availableSources: [MediaPlaybackSource] { DemoCatalog.feed(mode).compactMap(\.source) }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                shell(width: geometry.size.width)
                    .frame(maxWidth: .infinity, maxHeight: expanded ? 0 : .infinity)
                    .clipped()
                    .opacity(expanded ? 0 : 1)
                    .disabled(expanded)
                    .accessibilityHidden(expanded)

                if let video = selectedVideo {
                    workspace(video, height: geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(mode.tint)
        .sheet(isPresented: $settingsPresented) { settings }
        .onChange(of: player.selectedID) { _, id in
            if let id { record(id) } else { expanded = false }
        }
        .onChange(of: mode) {
            player.closeAll()
            paths.removeAll()
            selection = .home
            expanded = false
            if pendingShowcaseWatch {
                pendingShowcaseWatch = false
                openShowcaseWatch()
            }
        }
        .onAppear { applyLaunchScenario() }
    }

    @ViewBuilder private func shell(width: CGFloat) -> some View {
        #if os(macOS)
        sidebar
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad && width >= 750 {
            sidebar.navigationSplitViewStyle(.balanced)
        } else {
            tabs
        }
        #else
        tabs
        #endif
    }

    #if !os(tvOS)
    private var sidebar: some View {
        NavigationSplitView {
            List(selection: Binding<DemoTab?>(get: { selection }, set: { if let tab = $0 { selection = tab } })) {
                ForEach(mode.tabs) { tab in Label(tab.title, systemImage: tab.symbol).tag(tab) }
            }
            .navigationTitle("Swift Media UI")
            #if os(macOS)
            .contentMargins(.top, 48, for: .scrollContent)
            #endif
            .safeAreaInset(edge: .top, spacing: 0) {
                HStack {
                    wordmark
                    Text(mode.title).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, MediaLayout.pageInset)
            }
        } detail: {
            stack(selection)
        }
    }
    #endif

    private var tabs: some View {
        TabView(selection: $selection) {
            ForEach(mode.tabs) { tab in
                stack(tab)
                    .tabItem { Label(tab.title, systemImage: tab.symbol) }
                    .tag(tab)
            }
        }
    }

    private func stack(_ tab: DemoTab) -> some View {
        NavigationStack(path: Binding(get: { paths[tab, default: []] }, set: { paths[tab] = $0 })) {
            tabContent(tab)
                .navigationTitle(tab.title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    MediaToolbarWordmarkItem(image: DemoAssets.wordmark, title: "XNVR", identifier: "demo.wordmark")
                    ToolbarItem(placement: .topBarTrailing) { toolbarActions(tab) }
                    #elseif os(macOS)
                    ToolbarItem(placement: .navigation) { wordmark }
                    ToolbarItemGroup(placement: .primaryAction) {
                        searchButton(tab)
                        settingsButton
                    }
                    #endif
                }
                #if os(tvOS)
                .safeAreaInset(edge: .top) {
                    HStack {
                        wordmark
                        Spacer()
                        toolbarActions(tab)
                    }
                    .padding(.horizontal, MediaLayout.pageInset)
                    .padding(.bottom, 16)
                }
                #endif
                .navigationDestination(for: DemoRoute.self) { route in
                    switch route {
                    case .search:
                        DemoSearch(videos: DemoCatalog.feed(mode), open: open)
                    case .channel(let channel):
                        DemoChannelPage(
                            channel: channel, mode: mode, followed: contains(channel.id, in: followedIDs),
                            toggleFollowed: { followedIDs = toggled(channel.id, in: followedIDs) }, open: open
                        )
                    case .post(let channel):
                        DemoPostPage(
                            channel: channel, liked: contains(channel.id, in: reactedIDs),
                            toggleLike: { reactedIDs = toggled(channel.id, in: reactedIDs) }
                        )
                    }
                }
        }
    }

    private var wordmark: some View {
        DemoAssets.wordmark
            .renderingMode(.template)
            .resizable().scaledToFit()
            #if os(tvOS)
            .frame(width: 68, height: MediaToolbarWordmarkMetrics.height)
            #else
            .frame(width: 44, height: 28)
            #endif
            .foregroundStyle(.white)
            .accessibilityLabel("XNVR")
    }

    private func toolbarActions(_ tab: DemoTab) -> some View {
        HStack {
            searchButton(tab)
            settingsButton
        }
        .tint(.white)
    }

    private func searchButton(_ tab: DemoTab) -> some View {
        Button { paths[tab, default: []].append(.search) } label: {
            Label("Search", systemImage: "magnifyingglass").labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("demo.search")
    }

    private var settingsButton: some View {
        Button { settingsPresented = true } label: {
            Label("Settings", systemImage: "gearshape").labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("demo.settings")
    }

    @ViewBuilder private func tabContent(_ tab: DemoTab) -> some View {
        switch tab {
        case .home:
            DemoScrollPage {
                if mode == .live {
                    DemoHeading("Home", subtitle: "Live streams and replays")
                    DemoVideoSection("Live from MY", videos: DemoCatalog.live.filter {
                        contains($0.channel.id, in: followedIDs)
                    }, open: open)
                    DemoVideoSection("Recommended live", videos: DemoCatalog.live.filter {
                        !contains($0.channel.id, in: followedIDs)
                    }, open: open)
                    DemoVideoSection("Replays", videos: [DemoCatalog.amber], open: open)
                } else {
                    DemoHeading("Home", subtitle: "Recommended for you")
                    DemoVideoSection(nil, videos: [DemoCatalog.tidal, DemoCatalog.amber], open: open)
                    DemoVideoSection("Shorts", videos: DemoCatalog.shorts, portrait: true, open: open)
                }
                DemoCommunityCard(channel: mode == .live ? DemoCatalog.afterhours : DemoCatalog.motion)
            }
        case .subscriptions:
            DemoScrollPage {
                DemoHeading("Subscriptions", subtitle: "The channels you follow")
                DemoVideoSection("Latest videos", videos: DemoCatalog.feed(.video).filter {
                    contains($0.channel.id, in: followedIDs)
                }, open: open)
                DemoChannelList(channels: DemoCatalog.channels)
            }
        case .shorts:
            DemoScrollPage {
                DemoHeading("Shorts", subtitle: "Vertical videos")
                DemoVideoSection(nil, videos: DemoCatalog.shorts, portrait: true, open: open)
            }
        case .my:
            DemoScrollPage {
                DemoHeading("MY", subtitle: "Alex Morgan · Sample profile")
                if mode == .live {
                    DemoChannelList(channels: DemoCatalog.channels.filter { contains($0.id, in: followedIDs) })
                    DemoCommunityCard(channel: DemoCatalog.afterhours)
                }
                DemoVideoSection(mode == .video ? "Watch history" : "Recently watched", videos: videos(in: watchedIDs), open: open)
                DemoVideoSection(mode == .video ? "Watch later" : "Saved videos", videos: videos(in: savedIDs), open: open)
            }
        case .live:
            DemoScrollPage {
                DemoHeading("LIVE", subtitle: "Browse sample live channels")
                DemoVideoSection(nil, videos: DemoCatalog.live, open: open)
            }
        case .categories:
            DemoScrollPage {
                DemoHeading("Categories", subtitle: "Find a channel by category")
                DemoChannelList(channels: DemoCatalog.channels, categoryFirst: true)
            }
        }
    }

    private func workspace(_ video: DemoVideo, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            if expanded {
                HStack {
                    Button {
                        expanded = false
                    } label: {
                        Label("Back to browse", systemImage: "chevron.down")
                    }
                    .accessibilityIdentifier("demo.minimize")
                    Spacer()
                    Text(video.isLive ? "LIVE" : video.isShort ? "Shorts" : "Watch")
                        .font(.headline)
                    Spacer()
                    Button {
                        player.closeAll()
                    } label: {
                        Label("Close player", systemImage: "xmark").labelStyle(.iconOnly)
                    }
                    .accessibilityIdentifier("demo.closePlayer")
                }
                .padding(.horizontal, MediaLayout.pageInset)
                .padding(.vertical, 10)
                #if os(tvOS)
                .onExitCommand { expanded = false }
                #endif
            }

            MediaPlayer(
                controller: player, availableSources: availableSources, showsControls: expanded,
                onRestorePictureInPicture: { expanded = true }
            )
            .frame(height: expanded ? max(180, height * 0.53) : miniHeight)
            .background(.black)

            if expanded {
                DemoScrollPage {
                    DemoHeading(video.title, subtitle: "\(video.channel.name) · \(video.metadata)")
                    watchActions(video)
                    DemoDiscussion(live: video.isLive)
                    DemoVideoSection("Up next", videos: DemoCatalog.feed(mode).filter { $0.id != video.id }, open: open)
                }
            } else {
                HStack {
                    Button {
                        expanded = true
                    } label: {
                        Label(video.title, systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .accessibilityIdentifier("demo.expand")
                    Spacer()
                    Button {
                        player.closeAll()
                    } label: {
                        Label("Close player", systemImage: "xmark").labelStyle(.iconOnly)
                    }
                    .accessibilityIdentifier("demo.closePlayer")
                }
                .padding(.horizontal, MediaLayout.pageInset)
                .padding(.vertical, 6)
            }
        }
    }

    private var miniHeight: CGFloat {
        #if os(tvOS)
        110
        #else
        76
        #endif
    }

    private func watchActions(_ video: DemoVideo) -> some View {
        ScrollView(.horizontal) {
            HStack {
                Button {
                    paths[selection, default: []].append(.channel(video.channel))
                    expanded = false
                } label: {
                    Label(video.channel.name, systemImage: video.channel.symbol)
                }
                Button {
                    savedIDs = toggled(video.id, in: savedIDs)
                } label: {
                    let saved = contains(video.id, in: savedIDs)
                    Label(saved ? "Saved" : "Save", systemImage: saved ? "bookmark.fill" : "bookmark")
                }
                if video.isShort {
                    Button("Next Short") {
                        if let next = DemoCatalog.shorts.first(where: { $0.id != video.id }) { open(next) }
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var settings: some View {
        NavigationStack {
            DemoScrollPage {
                DemoHeading("Settings", subtitle: "Choose a sample experience")
                ForEach(DemoMode.allCases) { option in
                    Button {
                        mode = option
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(option.title).font(.headline)
                                Text(option.description).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if mode == option { Image(systemName: "checkmark.circle.fill") }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                    }
                    .accessibilityIdentifier("demo.mode.\(option.rawValue)")
                    .accessibilityAddTraits(mode == option ? .isSelected : [])
                }
                Button("Done") { settingsPresented = false }
                    .accessibilityIdentifier("demo.settings.done")
            }
            .navigationTitle("Settings")
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 360)
        #endif
    }

    private func open(_ video: DemoVideo) {
        guard let source = video.source else { return }
        if !player.sourceIDs.contains(source.id) { player.closeAll() }
        player.add(source)
        expanded = true
    }

    private func applyLaunchScenario() {
        guard !didLaunch else { return }
        didLaunch = true
        let arguments = ProcessInfo.processInfo.arguments
        let requested = arguments.contains("--showcase-live") ? DemoMode.live
            : arguments.contains("--showcase-video") ? .video : mode
        let launchesPlayer = arguments.contains("--showcase-watch")
        if requested != mode {
            pendingShowcaseWatch = launchesPlayer
            mode = requested
        } else if launchesPlayer {
            openShowcaseWatch()
        }
    }

    private func openShowcaseWatch() {
        let pair = mode == .live ? DemoCatalog.live : [DemoCatalog.tidal, DemoCatalog.amber]
        for video in pair {
            if let source = video.source { player.add(source) }
        }
        if let first = pair.first { player.select(first.id) }
        expanded = !player.sourceIDs.isEmpty
    }

    private func record(_ id: String) {
        watchedIDs = ([id] + watchedIDs.split(separator: ",").map(String.init).filter { $0 != id }).joined(separator: ",")
    }

    private func contains(_ id: String, in values: String) -> Bool {
        values.split(separator: ",").contains(Substring(id))
    }

    private func toggled(_ id: String, in values: String) -> String {
        let ids = values.split(separator: ",").map(String.init)
        return (ids.contains(id) ? ids.filter { $0 != id } : ids + [id]).joined(separator: ",")
    }

    private func videos(in values: String) -> [DemoVideo] {
        values.split(separator: ",").compactMap { id in DemoCatalog.all.first { $0.id == String(id) } }
    }
}

struct DemoChannelList: View {
    let channels: [DemoChannel]
    var categoryFirst = false

    var body: some View {
        VStack(alignment: .leading, spacing: MediaLayout.sectionContentSpacing) {
            Text(categoryFirst ? "Categories" : "Channels").font(MediaLayout.sectionTitle)
            ForEach(channels) { channel in
                NavigationLink(value: DemoRoute.channel(channel)) {
                    HStack {
                        DemoChannelAvatar(channel: channel)
                        VStack(alignment: .leading) {
                            Text(categoryFirst ? channel.category : channel.name).font(.headline)
                            Text(categoryFirst ? channel.name : channel.category).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }
}

struct DemoCommunityCard: View {
    let channel: DemoChannel

    var body: some View {
        VStack(alignment: .leading, spacing: MediaLayout.sectionContentSpacing) {
            Text("Community").font(MediaLayout.sectionTitle)
            NavigationLink(value: DemoRoute.post(channel)) {
                MediaPostCard(
                    MediaPostCardData(author: channel.name, avatar: nil, title: "Behind the scenes",
                                      body: "What should we play next? Tell us your favorite moment from the latest session.",
                                      views: "1.4K", likes: "128", comments: "4"),
                    surface: Color.white.opacity(0.07)
                ) { Text("2 hours ago").font(.caption).foregroundStyle(.secondary) }
            }
            .buttonStyle(.plain)
        }
    }
}
