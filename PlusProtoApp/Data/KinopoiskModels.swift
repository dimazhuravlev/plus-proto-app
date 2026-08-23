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
enum KinopoiskPosterSize: String {
    case small = "300x450"
    case medium = "600x900"
    /// Нативный размер кадра `backdrop`. Витрина показывает его в рамке 322×181pt,
    /// то есть 966×543px — брать `wide` вдвое дороже по памяти без выигрыша в чёткости.
    case frame = "1344x756"
    case wide = "1920x1080"
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
        let resized = raw.replacingOccurrences(
            of: #"/(?:orig|\d*x\d*)$"#,
            with: "/" + size.rawValue,
            options: .regularExpression
        )
        return URL(string: resized)
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
/// **Полнота ответа зависит от роута.** Списочный `/v1.4/movie` на бесплатном тарифе
/// отдаёт урезанный набор (без `videos`, `persons`, `similarMovies`) и `selectFields`
/// его не расширяет; всё перечисленное приезжает только с `/v1.4/movie/{id}`.
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
    let videos: KinopoiskVideos?
    let persons: [KinopoiskPerson]?
    let similarMovies: [KinopoiskSimilarMovie]?

    /// Заголовок для UI: русское название, иначе оригинальное.
    var displayTitle: String {
        name ?? alternativeName ?? ""
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
