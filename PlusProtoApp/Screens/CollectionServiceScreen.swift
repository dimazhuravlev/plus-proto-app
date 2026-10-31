import SwiftUI

/// Экран вида коллекции со своей структурой — «Кино» и «Книги» полки «Любимое»
/// (задача пользователя 2026-10-19, структура — по «Моё» Кинопоиска и «Мои книги»):
/// по заголовку карусели коллекции открываются они, а не общий полный список.
enum CollectionServiceRoute: Hashable {
    case movies, books

    var title: String {
        switch self {
        case .movies: CollectionItem.Kind.movie.title
        case .books: CollectionItem.Kind.book.title
        }
    }
}

/// Куда ведёт заголовок карусели коллекции: «Кино» и «Книги» в «Любимом» — экраны со
/// своей структурой, остальное — полный список вида, без чипсов других видов.
enum CollectionSectionNavigation {
    @MainActor
    static func open(_ kind: CollectionItem.Kind, on shelf: CollectionStore.Shelf, navigation: AppNavigationState) {
        switch (kind, shelf) {
        case (.movie, .favorites): navigation.push(CollectionServiceRoute.movies)
        case (.book, .favorites): navigation.push(CollectionServiceRoute.books)
        // Треки — свой экран полки с кавером (`CollectionTracksScreen`, 2026-10-20).
        case (.track, _): navigation.push(CollectionTracksRoute(shelf: shelf))
        // Плейлисты «Любимого» — с чипсами, на «Любимых»: лента за карточкой
        // «Мои плейлисты» — любимые (2026-10-20).
        case (.playlist, .favorites): navigation.push(CollectionListRoute(source: .playlists(.liked), title: CollectionItem.Kind.playlist.title))
        case (_, .downloads): navigation.push(CollectionListRoute(source: .shelf(kind, shelf), title: downloadsTitle(kind)))
        default: navigation.push(CollectionListRoute(source: .shelf(kind, shelf), title: kind.title))
        }
    }

    /// Карточка «Мои плейлисты»: в «Любимом» — список с чипсами на «Моих»,
    /// в «Скачанном» — скачанные плейлисты без чипсов.
    static func openMyPlaylists(on shelf: CollectionStore.Shelf, navigation: AppNavigationState) {
        if shelf == .favorites {
            navigation.push(CollectionListRoute(source: .playlists(.mine), title: CollectionItem.Kind.playlist.title))
        } else {
            navigation.push(CollectionListRoute(source: .shelf(.playlist, shelf), title: downloadsTitle(.playlist)))
        }
    }

    /// Полные списки «Скачанного» — «Скачанное кино», «Скачанные книги»… (правка
    /// пользователя 2026-10-20). Исполнителей в «Скачанном» нет — у них нечего скачивать.
    static func downloadsTitle(_ kind: CollectionItem.Kind) -> String {
        switch kind {
        case .movie: "Скачанное кино"
        case .book: "Скачанные книги"
        case .track: "Скачанные треки"
        case .album: "Скачанные альбомы"
        case .playlist: "Скачанные плейлисты"
        case .artist: kind.title
        }
    }
}

// MARK: - Лайкнутое и начатое

/// Карточка карусели «Кино» или «Книги» полки «Любимое» — лайкнутое или начатое.
struct CollectionMixEntry: Identifiable {
    let item: CollectionItem
    /// Начатый фильм без своего экрана (моки витрины): тап продолжает просмотр.
    var resume: MovieInProgress? = nil
    /// Последнее взаимодействие — лайк или запуск, что позже.
    let date: Date
    /// Сколько посмотрели или прочитали — у начатого; полоса под карточкой.
    var progress: Double? = nil
    /// Начатая книга «Читаю»: тап — сразу читалка, а не экран книги (правка
    /// пользователя 2026-10-20).
    var readBook: BookInProgress? = nil

    var id: String { item.id }
}

/// Карусели «Кино» и «Книги» полки «Любимое» — лайкнутое вперемешку с начатым (что
/// смотрели и читали), свежее первым: лайк и запуск одинаково поднимают карточку
/// в начало (задача пользователя 2026-10-19). Одна сущность — одна карточка, по
/// последнему из её взаимодействий.
@MainActor
enum CollectionMix {
    static func movies(_ collection: CollectionStore, history: WatchHistory) -> [CollectionMixEntry] {
        merge(
            liked: collection.items(.movie, on: .favorites),
            started: history.continuing.map { entry in
                let item = continuingMovie(entry.movie)
                return CollectionMixEntry(
                    item: item,
                    resume: item.route == nil ? entry.movie : nil,
                    date: entry.updatedAt,
                    progress: entry.progress
                )
            }
        )
    }

    static func books(_ collection: CollectionStore, reading: ReadingHistory) -> [CollectionMixEntry] {
        merge(
            liked: collection.items(.book, on: .favorites),
            started: readingEntries(reading)
        )
    }

    /// Читалка начатой книги по id записи коллекции — строки полного списка «Читаю».
    static func readBook(_ itemID: String, in reading: ReadingHistory) -> BookInProgress? {
        reading.started.first { readingItem($0).id == itemID }?.book
    }

    /// «Читаю» — начатые книги записями коллекции: их рисуют те же карточки и строки.
    static func readingItems(_ reading: ReadingHistory) -> [CollectionItem] {
        reading.started.map(readingItem)
    }

    /// «Читаю» карточками — с прочитанной долей.
    static func readingEntries(_ reading: ReadingHistory) -> [CollectionMixEntry] {
        reading.started.map { CollectionMixEntry(item: readingItem($0), date: $0.updatedAt, progress: $0.progress, readBook: $0.book) }
    }

    private static func readingItem(_ entry: ReadingHistory.Entry) -> CollectionItem {
        .book(
            EntityRef(
                id: entry.book.id,
                title: entry.book.title,
                subtitle: entry.book.author ?? "",
                artwork: entry.book.cover
            ),
            aspect: entry.aspect
        )
    }

    /// Начатый фильм — постером, а без постера кадром. Моки витрины («Здесь был Юра»
    /// и др.) без экрана тайтла — маршрута у них нет.
    private static func continuingMovie(_ movie: MovieInProgress) -> CollectionItem {
        let artwork = movie.poster ?? movie.still
        var item = CollectionItem.movie(
            EntityRef(id: movie.id, title: movie.title, subtitle: "", artwork: artwork),
            poster: artwork,
            year: nil
        )
        if !movie.id.hasPrefix("kp-") { item.route = nil }
        return item
    }

    private static func merge(liked: [CollectionItem], started: [CollectionMixEntry]) -> [CollectionMixEntry] {
        var entries: [String: CollectionMixEntry] = [:]
        for item in liked {
            entries[item.id] = CollectionMixEntry(item: item, date: item.favoritedAt ?? .distantPast)
        }
        for entry in started {
            if let liked = entries[entry.id] {
                entries[entry.id] = CollectionMixEntry(item: liked.item, date: max(liked.date, entry.date), progress: entry.progress)
            } else {
                entries[entry.id] = entry
            }
        }
        return entries.values.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date > $1.date }
    }
}

// MARK: - Экран

/// «Кино»: «Смотреть дальше» (карточки витрины Кинопоиска), «Буду смотреть» —
/// лайкнутое, «Покупки»; скачанное — в «Скачанном», не здесь (правка пользователя
/// 2026-10-20). «Книги»: «Читаю», «Буду читать» (лайкнутое; правка пользователя 2026-10-20),
/// «Прочитано». Всё — компонентами коллекции; пустые секции не показываются.
/// Заголовки — в полные списки своих секций.
struct CollectionServiceScreen: View {
    let route: CollectionServiceRoute

    @Environment(CollectionStore.self) private var collection
    @Environment(ActionBarState.self) private var actionBar
    @Environment(AppNavigationState.self) private var navigation
    @State private var scrollOffset: CGFloat = 0

    /// Название — всегда, подложка проявляется с первых пунктов скролла, как у дебаг-меню.
    private static let navThresholds = EntityNavBarThresholds(
        backgroundStart: 0,
        backgroundRamp: ServiceTopNavMotion.backdropRamp,
        titleStart: -.greatestFiniteMagnitude,
        titleRamp: 0
    )

    var body: some View {
        ZStack(alignment: .top) {
            Color.surfaceOne.ignoresSafeArea()

            ScrollView {
                VStack(spacing: CollectionLayout.sectionGap) {
                    switch route {
                    case .movies: movieSections
                    case .books: bookSections
                    }
                }
                .padding(.bottom, CollectionLayout.feedBottom)
            }
            .scrollIndicators(.hidden)
            .contentMargins(.top, EntityNavBarGeometry.barHeight, for: .scrollContent)
            .trackNavBarScroll(into: $scrollOffset)
        }
        .overlay(alignment: .top) {
            EntityNavBar(title: route.title, scrollOffset: scrollOffset, thresholds: Self.navThresholds)
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: Кино

    @ViewBuilder
    private var movieSections: some View {
        let watching = actionBar.watchHistory.continuing
        if !watching.isEmpty {
            CollectionCarousel(
                // «Смотрю» — пара к «Читаю» книг (правка пользователя 2026-10-20).
                title: "Смотрю",
                height: PPMovieCard.rowHeight(.medium, movies: watching.map(\.movie)),
                items: watching
            ) { entry in
                PPMovieResumeCard(entry: entry, size: .medium)
            }
        }

        let later = collection.items(.movie, on: .favorites)
        if !later.isEmpty {
            CollectionCarousel(
                title: "Буду смотреть",
                height: posterRowHeight(later),
                items: later,
                openAll: { openList(.shelf(.movie, .favorites), title: "Буду смотреть") }
            ) { item in
                CollectionPosterCard(item: item, progress: moviesProgress(item), shelf: .favorites)
            }
        }

        // «Моих оценок» в коллекции нет — макет экрана «Кино» `18113:10064`: «Смотрю»,
        // «Буду смотреть», «Покупки» (решение пользователя 2026-10-28). Оценки живут
        // в блоке экрана тайтла (`MovieRatings`).
        let purchases = CollectionSeeds.purchases
        CollectionCarousel(
            title: "Покупки",
            height: posterRowHeight(purchases),
            items: purchases,
            openAll: { openList(.purchases, title: "Покупки") }
        ) { item in
            CollectionPosterCard(item: item, progress: moviesProgress(item))
        }
    }

    /// Начатый фильм — полоса под постером в любой карусели «Кино».
    private func moviesProgress(_ item: CollectionItem) -> Double? {
        CollectionProgress.movie(item, history: actionBar.watchHistory)
    }

    private func posterRowHeight(_ items: [CollectionItem]) -> CGFloat {
        CollectionLayout.rowHeight(CollectionLayout.posterRowHeight, progress: items.map(moviesProgress))
    }

    // MARK: Книги

    @ViewBuilder
    private var bookSections: some View {
        let reading = CollectionMix.readingEntries(actionBar.readingHistory)
        if !reading.isEmpty {
            bookCarousel("Читаю", entries: reading, source: .reading)
        }

        let added = collection.items(.book, on: .favorites)
        if !added.isEmpty {
            bookCarousel("Буду читать", entries: added.map(Self.entry), source: .shelf(.book, .favorites))
        }

        bookCarousel("Прочитано", entries: CollectionSeeds.read.map(Self.entry), source: .read)
    }

    private static func entry(_ item: CollectionItem) -> CollectionMixEntry {
        CollectionMixEntry(item: item, date: item.favoritedAt ?? .distantPast)
    }

    private func bookCarousel(_ title: String, entries: [CollectionMixEntry], source: CollectionListRoute.Source) -> some View {
        let progress = entries.map { CollectionProgress.book($0, reading: actionBar.readingHistory) }
        return CollectionCarousel(
            title: title,
            height: CollectionLayout.rowHeight(CollectionLayout.bookRowHeight, progress: progress),
            items: entries,
            openAll: { openList(source, title: title) }
        ) { entry in
            // «Читаю» — сразу читалка; «Буду читать» и «Прочитано» — экран книги.
            CollectionBookCard(
                item: entry.item,
                readBook: entry.readBook,
                progress: CollectionProgress.book(entry, reading: actionBar.readingHistory),
                shelf: source.shelf
            )
        }
    }

    private func openList(_ source: CollectionListRoute.Source, title: String) {
        navigation.push(CollectionListRoute(source: source, title: title))
    }
}
