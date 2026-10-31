import SwiftUI

/// Полки после большой карусели — общие компоненты сервисов (задача пользователя 2026-10-31:
/// локальные карусели «Главной» переехали на них): постеры Кино (`CinemaPosterCarousel`),
/// книги (`BooksCarousel`), исполнители — карточка музыки (`MusicCard`), «Топ-10» — те же
/// карусели Кино и Книг с цифрами мест, «Популярная музыка» — «Открытый плейлист»
/// (`MusicOpenPlaylistCard`). Шапка карусели ведёт в таб сервиса. Своё здесь — только
/// «Моё избранное».
struct HomeShelves: View {
    let feed: ShowcaseFeed
    @Environment(CinemaCatalog.self) private var cinema
    @Environment(BooksHomeCatalog.self) private var books
    @Environment(CollectionStore.self) private var collection
    @Environment(AppNavigationState.self) private var navigation

    /// Без ключей полки стоят на образцах `HomeShelfSamples`; живое — из каталогов
    /// сервисов, моки каталогов (`mock…`) сюда не идут.
    private var isLive: Bool { APIKeysCheck.isKinopoiskConfigured }

    private var movies: [CinemaCatalog.Title] {
        let live = isLive ? unique(cinema.rows.flatMap(\.titles).filter { !$0.id.hasPrefix("mock") && $0.poster != nil }) : []
        return live.isEmpty ? HomeShelfSamples.movies.map(Self.movie) : live
    }
    private var topMovies: [CinemaCatalog.Title] {
        let live = isLive ? cinema.topTitles.filter { !$0.id.hasPrefix("mock") } : []
        return live.isEmpty ? HomeShelfSamples.movies.map(Self.movie) : live
    }
    private var bookItems: [BooksHomeCatalog.Book] {
        let live = isLive ? unique(books.rows.flatMap(\.books).filter { !$0.id.hasPrefix("mock") }) : []
        return live.isEmpty ? HomeShelfSamples.books.map(Self.book) : live
    }
    private var topBooks: [BooksHomeCatalog.Book] {
        let live = isLive ? books.top.filter { !$0.id.hasPrefix("mock") } : []
        return live.isEmpty ? HomeShelfSamples.books.map(Self.book) : live
    }
    private var artists: [HomeShelfItem] {
        guard isLive else { return HomeShelfSamples.artists }
        let live = feed.promo.compactMap { block -> HomeShelfItem? in
            guard case .artist(let artist) = block else { return nil }
            return HomeShelfItem(id: block.id, title: artist.name, subtitle: "", artwork: artist.picture, route: artist.route)
        }
        return live.isEmpty ? HomeShelfSamples.artists : live
    }
    private var tracks: [MusicNowPlaying] {
        guard isLive else { return HomeShelfSamples.tracks + Array(MyVibeTracks.all.prefix(3)) }
        let live = collection.items(.track, on: .favorites).compactMap(\.playable)
        return live.isEmpty ? HomeShelfSamples.tracks : live
    }

    var body: some View {
        VStack(spacing: 0) {
            CinemaPosterCarousel(title: "Кино для вас", titles: movies, headerAction: { navigation.select(.kinopoisk) })
            favorites
            artistShelf
            BooksCarousel(title: "Книги для вас", books: bookItems, headerAction: { navigation.select(.books) })
            CinemaPosterCarousel(title: CinemaCatalog.topTitle, titles: topMovies, isRanked: true, headerAction: { navigation.select(.kinopoisk) })
            MusicOpenPlaylistCard(title: "Популярная музыка", tracks: tracks)
            BooksCarousel(title: BooksHomeCatalog.topTitle, books: topBooks, isRanked: true, headerAction: { navigation.select(.books) })
        }
    }

    // MARK: - Музыка для вас

    /// Исполнители — круги карточки музыки, две целые и край третьей (`MusicCarouselFit.medium`).
    private var artistShelf: some View {
        let width = MusicCarouselFit.medium.cardWidth
        return ServiceCarousel(
            title: "Музыка для вас",
            cardHeight: MusicCardLayout.height(.medium, width: width, shape: .circle),
            headerAction: { navigation.select(.music) }
        ) {
            ForEach(artists) { item in
                Button { navigation.open(item.route) } label: {
                    MusicCard(size: .medium, width: width, shape: .circle, cover: item.artwork, title: item.title, zoomRoute: item.route)
                }
                .buttonStyle(PressScaleButtonStyle(pressedScale: PressMotion.cardScale))
            }
        }
    }

    // MARK: - Моё избранное

    private var favorites: some View {
        VStack(spacing: 0) {
            EntitySectionHeader(title: "Моё избранное", showsChevron: false, lineHeight: ServiceCarouselLayout.headerLine)
            HStack(spacing: 8) {
                favorite("Кино", icon: "shelfFavoriteMovie", glow: "shelfGlowMovie", kind: .movie, size: CGSize(width: 243.422, height: 143))
                favorite("Музыка", icon: "shelfFavoriteMusic", glow: "shelfGlowMusic", kind: .track, size: CGSize(width: 240.033, height: 121.817))
                favorite("Книги", icon: "shelfFavoriteBook", glow: "shelfGlowBook", kind: .book, size: CGSize(width: 220.755, height: 143.446))
            }
            .padding(.horizontal, 16)
        }.padding(.vertical, 8)
    }

    private func favorite(_ title: String, icon: String, glow: String, kind: CollectionItem.Kind, size: CGSize) -> some View {
        Button { navigation.push(CollectionListRoute(source: .shelf(kind, .favorites), title: title)) } label: {
            Color.clear.frame(maxWidth: .infinity).frame(height: 94)
                .glassSurface(
                    RoundedRectangle(cornerRadius: 32),
                    blur: 20, fill: .fillNine,
                    border: Color.white.opacity(0.1), borderWidth: 1
                )
                .overlay(alignment: .top) {
                    let isMovie = kind == .movie
                    let isMusic = kind == .track
                    let centerY: CGFloat = isMovie ? 100.658 : (isMusic ? 102.602 : 95.028)
                    Image(glow).resizable().frame(width: size.width, height: size.height)
                        .scaleEffect(x: 1, y: -1)
                        .rotationEffect(.degrees(isMovie ? -172.59 : (isMusic ? 177.24 : 178.9)))
                        .offset(x: isMovie ? 3.155 : (isMusic ? 6.014 : 10.907), y: centerY - size.height / 2)
                }
                .overlay(alignment: .top) {
                    VStack(spacing: 12) {
                        Image(icon).resizable().frame(width: 24, height: 24)
                        Text(title).plusText(.textS, .medium).foregroundStyle(Color.fillOne)
                    }.padding(.top, 19)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .overlay { RoundedRectangle(cornerRadius: 32).strokeBorder(Color.white.opacity(0.1), lineWidth: 1) }
        }.buttonStyle(.plain)
    }

    // MARK: - Данные

    /// Тайтл или книга — один раз на полку: в подборках сервиса они могут повторяться.
    private func unique<Item: Identifiable>(_ items: [Item]) -> [Item] where Item.ID == String {
        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    private static func movie(_ item: HomeShelfItem) -> CinemaCatalog.Title {
        CinemaCatalog.Title(id: item.id, title: item.title, poster: item.artwork, route: item.route)
    }

    private static func book(_ item: HomeShelfItem) -> BooksHomeCatalog.Book {
        BooksHomeCatalog.Book(id: item.id, title: item.title, author: item.subtitle, cover: item.artwork, aspect: nil)
    }
}
