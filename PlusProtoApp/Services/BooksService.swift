import Foundation

// MARK: - Errors

enum BooksError: Error, LocalizedError {
    case invalidResponse
    case rateLimited
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Некорректный ответ Google Books"
        case .rateLimited: "Слишком много запросов к Google Books"
        case .http(let code): "HTTP-ошибка \(code)"
        }
    }
}

// MARK: - Service

/// Google Books. Ключ поднимает квоту до ~1000 запросов в сутки; без него работает
/// общий пул на всех и легко ловится 429. Шаблон тот же, что у `KinopoiskService`.
actor BooksService {
    static let shared = BooksService()

    private let baseURL = "https://www.googleapis.com/books/v1"
    private let session: URLSession
    private let decoder = JSONDecoder()

    /// Официальный лимит — 1 запрос в секунду на пользователя.
    private var requestTimestamps: [Date] = []
    private let maxRequestsPerWindow = 1
    private let windowDuration: TimeInterval = 1

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024,
            diskPath: "books_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Поиск с русским ограничением языка. Возвращаются только тома с настоящей
    /// обложкой: каталог Google Books наполовину состоит из библиографических
    /// указателей, и у них `frontcover` отдаёт серую заглушку «image not available».
    /// Признак — `readingModes.image`, см. `GoogleBookReadingModes`.
    func search(_ query: String, limit: Int = 10) async throws -> [GoogleBook] {
        let response: GoogleBooksResponse = try await fetch(
            path: "/volumes",
            query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "langRestrict", value: "ru"),
                URLQueryItem(name: "printType", value: "books"),
                URLQueryItem(name: "orderBy", value: "relevance"),
                URLQueryItem(name: "maxResults", value: "\(limit)")
            ]
        )
        return (response.items ?? []).filter(\.hasScannedCover)
    }

    func volume(id: String) async throws -> GoogleBook {
        try await fetch(path: "/volumes/\(id)")
    }

    // MARK: - Private

    private func fetch<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
        await throttle()

        guard var components = URLComponents(string: baseURL + path) else {
            throw BooksError.invalidResponse
        }
        var items = query
        items.append(URLQueryItem(name: "key", value: APIKeys.googleBooks))
        components.queryItems = items
        guard let url = components.url else { throw BooksError.invalidResponse }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299: break
            case 429: throw BooksError.rateLimited
            default: throw BooksError.http(http.statusCode)
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BooksError.invalidResponse
        }
    }

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
