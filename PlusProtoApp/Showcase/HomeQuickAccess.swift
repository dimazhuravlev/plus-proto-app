import SwiftUI

struct HomeQuickAccess: View {
    let feed: ShowcaseFeed
    var showsTelegramOverlay = false
    @State private var debugWaveIsPlaying = false
    @Environment(ActionBarState.self) var actionBar
    @Environment(AppNavigationState.self) var navigation
    @Environment(CinemaCatalog.self) var cinema

    private var isVibePlaying: Bool {
        #if DEBUG
        // Только визуальная проверка GPU, без изменений музыки и истории.
        if ProcessInfo.processInfo.arguments.contains("-debugRecentWaveShader") { return true }
        if ProcessInfo.processInfo.arguments.contains("-debugRecentWaveTransition") { return debugWaveIsPlaying }
        #endif
        return actionBar.isMusicPlaying && actionBar.music.map { MyVibeTracks.isVibe($0.id) } == true
    }

    var content: HomeRecentlyContent {
        HomeRecentlyContent(
            feed: feed,
            cinemaPromos: cinema.promos,
            previewIndex: HomePresentationSettings.shared.recentlyPreviewIndex,
            hasContinuingMovie: !actionBar.watchHistory.continuing.isEmpty,
            hasCurrentBook: actionBar.book != nil
        )
    }

    var compactStations: [VibeStation] { content.compactStations }
    var movie: MovieBlock? { content.movie }
    var album: AlbumBlock? { content.album }
    var book: BookBlock? { content.book }
    var artist: ArtistBlock? { content.artist }
    var additionalItems: [HomeShelfItem] { content.additionalItems }
    var moviePosition: Int { content.moviePosition }

    var body: some View {
        if showsTelegramOverlay {
            telegramOverlay
        } else if HomeRecentlyInlineLayout.isEnabled {
            inlineLabelsRow
        } else if HomeRecentlyTelegramLayout.isEnabled {
            telegramRow

        } else {
            standardRow
        }
    }

    private var standardRow: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: HomeQuickAccessLayout.gap) {
                    ForEach(actionBar.recently.items) { item in
                        historyCard(item)
                            .id(item.id)
                            .accessibilityIdentifier("recent-history-" + item.id)
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, HomeQuickAccessLayout.leading)
                .padding(.trailing, ServiceTopNavLayout.side)
                .frame(height: HomeQuickAccessLayout.rowHeight, alignment: .top)
                .backgroundPreferenceValue(HomeRecentlyWidths.self) { widths in
                    HomeRecentlyHorizontalAnchor(widths: widths, scale: HomeQuickAccessLayout.scale)
                }
            }
            .scrollIndicators(.hidden)
            // Ореол волны выходит за бокс миниатюры, но не увеличивает высоту ряда.
            .scrollClipDisabled()
            .frame(height: HomeQuickAccessLayout.rowHeight, alignment: .top)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Быстрый доступ")
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-debugRecentWaveTransition") {
                    for playing in [true, false, true] {
                        try? await Task.sleep(for: .seconds(4))
                        guard !Task.isCancelled else { return }
                        debugWaveIsPlaying = playing
                    }
                }
                if ProcessInfo.processInfo.arguments.contains("-debugRecentPetals") {
                    try? await Task.sleep(for: .seconds(2))
                    reader.scrollTo("station:testosterone", anchor: .center)
                }
                #endif
            }
        }
    }

    @ViewBuilder private var movieCard: some View {
        // Настоящая история приоритетнее рекомендации: прогресс не выдумывается.
        if HomePresentationSettings.shared.recentlyPreviewIndex < 0, let entry = actionBar.watchHistory.continuing.first {
            Button { actionBar.watch(entry.movie) } label: {
                captioned(entry.movie.title, width: 138) {
                    movieThumbnail(entry.movie.still, movieID: entry.movie.id, progress: entry.progress)
                }
            }
            .accessibilityLabel("Продолжить смотреть: \(entry.movie.title)")
            .zIndex(1)
        } else if let movie {
            Button { open(.movie(movie)) } label: {
                captioned(movie.title, width: 138) {
                    movieThumbnail(movie.still, movieID: movie.id, progress: HomePresentationSettings.shared.recentlyPreviewIndex >= 0 ? HomePresentationSettings.shared.recentlyPreviewProgress : movieProgress(movie.id))
                }
            }
            .accessibilityLabel(movie.title)
            .zIndex(1)
        }
    }

    @ViewBuilder private func stationCard(_ station: VibeStation) -> some View {
        if let photo = station.photo {
            // Фото исполнителя — сущность Artist, а не персональная волна.
            Button { open(.artist(ArtistBlock(id: 5535442, name: station.title, picture: .remote(photo)))) } label: {
                captioned(station.title, width: 80) {
                    artwork(.remote(photo), width: 80, height: 80, radius: 40)
                }
            }
            .accessibilityLabel(station.title)
            .id("recent-station-" + station.id)
        } else {
            Button { actionBar.openMyVibe() } label: {
                captioned(station.title, width: 80) {
                    CompactVibePetal(station: station, height: HomeQuickAccessLayout.height)
                }
            }
            .accessibilityLabel("Включить Мою волну: \(station.title)")
            .id("recent-station-" + station.id)
        }
    }

    private func additionalCard(_ item: HomeShelfItem) -> some View {
        Button { navigation.open(item.route) } label: {
            if case .book = item.route {
                captioned(item.title, width: bookSlotWidth) { bookThumbnail(item.artwork) }
            } else if case .artist = item.route {
                captioned(item.title, width: 80) { artwork(item.artwork, width: 80, height: 80, radius: 40) }
            } else {
                captioned(item.title, width: 78) { artwork(item.artwork, width: 78, height: 78, radius: 12) }
            }
        }.accessibilityLabel(item.title)
    }

    private func movieProgress(_ id: String) -> Double? {
        actionBar.watchHistory.entries.first { $0.id == id }?.progress
    }

    var vibeButton: some View {
        let scale = HomeQuickAccessLayout.scale
        let inlineProgress = HomeRecentlyInlineLayout.isEnabled ? HomeRecentlyPullState.shared.progress : 0
        let controlWidth = (isVibePlaying ? 43.0 : 42.0) * 0.8 + 8 * inlineProgress
        let controlHeight = (isVibePlaying ? 47.0 : 47.5) * 0.8 + 8 * inlineProgress
        let controlOpacity = HomeRecentlyInlineLayout.isEnabled
            ? HomeRecentlyInlineLayout.smooth((inlineProgress - 0.25) / 0.65) : 1
        return Button {
            if actionBar.music.map({ MyVibeTracks.isVibe($0.id) }) == true {
                actionBar.toggleMusicPlayback()
            } else {
                actionBar.openMyVibe()
            }
        } label: {
            Color.clear
                .frame(width: 70 * scale, height: 80 * scale)
                .overlay {
                    if HomePresentationSettings.shared.waveShaderEnabled {
                        RecentWaveShader(isPlaying: isVibePlaying)
                    } else if HomePresentationSettings.shared.recentlyWaveVideoEnabled && isVibePlaying {
                        VibeShader(isPlaying: isVibePlaying, opacity: HomePresentationSettings.shared.recentlyWaveOpacity)
                            .frame(width: (isVibePlaying ? 142 * 1.25 : 107.1) * scale,
                                   height: (isVibePlaying ? 141 * 1.25 : 107.1) * scale)
                            .saturation(HomePresentationSettings.shared.recentlyWaveSaturation)
                            .contrast(HomePresentationSettings.shared.recentlyWaveContrast)
                            .blendMode(.screen)
                            .offset(x: 6 * scale, y: -0.5 * scale)
                    } else {
                        Image("quickAccessWave").resizable()
                            .frame(width: 138 * scale, height: 137 * scale)
                            .blur(radius: 6 * scale).opacity(0.14)
                            .offset(x: 6 * scale, y: -0.5 * scale)
                        Image("quickAccessWave").resizable()
                            .frame(width: (isVibePlaying ? 142 : 107.1) * scale, height: (isVibePlaying ? 141 : 107.1) * scale)
                            .offset(x: 6 * scale, y: -0.5 * scale)
                    }
                }
                .overlay {
                    // SVG glyph centres differ from their shadow canvas centres.
                    // Keep the visible glyph centred as its canvas grows during expansion.
                    Image(isVibePlaying ? "quickAccessPause" : "quickAccessPlay")
                        .resizable()
                        .frame(width: controlWidth, height: controlHeight)
                        .offset(x: 6 * scale + (isVibePlaying ? -5.5 : -7) * controlWidth / (isVibePlaying ? 43 : 42),
                                y: -0.5 * scale + (isVibePlaying ? 7.5 : 7.75) * controlHeight / (isVibePlaying ? 47 : 47.5))
                        .opacity(controlOpacity)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .animation(HomeQuickAccessLayout.feedback, value: isVibePlaying)
        }
        .accessibilityLabel("Открыть опрос с Моей волны")
    }

    private func open(_ block: ShowcaseBlock) {
        if case .album(let album) = block {
            navigation.open(.album(EntityRef(id: album.id, title: album.subtitle, subtitle: album.title, artwork: album.cover)))
            return
        }
        if let route = block.entityRoute { navigation.open(route) }
    }
}
