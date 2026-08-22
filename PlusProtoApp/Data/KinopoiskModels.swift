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
struct KinopoiskImage: Decodable {
    let url: String?
    let previewUrl: String?
}

/// Размеры, которые реально отдаёт Яндекс-CDN. `1000x1500` и `1440x2160` возвращают 404 — не добавлять.
enum KinopoiskPosterSize: String {
    case small = "300x450"
    case medium = "600x900"
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
}

// MARK: - Movie

struct KinopoiskRating: Decodable {
    let kp: Double?
    let imdb: Double?
    let filmCritics: Double?
    let russianFilmCritics: Double?
}

struct KinopoiskGenre: Decodable, Identifiable {
    let name: String

    var id: String { name }
}

struct KinopoiskCountry: Decodable, Identifiable {
    let name: String

    var id: String { name }
}

/// Фильм/сериал. Почти всё опционально: у части каталога нет ни `logo`, ни `backdrop`,
/// ни `shortDescription`, а у зарубежных релизов иногда пусто русское `name`.
/// Поле `videos` на бесплатном тарифе всегда `null` — не моделируем.
struct KinopoiskMovie: Decodable, Identifiable {
    let id: Int
    let name: String?
    let alternativeName: String?
    let year: Int?
    let description: String?
    let shortDescription: String?
    let movieLength: Int?
    let isSeries: Bool?
    let ageRating: Int?
    let genres: [KinopoiskGenre]?
    let countries: [KinopoiskCountry]?
    let rating: KinopoiskRating?
    let poster: KinopoiskImage?
    let backdrop: KinopoiskImage?
    let logo: KinopoiskImage?

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
