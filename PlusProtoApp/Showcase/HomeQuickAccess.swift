import SwiftUI

struct HomeQuickAccess: View {
    let feed: ShowcaseFeed
    @State private var debugWaveIsPlaying = false
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @Environment(CinemaCatalog.self) private var cinema

    private var isVibePlaying: Bool {
        #if DEBUG
        // Только визуальная проверка GPU, без изменений музыки и истории.
        if ProcessInfo.processInfo.arguments.contains("-debugRecentWaveShader") { return true }
        if ProcessInfo.processInfo.arguments.contains("-debugRecentWaveTransition") { return debugWaveIsPlaying }
        #endif
        return actionBar.isMusicPlaying && actionBar.music.map { MyVibeTracks.isVibe($0.id) } == true
    }

    private var content: HomeRecentlyContent {
        HomeRecentlyContent(
            feed: feed,
            cinemaPromos: cinema.promos,
            previewIndex: HomePresentationSettings.shared.recentlyPreviewIndex,
            hasContinuingMovie: !actionBar.watchHistory.continuing.isEmpty,
            hasCurrentBook: actionBar.book != nil
        )
    }

    private var compactStations: [VibeStation] { content.compactStations }
    private var movie: MovieBlock? { content.movie }
    private var album: AlbumBlock? { content.album }
    private var book: BookBlock? { content.book }
    private var artist: ArtistBlock? { content.artist }
    private var additionalItems: [HomeShelfItem] { content.additionalItems }
    private var moviePosition: Int { content.moviePosition }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(spacing: HomeQuickAccessLayout.gap) {
                    captioned("Моя волна", width: 70, leading: 4) { vibeButton }
                        .zIndex(1)
                    if moviePosition == 0 { movieCard }
                    if let album {
                        Button { open(.album(album)) } label: {
                            captioned(album.subtitle, width: 78) {
                                artwork(album.cover, width: 78, height: 78, radius: 12)
                            }
                        }
                        .accessibilityLabel("\(album.title), \(album.subtitle)")
                        .zIndex(1)
                    }
                    if moviePosition == 1 { movieCard }
                    if HomePresentationSettings.shared.recentlyPreviewIndex < 0, let current = actionBar.book {
                        Button { actionBar.read(current) } label: { captioned(current.title, width: bookSlotWidth) { bookThumbnail(current.cover) } }
                            .accessibilityLabel("Продолжить читать: \(current.title)")
                            .zIndex(1)
                    } else if let book {
                        Button { open(.book(book)) } label: { captioned(book.title, width: bookSlotWidth) { bookThumbnail(book.cover) } }
                            .accessibilityLabel(book.title)
                            .zIndex(1)
                    }
                    if moviePosition == 2 { movieCard }
                    if HomePresentationSettings.shared.recentlyPreviewIndex >= 0 {
                        let pool = HomeShelfSamples.artists
                        let item = pool[HomePresentationSettings.shared.recentlyPreviewIndex % pool.count]
                        Button { navigation.open(item.route) } label: {
                            captioned(item.title, width: 80) {
                                artwork(item.artwork, width: 80, height: 80, radius: 40)
                            }
                        }.accessibilityLabel(item.title)
                            .zIndex(1)
                    } else if let artist {
                        Button { open(.artist(artist)) } label: {
                            captioned(artist.name, width: 80) {
                                artwork(artist.picture, width: 80, height: 80, radius: 40)
                            }
                        }
                        .accessibilityLabel(artist.name)
                        .zIndex(1)
                    }
                    if moviePosition == 3 { movieCard }
                    ForEach(Array(additionalItems.enumerated()), id: \.offset) { index, item in
                        additionalCard(item).zIndex(1)
                        if moviePosition == index + 4 { movieCard }
                        if index < compactStations.count {
                            stationCard(compactStations[index]).zIndex(compactStations[index].photo == nil ? 0 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, HomeQuickAccessLayout.leading)
                .padding(.trailing, ServiceTopNavLayout.side)
                .frame(height: HomeQuickAccessLayout.rowHeight)
                .backgroundPreferenceValue(HomeRecentlyWidths.self) { widths in
                    HomeRecentlyHorizontalAnchor(widths: widths, scale: HomeQuickAccessLayout.scale)
                }
            }
            .scrollIndicators(.hidden)
            // Ореол волны выходит за бокс миниатюры, но не увеличивает высоту ряда.
            .scrollClipDisabled()
            .frame(height: HomeQuickAccessLayout.rowHeight)
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
                    reader.scrollTo("recent-station-" + compactStations[0].id, anchor: .center)
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

    private var vibeButton: some View {
        let scale = HomeQuickAccessLayout.scale
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
                    // Keep the control fixed-size, following the artwork centre (6, -0.5).
                    Image(isVibePlaying ? "quickAccessPause" : "quickAccessPlay")
                        .resizable()
                        .frame(width: (isVibePlaying ? 43 : 42) * 0.8, height: (isVibePlaying ? 47 : 47.5) * 0.8)
                        .offset(x: 6 * scale + (isVibePlaying ? -5.5 : -7) * 0.8,
                                y: -0.5 * scale + (isVibePlaying ? 7.5 : 7.75) * 0.8)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .animation(HomeQuickAccessLayout.feedback, value: isVibePlaying)
        }
        .accessibilityLabel(isVibePlaying ? "Пауза Моей волны" : "Включить Мою волну")
        .accessibilityValue(isVibePlaying ? "Играет" : "На паузе")
    }

    private func open(_ block: ShowcaseBlock) {
        if case .album(let album) = block {
            navigation.open(.album(EntityRef(id: album.id, title: album.subtitle, subtitle: album.title, artwork: album.cover)))
            return
        }
        if let route = block.entityRoute { navigation.open(route) }
    }
}
