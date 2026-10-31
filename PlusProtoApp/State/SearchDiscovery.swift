import Foundation

/// Пустое нулевое состояние поиска — пока в «Искали недавно» нет ни одного айтема
/// (задача пользователя 2026-10-30): три карусели рекомендаций вместо ленты истории.
///
/// Карточки — витринные, крупные (правка пользователя того же дня): постеры главной
/// Кинопоиска, книги главной Книг, исполнители — `MusicCard` Medium кругом. Данные —
/// каталоги этих витрин, они живут в корне и собираются после заставки: кино —
/// подборка Кинопоиска «Смотреть на выходных», исполнители — похожие из блоков
/// «Похоже на …» Музыки, книги — темы Книг. Своих запросов здесь нет. Пока каталог
/// не собран — скелетон его витрины; без ключей каталоги кино и книг сами идут
/// на моки, исполнители без Deezer — образцы полок «Главной».
@MainActor
enum SearchDiscovery {
    static let moviesTitle = "Что смотреть на выходных"
    static let artistsTitle = "Музыка для вас"
    static let booksTitle = "Вам может понравиться"

    /// Карточек в карусели — как в ленте «Искали недавно».
    static let limit = SearchRecents.carouselLimit

    /// Подборка «Смотреть на выходных» (`CinemaCatalog.rowSpecs`, у моков — тоже); нет её —
    /// первая собранная. `nil` — показывать нечего.
    static func movies(_ cinema: CinemaCatalog) -> CinemaCatalog.Row? {
        guard let row = cinema.rows.first(where: { $0.title == "Смотреть на выходных" }) ?? cinema.rows.first,
              !row.titles.isEmpty
        else { return nil }
        return CinemaCatalog.Row(id: row.id, title: moviesTitle, titles: Array(row.titles.prefix(limit)))
    }

    /// Похожие исполнители блоков «Похоже на …» — по одному из каждого блока по очереди,
    /// без повторов: сами исполнители блоков — это вкус пользователя, а не рекомендация.
    static func artists(_ music: MusicHomeCatalog) -> [MusicItem] {
        let live = roundRobin(music.blocks.map { block in block.items.filter { $0.shape == .circle } })
        guard live.isEmpty else {
            var seen = Set<String>()
            return Array(live.filter { seen.insert($0.id).inserted }.prefix(limit))
        }
        return HomeShelfSamples.artists.map { item in
            MusicItem(id: item.id, shape: .circle, title: item.title, cover: item.artwork, route: item.route)
        }
    }

    /// Темы Книг вперемешку — по книге из каждой по очереди. `nil` — показывать нечего.
    static func books(_ books: BooksHomeCatalog) -> BooksHomeCatalog.Row? {
        var seen = Set<String>()
        let mixed = roundRobin(books.rows.map(\.books)).filter { seen.insert($0.id).inserted }
        guard !mixed.isEmpty else { return nil }
        return BooksHomeCatalog.Row(id: "search-discovery", title: booksTitle, books: Array(mixed.prefix(limit)))
    }

    private static func roundRobin<Item>(_ rows: [[Item]]) -> [Item] {
        var mixed: [Item] = []
        let longest = rows.map(\.count).max() ?? 0
        for index in 0..<longest {
            for row in rows where index < row.count { mixed.append(row[index]) }
        }
        return mixed
    }
}
