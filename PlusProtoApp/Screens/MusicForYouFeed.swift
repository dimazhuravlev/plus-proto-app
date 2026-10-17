import SwiftUI

/// Числа ленты «Для вас» — макет `68:15807` (холст 375; карусели — `MusicCarouselFit`).
enum MusicForYouLayout {
    /// Лента начинается под навигацией: первая карусель заходит под ряд на 6
    /// (`carousel` на y 104 при низе навигации 110)
    static let contentTop: CGFloat = ServiceTopNavLayout.rowHeight - 6
    /// Поле под лентой — `pb-[24px]` у малых, больших и станций, `pb-[16px]` у счётчиков
    static let wideBottom: CGFloat = 24
    static let counterBottom: CGFloat = 16
    static let feedBottom: CGFloat = 16
    static let legalSide: CGFloat = 16
    static let legalPadding: CGFloat = 16
    static let legalRadius: CGFloat = 16
}

/// Плитка средней карусели — фото и что на нём, плюс куда ведёт тап.
private struct MusicTile: Identifiable {
    let id: String
    let image: ArtworkSource?
    let content: MusicTileCard.Content
    var caption: String? = nil
    var route: EntityRoute? = nil
    var playable: MusicNowPlaying? = nil
    /// Станция «Моей волны» — тап включает волну.
    var isVibe = false
    /// «Играет сейчас» — тап раскрывает плеер.
    var opensPlayer = false
}

/// Витрина «Для вас» таба Музыки (задача пользователя 2026-10-17, макет `68:15807`): сверху
/// вниз — «Слушали недавно», блоки «Похоже на …» вперемешку со средними каруселями,
/// «Новые релизы» и юридический текст.
///
/// Живое: «Слушали недавно» — ряд ПП (`RecentlyConsumed`) и «Мне нравится»; «Похоже на»
/// и «Новые релизы» — Deezer (`MusicHomeCatalog`); «Играет сейчас» — бар. Статистики
/// у нас нет: «На повторе» и «Герои месяца» — треки и исполнители из истории, числа —
/// текстом макета; станции «Моей волны» — названия и фото макета, тап включает волну
/// (решение пользователя 2026-10-17).
struct MusicForYouFeed: View {
    @Binding var scrollOffset: CGFloat
    @Binding var scrollPosition: ScrollPosition

    @Environment(MusicHomeCatalog.self) private var catalog
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation

    private typealias Layout = MusicForYouLayout

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                recentSection
                block(0)
                tilesSection("На повторе в этом месяце", tiles: repeatTiles, bottom: Layout.counterBottom)
                tilesSection("Жанры на ваш вкус", tiles: genreTiles, bottom: Layout.wideBottom)
                tilesSection("Герои вашего месяца", tiles: heroTiles, captionLines: 2, bottom: Layout.counterBottom)
                releasesSection
                block(1)
                tilesSection("Моя Волна: любимые", tiles: Self.stations(MusicForYouMocks.favourites), bottom: Layout.wideBottom)
                block(2)
                tilesSection("Совпадает с моментом", tiles: Self.stations(MusicForYouMocks.moments), bottom: Layout.wideBottom)
                block(3)
                tilesSection("Моя Волна под любое дело", tiles: Self.stations(MusicForYouMocks.activities), bottom: Layout.wideBottom)
                legal
            }
            .animation(EntityMotion.reveal, value: catalog.isLoaded)
            .padding(.bottom, Layout.feedBottom)
        }
        .scrollIndicators(.hidden)
        .contentMargins(.top, Layout.contentTop, for: .scrollContent)
        .scrollPosition($scrollPosition)
        .trackNavBarScroll(into: $scrollOffset)
        #if DEBUG
        // `-debugMusicScroll <pt>` — стартовая прокрутка ленты, когда каталог собрался:
        // нижние секции иначе не снять скриншотом.
        .task(id: catalog.isLoaded) {
            let offset = UserDefaults.standard.double(forKey: "debugMusicScroll")
            guard offset > 0, catalog.isLoaded else { return }
            try? await Task.sleep(for: .milliseconds(1500))
            guard !Task.isCancelled else { return }
            scrollPosition.scrollTo(y: offset)
        }
        #endif
    }

    // MARK: - Слушали недавно

    /// «Мне нравится» и что слушали — альбомы, плейлисты, исполнители ряда ПП.
    private var recentItems: [MusicItem] {
        var items = [MusicItem(id: "liked", title: "Мне нравится", cover: .asset("musicLikedCover"), route: nil)]
        for recent in actionBar.recently.items {
            switch recent {
            case .music(let track):
                items.append(MusicItem(
                    id: "recent-" + recent.id,
                    title: track.album ?? track.title,
                    subtitle: track.artist,
                    cover: track.cover,
                    route: track.containerRoute,
                    playable: track
                ))
            case .artist(let ref):
                items.append(MusicItem(id: "recent-" + recent.id, shape: .circle, title: ref.title, cover: ref.artwork, route: .artist(ref)))
            case .movie, .book, .myVibe:
                break
            }
        }
        return items
    }

    private var recentSection: some View {
        let width = MusicCarouselFit.small.cardWidth
        return ServiceCarousel(
            title: "Слушали недавно",
            cardHeight: MusicCardLayout.height(.small, width: width),
            showsChevron: false,
            bottomPadding: Layout.wideBottom
        ) {
            ForEach(recentItems) { item in
                Button {
                    if item.id == "liked" {
                        // «Мне нравится» — коллекция «Моё».
                        navigation.showRoot(of: .collection)
                    } else {
                        MusicItemAction.perform(item, actionBar: actionBar, navigation: navigation)
                    }
                } label: {
                    MusicCard(
                        size: .small,
                        width: width,
                        shape: item.shape,
                        cover: item.cover,
                        title: item.title,
                        subtitle: item.subtitle,
                        zoomRoute: item.route
                    )
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
            }
        }
    }

    // MARK: - Похоже на

    @ViewBuilder
    private func block(_ index: Int) -> some View {
        if !catalog.isLoaded {
            MusicArtistBlockSkeleton()
                .transition(.opacity)
        } else if catalog.blocks.indices.contains(index) {
            MusicArtistBlockCard(block: catalog.blocks[index])
                .transition(.opacity)
        }
    }

    // MARK: - Новые релизы

    @ViewBuilder
    private var releasesSection: some View {
        let width = MusicCarouselFit.large.cardWidth
        if !catalog.isLoaded || !catalog.releases.isEmpty {
            ServiceCarousel(
                title: "Новые релизы",
                cardHeight: MusicCardLayout.height(.large, width: width, showsAvatar: true),
                bottomPadding: Layout.wideBottom
            ) {
                if catalog.isLoaded {
                    ForEach(catalog.releases) { item in
                        Button { MusicItemAction.perform(item, actionBar: actionBar, navigation: navigation) } label: {
                            MusicCard(
                                size: .large,
                                width: width,
                                cover: item.cover,
                                title: item.title,
                                subtitle: item.subtitle,
                                avatar: item.avatar,
                                isExplicit: item.isExplicit,
                                zoomRoute: item.route
                            )
                        }
                        .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
                    }
                } else {
                    ForEach(0..<2, id: \.self) { _ in
                        MusicCardSkeleton(size: .large, width: width, showsAvatar: true)
                    }
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Средние карусели

    private func tilesSection(_ title: String, tiles: [MusicTile], captionLines: Int = 1, bottom: CGFloat) -> some View {
        let width = MusicCarouselFit.medium.cardWidth
        let hasCaption = tiles.contains { $0.caption != nil }
        return ServiceCarousel(
            title: title,
            cardHeight: MusicTileCard.height(width: width, captionLines: hasCaption ? captionLines : 0),
            showsChevron: false,
            bottomPadding: bottom
        ) {
            ForEach(tiles) { tile in
                Button { open(tile) } label: {
                    MusicTileCard(
                        image: tile.image,
                        content: tile.content,
                        caption: tile.caption,
                        captionLines: captionLines,
                        width: width
                    )
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
            }
        }
    }

    private func open(_ tile: MusicTile) {
        if tile.opensPlayer {
            actionBar.openMusicPlayer()
        } else if tile.isVibe {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.openMyVibe()
        } else if let route = tile.route {
            navigation.open(route)
        } else if let playable = tile.playable {
            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred(intensity: ShowcaseMotion.tapHapticIntensity)
            actionBar.open(.music(playable))
        }
    }

    /// Треки из истории, свежие первыми; не хватает — свежие релизы.
    private var historyTracks: [MusicNowPlaying] {
        var seen = Set<String>()
        return actionBar.recently.items.compactMap { item -> MusicNowPlaying? in
            guard case .music(let track) = item, seen.insert(track.title).inserted else { return nil }
            return track
        }
    }

    /// «На повторе в этом месяце» — числа макета (184, 93, 701), треки — из истории.
    private var repeatTiles: [MusicTile] {
        var tiles = historyTracks.prefix(MusicForYouMocks.repeatCounts.count).enumerated().map { index, track in
            MusicTile(
                id: "repeat-\(track.id)",
                image: track.cover,
                content: .counter(value: MusicForYouMocks.repeatCounts[index], unit: MusicForYouMocks.timesUnit(MusicForYouMocks.repeatCounts[index])),
                caption: track.title,
                playable: track
            )
        }
        for release in catalog.releases where tiles.count < MusicForYouMocks.repeatCounts.count {
            let count = MusicForYouMocks.repeatCounts[tiles.count]
            tiles.append(MusicTile(
                id: "repeat-\(release.id)",
                image: release.cover,
                content: .counter(value: count, unit: MusicForYouMocks.timesUnit(count)),
                caption: release.title,
                route: release.route
            ))
        }
        return tiles
    }

    /// «Герои вашего месяца» — исполнители из истории и блоков, минуты — текстом макета.
    private var heroTiles: [MusicTile] {
        var seen = Set<String>()
        var heroes: [(name: String, photo: ArtworkSource, route: EntityRoute?)] = []
        for item in actionBar.recently.items {
            switch item {
            case .artist(let ref) where seen.insert(ref.title).inserted:
                heroes.append((ref.title, ref.artwork, .artist(ref)))
            case .music(let track) where track.artistPicture != nil && seen.insert(track.artist).inserted:
                heroes.append((track.artist, track.artistPicture ?? track.cover, nil))
            default:
                break
            }
        }
        for block in catalog.blocks where seen.insert(block.name).inserted {
            heroes.append((block.name, block.photo, block.route))
        }
        return heroes.prefix(MusicForYouMocks.heroMinutes.count).enumerated().map { index, hero in
            let minutes = MusicForYouMocks.heroMinutes[index]
            return MusicTile(
                id: "hero-\(hero.name)",
                image: hero.photo,
                content: .counter(value: minutes, unit: MusicForYouMocks.minutesUnit(minutes)),
                caption: hero.name,
                route: hero.route
            )
        }
    }

    /// «Жанры на ваш вкус»: «Играет сейчас» — что в баре (нет — исполнитель макета),
    /// дальше станции макета.
    private var genreTiles: [MusicTile] {
        let nowPlaying: MusicTile
        if let music = actionBar.music, !MyVibeTracks.isVibe(music.id) {
            nowPlaying = MusicTile(
                id: "now-playing",
                image: music.artistPicture ?? music.cover,
                content: .nowPlaying(label: "Играет сейчас", avatar: music.artistPicture ?? music.cover, name: music.artist),
                opensPlayer: true
            )
        } else {
            nowPlaying = MusicTile(
                id: "now-playing",
                image: .asset("mockStationNowPlaying"),
                content: .nowPlaying(label: "Играет сейчас", avatar: .asset("mockStationNowPlayingAvatar"), name: "Sonic Youth"),
                isVibe: true
            )
        }
        return [nowPlaying] + Self.stations(MusicForYouMocks.genres)
    }

    private static func stations(_ stations: [MusicForYouMocks.Station]) -> [MusicTile] {
        stations.map { station in
            MusicTile(
                id: "station-\(station.title)",
                image: .asset(station.image),
                content: .station(label: "Моя волна", title: station.title),
                isVibe: true
            )
        }
    }

    // MARK: - Юридический текст

    private var legal: some View {
        Text(MusicForYouMocks.legal)
            .plusText(.textS, .medium)
            .foregroundStyle(Color.fillSeven)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Layout.legalPadding)
            .background(Color.fillNine, in: RoundedRectangle(cornerRadius: Layout.legalRadius, style: .continuous))
            .padding(Layout.legalSide)
    }
}

/// Тексты и картинки «Для вас», которых нет в данных, — ровно из макета `68:15807`.
enum MusicForYouMocks {
    /// Станция «Моей волны» — без «нравится» в углу (правка пользователя 2026-10-17).
    struct Station {
        let title: String
        let image: String
    }

    static let repeatCounts = [184, 93, 701]
    static let heroMinutes = [17, 6, 17]

    static func timesUnit(_ count: Int) -> String {
        CollectionCopy.plural(count, one: "раз", few: "раза", many: "раз")
    }

    static func minutesUnit(_ count: Int) -> String {
        CollectionCopy.plural(count, one: "минута", few: "минуты", many: "минут")
    }

    static let genres = [
        Station(title: "Трип-хоп", image: "mockStationTripHop"),
        Station(title: "Focus", image: "mockStationFocus"),
    ]
    static let favourites = [
        Station(title: "Bosnian Rainbows", image: "mockStationBosnianRainbows"),
        Station(title: "Ride", image: "mockStationRide"),
        Station(title: "Portishead", image: "mockStationPortishead"),
    ]
    static let moments = [
        Station(title: "Спокойное", image: "mockStationCalm"),
        Station(title: "Сентиментальное", image: "mockStationSentimental"),
        Station(title: "Грустное", image: "mockStationSad"),
    ]
    static let activities = [
        Station(title: "Бег", image: "mockStationRun"),
        Station(title: "В\u{00A0}дороге", image: "mockStationRoad"),
        Station(title: "Тренируюсь", image: "mockStationSad"),
    ]

    /// Юридический текст Яндекс Музыки — из макета; однобуквенные слова — с неразрывным пробелом.
    static let legal = """
    © 2026 Яндекс Музыка • Проект компании Яндекс

    В\u{00A0}Яндекс Музыке может встречаться контент, не предназначенный для несовершеннолетних. Эти материалы отмечены значком (!). Их показ можно ограничить в\u{00A0}Настройках

    Незаконное потребление наркотических средств, психотропных веществ, их аналогов причиняет вред здоровью, их незаконный оборот запрещён и\u{00A0}влечёт установленную законодательством ответственность
    """
}
