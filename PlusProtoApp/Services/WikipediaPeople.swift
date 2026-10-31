import Foundation

/// Писатель, режиссёр или актёр к поисковой выдаче — имя и фото из русской Википедии.
///
/// Один бесплатный запрос без ключа: поиск по тексту запроса, у первых пяти страниц —
/// главная картинка и короткое описание. Персона — первая страница, на которой
/// всё сходится (откалибровано на живых запросах 2026-10-03; пять страниц вместо одной
/// и актёры — задача пользователя 2026-10-31: «Нолан», «Ди Каприо» первой страницей
/// не находились):
/// - заголовок в формате статьи о человеке — «Фамилия, Имя»: на «интерстеллар»
///   и «дюна» первыми приходят страницы фильма, романа и холма, у них запятой нет;
/// - в описании профессия: «кинорежиссёр», «актёр», «актриса» → кино, «писатель», «поэт»,
///   «антрополог»… → книги; из нескольких — та, что названа раньше («актёр
///   и режиссёр» — актёр). Так отсеиваются однофамильцы: «Аня Фёдорова» находит
///   модель Оксану Фёдорову, а у неё в описании ни то ни другое;
/// - есть фото — карточка без него не собирается (у Пелевина в Википедии фото нет);
/// - со второй страницы — имя отвечает запросу (`PersonNameMatch`): на «дюна» среди
///   первых пяти есть статья о Фрэнке Херберте, но запрос назвал не его.
///
/// Прототип: однофамилец с подходящей профессией всё равно пройдёт. Кинопоиск
/// для режиссёров не подошёл — его поиск персон на «Хичкок» отдаёт малоизвестных
/// однофамильцев без фото и профессии, а найти нужного стоило бы запросов из квоты.
actor WikipediaPeople {
    static let shared = WikipediaPeople()

    struct Person: Sendable, Hashable {
        enum Role: Sendable { case writer, director, actor }
        let pageID: Int
        let name: String
        let role: Role
        let photo: URL
        /// В описании «актриса» — подпись карточки «Актриса», а не «Актёр».
        let isFemale: Bool
    }

    /// Ответы на процесс — и пустые тоже: повторный ввод того же запроса бесплатен.
    private var cache: [String: Person?] = [:]
    private var portraits: [String: URL?] = [:]
    private let session: URLSession

    private static let directorMarkers = ["режиссёр", "режиссер"]
    private static let actorMarkers = ["актёр", "актер", "актриса"]
    private static let femaleMarkers = ["актриса"]
    /// Сколько первых страниц поиска смотреть
    private static let candidates = 5
    private static let writerMarkers = [
        "писател", "поэт", "прозаик", "драматург", "литератор", "публицист",
        "эссеист", "философ", "антрополог", "историк", "социолог",
    ]
    /// Фото под постер 86 × 129 на @3x.
    private static let thumbnailSize = 400

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        // Правила Викимедиа: запросы без внятного User-Agent режут.
        config.httpAdditionalHeaders = ["User-Agent": "PlusProto/1.0 (iOS prototype)"]
        session = URLSession(configuration: config)
    }

    /// Персона под запрос или `nil`. Ошибки сети (в том числе 429) — просто `nil`:
    /// выдача без карточки персоны остаётся выдачей.
    func person(matching query: String) async -> Person? {
        let key = query.lowercased()
        if let cached = cache[key] { return cached }
        let found = await fetch(query)
        guard !Task.isCancelled else { return found }
        cache[key] = found
        return found
    }

    /// Фото автора книги для строки под названием на экране книги (2026-10-04).
    /// Ищется по имени из метаданных тома, поэтому профессию не проверяем: у авторов
    /// нон-фикшена в описании «экономист», «лингвист», а не «писатель». Страница
    /// обязана быть статьёй о человеке («Фамилия, Имя») и с фото — иначе `nil`.
    func portrait(of name: String) async -> URL? {
        let key = name.lowercased()
        if let cached = portraits[key] { return cached }
        let found = await pages(for: name).first.flatMap { page -> URL? in
            guard Self.displayName(fromTitle: page.title) != nil else { return nil }
            return page.thumbnail.flatMap { URL(string: $0.source) }
        }
        guard !Task.isCancelled else { return found }
        portraits[key] = found
        return found
    }

    private func fetch(_ query: String) async -> Person? {
        for (rank, page) in await pages(for: query).enumerated() {
            guard
                let source = page.thumbnail?.source,
                let photo = URL(string: source),
                let name = Self.displayName(fromTitle: page.title),
                let role = Self.role(from: page.description),
                rank == 0 || PersonNameMatch.matches(name, query: query)
            else { continue }
            let description = page.description?.lowercased() ?? ""
            return Person(
                pageID: page.pageid,
                name: name,
                role: role,
                photo: photo,
                isFemale: Self.femaleMarkers.contains(where: description.contains)
            )
        }
        return nil
    }

    /// Первые страницы поиска Википедии с главной картинкой и описанием — в порядке поиска.
    private func pages(for query: String) async -> [Page] {
        var components = URLComponents(string: "https://ru.wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query),
            URLQueryItem(name: "gsrlimit", value: "\(Self.candidates)"),
            URLQueryItem(name: "prop", value: "pageimages|description"),
            URLQueryItem(name: "piprop", value: "thumbnail"),
            URLQueryItem(name: "pithumbsize", value: "\(Self.thumbnailSize)"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2"),
        ]
        guard
            let url = components?.url,
            let result = try? await session.data(from: url),
            (result.1 as? HTTPURLResponse)?.statusCode == 200
        else { return [] }
        let pages = (try? JSONDecoder().decode(Response.self, from: result.0))?.query?.pages ?? []
        // Порядок массива у генератора не гарантирован — место в поиске в `index`.
        return pages.sorted { ($0.index ?? .max) < ($1.index ?? .max) }
    }

    /// «Толстой, Лев Николаевич» → «Лев Толстой», «Ремарк, Эрих Мария» → «Эрих Мария
    /// Ремарк». Отчество отбрасываем, иностранные вторые имена оставляем. Без запятой —
    /// не статья о человеке.
    private static func displayName(fromTitle title: String) -> String? {
        var title = title
        if let bracket = title.range(of: " (") { title = String(title[..<bracket.lowerBound]) }
        let parts = title.components(separatedBy: ", ")
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return nil }
        let given = parts[1]
            .split(separator: " ")
            .filter { word in !isPatronymic(word) }
            .joined(separator: " ")
        return given.isEmpty ? nil : "\(given) \(parts[0])"
    }

    private static func isPatronymic(_ word: Substring) -> Bool {
        word.count > 4 && (word.hasSuffix("ич") || word.hasSuffix("вна") || word.hasSuffix("чна"))
    }

    /// Профессия из описания — названная раньше остальных.
    private static func role(from description: String?) -> Person.Role? {
        guard let text = description?.lowercased() else { return nil }
        let found: [(Person.Role, String.Index)] = [
            (.director, directorMarkers), (.actor, actorMarkers), (.writer, writerMarkers),
        ].compactMap { role, markers in
            markers.compactMap { text.range(of: $0)?.lowerBound }.min().map { (role, $0) }
        }
        return found.min { $0.1 < $1.1 }?.0
    }

    // MARK: - Ответ API (formatversion=2: страницы массивом)

    private struct Response: Decodable {
        let query: Query?
    }

    private struct Query: Decodable {
        let pages: [Page]
    }

    private struct Page: Decodable {
        let pageid: Int
        /// Место в поиске
        let index: Int?
        let title: String
        let description: String?
        let thumbnail: Thumbnail?
    }

    private struct Thumbnail: Decodable {
        let source: String
    }
}

/// Имя персоны отвечает запросу: каждое слово запроса — начало какого-то слова имени
/// («нолан» → «Кристофер Нолан», «ди каприо» → «Леонардо Ди Каприо», «тарант» →
/// «Квентин Тарантино»). Регистр, «ё» и диакритика не важны.
enum PersonNameMatch {
    static func matches(_ name: String, query: String) -> Bool {
        let nameWords = words(name)
        let needles = words(query)
        guard !needles.isEmpty else { return false }
        return needles.allSatisfy { needle in nameWords.contains { $0.hasPrefix(needle) } }
    }

    private static func words(_ text: String) -> [Substring] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru"))
            .replacingOccurrences(of: "ё", with: "е")
            .split { !$0.isLetter && !$0.isNumber }
    }
}
