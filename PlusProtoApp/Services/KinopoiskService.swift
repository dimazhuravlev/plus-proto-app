import Foundation

// MARK: - Errors

enum KinopoiskError: Error, LocalizedError {
    case rateLimited
    case unauthorized
    case quotaExceeded
    /// Битый URL или тело, которое не разобралось в ожидаемую модель.
    case invalidResponse
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .rateLimited: return "Слишком много запросов в секунду"
        case .unauthorized: return "Неверный ключ X-API-KEY"
        case .quotaExceeded: return "Исчерпана суточная квота запросов"
        case .invalidResponse: return "Некорректный ответ API"
        case .http(let code): return "HTTP-ошибка \(code)"
        }
    }
}

// MARK: - Service

actor KinopoiskService {
    static let shared = KinopoiskService()

    /// Поля, которые умеет разобрать `KinopoiskMovie`, — сужаем ответ через `selectFields`.
    ///
    /// Набор покрывает не только витрину, но и карточку тайтла целиком: `persons`,
    /// `similarMovies` и `videos` списочный роут отдаёт наравне с `/movie/{id}`
    /// (замер — см. `KinopoiskMovie`). Благодаря этому пул фильмов кормит карточку
    /// с диска, и на её открытие не уходит ни одного запроса из суточных двухсот.
    /// Цена — вес ответа: около 22 КБ на тайтл вместо 2 КБ, то есть ~5 МБ на пачку
    /// в 250 фильмов. Это один запрос в неделю, трафик здесь дешевле квоты.
    static let movieFields = [
        "id", "name", "alternativeName", "year", "description", "shortDescription",
        "slogan", "movieLength", "isSeries", "ageRating", "ratingMpaa",
        "genres", "countries", "rating", "votes", "top250",
        "poster", "backdrop", "logo", "videos", "persons", "similarMovies"
    ]

    /// `api.kinopoisk.dev` отдаёт 301 сюда — ходим сразу на конечный домен, экономим редирект.
    private let baseURL = "https://api.poiskkino.dev"
    private let session: URLSession
    private let decoder = JSONDecoder() // ответ уже camelCase, конвертер из snake_case не нужен

    // Троттлинг: скользящее окно, заголовок `x-ratelimit-limit: 5` = 5 запросов/сек.
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerWindow = 5
    private let windowDuration: TimeInterval = 1

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,  // 20 MB memory
            diskCapacity: 100 * 1024 * 1024,   // 100 MB disk
            diskPath: "kinopoisk_cache"
        )
        // Квота всего 200 запросов в сутки — свежесть менее важна, чем экономия.
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    func searchMovies(query: String, limit: Int = 10) async throws -> [KinopoiskMovie] {
        let response: KinopoiskListResponse<KinopoiskMovie> = try await fetch(
            path: "/v1.4/movie/search",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return response.docs
    }

    func movie(id: Int) async throws -> KinopoiskMovie {
        // Без `selectFields`: на роуте `/movie/{id}` он не проверен, а карточке нужны все поля.
        try await fetch(path: "/v1.4/movie/\(id)")
    }

    /// Батч по id — один запрос вместо N одиночных, главный способ не сжечь квоту.
    func movies(ids: [Int]) async throws -> [KinopoiskMovie] {
        guard !ids.isEmpty else { return [] }
        var query = ids.map { URLQueryItem(name: "id", value: "\($0)") }
        query.append(URLQueryItem(name: "limit", value: "\(min(ids.count, 250))"))
        query.append(contentsOf: Self.selectFields(Self.movieFields))

        let response: KinopoiskListResponse<KinopoiskMovie> = try await fetch(
            path: "/v1.4/movie",
            query: query
        )
        // API отдаёт docs в своём порядке — возвращаем в порядке запрошенных id.
        let byId = Dictionary(response.docs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return ids.compactMap { byId[$0] }
    }

    /// Фильмы из подборки по slug (например `hd-must-see`, `top250`).
    func movies(list slug: String, limit: Int = 10, page: Int = 1) async throws -> [KinopoiskMovie] {
        var query = [
            URLQueryItem(name: "lists", value: slug),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        query.append(contentsOf: Self.selectFields(Self.movieFields))

        let response: KinopoiskListResponse<KinopoiskMovie> = try await fetch(
            path: "/v1.4/movie",
            query: query
        )
        return response.docs
    }

    /// Кадры (`type=still`) сразу для нескольких тайтлов.
    ///
    /// `movieId` — повторяющийся параметр, поэтому один запрос покрывает целую пачку
    /// фильмов: иначе кадры стоили бы запроса на тайтл, а квота 200 в сутки этого
    /// не переживёт. Выдача общая на всю пачку, и жадный тайтл (у «Игры престолов»
    /// 1423 кадра) может занять её целиком — отсюда небольшие пачки, а не все 250 сразу.
    func stills(movieIDs: [Int], limit: Int = 250) async throws -> [KinopoiskStill] {
        guard !movieIDs.isEmpty else { return [] }
        var query = movieIDs.map { URLQueryItem(name: "movieId", value: "\($0)") }
        query.append(URLQueryItem(name: "type", value: "still"))
        query.append(URLQueryItem(name: "limit", value: "\(limit)"))
        query.append(contentsOf: Self.selectFields(["movieId", "url", "width", "height"]))

        let response: KinopoiskListResponse<KinopoiskStill> = try await fetch(
            path: "/v1.4/image",
            query: query
        )
        return response.docs
    }

    /// Каталог подборок (всего их около 300).
    func lists(limit: Int = 10, page: Int = 1) async throws -> [KinopoiskMovieList] {
        let response: KinopoiskListResponse<KinopoiskMovieList> = try await fetch(
            path: "/v1.4/list",
            query: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return response.docs
    }

    /// Остаток суточной квоты. Сам этот запрос квоту не тратит.
    func tokenInfo() async throws -> KinopoiskTokenInfo {
        try await fetch(path: "/v1.5/token")
    }

    // MARK: - Private

    /// `selectFields` передаётся повторяющимся параметром, по одному полю на вхождение.
    private static func selectFields(_ fields: [String]) -> [URLQueryItem] {
        fields.map { URLQueryItem(name: "selectFields", value: $0) }
    }

    private func fetch<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
        let data = try await fetchData(path: path, query: query)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw KinopoiskError.invalidResponse
        }
    }

    private func fetchData(path: String, query: [URLQueryItem] = []) async throws -> Data {
        await throttle()

        guard var components = URLComponents(string: baseURL + path) else {
            throw KinopoiskError.invalidResponse
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw KinopoiskError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue(APIKeys.kinopoisk, forHTTPHeaderField: "X-API-KEY")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        // Остаток квоты нужен на «сейчас» — из кэша он бессмыслен.
        if path.hasSuffix("/token") {
            request.cachePolicy = .reloadIgnoringLocalCacheData
        }

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            switch httpResponse.statusCode {
            case 200...299:
                break
            case 401:
                throw KinopoiskError.unauthorized
            case 403:
                throw KinopoiskError.quotaExceeded
            case 429:
                throw KinopoiskError.rateLimited
            default:
                throw KinopoiskError.http(httpResponse.statusCode)
            }
        }

        return data
    }

    /// Скользящее окно: держим не больше `maxRequestsPerWindow` отметок за последнюю секунду,
    /// при переполнении ждём ровно до момента, когда самая старая из них выпадет из окна.
    private func throttle() async {
        requestTimestamps.removeAll { Date().timeIntervalSince($0) > windowDuration }

        if requestTimestamps.count >= maxRequestsPerWindow, let oldest = requestTimestamps.first {
            let wait = windowDuration - Date().timeIntervalSince(oldest)
            if wait > 0 {
                try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            }
            requestTimestamps.removeAll { Date().timeIntervalSince($0) > windowDuration }
        }

        requestTimestamps.append(Date())
    }
}
