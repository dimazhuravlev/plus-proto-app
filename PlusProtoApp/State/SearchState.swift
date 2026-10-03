import SwiftUI

/// Кросс-сервисный поиск: один запрос — выдача сразу по музыке, кино и книгам.
///
/// **Три домена идут параллельно, а показываются разом.** Выдача собирается
/// целиком: ждём ответа всех трёх API, считаем порядок секций и публикуем всё одним
/// присваиванием (правка пользователя 2026-10-03). Прежде каждый домен рисовался
/// по мере готовности, а порядок, пересчитанный после последнего ответа,
/// переставлял блоки уже с данными. Запросы при этом параллельны: ждём самый
/// медленный (Deezer 150–300мс, Google Books 200–400 и его обложки, Кинопоиск
/// полсекунды), а не их сумму.
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

    /// Выдача на экране: все три домена разом и уже в окончательном порядке.
    /// Меняется только целиком — одним присваиванием, когда новая выдача собрана.
    /// `nil` — показывать ещё нечего: на первом запросе на её месте скелетон.
    private var shown: Results?
    /// Запрос в пути. Прежняя выдача всё это время стоит как есть: сброс в скелетон
    /// на каждой букве моргал карточками (жалоба пользователя 2026-10-03), а подмена
    /// по доменам переставляла блоки с данными.
    private var isLoading = false

    /// Собранная выдача одного запроса.
    private struct Results {
        let order: [Section.Kind]
        let music: [SearchHit]
        let movies: [SearchHit]
        let books: [SearchHit]

        func hits(_ kind: Section.Kind) -> [SearchHit] {
            switch kind {
            case .music: music
            case .movies: movies
            case .books: books
            }
        }

        var isEmpty: Bool { music.isEmpty && movies.isEmpty && books.isEmpty }
    }

    /// Состояние одного домена выдачи — так секцию видит экран.
    struct Domain {
        var isLoading = false
        var hits: [SearchHit] = []
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

    /// Куда пользователь ушёл из выдачи: таб и глубина навигации на момент тапа.
    /// `nil` — из поиска никуда не уходили.
    ///
    /// Запрос и результаты при переходе никуда не деваются (живут здесь же), поэтому
    /// «вернуть поиск» — это просто вернуть фокус полю: слой выдачи покажет то же,
    /// что было (правка пользователя 2026-08-25 — раньше поиск закрывался насовсем).
    private var suspended: (tab: AppTab, depth: Int)?

    /// Глубина навигации, на которой поиск открыли: 0 — корень таба, больше —
    /// запушенный экран (альбом, книга). По ней экран решает, его ли это поиск,
    /// и показывает слои затемнения с выдачей (`SearchLayers`).
    ///
    /// Раньше слои были прибиты к корню стека, и поиск, открытый **с** альбома,
    /// оказывался под ним — затемнения не было вовсе (жалоба пользователя
    /// 2026-08-27). Живёт здесь, а не в навигации: это свойство поиска, а не
    /// экрана, и гаснет вместе с ним.
    private(set) var hostDepth: Int = 0

    private var searchTask: Task<Void, Never>?
    /// Собранные выдачи на процесс: возврат к уже набранному запросу бесплатен.
    private var cache: [String: Results] = [:]

    /// Есть что показывать слоем выдачи.
    var isActive: Bool {
        normalized.count >= Self.minimumQueryLength
    }

    /// Ни один домен ничего не нашёл, и все уже ответили.
    var isEmptyResult: Bool {
        shown?.isEmpty ?? false
    }

    /// Секция выдачи: домен, его заголовок и результаты.
    struct Section: Identifiable {
        let id: Kind
        let domain: Domain

        enum Kind: CaseIterable {
            case music, movies, books

            var title: String {
                switch self {
                case .music: "Музыка"
                case .movies: "Кино"
                case .books: "Книги"
                }
            }
        }

        var title: String { id.title }
        /// У музыки карточка квадратная, у кино и книг — постер 2:3.
        var isPoster: Bool { id != .music }
    }

    /// Секции в порядке показа. Порядок считается по релевантности запросу
    /// (решение пользователя 2026-08-25) **до** показа: выдача публикуется, когда
    /// ответили все три домена, и появляется сразу на своих местах — блоки после
    /// этого не переставляются (правка пользователя 2026-10-03).
    ///
    /// Скелетон первого запроса — три секции в порядке по умолчанию: настоящий
    /// порядок ещё неизвестен. Пустые домены экран не показывает вовсе.
    var sections: [Section] {
        guard let shown else {
            guard isLoading else { return [] }
            return Section.Kind.allCases.map { Section(id: $0, domain: Domain(isLoading: true)) }
        }
        return shown.order.map { Section(id: $0, domain: Domain(hits: shown.hits($0))) }
    }

    private var normalized: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Уход в сущность и возврат

    /// Привязать поиск к экрану, на котором он открыт. Зовётся на получении фокуса
    /// и на смене глубины при уже открытом поиске: свайп-назад с альбома не закрывает
    /// клавиатуру, и поиск обязан переехать на экран, где пользователь оказался.
    func host(at depth: Int) {
        hostDepth = depth
    }

    /// Забыть точку ухода в карточку: поиск начали заново (новый фокус), вышли из него
    /// или ушли на другой таб. Отметка гаснет и сама — на возврате (`consumeResume`).
    func dropSuspension() {
        suspended = nil
    }

    /// Запомнить точку, из которой пользователь ушёл в открытую карточку.
    func suspend(tab: AppTab, depth: Int) {
        suspended = (tab, depth)
        // Под карточкой выдачу держит отметка, а не просмотр.
        isBrowsing = false
    }

    /// Пора ли вернуть поиск: пользователь закрыл всё, что открывал из выдачи,
    /// и оказался ровно там, откуда уходил. Метод «съедает» отметку — восстановление
    /// одноразовое, иначе поиск лез бы обратно на каждый поп в этом табе.
    ///
    /// Таб проверяется вместе с глубиной: уйти можно и переключением таба, и тогда
    /// возвращать выдачу пользователю точно не надо.
    ///
    /// Возвращается выдача **без клавиатуры** (`isBrowsing`): поле стоит внизу с тем же
    /// запросом, тап по нему возвращает ввод (правка пользователя 2026-10-03). Отметка
    /// и просмотр меняются в одном апдейте — слой выдачи не гаснет ни на кадр.
    func consumeResume(tab: AppTab, depth: Int) -> Bool {
        guard let suspended, suspended.tab == tab, depth <= suspended.depth else { return false }
        self.suspended = nil
        // Запрос стёрли, пока ходили по карточкам (крестом в поиске, открытом поверх
        // них), — возвращать нечего. Просмотр без выдачи спрятал бы таббар впустую.
        guard isActive else { return false }
        isBrowsing = true
        return true
    }

    /// Выдача открыта, но поле без фокуса: клавиатуру опустили при непустой выдаче,
    /// или пользователь вернулся из карточки. Таббара в этом состоянии нет, бар стоит
    /// на его месте (`BottomChrome`). Гаснет, когда поиск закрыли (крест, смена таба,
    /// круг плеера) или когда поле снова получило клавиатуру — дальше слой держит она.
    var isBrowsing = false

    /// Поиск ушёл в открытую карточку, но не закрылся: слой выдачи остаётся
    /// на экране **под** карточкой всё время, пока она открыта.
    ///
    /// Глубина здесь намеренно не проверяется: слои живут на экране, с которого
    /// поиск открыли (`hostDepth`), и открытая поверх карточка накрывает их сама.
    /// Пряталась выдача — и мелькала витрина, пока карточка доезжала
    /// (жалоба пользователя 2026-08-25, поймано на видео).
    var isSuspended: Bool { suspended != nil }

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
            isLoading = false
            shown = cached
            if let expanded { startFull(expanded, text) }
            return
        }

        // Скелетон — только когда показывать ещё нечего, то есть на первом запросе;
        // уточнение запроса держит прежнюю выдачу до готовности новой.
        isLoading = true

        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }
            await self?.run(text)
        }
    }

    private func run(_ text: String) async {
        // Запросы параллельны, показ — общий: ждём все три ответа и персону.
        async let music = fetchMusic(text)
        async let movies = fetchMovies(text)
        async let books = fetchBooks(text)
        async let person = WikipediaPeople.shared.person(matching: text)
        let (musicHits, fetchedMovies, fetchedBooks, found) = await (music, movies, books, person)

        guard !Task.isCancelled else { return }
        var movieHits = fetchedMovies
        var bookHits = fetchedBooks
        // Персона — первой в карусели своего домена: запрос назвал её саму, а не её
        // книгу или фильм (правка пользователя 2026-10-03, вид — как у соседей).
        if let found {
            let hit = SearchHit(person: found)
            switch found.role {
            case .director: movieHits = Array(([hit] + movieHits).prefix(Self.perSection))
            case .writer: bookHits = Array(([hit] + bookHits).prefix(Self.perSection))
            }
        }
        let results = Results(
            order: Self.order(for: text, music: musicHits, movies: movieHits, books: bookHits),
            music: musicHits,
            movies: movieHits,
            books: bookHits
        )
        cache[text] = results
        // Одно присваивание — один кадр: все блоки появляются разом и сразу
        // в окончательном порядке.
        shown = results
        isLoading = false
        // Раскрытый раздел следует за запросом: поле в баре на экране полной выдачи
        // живое, набранное меняет и её. Персона раздела берётся из только что
        // собранного обзора, поэтому полная выдача — после него.
        if let expanded { startFull(expanded, text) }
    }

    private func reset() {
        shown = nil
        isLoading = false
        // Запрос стёрт — раскрытому разделу показывать нечего.
        expanded = nil
        fullTask?.cancel()
    }

    // MARK: - Полная выдача раздела

    /// Раздел, раскрытый на весь экран — переход по заголовку его карусели (задача
    /// пользователя 2026-10-03, макет музыки `2440:27920`). `nil` — обзор каруселями.
    /// Это подэкран слоя выдачи, а не пуш: «Назад» в баре сперва сворачивает его
    /// к обзору, а вся навигация вокруг поиска (отметка ухода, просмотр, привязка
    /// к экрану) остаётся прежней.
    private(set) var expanded: Section.Kind?
    /// Полная выдача — последняя собранная; к запросу и разделу её сверяет `full(for:)`.
    private var full: FullResults?
    private var fullTask: Task<Void, Never>?
    private var fullCache: [String: FullResults] = [:]

    /// Полная выдача одного раздела по одному запросу.
    struct FullResults {
        let kind: Section.Kind
        let text: String
        let hits: [SearchHit]
        /// Колдунщик — только у музыки.
        let wizard: MusicWizard?
    }

    /// Колдунщик музыки — самый подходящий запросу исполнитель (макет `2440:29310`):
    /// фото, имя, play и карусель его альбомов.
    struct MusicWizard {
        let artist: SearchHit
        let albums: [SearchHit]
        /// Трек этого исполнителя из выдачи — его включает play. Нет — первый альбом.
        let topTrack: SearchHit?
    }

    /// Сколько просим у каждой ручки на полной выдаче — больше, чем у карусели.
    private enum FullLimits {
        static let tracks = 20
        static let albums = 15
        static let artists = 10
        static let playlists = 10
        static let movies = 30
        static let networkMovies = 20
        /// Меньше стольких фильмов в запасе — добор из сети (квота Кинопоиска).
        static let poolEnough = 10
        static let books = 20
        static let wizardAlbums = 12
        static let musicTotal = 50
    }

    /// Раскрыть раздел. Анимацию перехода ведёт слой выдачи.
    func expand(_ kind: Section.Kind) {
        expanded = kind
        // Обзор этого текста ещё в пути — полную выдачу запустит он сам, когда соберётся:
        // персона раздела берётся из него, и раньше времени она была бы от прошлого
        // запроса.
        if cache[normalized] != nil {
            startFull(kind, normalized)
        }
    }

    /// Свернуть к обзору — «Назад» в баре, новый поиск, смена таба.
    func collapse() {
        expanded = nil
    }

    /// Полная выдача раскрытого раздела; `nil` — первая ещё собирается. Уточнение
    /// запроса держит прежнюю выдачу раздела до готовности новой — как и обзор
    /// (правка пользователя 2026-10-03): скелетон на каждой букве сбрасывал список
    /// и фильтр.
    var fullResults: FullResults? {
        guard let expanded, let full, full.kind == expanded else { return nil }
        return full
    }

    private func startFull(_ kind: Section.Kind, _ text: String) {
        fullTask?.cancel()
        let key = "\(kind)|\(text)"
        if let cached = fullCache[key] {
            full = cached
            return
        }
        fullTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.loadFull(kind, text)
            guard !Task.isCancelled else { return }
            // Пустой ответ не кэшируем: за ним бывает сбой сети или 429, и «ничего
            // не нашлось» залипло бы до перезапуска.
            if !result.hits.isEmpty { self.fullCache[key] = result }
            self.full = result
        }
    }

    private func loadFull(_ kind: Section.Kind, _ text: String) async -> FullResults {
        switch kind {
        case .music:
            let (hits, wizard) = await fetchFullMusic(text)
            return FullResults(kind: kind, text: text, hits: hits, wizard: wizard)
        case .movies:
            let hits = await fetchFullMovies(text)
            return FullResults(kind: kind, text: text, hits: personFirst(.director, in: cache[text]?.movies, hits), wizard: nil)
        case .books:
            let found = (try? await BooksService.shared.search(text, limit: FullLimits.books)) ?? []
            let hits = found.map(SearchHit.init(book:))
            return FullResults(kind: kind, text: text, hits: personFirst(.writer, in: cache[text]?.books, hits), wizard: nil)
        }
    }

    /// Персона из обзора — первой и в полной выдаче: запрос назвал её саму.
    private func personFirst(_ kind: SearchHit.Kind, in overview: [SearchHit]?, _ hits: [SearchHit]) -> [SearchHit] {
        guard let person = overview?.first(where: { $0.kind == kind }) else { return hits }
        return [person] + hits
    }

    private func fetchFullMusic(_ text: String) async -> ([SearchHit], MusicWizard?) {
        async let tracks = try? DeezerService.shared.searchTracks(query: text, limit: FullLimits.tracks)
        async let albums = try? DeezerService.shared.searchAlbums(query: text, limit: FullLimits.albums)
        async let artists = try? DeezerService.shared.searchArtists(query: text, limit: FullLimits.artists)
        async let playlists = try? DeezerService.shared.searchPlaylists(query: text, limit: FullLimits.playlists)
        let (foundTracks, foundAlbums, allArtists, foundPlaylists) = await (
            tracks ?? [], albums ?? [], artists ?? [], playlists ?? []
        )
        // Исполнители без фото — вне выдачи (правка пользователя 2026-10-03).
        let foundArtists = allArtists.filter(\.hasPhoto)

        // Вперемешку по одному от каждого вида — как и в карусели.
        let byKind = [
            foundTracks.map(SearchHit.init(track:)),
            foundAlbums.map(SearchHit.init(album:)),
            foundArtists.map(SearchHit.init(artist:)),
            foundPlaylists.map(SearchHit.init(playlist:)),
        ]
        var hits: [SearchHit] = []
        var seen: Set<String> = []
        for index in 0..<(byKind.map(\.count).max() ?? 0) {
            for kind in byKind where index < kind.count {
                let hit = kind[index]
                guard seen.insert((hit.title + "|" + hit.subtitle).lowercased()).inserted else { continue }
                hits.append(hit)
            }
        }
        hits = Array(hits.prefix(FullLimits.musicTotal))

        // Колдунщик — исполнитель, чьё имя отвечает запросу; из таких — самый
        // популярный. Не нашлось — колдунщика нет, а не случайный исполнитель.
        // И только с альбомами: колдунщик без карусели — пустая плашка (правка
        // пользователя 2026-10-03).
        let needle = text.folded
        guard let best = foundArtists
            .filter({ Self.nameMatches($0.name.folded, needle) && ($0.nbAlbum ?? 1) > 0 })
            .max(by: { ($0.nbFan ?? 0) < ($1.nbFan ?? 0) })
        else { return (hits, nil) }
        let artistAlbums = (try? await DeezerService.shared.artistAlbums(id: best.id, limit: FullLimits.wizardAlbums)) ?? []
        var albumTitles: Set<String> = []
        let wizardAlbums = artistAlbums
            .filter { albumTitles.insert($0.title.lowercased()).inserted }
            .map(SearchHit.init(album:))
        guard !wizardAlbums.isEmpty else { return (hits, nil) }
        let artistName = best.name.folded
        let topTrack = hits.first { $0.kind == .track && $0.subtitle.folded == artistName }
        return (hits, MusicWizard(artist: SearchHit(artist: best), albums: wizardAlbums, topTrack: topTrack))
    }

    /// Ответы сетевого поиска Кинопоиска на процесс. Обзор и полная выдача раздела
    /// берут одну выдачу на текст (лимит полной, обзору — начало): иначе раскрытый
    /// раздел тратил второй запрос из 200 в сутки на тот же текст (проверка 2026-10-03).
    private var kinopoiskRaw: [String: [KinopoiskMovie]] = [:]

    private func kinopoiskMovies(_ text: String) async -> [KinopoiskMovie] {
        if let cached = kinopoiskRaw[text] { return cached }
        let found = (try? await KinopoiskService.shared.searchMovies(query: text, limit: FullLimits.networkMovies)) ?? []
        // Пустой — не кэшируем: за ним бывает сбой.
        if !found.isEmpty { kinopoiskRaw[text] = found }
        return found
    }

    /// Имя отвечает запросу: совпадает, начинается с него или содержит его целым словом.
    private static func nameMatches(_ name: String, _ needle: String) -> Bool {
        guard !needle.isEmpty else { return false }
        return name == needle
            || name.hasPrefix(needle)
            || name.split(separator: " ").contains { $0 == needle }
    }

    private func fetchFullMovies(_ text: String) async -> [SearchHit] {
        let pooled = await MoviePool.shared.search(text, limit: FullLimits.movies)
            .filter(Self.isShowableMovie)
        var hits = pooled.map(SearchHit.init(movie:))
        guard pooled.count < FullLimits.poolEnough, !Task.isCancelled else { return hits }
        let found = await kinopoiskMovies(text)
        let known = Set(pooled.map(\.id))
        hits += found
            .filter { !known.contains($0.id) && Self.isShowableMovie($0) }
            .map(SearchHit.init(movie:))
        return hits
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
        music: [SearchHit],
        movies: [SearchHit],
        books: [SearchHit]
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
    private static func score(_ text: String, _ hits: [SearchHit]) -> Double {
        let needle = text.folded
        guard !needle.isEmpty else { return 0 }

        return hits.map { hit -> Double in
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

    /// Загрузчики доменов ничего не пишут в состояние — только возвращают
    /// результаты: показывает их `run`, когда собраны все три.
    ///
    /// Музыка — три ручки Deezer разом: у него нет объединённого поиска, а треки,
    /// альбомы и исполнителей выдача показывает отдельными строками.
    private func fetchMusic(_ text: String) async -> [SearchHit] {
        async let tracks = try? DeezerService.shared.searchTracks(query: text, limit: Self.perKind)
        async let albums = try? DeezerService.shared.searchAlbums(query: text, limit: Self.perKind)
        async let artists = try? DeezerService.shared.searchArtists(query: text, limit: Self.perKind)

        // Вперемешку по одному от каждого вида, а не подряд: при простой склейке
        // потолок секции съедали бы одни треки, и альбом с исполнителем не попадали
        // в выдачу вовсе.
        let byKind = await [
            (tracks ?? []).map(SearchHit.init(track:)),
            (albums ?? []).map(SearchHit.init(album:)),
            // Исполнители без фото — вне выдачи (правка пользователя 2026-10-03).
            (artists ?? []).filter(\.hasPhoto).map(SearchHit.init(artist:)),
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

        return Array(hits.prefix(Self.perSection))
    }

    /// Кино — сперва запас на диске, сеть только в добор. Если в запасе уже есть
    /// сколько нужно, поиск по кино не стоит ни одного запроса из квоты.
    private func fetchMovies(_ text: String) async -> [SearchHit] {
        let pooled = await MoviePool.shared.search(text, limit: Self.perKind)
            .filter(Self.isShowableMovie)
        let local = pooled.map(SearchHit.init(movie:))
        guard pooled.count < Self.poolEnough, !Task.isCancelled else {
            return Array(local.prefix(Self.perSection))
        }

        let found = Array(await kinopoiskMovies(text).prefix(Self.perKind))
        // Сетевые дополняют локальные, дубликаты по id отбрасываем.
        let known = Set(pooled.map(\.id))
        let network = found
            .filter { !known.contains($0.id) && Self.isShowableMovie($0) }
            .map(SearchHit.init(movie:))
        return Array((local + network).prefix(Self.perSection))
    }

    /// Карточка фильма без названия или без постера в карусели — серый пустой
    /// прямоугольник с одним годом: сетевой поиск Кинопоиска отдаёт и такие записи
    /// (жалоба пользователя 2026-10-03). Фильтр — и для запаса на диске: дёшево.
    private static func isShowableMovie(_ movie: KinopoiskMovie) -> Bool {
        let title = movie.displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !title.isEmpty && movie.poster?.url(size: .small) != nil
    }

    private func fetchBooks(_ text: String) async -> [SearchHit] {
        let found = (try? await BooksService.shared.search(text, limit: Self.perKind)) ?? []
        guard !Task.isCancelled else { return [] }
        var hits = found.prefix(Self.perSection).map(SearchHit.init(book:))
        // Карточка книги — по пропорциям обложки (макет `2311:25096`), поэтому книги
        // готовы, когда обложки уже приехали: ширины известны, карусель не
        // перекладывается, а сами обложки встают из кэша без проявления.
        let aspects = await Self.coverAspects(of: hits)
        for index in hits.indices {
            hits[index].artworkAspect = aspects[hits[index].id]
        }
        return Array(hits)
    }

    /// Сколько ждём обложки книг. Не дождались — карточка встаёт на пропорции
    /// по умолчанию, а обложка проявится, когда приедет.
    private static let coverWait: Duration = .milliseconds(1500)

    /// Пропорции обложек — с самих картинок: размеров Google Books не отдаёт.
    private static func coverAspects(of hits: [SearchHit]) async -> [String: CGFloat] {
        let urls = hits.compactMap { hit in hit.artwork?.remoteURL.map { (hit.id, $0) } }
        guard !urls.isEmpty else { return [:] }
        return await withTaskGroup(of: (String, CGFloat?).self) { group in
            for (id, url) in urls {
                group.addTask { @MainActor in
                    let image = await ArtworkLoader.shared.image(for: url)
                    return (id, image.map { $0.size.width / max($0.size.height, 1) })
                }
            }
            group.addTask {
                try? await Task.sleep(for: coverWait)
                return ("", nil)
            }
            var aspects: [String: CGFloat] = [:]
            var answered = 0
            for await (id, aspect) in group {
                // Пустой id — истёк потолок ожидания.
                guard !id.isEmpty else { break }
                answered += 1
                if let aspect { aspects[id] = aspect }
                if answered == urls.count { break }
            }
            group.cancelAll()
            return aspects
        }
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
            // Подписи нет: круглая карточка и так читается исполнителем (правка
            // пользователя 2026-10-03, прежде — «Исполнитель»).
            subtitle: "",
            artwork: (artist.pictureXl ?? artist.pictureBig ?? artist.pictureMedium)?.deezerUpscaled.map { .remote($0) },
            // Экрана исполнителя в проекте нет вовсе — строка не нажимается.
            route: nil,
            // Фанаты растут на порядки, поэтому логарифм: 10 млн — это 1.0.
            authority: min(1, log10(Double(artist.nbFan ?? 0) + 1) / 7)
        )
    }

    init(movie: KinopoiskMovie) {
        // Часть постеров Кинопоиск отдаёт ссылкой на `image.tmdb.org`, а его у нас режут:
        // карточка выходила пустой (жалоба пользователя 2026-10-03, «Хичкок: Тень гения»).
        // Через тот же прокси, что и логотипы тайтлов, — постер на месте.
        let raw = movie.poster?.url(size: .small)
        let poster = raw.flatMap { TMDBImageProxy.rewrite($0, width: 300) } ?? raw
        self.init(
            id: "movie-\(movie.id)",
            kind: .movie,
            title: movie.displayTitle,
            // Только год, как в макете: жанр с разделителем-точкой убран (правка
            // пользователя 2026-10-03).
            subtitle: movie.year.map { "\($0)" } ?? "",
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

    /// Писатель или режиссёр: одно имя, фото с Википедии. Не нажимается — экрана
    /// персоны в проекте нет. Вес высокий: совпадение запроса с именем — сильный
    /// сигнал, что секция про него.
    /// Плейлист — только в полной выдаче: экрана нет, строка не нажимается.
    init(playlist: DeezerPlaylistBrief) {
        self.init(
            id: "playlist-\(playlist.id)",
            kind: .playlist,
            title: playlist.title,
            subtitle: playlist.user?.name ?? "",
            artwork: (playlist.pictureXl ?? playlist.pictureBig)?.deezerUpscaled.map { .remote($0) },
            route: nil
        )
    }

    init(person: WikipediaPeople.Person) {
        self.init(
            id: "person-\(person.pageID)",
            kind: person.role == .director ? .director : .writer,
            title: person.name,
            subtitle: "",
            artwork: .remote(person.photo),
            route: nil,
            authority: 0.8
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
