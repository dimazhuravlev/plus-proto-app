import Foundation

// MARK: - Errors

enum DeezerError: Error, LocalizedError {
    case invalidResponse
    case rateLimited
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "Некорректный ответ Deezer"
        case .rateLimited: "Слишком много запросов к Deezer"
        case .http(let code): "HTTP-ошибка \(code)"
        }
    }
}

// MARK: - Service

/// Deezer: авторизация не нужна вовсе, официальная квота 50 запросов за 5 секунд.
/// Порт `DeezerService` из MusicPlayer по тому же шаблону, что `KinopoiskService`:
/// actor + синглтон + URLCache + скользящее окно троттлинга + generic `fetch`.
actor DeezerService {
    static let shared = DeezerService()

    private let baseURL = "https://api.deezer.com"
    private let session: URLSession
    private let decoder: JSONDecoder

    private var requestTimestamps: [Date] = []
    private let maxRequestsPerWindow = 50
    private let windowDuration: TimeInterval = 5

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 100 * 1024 * 1024,
            diskPath: "deezer_cache"
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)

        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        decoder = dec
    }

    // MARK: - Public API

    func album(id: Int) async throws -> DeezerAlbum {
        try await fetch(path: "/album/\(id)")
    }

    func searchAlbums(query: String, limit: Int = 25) async throws -> [DeezerAlbumBrief] {
        let response: DeezerListResponse<DeezerAlbumBrief> = try await fetch(
            path: "/search/album",
            query: [
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
        )
        return response.data
    }

    /// Плейлист вместе с треками — из него собирается и «Моя Волна», и запас альбомов.
    func playlist(id: Int) async throws -> DeezerPlaylist {
        try await fetch(path: "/playlist/\(id)")
    }

    /// Треклист альбома. Лимит 100 покрывает всё разумное: у Deezer дефолтные 25
    /// режут двухдисковые издания посреди первого диска.
    func albumTracks(id: Int, limit: Int = 100) async throws -> [DeezerAlbumTrack] {
        let response: DeezerListResponse<DeezerAlbumTrack> = try await fetch(
            path: "/album/\(id)/tracks",
            query: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
        return response.data
    }

    /// Дискография артиста — секция «Другие альбомы» на экране альбома.
    func artistAlbums(id: Int, limit: Int = 50) async throws -> [DeezerAlbumBrief] {
        let response: DeezerListResponse<DeezerAlbumBrief> = try await fetch(
            path: "/artist/\(id)/albums",
            query: [URLQueryItem(name: "limit", value: "\(limit)")]
        )
        return response.data
    }

    // MARK: - Private

    private func fetch<T: Decodable>(path: String, query: [URLQueryItem] = []) async throws -> T {
        await throttle()

        guard var components = URLComponents(string: baseURL + path) else {
            throw DeezerError.invalidResponse
        }
        if !query.isEmpty { components.queryItems = query }
        guard let url = components.url else { throw DeezerError.invalidResponse }

        var request = URLRequest(url: url)
        // Каталог у Deezer геолокализован по IP; язык фиксируем, чтобы выдача
        // не менялась от того, откуда показывают прототип.
        request.setValue("en", forHTTPHeaderField: "Accept-Language")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse {
            switch http.statusCode {
            case 200...299: break
            case 429: throw DeezerError.rateLimited
            default: throw DeezerError.http(http.statusCode)
            }
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DeezerError.invalidResponse
        }
    }

    /// Скользящее окно — копия троттла `KinopoiskService`, только окно 5 секунд.
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
