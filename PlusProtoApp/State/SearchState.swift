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
            // Набор уводит из полного списка истории. Пока запрос короче двух символов —
            // сразу, переходом подэкрана к ленте. С двух (вставка, подсказка клавиатуры)
            // слой сам сменит нулевое состояние на выдачу, и список снимается уже после
            // этого (`dismissHistory`): иначе на смене мелькала лента (ревью 2026-10-03).
            if !normalized.isEmpty, !isActive { isHistoryShown = false }
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
        let text: String
        let order: [Section.Kind]
        let music: [SearchHit]
        let movies: [SearchHit]
        let books: [SearchHit]
        /// Все разделы одной лентой — порядок сетки (`mixed`), посчитанный вместе
        /// с порядком секций: сетка встаёт сразу на свои места, как и карусели.
        let mixed: [SearchHit]

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

    // MARK: - Искали недавно

    /// Найденное пользователем — во что он перешёл из выдачи, свежее первым.
    /// Живёт на диске (`SearchRecents`).
    private var found: [SearchHit] = SearchRecents.load()

    /// Лента нулевого состояния: найденное, за ним стартовый набор, не больше 12.
    /// Пустой не бывает — поэтому у поиска всегда есть что показать, и с пустым полем
    /// он ведёт себя как с выдачей (просмотр без клавиатуры, возврат из карточки).
    var recents: [SearchHit] { Array(history.prefix(SearchRecents.carouselLimit)) }

    /// Полный список истории — переход по заголовку ленты: всё найденное и стартовый набор.
    var history: [SearchHit] { SearchRecents.merged(found) }

    /// Полный список истории на экране — подэкран нулевого состояния, как раскрытый
    /// раздел у выдачи: «Назад» сперва сворачивает его к ленте (`collapse`).
    private(set) var isHistoryShown = false

    func showHistory() {
        isHistoryShown = true
    }

    /// Нулевое состояние ушло с экрана, уступив выдаче: список истории больше не открыт.
    /// Зовёт слой, когда нулевое состояние уже снято и гаснет замороженным.
    func dismissHistory() {
        isHistoryShown = false
    }

    /// «Удалить историю» (с подтверждением в списке): найденное стирается, и список
    /// уходит к ленте — в ней остаётся стартовый набор, пустой она не бывает.
    func clearHistory() {
        found = []
        SearchRecents.save(found)
        isHistoryShown = false
    }

    /// Пользователь перешёл в айтем из выдачи — айтем встаёт первым в «Искали недавно».
    /// Из самой карусели не зовётся: она переставлялась бы под зумом открытой карточки.
    func remember(_ hit: SearchHit) {
        found.removeAll { $0.id == hit.id }
        found.insert(hit, at: 0)
        found = Array(found.prefix(SearchRecents.limit))
        SearchRecents.save(found)
        if hit.kind == .book, hit.artworkAspect == nil { measureCover(of: hit) }
    }

    /// Пропорции обложки книги, пришедшей без них. Их снимает только обзор каруселей,
    /// а книга из полного списка встала бы в ленту по 2:3 — с обрезанной обложкой
    /// (ревью 2026-10-03). Картинка к этому времени обычно уже в кэше загрузчика.
    private func measureCover(of hit: SearchHit) {
        Task { [weak self] in
            guard let aspect = await Self.coverAspects(of: [hit])[hit.id],
                  let self,
                  let index = self.found.firstIndex(where: { $0.id == hit.id })
            else { return }
            self.found[index].artworkAspect = aspect
            SearchRecents.save(self.found)
        }
    }

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
    ///
    /// С пустым полем — так же: возвращаться есть куда, в «Искали недавно» (нулевое
    /// состояние, 2026-10-03). Прежде пустой запрос поиск на возврате закрывал.
    func consumeResume(tab: AppTab, depth: Int) -> Bool {
        guard let suspended, suspended.tab == tab, depth <= suspended.depth else { return false }
        self.suspended = nil
        isBrowsing = true
        return true
    }

    /// Выдача открыта, но поле без фокуса: клавиатуру опустили (скроллом, свайпом
    /// по полю, «Найти»), или пользователь вернулся из карточки. С пустым полем —
    /// то же самое, только на экране «Искали недавно». Таббара в этом состоянии нет, бар стоит
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
        let (fetchedMusic, fetchedMovies, fetchedBooks, found) = await (music, movies, books, person)

        guard !Task.isCancelled else { return }
        // Внутри карусели — самое точное совпадение первым (`ranked`).
        let musicHits = Self.ranked(fetchedMusic, for: text)
        var movieHits = Self.ranked(fetchedMovies, for: text)
        var bookHits = Self.ranked(fetchedBooks, for: text)
        // Персона — первой в карусели своего домена: запрос назвал её саму, а не её
        // книгу или фильм (правка пользователя 2026-10-03, вид — как у соседей).
        if let found {
            let hit = SearchHit(person: found)
            switch found.role {
            case .director: movieHits = Array(([hit] + movieHits).prefix(Self.perSection))
            case .writer: bookHits = Array(([hit] + bookHits).prefix(Self.perSection))
            }
        }
        let order = Self.order(for: text, music: musicHits, movies: movieHits, books: bookHits)
        let byKind: [Section.Kind: [SearchHit]] = [.music: musicHits, .movies: movieHits, .books: bookHits]
        let results = Results(
            text: text,
            order: order,
            music: musicHits,
            movies: movieHits,
            books: bookHits,
            mixed: Self.mixed(order.map { ($0, byKind[$0] ?? []) }, for: text, leadsWithHeads: true)
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

    /// Свернуть к обзору — «Назад» в баре, новый поиск, смена таба. И полный список
    /// истории — к ленте «Искали недавно».
    func collapse() {
        expanded = nil
        isHistoryShown = false
    }

    /// Открыт подэкран слоя: раскрытый раздел выдачи или полный список истории
    /// (он — только в нулевом состоянии; с выдачей на экране флаг досбрасывается
    /// апдейтом позже, и «Назад» в этот миг уже выходит из поиска).
    var isSubscreenShown: Bool { expanded != nil || (isHistoryShown && !isActive) }

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

    /// Полная выдача ранжируется так же, как карусель обзора (`ranked`): раскрытый
    /// раздел продолжает карусель, а не переставляет её.
    private func loadFull(_ kind: Section.Kind, _ text: String) async -> FullResults {
        switch kind {
        case .music:
            let (hits, wizard) = await fetchFullMusic(text)
            return FullResults(kind: kind, text: text, hits: Self.ranked(hits, for: text), wizard: wizard)
        case .movies:
            let hits = Self.ranked(await fetchFullMovies(text), for: text)
            return FullResults(kind: kind, text: text, hits: personFirst(.director, in: cache[text]?.movies, hits), wizard: nil)
        case .books:
            let found = (try? await BooksService.shared.search(text, limit: FullLimits.books)) ?? []
            let hits = Self.ranked(found.map(SearchHit.init(book:)), for: text)
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

    // MARK: - Сетка

    /// Вторая версия выдачи — сетка вперемешку (`SearchMosaicView`, задача пользователя
    /// 2026-10-05). Начинается с той же выдачи, что карусели (`Results.mixed`), а когда
    /// её карточки кончаются, добирает полные выдачи трёх разделов — один раз на текст.
    /// Добор — только по просьбе сетки, когда до низа уже недалеко: Deezer и Google
    /// Books не тратятся на запросы, до конца которых никто не долистает.
    ///
    /// Ключ — текст выдачи, а не поля: уточнение запроса держит прежнюю выдачу,
    /// и добор относится к ней.
    private var mosaicExtra: [String: [SearchHit]] = [:]
    /// Тексты, у которых добор уже был: больше брать неоткуда. Отметка ставится
    /// и на пустом доборе — иначе сетка у низа просила бы его снова и снова.
    private var mosaicDone: Set<String> = []
    /// Текст, чей добор сейчас в пути.
    private var mosaicLoading: String?

    /// Текст показанной выдачи: по нему сетка узнаёт, что пришёл новый запрос.
    var shownText: String? { shown?.text }

    /// Карточки сетки — смешанная выдача обзора и добор за ней. Дописывается только
    /// в конец: стоящие карточки не переставляются.
    var mosaicHits: [SearchHit] {
        guard let shown else { return [] }
        return shown.mixed + (mosaicExtra[shown.text] ?? [])
    }

    /// Добор ещё впереди.
    var canExtendMosaic: Bool {
        guard let shown else { return false }
        return !mosaicDone.contains(shown.text) && mosaicLoading != shown.text
    }

    /// Добор в пути — сетка держит внизу скелетоны.
    var isExtendingMosaic: Bool {
        guard let shown else { return false }
        return mosaicLoading == shown.text
    }

    /// Добрать сетку: полные выдачи трёх разделов параллельно, за вычетом уже показанного,
    /// смешанные тем же порядком (`mixed`) и дописанные в конец.
    func extendMosaic() {
        guard let base = shown, canExtendMosaic else { return }
        let text = base.text
        mosaicLoading = text
        Task { [weak self] in
            guard let self else { return }
            async let music = self.loadFull(.music, text)
            async let movies = self.loadFull(.movies, text)
            async let books = self.loadFull(.books, text)
            let full = await [music, movies, books]
            // Те же полные выдачи откроются и заголовком карусели — без новых запросов.
            for result in full where !result.hits.isEmpty {
                self.fullCache["\(result.kind)|\(text)"] = result
            }

            var known = Set(base.mixed.map(\.id))
            var fresh: [Section.Kind: [SearchHit]] = [:]
            for result in full {
                // Плейлисты — вне сетки: своего экрана у них нет, карточка не нажималась бы.
                fresh[result.kind] = result.hits.filter { $0.kind != .playlist && known.insert($0.id).inserted }
            }
            // Книге в сетке высоту задают пропорции обложки — снимаем их до показа,
            // как в обзоре (`fetchBooks`): узнай их поздно, колонки переложились бы.
            if var newBooks = fresh[.books], !newBooks.isEmpty {
                let aspects = await Self.coverAspects(of: newBooks)
                for index in newBooks.indices {
                    newBooks[index].artworkAspect = aspects[newBooks[index].id]
                }
                fresh[.books] = newBooks
            }

            let extra = Self.mixed(
                base.order.map { ($0, fresh[$0] ?? []) },
                for: text,
                leadsWithHeads: false,
                after: base.mixed.last?.kind.domain
            )
            self.mosaicExtra[text, default: []] += extra
            self.mosaicDone.insert(text)
            if self.mosaicLoading == text { self.mosaicLoading = nil }
        }
    }

    /// Смешивание разделов для сетки. Единого скора у трёх API нет (см. `MatchScore`),
    /// поэтому вес карточки — тот же, что у порядка секций: ступень совпадения
    /// с названием × (1 + доля × вес внутри домена).
    ///
    /// 1. **Первый ряд** — лучшее от каждого раздела, чьё название отвечает запросу
    ///    хотя бы вхождением, по убыванию веса: наверху сетки — самое релевантное
    ///    из разных API, а не пачка одного.
    /// 2. **Дальше** — слияние трёх очередей: на каждом шаге берётся голова с бо́льшим
    ///    весом, но каждая следующая подряд карточка того же раздела теряет 15 %
    ///    (`MixScore.repeatPenalty`). Сильный раздел идёт несколько карточек подряд,
    ///    слабые не проваливаются в самый низ, а без совпадений разделы чередуются.
    ///
    /// Порядок внутри раздела не трогается — это его `ranked`: точное совпадение
    /// первым, исполнитель выше своих треков, чередование видов музыки.
    private enum MixScore {
        /// Порог первого ряда — вхождение запроса в название
        static let headThreshold = MatchScore.substring
        /// Во сколько раз легчает каждая следующая подряд карточка того же раздела
        static let repeatPenalty = 0.85
        /// Прибавка к весу: у карточек без совпадения он ноль, и без неё штраф
        /// за повтор ничего бы не менял — хвост шёл бы пачкой одного раздела.
        static let floor = 1.0
    }

    /// `after` — раздел последней уже показанной карточки: добор продолжает её серию.
    private static func mixed(
        _ queues: [(kind: Section.Kind, hits: [SearchHit])],
        for text: String,
        leadsWithHeads: Bool,
        after previous: Section.Kind? = nil
    ) -> [SearchHit] {
        let needle = text.folded
        func weight(_ hit: SearchHit) -> Double {
            match(hit, needle) * (1 + hit.authority * MatchScore.authorityShare)
        }

        var queues = queues.map { (kind: $0.kind, hits: ArraySlice($0.hits)) }
        var result: [SearchHit] = []
        var last = previous
        var run = previous == nil ? 0 : 1

        func take(_ index: Int) {
            result.append(queues[index].hits.removeFirst())
            if queues[index].kind == last {
                run += 1
            } else {
                last = queues[index].kind
                run = 1
            }
        }

        if leadsWithHeads {
            // Ничья — по порядку секций: он уже отражает, о чём запрос.
            let heads = queues.indices
                .filter { index in
                    queues[index].hits.first.map { match($0, needle) >= MixScore.headThreshold } ?? false
                }
                .sorted { left, right in
                    let l = weight(queues[left].hits.first!), r = weight(queues[right].hits.first!)
                    return l != r ? l > r : left < right
                }
            for index in heads { take(index) }
        }

        while true {
            var best: (index: Int, value: Double)?
            for index in queues.indices {
                guard let head = queues[index].hits.first else { continue }
                let repeats = queues[index].kind == last ? run : 0
                let value = (weight(head) + MixScore.floor) * pow(MixScore.repeatPenalty, Double(repeats))
                // Строго больше: при равенстве остаётся раздел выше по порядку секций.
                if best.map({ value > $0.value }) ?? true { best = (index, value) }
            }
            guard let best else { break }
            take(best.index)
        }
        return result
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
        /// Доля прибавки за вес результата внутри домена (`SearchHit.authority`):
        /// совпадение × (1 + доля × вес), то есть не больше +25 % к своей ступени.
        ///
        /// Вес нужен там, где точное совпадение названия есть у всех трёх доменов
        /// сразу («Интерстеллар» — и фильм, и десяток каверов на его саундтрек):
        /// различает их только то, насколько результат главный у себя дома.
        /// Но только **внутри** ступени совпадения: прибавка процентом, а не
        /// слагаемым, и популярность не перетягивает более точное название
        /// (правка пользователя 2026-10-03: «больший вес — совпадению в названии»).
        /// Слагаемым +25 подзаголовок популярного исполнителя (15 + 25) обгонял
        /// вхождение в название (25).
        static let authorityShare = 0.25
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
        return hits.map { match($0, needle) * (1 + $0.authority * MatchScore.authorityShare) }.max() ?? 0
    }

    /// Порядок внутри карусели — по той же ступени совпадения, что и порядок секций
    /// (правка пользователя 2026-10-04: на «кино» группа «Кино» стояла третьей —
    /// за своими песнями, которые совпадали с запросом только исполнителем).
    ///
    /// Ступень — первый ключ. В одной ступени исполнитель выше треков и альбомов:
    /// запрос назвал его самого. Дальше — порядок ответа, то есть чередование видов
    /// и ранжирование API внутри ступени остаются как были. Вес результата
    /// (`authority`) сюда не входит: у альбомов его нет вовсе, и он сбил бы
    /// чередование — все треки встали бы перед всеми альбомами.
    private static func ranked(_ hits: [SearchHit], for text: String) -> [SearchHit] {
        let needle = text.folded
        guard !needle.isEmpty else { return hits }
        return hits.enumerated()
            .map { (hit: $0.element, offset: $0.offset, match: match($0.element, needle)) }
            .sorted { left, right in
                if left.match != right.match { return left.match > right.match }
                let leftArtist = left.hit.kind == .artist
                let rightArtist = right.hit.kind == .artist
                if leftArtist != rightArtist { return leftArtist }
                return left.offset < right.offset
            }
            .map(\.hit)
    }

    /// Ступень совпадения результата с запросом (`MatchScore`), без его веса:
    /// по названию или второму названию, иначе по подзаголовку; 0 — не совпал.
    private static func match(_ hit: SearchHit, _ needle: String) -> Double {
        let titles = [hit.title] + (hit.altTitle.map { [$0] } ?? [])
        let best = titles.map { titleMatch($0.folded, needle) }.max() ?? 0
        if best > 0 { return best }
        return hit.subtitle.folded.contains(needle) ? MatchScore.subtitle : 0
    }

    private static func titleMatch(_ title: String, _ needle: String) -> Double {
        if title == needle { return MatchScore.exact }
        if title.hasPrefix(needle) { return MatchScore.prefix }
        if title.split(separator: " ").contains(where: { $0 == needle }) { return MatchScore.word }
        if title.contains(needle) { return MatchScore.substring }
        return fuzzyMatch(title, needle) ?? 0
    }

    /// Нечёткое совпадение по словам — когда запрос с опечаткой или с другой
    /// транслитерацией. Поиски API сами прощают опечатки и находят верное название,
    /// а точное сравнение его не узнавало: на «чункингский» Кинопоиск отдаёт
    /// «Чунгкингский экспресс», кино получало ноль, и выше вставала музыка, где
    /// в названиях этого слова нет вовсе (жалоба пользователя 2026-10-03).
    ///
    /// Каждое слово запроса должно найти в названии похожее слово; ступень — как
    /// у точного совпадения (первое слово названия — «начало», иначе «слово»),
    /// умноженная на похожесть худшего из слов. `nil` — не похоже.
    private static func fuzzyMatch(_ title: String, _ needle: String) -> Double? {
        let titleWords = words(title)
        let queryWords = words(needle)
        guard let firstTitle = titleWords.first, let firstQuery = queryWords.first else { return nil }
        var worst = 1.0
        for query in queryWords {
            let best = titleWords.map { similarity(query, $0) }.max() ?? 0
            guard best > 0 else { return nil }
            worst = min(worst, best)
        }
        let tier = similarity(firstQuery, firstTitle) > 0 ? MatchScore.prefix : MatchScore.word
        return tier * worst
    }

    private static func words(_ text: String) -> [Substring] {
        text.split { !$0.isLetter && !$0.isNumber }
    }

    /// Похожесть слова запроса на слово названия, 0…1; 0 — не похоже.
    /// Слово названия может быть недопечатано в запросе («экспр» → «экспресс»),
    /// поэтому запрос сравнивается с началом слова той же длины ±1. Допуск —
    /// одна правка на короткое слово, две на длинное; слова короче четырёх
    /// букв — только точно: «кот» и «кит» не одно и то же.
    private static func similarity(_ query: Substring, _ word: Substring) -> Double {
        if word.hasPrefix(query) { return 1 }
        let length = query.count
        guard length >= FuzzyLimits.minLength else { return 0 }
        let allowed = length <= FuzzyLimits.shortWord ? 1 : 2
        let q = Array(query), w = Array(word)
        let distance = (max(0, length - 1)...(length + 1))
            .filter { $0 <= w.count && $0 > 0 }
            .map { editDistance(q, w[..<$0]) }
            .min() ?? .max
        guard distance <= allowed else { return 0 }
        return 1 - Double(distance) / Double(length)
    }

    private enum FuzzyLimits {
        /// Короче — только точное совпадение
        static let minLength = 4
        /// До этой длины допускается одна правка, длиннее — две
        static let shortWord = 6
    }

    /// Расстояние Левенштейна: вставки, удаления, замены по одной букве.
    private static func editDistance(_ a: [Character], _ b: ArraySlice<Character>) -> Int {
        let b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
            }
            swap(&previous, &current)
        }
        return previous[b.count]
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

extension SearchHit.Kind {
    /// Раздел выдачи, к которому относится карточка: персоны — к разделу своих работ.
    var domain: SearchState.Section.Kind {
        switch self {
        case .track, .album, .artist, .playlist: .music
        case .movie, .director: .movies
        case .book, .writer: .books
        }
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
        let picture = (artist.pictureXl ?? artist.pictureBig ?? artist.pictureMedium)?.deezerUpscaled
            .map { ArtworkSource.remote($0) }
        self.init(
            id: "artist-\(artist.id)",
            kind: .artist,
            title: artist.name,
            // Подписи нет: круглая карточка и так читается исполнителем (правка
            // пользователя 2026-10-03, прежде — «Исполнитель»).
            subtitle: "",
            artwork: picture,
            // Экран исполнителя (`PersonScreen`, 2026-10-04).
            route: .artist(EntityRef(
                id: "dz-\(artist.id)",
                title: artist.name,
                subtitle: "",
                artwork: picture ?? .asset("")
            )),
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
            authority: movie.top250 != nil ? 1 : min(1, max(0, ((movie.rating?.kp ?? 0) - 5) / 4)),
            altTitle: movie.alternativeName
        )
    }

    /// Писатель или режиссёр: одно имя, фото с Википедии; тап — экран персоны
    /// (`PersonScreen`: режиссёр ищется в Кинопоиске по имени, писатель — в Google
    /// Books). Вес высокий: совпадение запроса с именем — сильный сигнал, что секция
    /// про него.
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
            route: Self.personRoute(person),
            authority: 0.8
        )
    }

    private static func personRoute(_ person: WikipediaPeople.Person) -> EntityRoute {
        let ref = EntityRef(id: "wp-\(person.pageID)", title: person.name, subtitle: "", artwork: .remote(person.photo))
        switch person.role {
        case .director: return .director(ref)
        case .writer: return .writer(ref)
        }
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
