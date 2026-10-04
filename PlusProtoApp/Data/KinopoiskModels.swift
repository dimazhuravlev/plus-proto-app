import Foundation

// MARK: - Generic List Response

/// Общая обёртка постраничной выдачи (`/movie`, `/movie/search`, `/list`).
struct KinopoiskListResponse<T: Decodable>: Decodable {
    let docs: [T]
    let total: Int?
    let limit: Int?
    let page: Int?
    let pages: Int?
}

// MARK: - Image

/// Картинка КП: `url` — оригинал, `previewUrl` — уменьшенная копия.
struct KinopoiskImage: Codable {
    let url: String?
    let previewUrl: String?
}

/// Размеры, которые реально отдаёт Яндекс-CDN. `1000x1500` и `1440x2160` возвращают 404 — не добавлять.
///
/// Размер здесь — бокс, а не кроп: CDN вписывает картинку, сохраняя пропорции
/// (замер: кадр 6000×4308 по `600x900` приезжает как 600×431). Поэтому для вертикальных
/// картинок ширину задаёт высота бокса, и наоборот.
enum KinopoiskPosterSize: String {
    case small = "300x450"
    case medium = "600x900"
    /// Нативный размер кадра `backdrop`. Витрина показывает его в рамке 322×181pt,
    /// то есть 966×543px — брать `wide` вдвое дороже по памяти без выигрыша в чёткости.
    /// Работает только для `get-ott`: на `get-kinopoisk-image` этот пресет отдаёт 404.
    case frame = "1344x756"
    case wide = "1920x1080"
    /// Квадратный бокс. Единственный крупный пресет, который берут кадры `still`:
    /// вертикальный кадр приезжает как 1280×1920 — как раз под кавер 3:4 на ×3.
    case huge = "1920x1920"
    case tall = "x1000"
    case original = "orig"
}

extension KinopoiskImage {
    /// Ссылка на картинку нужного размера.
    /// У Яндекс-CDN размер — последний сегмент пути
    /// (`https://avatars.mds.yandex.net/get-kinopoisk-image/<a>/<uuid>/300x450`),
    /// поэтому подменяем его регуляркой. Если хвост на размер не похож — отдаём URL как есть.
    func url(size: KinopoiskPosterSize) -> URL? {
        guard let raw = url ?? previewUrl, !raw.isEmpty else { return nil }
        return URL(string: Self.resized(raw, to: size))
    }

    /// Подмена размера в ссылке Яндекс-CDN. Хвост бывает и голым числом — `…/600`:
    /// такой CDN отдаёт 404 (замер 2026-10-04), поэтому он тоже размер и подменяется.
    static func resized(_ raw: String, to size: KinopoiskPosterSize) -> String {
        raw.replacingOccurrences(
            of: #"/(?:orig|\d*x\d*|\d+)$"#,
            with: "/" + size.rawValue,
            options: .regularExpression
        )
    }

    /// Ссылка на PNG-логотип тайтла шириной `width` пикселей.
    ///
    /// Отдельно от `url(size:)`, потому что логотипы лежат не на Яндекс-CDN, а на tmdb,
    /// и размер там задаётся сегментом `/t/p/<size>/`, а не хвостом пути.
    func logoURL(width: Int) -> URL? {
        guard let raw = url ?? previewUrl, !raw.isEmpty, let direct = URL(string: raw) else { return nil }
        return TMDBImageProxy.rewrite(direct, width: width) ?? direct
    }
}

/// Логотипы тайтлов Кинопоиск отдаёт с `image.tmdb.org`, а этот домен здесь **не резолвится**:
/// системный резолвер отвечает `127.0.0.1`, публичные (1.1.1.1, 8.8.8.8) — настоящим адресом.
/// Значит режет DNS, а не сеть, и симулятор ходит через тот же системный резолвер —
/// прямая ссылка не загрузится ни в витрине, ни на карточке тайтла (замер 2026-08-23).
///
/// Поэтому tmdb ходим через открытый image-прокси. Прокси нужен ровно этому хосту:
/// картинки Яндекс-CDN и так доступны и идут напрямую. Если DNS перестанет резать
/// tmdb — достаточно вернуть `nil` из `rewrite`, остальной код не изменится.
enum TMDBImageProxy {
    private static let blockedHost = "image.tmdb.org"
    private static let endpoint = "https://images.weserv.nl/"

    /// `nil` — ссылка не с tmdb, проксировать нечего.
    static func rewrite(_ url: URL, width: Int) -> URL? {
        guard url.host == blockedHost, var components = URLComponents(string: endpoint) else { return nil }
        components.queryItems = [
            // Прокси ждёт адрес без схемы.
            URLQueryItem(name: "url", value: blockedHost + url.path),
            URLQueryItem(name: "w", value: "\(width)"),
            // Без `output=png` прокси отдаёт логотип на белом — альфа обязательна.
            URLQueryItem(name: "output", value: "png"),
        ]
        return components.url
    }
}

// MARK: - Кадры тайтла

/// Кадр из ручки `/v1.4/image` с `type=still`.
///
/// Зачем он нужен помимо `backdrop`: `backdrop` у тайтла ровно один, всегда 16:9,
/// а кавер карточки — портретный 3:4, и от кадра в нём оставалось меньше половины
/// ширины (DECISIONS 2026-08-23). Среди `still` есть и вертикальные кадры высокого
/// разрешения — они закрывают кавер целиком. Обратная сторона: `still` есть далеко
/// не у всех тайтлов (замер по пачке из 10 фильмов пула: кадры нашлись у четырёх),
/// поэтому `backdrop` остаётся фолбэком, а не уходит.
struct KinopoiskStill: Codable, Identifiable {
    let movieId: Int
    let url: String
    let width: Int?
    let height: Int?

    var id: String { url }

    /// Вертикальный кадр — тот, что годится каверу без жёсткого кропа.
    var isPortrait: Bool {
        guard let width, let height else { return false }
        return height > width
    }

    /// Ссылка на кадр нужного размера — размер у Яндекс-CDN задаётся последним
    /// сегментом пути, как и у `KinopoiskImage`.
    func url(size: KinopoiskPosterSize) -> URL? {
        guard !url.isEmpty else { return nil }
        let resized = url.replacingOccurrences(
            of: #"/(?:orig|\d*x\d*)$"#,
            with: "/" + size.rawValue,
            options: .regularExpression
        )
        return URL(string: resized)
    }
}

// MARK: - Movie

struct KinopoiskRating: Codable {
    let kp: Double?
    let imdb: Double?
    let filmCritics: Double?
    let russianFilmCritics: Double?
}

struct KinopoiskGenre: Codable, Identifiable {
    let name: String

    var id: String { name }
}

struct KinopoiskCountry: Codable, Identifiable {
    let name: String

    var id: String { name }
}

/// Персона тайтла. Роль различаем по `enProfession` (`actor`, `director`) — русское
/// `profession` приходит во множественном числе и в разных падежах.
/// Имя бывает пустым у эпизодических персон, поэтому оптионально всё.
struct KinopoiskPerson: Codable {
    let id: Int?
    let name: String?
    let enName: String?
    let photo: String?
    let profession: String?
    let enProfession: String?
    /// Роль в этом тайтле («Микки Пирсон»), не профессия
    let description: String?

    var displayName: String? { name ?? enName }
    var photoURL: URL? {
        guard let photo, !photo.isEmpty else { return nil }
        // `st.kp.yandex.net` отвечает 302 на Яндекс-CDN — `URLSession` редирект пройдёт сам.
        return URL(string: photo)
    }
}

/// Похожий тайтл из `similarMovies`: усечённый фильм — ни описания, ни хронометража.
struct KinopoiskSimilarMovie: Codable, Identifiable {
    let id: Int
    let name: String?
    let alternativeName: String?
    let year: Int?
    let poster: KinopoiskImage?
    let rating: KinopoiskRating?

    var displayTitle: String { name ?? alternativeName ?? "" }
}

/// Ролик тайтла. `url` — **страница-эмбед плеера Кинопоиска**, а не файл: прямой поток
/// внутри неё подписан и отдаёт 403 любому клиенту вне их плеера (замер 2026-08-23,
/// curl и настоящий браузер). Пригодны из этой модели `name` и `previewUrl` — кадр ролика.
struct KinopoiskVideo: Codable {
    let url: String?
    let name: String?
    let site: String?
    let type: String?
    /// Единственное поле API в snake_case — отсюда явные `CodingKeys`
    let previewUrl: String?

    enum CodingKeys: String, CodingKey {
        case url, name, site, type
        case previewUrl = "preview_url"
    }

    /// Ссылка, которую и правда можно отдать `AVPlayer`. Страница-эмбед сюда не попадает.
    var directStreamURL: URL? {
        guard let url, let parsed = URL(string: url) else { return nil }
        let ext = parsed.pathExtension.lowercased()
        return ["mp4", "m3u8", "mov"].contains(ext) ? parsed : nil
    }

    var previewImageURL: URL? {
        guard let previewUrl, !previewUrl.isEmpty else { return nil }
        return URL(string: previewUrl)
    }
}

/// Ролики тайтла. Секция целиком бывает пустой (`"videos": {}`) — у половины каталога.
struct KinopoiskVideos: Codable {
    let trailers: [KinopoiskVideo]?
    let teasers: [KinopoiskVideo]?
}

/// Фильм/сериал. Почти всё опционально: у части каталога нет ни `logo`, ни `backdrop`,
/// ни `shortDescription`, а у зарубежных релизов иногда пусто русское `name`.
///
/// **Полнота списочного ответа задаётся `selectFields`.** Замер 2026-08-23 по
/// `/v1.4/movie?lists=hd-must-see&limit=250`: с явным `selectFields` списочный роут
/// отдаёт и `persons` (в среднем 74 на тайтл), и `similarMovies`, и `videos` — то есть
/// всё, что показывает карточка. Отдельный поход на `/v1.4/movie/{id}` нужен только
/// тайтлам не из витрины. Вложенные поля (`persons.name`) `selectFields` не понимает —
/// секция приходит целиком.
struct KinopoiskMovie: Codable, Identifiable {
    let id: Int
    let name: String?
    let alternativeName: String?
    let year: Int?
    let description: String?
    let shortDescription: String?
    let slogan: String?
    let movieLength: Int?
    let isSeries: Bool?
    let ageRating: Int?
    let ratingMpaa: String?
    let genres: [KinopoiskGenre]?
    let countries: [KinopoiskCountry]?
    let rating: KinopoiskRating?
    let votes: KinopoiskRating?
    /// Позиция в топ-250 Кинопоиска, если тайтл там есть
    let top250: Int?
    /// Слаги подборок, в которые входит тайтл (`top250`, `popular`, …)
    let lists: [String]?
    let poster: KinopoiskImage?
    let backdrop: KinopoiskImage?
    let logo: KinopoiskImage?
    // Три секции карточки изменяемые: `MoviePool` держит запись в двух видах —
    // лёгком для витрины (эти поля обнулены) и обрезанном для карточки.
    var videos: KinopoiskVideos?
    var persons: [KinopoiskPerson]?
    var similarMovies: [KinopoiskSimilarMovie]?

    /// Заголовок для UI: русское название, иначе оригинальное.
    var displayTitle: String {
        name ?? alternativeName ?? ""
    }
}

// MARK: - Персона (экран режиссёра)

/// Персона из `/v1.4/person/search`: профессий поиск не отдаёт — только имя и фото.
struct KinopoiskPersonHit: Decodable, Identifiable {
    let id: Int
    let name: String?
    let enName: String?
    let photo: String?

    var hasPhoto: Bool { !(photo ?? "").isEmpty }
}

/// Персона из `/v1.4/person/{id}` — с фильмографией: у каждого тайтла своя профессия
/// (`enProfession`), по ней отбираются фильмы, где персона режиссёр. Постеров
/// фильмография не несёт — их добирает пачка `KinopoiskService.moviesBrief`.
struct KinopoiskPersonDetails: Decodable, Identifiable {
    let id: Int
    let name: String?
    let enName: String?
    let photo: String?
    let movies: [Movie]?

    struct Movie: Decodable {
        let id: Int
        let name: String?
        let alternativeName: String?
        let enProfession: String?
    }

    var photoURL: URL? {
        guard let photo, !photo.isEmpty else { return nil }
        return URL(string: photo)
    }
}

// MARK: - Movie List (подборка)

/// Подборка каталога (`/v1.4/list`); `slug` — ключ для `/v1.4/movie?lists=<slug>`.
struct KinopoiskMovieList: Decodable, Identifiable {
    let name: String?
    let slug: String
    let category: String?
    let moviesCount: Int?
    let cover: KinopoiskImage?

    var id: String { slug }
}

// MARK: - Token / Quota

/// Остаток суточной квоты (`/v1.5/token`). Сброс — в 21:00 UTC.
struct KinopoiskTokenInfo: Decodable {
    let requestsLimit: Int?
    let requestsUsed: Int?
    let requestsRemaining: Int?
    let resetAt: String?

    var resetDate: Date? {
        guard let resetAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: resetAt) ?? ISO8601DateFormatter().date(from: resetAt)
    }
}
