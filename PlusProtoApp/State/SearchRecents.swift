import Foundation

/// «Искали недавно» — карусель нулевого состояния поиска (макет `2118:17378`, задача
/// пользователя 2026-10-03): одна лента вперемешку — музыка, кино, книги.
///
/// **Найденное — то, во что перешли из выдачи** (определение пользователя): карточка
/// карусели, строка полного списка, альбом колдунщика; трек, включённый из полного
/// списка, — тоже, это тот же выбор из выдачи. Что выдача просто показала, сюда
/// не попадает. Свежее — первым, повтор поднимается в начало.
///
/// Карусель видна всегда: за найденным стоит стартовый набор из шести реальных
/// айтемов, и пустой истории не бывает. Найденное хранится локально (`UserDefaults`),
/// стартовый набор — в коде: поменяется набор — у пользователя поменяется и хвост.
enum SearchRecents {
    /// Сколько найденного храним — весь полный список истории.
    static let limit = 20
    /// Сколько карточек в ленте нулевого состояния; остальное — в полном списке
    /// (правка пользователя 2026-10-03).
    static let carouselLimit = 12

    private static let storageKey = "searchRecents.v1"

    /// Найденное с диска, свежее первым. Битые данные — пустая история, а не падение.
    static func load() -> [SearchHit] {
        #if DEBUG
        // `-debugResetSearchRecents 1` — начать с пустой истории: один стартовый набор.
        if UserDefaults.standard.bool(forKey: "debugResetSearchRecents") {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return []
        }
        #endif
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([SearchHit].self, from: data)) ?? []
    }

    static func save(_ hits: [SearchHit]) {
        guard let data = try? JSONEncoder().encode(hits) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// История целиком: найденное, за ним стартовый набор без повторов.
    static func merged(_ found: [SearchHit]) -> [SearchHit] {
        let foundIDs = Set(found.map(\.id))
        return found + starter.filter { !foundIDs.contains($0.id) }
    }

    /// Стартовый набор — вперемешку, как в макете: альбом, фильмы, исполнитель,
    /// книга, режиссёр. Айтемы настоящие — те же id и картинки, что отдала бы выдача
    /// (Deezer, Кинопоиск, Google Books, Википедия; сняты 2026-10-03), поэтому фильмы,
    /// альбом и книга открывают свои экраны. Исполнитель и режиссёр не нажимаются —
    /// как и в выдаче: их экранов в проекте нет.
    static let starter: [SearchHit] = [
        album(
            id: 10709540,
            title: "Currents",
            artist: "Tame Impala",
            cover: "https://cdn-images.dzcdn.net/images/cover/de5b9b704cd4ec36f8bf49beb3e17ba2/1000x1000-000000-80-0-0.jpg"
        ),
        movie(
            id: 5283168,
            title: "Идеальные дни",
            year: 2023,
            poster: "https://avatars.mds.yandex.net/get-kinopoisk-image/10809116/53656129-a885-4731-968b-bf7aa4a9c3e8/300x450"
        ),
        SearchHit(
            id: "artist-4050205",
            kind: .artist,
            title: "The Weeknd",
            subtitle: "",
            artwork: remote("https://cdn-images.dzcdn.net/images/artist/581693b4724a7fcfa754455101e13a44/1000x1000-000000-80-0-0.jpg"),
            route: nil
        ),
        book(
            id: "wuiaEAAAQBAJ",
            title: "Мастер и Маргарита",
            author: "Михаил Булгаков",
            // Пропорции скана обложки 575 × 860: карточка книги — по ширине обложки.
            aspect: 575.0 / 860.0
        ),
        SearchHit(
            id: "person-1087",
            kind: .director,
            title: "Альфред Хичкок",
            subtitle: "",
            // Ссылка — как её отдаёт API Википедии: размеры превью у Wikimedia теперь
            // фиксированные, произвольный (400px) отвечает 400.
            artwork: remote("https://thumb.wikimedia.org/wikipedia/commons/thumb/9/94/Hitchcock%2C_Alfred_02.jpg/500px-Hitchcock%2C_Alfred_02.jpg"),
            route: nil
        ),
        movie(
            id: 656,
            title: "Любовное настроение",
            year: 2000,
            poster: "https://avatars.mds.yandex.net/get-kinopoisk-image/9784475/d31f4594-4215-434d-ac47-d4166059fbee/300x450"
        ),
    ]

    // MARK: - Сборка айтемов — в форме мапперов выдачи (`SearchState`)

    private static func remote(_ string: String) -> ArtworkSource? {
        URL(string: string).map { .remote($0) }
    }

    private static func album(id: Int, title: String, artist: String, cover: String) -> SearchHit {
        let artwork = remote(cover)
        return SearchHit(
            id: "album-\(id)",
            kind: .album,
            title: title,
            subtitle: artist,
            artwork: artwork,
            route: .album(EntityRef(
                id: "dz-\(id)",
                title: title,
                subtitle: artist,
                artwork: artwork ?? .asset("mockAlbumCover")
            ))
        )
    }

    private static func movie(id: Int, title: String, year: Int, poster: String) -> SearchHit {
        let artwork = remote(poster)
        return SearchHit(
            id: "movie-\(id)",
            kind: .movie,
            title: title,
            subtitle: "\(year)",
            artwork: artwork,
            route: .movie(EntityRef(
                id: "kp-\(id)",
                title: title,
                subtitle: "",
                artwork: artwork ?? .asset("mockMoviePoster")
            ))
        )
    }

    private static func book(id: String, title: String, author: String, aspect: CGFloat) -> SearchHit {
        let artwork = remote("https://books.google.com/books/content?id=\(id)&printsec=frontcover&img=1&zoom=3&source=gbs_api")
        return SearchHit(
            id: "book-\(id)",
            kind: .book,
            title: title,
            subtitle: author,
            artwork: artwork,
            route: .book(EntityRef(
                id: "gb-\(id)",
                title: title,
                subtitle: author,
                artwork: artwork ?? .asset("mockBookTechno")
            )),
            artworkAspect: aspect
        )
    }
}
