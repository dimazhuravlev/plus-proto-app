import SwiftUI

/// Кросс-сервисный поиск: один запрос — выдача сразу по музыке, кино и книгам.
///
/// **Три домена идут параллельно и рендерятся по мере готовности.** Ждать самый
/// медленный нельзя: Deezer отвечает за 150–300мс, Google Books за 200–400,
/// Кинопоиск за полсекунды — при последовательном заходе выдача появлялась бы
/// через секунду с лишним. Каждый загрузчик пишет свой домен, `@Observable`
/// перерисовывает только его секцию.
///
/// **Ввод дебаунсится**, а не шлёт запрос на каждую букву: у Кинопоиска 200 запросов
/// в сутки на ключ. По той же причине кино сперва ищется в дисковом запасе
/// (`MoviePool.search`) и уходит в сеть, только если там нашлось мало.
@MainActor
@Observable
final class SearchState {
    /// Текст поля. Владеет им поиск, а не бар: выдачу показывает отдельный слой.
    var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    private(set) var music = Domain()
    private(set) var movies = Domain()
    private(set) var books = Domain()

    /// Состояние одного домена выдачи.
    struct Domain {
        var isLoading = false
        var hits: [SearchHit] = []
        /// Домен уже отвечал на текущий запрос — по этому признаку скелетон
        /// сменяется либо строками, либо ничем.
        var isAnswered = false
    }

    /// Ищем с двух символов: на одной букве выдача — случайный шум, а запросы
    /// уходят настоящие.
    private static let minimumQueryLength = 2
    /// Пауза после последнего нажатия. 400мс — набор успевает закончиться,
    /// а ожидание ещё не читается задержкой.
    private static let debounce: Duration = .milliseconds(400)
    /// Сколько карточек держит секция. Потолок вырос со списочных трёх: выдача
    /// стала каруселью (`SearchResultsView`, макет `2118:17378`), лишние карточки
    /// уезжают за правый край, а не давят на соседние секции.
    private static let perSection = 10
    /// Сколько просим у каждой ручки: с запасом, чтобы в секцию попали разные виды.
    private static let perKind = 8
    /// Ниже этого числа локальных совпадений кино добирается из сети.
    private static let poolEnough = 3

    /// Порядок секций текущего запроса. `nil` — ещё не все домены ответили,
    /// показываем порядок по умолчанию.
    private var rankedOrder: [Section.Kind]?

    /// Куда пользователь ушёл из выдачи: таб и глубина навигации на момент тапа.
    /// `nil` — из поиска никуда не уходили.
    ///
    /// Запрос и результаты при переходе никуда не деваются (живут здесь же), поэтому
    /// «вернуть поиск» — это просто вернуть фокус полю: слой выдачи покажет то же,
    /// что было (правка пользователя 2026-08-25 — раньше поиск закрывался насовсем).
    private var suspended: (tab: AppTab, depth: Int)?

    private var searchTask: Task<Void, Never>?
    /// Разобранные выдачи на процесс: возврат к уже набранному запросу бесплатен.
    private var cache: [String: (music: [SearchHit], movies: [SearchHit], books: [SearchHit])] = [:]

    /// Есть что показывать слоем выдачи.
    var isActive: Bool {
        normalized.count >= Self.minimumQueryLength
    }

    /// Ни один домен ничего не нашёл, и все уже ответили.
    var isEmptyResult: Bool {
        [music, movies, books].allSatisfy { $0.isAnswered && $0.hits.isEmpty }
    }

    /// Секция выдачи: домен, его заголовок и результаты.
    struct Section: Identifiable {
        let id: Kind
        let title: String
        let domain: Domain

        enum Kind { case music, movies, books }
        /// У музыки карточка квадратная, у кино и книг — постер 2:3.
        var isPoster: Bool { id != .music }
    }

    /// Секции в порядке показа. Пока ответили не все домены — порядок по умолчанию;
    /// как ответили все, он **один раз** пересчитывается по релевантности запросу
    /// (решение пользователя 2026-08-25). Считать на каждый ответ нельзя: домены
    /// отвечают вразнобой (кино из локального запаса приходит мгновенно, книги —
    /// через полсекунды), и секции прыгали бы под пальцем.
    var sections: [Section] {
        let all = [
            Section(id: .music, title: "Музыка", domain: music),
            Section(id: .movies, title: "Кино", domain: movies),
            Section(id: .books, title: "Книги", domain: books),
        ]
        guard let order = rankedOrder else { return all }
        return order.compactMap { kind in all.first { $0.id == kind } }
    }

    private var normalized: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Уход в сущность и возврат

    /// Запомнить точку, из которой пользователь ушёл в открытую карточку.
    func suspend(tab: AppTab, depth: Int) {
        suspended = (tab, depth)
    }

    /// Пора ли вернуть поиск: пользователь закрыл всё, что открывал из выдачи,
    /// и оказался ровно там, откуда уходил. Метод «съедает» отметку — восстановление
    /// одноразовое, иначе поиск лез бы обратно на каждый поп в этом табе.
    ///
    /// Таб проверяется вместе с глубиной: уйти можно и переключением таба, и тогда
    /// возвращать клавиатуру пользователю точно не надо.
    func consumeResume(tab: AppTab, depth: Int) -> Bool {
        guard let suspended, suspended.tab == tab, depth <= suspended.depth else { return false }
        self.suspended = nil
        return true
    }

    // MARK: - Поток поиска

    private func scheduleSearch() {
        // Новый ввод отменяет прошлый заход целиком: и паузу дебаунса, и уже
        // идущие запросы — их выдача всё равно относится к старому тексту.
        searchTask?.cancel()

        let text = normalized
        guard text.count >= Self.minimumQueryLength else {
            reset()
            return
        }

        if let cached = cache[text] {
            apply(cached)
            return
        }

        music = Domain(isLoading: true)
        movies = Domain(isLoading: true)
        books = Domain(isLoading: true)

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.run(text)
        }
    }

    private func run(_ text: String) async {
        // Три независимые задачи: домен, который ответил первым, тут же и покажется.
        async let musicDone: Void = loadMusic(text)
        async let moviesDone: Void = loadMovies(text)
        async let booksDone: Void = loadBooks(text)
        _ = await (musicDone, moviesDone, booksDone)

        guard !Task.isCancelled else { return }
        rankedOrder = Self.order(for: text, music: music, movies: movies, books: books)
        cache[text] = (music.hits, movies.hits, books.hits)
    }

    private func reset() {
        music = Domain()
        movies = Domain()
        books = Domain()
        rankedOrder = nil
    }

    private func apply(_ cached: (music: [SearchHit], movies: [SearchHit], books: [SearchHit])) {
        music = Domain(isLoading: false, hits: cached.music, isAnswered: true)
        movies = Domain(isLoading: false, hits: cached.movies, isAnswered: true)
        books = Domain(isLoading: false, hits: cached.books, isAnswered: true)
        rankedOrder = Self.order(for: normalized, music: music, movies: movies, books: books)
    }

    // MARK: - Ранжирование секций

    /// Насколько сильно результат отвечает запросу. Единого скора у трёх API нет
    /// (Deezer ранжирует по популярности, Кинопоиск и Google Books — по своему),
    /// и сравнивать их выдачи между собой нечем. Поэтому меру считаем сами —
    /// по совпадению запроса с названием, а названия у нас уже есть в `SearchHit`.
    private enum MatchScore {
        /// Название — это ровно запрос
        static let exact = 100.0
        /// Название начинается с запроса («интерстел» → «Интерстеллар»)
        static let prefix = 70.0
        /// Запрос — целое слово внутри названия
        static let word = 45.0
        /// Запрос где-то внутри названия
        static let substring = 25.0
        /// Совпал только подзаголовок — исполнитель, автор, год с жанром
        static let subtitle = 15.0
        /// Прибавка за вес результата внутри домена (`SearchHit.authority`).
        ///
        /// Ради неё всё и затевалось: на популярный запрос точное совпадение
        /// названия есть у всех трёх доменов сразу («Интерстеллар» — и фильм,
        /// и десяток каверов на его саундтрек), и различает их только то,
        /// насколько результат главный у себя дома.
        static let authority = 25.0
        /// Насколько домен должен обойти соседа, чтобы их поменяли местами.
        /// Без порога секции переставлялись бы от шума в выдаче.
        static let swap = 10.0
    }

    private static func order(
        for text: String,
        music: Domain,
        movies: Domain,
        books: Domain
    ) -> [Section.Kind] {
        let scored: [(Section.Kind, Double)] = [
            (.music, score(text, music)),
            (.movies, score(text, movies)),
            (.books, score(text, books)),
        ]
        // Сортировка устойчивая по дефолтному порядку: домены с близкими скорами
        // остаются как были, меняются местами только при разнице больше порога.
        return scored
            .enumerated()
            .sorted { left, right in
                let delta = left.element.1 - right.element.1
                if abs(delta) < MatchScore.swap { return left.offset < right.offset }
                return delta > 0
            }
            .map(\.element.0)
    }

    /// Скор домена — по его **лучшему** результату: качество совпадения плюс вес
    /// этого результата внутри домена. Пустой домен уходит вниз сам собой.
    ///
    /// Число совпадений в скор не входит намеренно: оно награждает объём каталога,
    /// а не релевантность. Замер на «интерстеллар» (2026-08-25): с надбавкой
    /// за каждое совпадение музыка набирала 148 против 100 у кино — просто потому,
    /// что у Deezer нашлось четыре трека с этим названием, а фильм такой один.
    private static func score(_ text: String, _ domain: Domain) -> Double {
        let needle = text.folded
        guard !needle.isEmpty else { return 0 }

        return domain.hits.map { hit -> Double in
            let title = hit.title.folded
            let match: Double
            if title == needle { match = MatchScore.exact }
            else if title.hasPrefix(needle) { match = MatchScore.prefix }
            else if title.split(separator: " ").contains(where: { $0 == needle }) { match = MatchScore.word }
            else if title.contains(needle) { match = MatchScore.substring }
            else if hit.subtitle.folded.contains(needle) { match = MatchScore.subtitle }
            else { return 0 }
            return match + hit.authority * MatchScore.authority
        }
        .max() ?? 0
    }

    // MARK: - Домены

    /// Музыка — три ручки Deezer разом: у него нет объединённого поиска, а треки,
    /// альбомы и исполнителей выдача показывает отдельными строками.
    private func loadMusic(_ text: String) async {
        async let tracks = try? DeezerService.shared.searchTracks(query: text, limit: Self.perKind)
        async let albums = try? DeezerService.shared.searchAlbums(query: text, limit: Self.perKind)
        async let artists = try? DeezerService.shared.searchArtists(query: text, limit: Self.perKind)

        // Вперемешку по одному от каждого вида, а не подряд: при простой склейке
        // потолок секции съедали бы одни треки, и альбом с исполнителем не попадали
        // в выдачу вовсе.
        let byKind = await [
            (tracks ?? []).map(SearchHit.init(track:)),
            (albums ?? []).map(SearchHit.init(album:)),
            (artists ?? []).map(SearchHit.init(artist:)),
        ]
        var hits: [SearchHit] = []
        // Дубли по паре «название + исполнитель»: у саундтреков трек и альбом
        // называются одинаково, и в выдаче они вставали двумя одинаковыми строками.
        var seen: Set<String> = []
        for index in 0..<Self.perKind {
            for kind in byKind where index < kind.count {
                let hit = kind[index]
                let key = (hit.title + "|" + hit.subtitle).lowercased()
                guard seen.insert(key).inserted else { continue }
                hits.append(hit)
            }
        }

        guard !Task.isCancelled else { return }
        music = Domain(isLoading: false, hits: Array(hits.prefix(Self.perSection)), isAnswered: true)
    }

    /// Кино — сперва запас на диске, сеть только в добор. Если в запасе уже есть
    /// сколько нужно, поиск по кино не стоит ни одного запроса из квоты.
    private func loadMovies(_ text: String) async {
        let pooled = await MoviePool.shared.search(text, limit: Self.perKind)
        if !pooled.isEmpty {
            guard !Task.isCancelled else { return }
            movies = Domain(isLoading: pooled.count < Self.poolEnough, hits: Array(pooled.map(SearchHit.init(movie:)).prefix(Self.perSection)), isAnswered: true)
        }
        guard pooled.count < Self.poolEnough else { return }

        let found = (try? await KinopoiskService.shared.searchMovies(query: text, limit: Self.perKind)) ?? []
        guard !Task.isCancelled else { return }
        // Сетевые дополняют локальные, дубликаты по id отбрасываем.
        let known = Set(pooled.map(\.id))
        let hits = pooled.map(SearchHit.init(movie:)) + found.filter { !known.contains($0.id) }.map(SearchHit.init(movie:))
        movies = Domain(isLoading: false, hits: Array(hits.prefix(Self.perSection)), isAnswered: true)
    }

    private func loadBooks(_ text: String) async {
        let found = (try? await BooksService.shared.search(text, limit: Self.perKind)) ?? []
        guard !Task.isCancelled else { return }
        books = Domain(isLoading: false, hits: found.prefix(Self.perSection).map(SearchHit.init(book:)), isAnswered: true)
    }
}

private extension String {
    /// Сравнение без регистра и диакритики: «ежик» обязан совпадать с «Ёжик».
    /// Тот же приём, что у поиска по запасу фильмов (`MoviePool.search`).
    var folded: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Мапперы доменов

private extension SearchHit {
    init(track: DeezerTrackHit) {
        self.init(
            id: "track-\(track.id)",
            kind: .track,
            title: track.title,
            subtitle: track.artist?.name ?? "",
            artwork: track.album.flatMap { $0.coverBig?.deezerUpscaled }.map { .remote($0) },
            // `rank` Deezer — 0…1 000 000; у заметного трека он за полмиллиона.
            // Экрана трека нет — ведём на альбом, к которому он принадлежит.
            route: track.album.map { album in
                .album(EntityRef(
                    id: "dz-\(album.id)",
                    title: album.title,
                    subtitle: track.artist?.name ?? "",
                    artwork: album.coverBig?.deezerUpscaled.map { ArtworkSource.remote($0) } ?? .asset("mockAlbumCover")
                ))
            },
            authority: min(1, Double(track.rank ?? 0) / 800_000)
        )
    }

    init(album: DeezerAlbumBrief) {
        let cover = (album.coverXl ?? album.coverBig)?.deezerUpscaled
        self.init(
            id: "album-\(album.id)",
            kind: .album,
            title: album.title,
            subtitle: album.artist?.name ?? "",
            artwork: cover.map { .remote($0) },
            route: .album(EntityRef(
                id: "dz-\(album.id)",
                title: album.title,
                subtitle: album.artist?.name ?? "",
                artwork: cover.map { ArtworkSource.remote($0) } ?? .asset("mockAlbumCover")
            ))
        )
    }

    init(artist: DeezerArtistBrief) {
        self.init(
            id: "artist-\(artist.id)",
            kind: .artist,
            title: artist.name,
            subtitle: "Исполнитель",
            artwork: (artist.pictureXl ?? artist.pictureBig ?? artist.pictureMedium)?.deezerUpscaled.map { .remote($0) },
            // Экрана исполнителя в проекте нет вовсе — строка не нажимается.
            route: nil,
            // Фанаты растут на порядки, поэтому логарифм: 10 млн — это 1.0.
            authority: min(1, log10(Double(artist.nbFan ?? 0) + 1) / 7)
        )
    }

    init(movie: KinopoiskMovie) {
        let poster = movie.poster?.url(size: .small)
        self.init(
            id: "movie-\(movie.id)",
            kind: .movie,
            title: movie.displayTitle,
            subtitle: [movie.year.map { "\($0)" }, movie.genres?.first?.name]
                .compactMap { $0 }
                .joined(separator: " · "),
            artwork: poster.map { .remote($0) },
            route: .movie(EntityRef(
                id: "kp-\(movie.id)",
                title: movie.displayTitle,
                subtitle: "",
                artwork: poster.map { ArtworkSource.remote($0) } ?? .asset("mockMoviePoster")
            )),
            // Топ-250 — сразу максимум; иначе рейтинг Кинопоиска, где 5 — дно шкалы,
            // а 9 — потолок.
            authority: movie.top250 != nil ? 1 : min(1, max(0, ((movie.rating?.kp ?? 0) - 5) / 4))
        )
    }

    init(book: GoogleBook) {
        self.init(
            id: "book-\(book.id)",
            kind: .book,
            title: book.title,
            subtitle: book.author,
            artwork: book.coverURL.map { .remote($0) },
            // Тот же экран, что открывает книжная карточка витрины.
            route: .book(EntityRef(
                id: "gb-\(book.id)",
                title: book.title,
                subtitle: book.author,
                artwork: book.coverURL.map { ArtworkSource.remote($0) } ?? .asset("mockBookTechno")
            ))
        )
    }
}
