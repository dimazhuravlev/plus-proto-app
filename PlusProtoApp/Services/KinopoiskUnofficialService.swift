import Foundation

/// Kinopoisk API Unofficial (kinopoiskapiunofficial.tech) — запас поиска фильмов: когда
/// у kinopoisk.dev кончилась квота на всех ключах, поиск идёт сюда (решение пользователя
/// 2026-10-09: тестеров 10–30, а квота kinopoisk.dev — 200 запросов в сутки на ключ).
/// У этого API своя квота — 500 запросов в сутки на ключ, бесплатный тариф (ответ
/// `/api/v1/api_keys/{ключ}`, 2026-10-09; остаток — тем же запросом, `scripts/set-unofficial-keys.sh`).
///
/// Только поиск. Витрины, карточки и кадры остаются на kinopoisk.dev: здесь нет пачек
/// по id и состава в списках, и те же экраны стоили бы в разы больше запросов.
///
/// Ответ приводится к `KinopoiskMovie`: id фильма — тот же id Кинопоиска, выдача поиска
/// источники не различает.
actor KinopoiskUnofficialService {
    static let shared = KinopoiskUnofficialService()

    /// Есть хотя бы один ключ — запас включён. Без ключей поиск ведёт себя как раньше.
    static var isConfigured: Bool {
        APIKeys.kinopoiskUnofficial.contains { !$0.isEmpty }
    }

    private let baseURL = "https://kinopoiskapiunofficial.tech"
    private let session: URLSession
    private let decoder = JSONDecoder()
    /// Ключ, на котором остановились: 402 — его квота кончилась, дальше — следующий.
    private var activeKeyIndex = 0

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 5 * 1024 * 1024,
            diskCapacity: 20 * 1024 * 1024,
            diskPath: "kinopoisk_unofficial_cache"
        )
        // Как у kinopoisk.dev: квота дороже свежести, повторный запрос — с диска.
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    /// Поиск по названию, по релевантности. Страница — 20 фильмов, берём первую.
    func searchMovies(query: String, limit: Int) async throws -> [KinopoiskMovie] {
        var components = URLComponents(string: baseURL + "/api/v2.1/films/search-by-keyword")
        components?.queryItems = [
            URLQueryItem(name: "keyword", value: query),
            URLQueryItem(name: "page", value: "1"),
        ]
        guard let url = components?.url else { throw KinopoiskError.invalidResponse }
        let data = try await fetch(url)
        guard let response = try? decoder.decode(SearchResponse.self, from: data) else {
            throw KinopoiskError.invalidResponse
        }
        return response.films.prefix(limit).map(\.movie)
    }

    private func fetch(_ url: URL) async throws -> Data {
        let keys = APIKeys.kinopoiskUnofficial.filter { !$0.isEmpty }
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "accept")
        while activeKeyIndex < keys.count {
            request.setValue(keys[activeKeyIndex], forHTTPHeaderField: "X-API-KEY")
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return data }
            switch http.statusCode {
            case 200...299:
                return data
            // 402 — суточный лимит ключа, 401 и 403 — ключ пустой, неверный или
            // заблокирован: и то и другое лечится следующим ключом.
            case 401, 402, 403:
                activeKeyIndex += 1
            case 429:
                throw KinopoiskError.rateLimited
            default:
                throw KinopoiskError.http(http.statusCode)
            }
        }
        throw KinopoiskError.quotaExceeded
    }
}

// MARK: - Ответ

/// `/api/v2.1/films/search-by-keyword` (спецификация API, 2026-10-09). Год, рейтинг
/// и длительность приходят строками; `description` — страна и режиссёр, а не сюжет.
private struct SearchResponse: Decodable {
    let films: [Film]

    struct Film: Decodable {
        let filmId: Int
        let nameRu: String?
        let nameEn: String?
        let type: String?
        let year: String?
        let filmLength: String?
        let countries: [Country]?
        let genres: [Genre]?
        /// «7.9» у вышедшего фильма, «99%» — ожидание у невышедшего.
        let rating: String?
        let ratingVoteCount: Int?
        let posterUrl: String?
        let posterUrlPreview: String?

        struct Country: Decodable { let country: String }
        struct Genre: Decodable { let genre: String }

        var movie: KinopoiskMovie {
            KinopoiskMovie(
                id: filmId,
                name: nameRu.flatMap { $0.isEmpty ? nil : $0 },
                alternativeName: nameEn.flatMap { $0.isEmpty ? nil : $0 },
                year: year.flatMap { Int($0.prefix(4)) },
                // Описание здесь — «страна, режиссёр», не сюжет: подписью его не ставим.
                description: nil,
                shortDescription: nil,
                slogan: nil,
                movieLength: minutes,
                isSeries: type.map { ["TV_SERIES", "MINI_SERIES", "TV_SHOW"].contains($0) },
                ageRating: nil,
                ratingMpaa: nil,
                genres: genres?.map { KinopoiskGenre(name: $0.genre) },
                countries: countries?.map { KinopoiskCountry(name: $0.country) },
                rating: rating.flatMap(Double.init).map {
                    KinopoiskRating(kp: $0, imdb: nil, filmCritics: nil, russianFilmCritics: nil)
                },
                votes: ratingVoteCount.map {
                    KinopoiskRating(kp: Double($0), imdb: nil, filmCritics: nil, russianFilmCritics: nil)
                },
                top250: nil,
                lists: nil,
                poster: (posterUrl ?? posterUrlPreview).map {
                    KinopoiskImage(url: Self.https($0), previewUrl: posterUrlPreview.map(Self.https))
                },
                backdrop: nil,
                logo: nil
            )
        }

        /// «2:17» → 137.
        private var minutes: Int? {
            guard let parts = filmLength?.split(separator: ":").compactMap({ Int($0) }), parts.count == 2 else {
                return nil
            }
            return parts[0] * 60 + parts[1]
        }

        /// Постеры API отдаёт и по `http://` — его iOS не пускает.
        private static func https(_ raw: String) -> String {
            raw.hasPrefix("http://") ? "https://" + raw.dropFirst("http://".count) : raw
        }
    }
}
