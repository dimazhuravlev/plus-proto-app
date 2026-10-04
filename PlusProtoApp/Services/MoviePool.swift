import Foundation

/// Запас фильмов на диске: один запрос к Кинопоиску кормит около сотни холодных запусков.
///
/// **Зачем.** Витрина обязана показывать новые фильмы при каждом холодном запуске,
/// а квота Кинопоиска — 200 запросов в сутки. Ходить в сеть на каждый запуск нельзя:
/// одна сессия разработки — это два десятка перезапусков, и квота кончается за пару часов.
///
/// Поэтому в сеть ходим редко и помногу. Замер 2026-08-23 по `top250`: `limit=250`
/// принимается и отдаёт всю подборку разом, из 250 фильмов годных для блока «посмотреть»
/// 247, для «продолжить смотреть» — 168 (узкое место логотип: он есть у 172). Показываем
/// по одному в каждый блок за запуск, то есть одного запроса хватает на ~100 запусков.
///
/// Тем же запросом набирается и содержимое карточек: списочный роут отдаёт состав,
/// похожие и ролики наравне с `/movie/{id}`, поэтому открытие карточки тайтла с витрины
/// не стоит ни одного запроса. Запас лежит двумя файлами — лёгким витринным и
/// подробным для карточки, который читается только когда карточку открыли.
///
/// Это замена окну ротации `ShowcaseRotation` для кино: раньше случайность привязывалась
/// ко времени, чтобы повторный запуск строил тот же URL и приходил с диска URLSession.
/// Побочно это значило, что полчаса подряд витрина показывает один и тот же фильм.
/// Музыка и книги остаются на окне — у Deezer и Google Books квота не жмёт.
actor MoviePool {
    static let shared = MoviePool()

    /// Ниже этого порога годных непоказанных — идём за новой пачкой.
    /// Не ноль: пополнение асинхронное, и запас должен пережить сам заход за ним.
    private static let refillThreshold = 6

    /// Пачка протухает: подборки Кинопоиска меняются, да и показывать один и тот же
    /// набор неделями незачем. Неделя — компромисс между свежестью и квотой.
    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60

    /// Ниже этого числа непоказанных с кадром — идём за новой пачкой кадров.
    /// Показываем по одному фильму в блок, так что это запас на несколько запусков.
    private static let stillsThreshold = 4

    private struct Storage: Codable {
        var movies: [KinopoiskMovie] = []
        var shown: Set<Int> = []
        var fetchedAt: Date = .distantPast
        /// Из каких подборок уже брали — чтобы пополнение не попадало в ту же.
        var sources: [String] = []
        /// Кадры тайтлов: id → до `stillsPerTitle` горизонтальных кадров сцен.
        /// Опционально, чтобы запас, записанный до появления кадров, читался как есть.
        var stills: [String: [KinopoiskStill]]?
        /// Тайтлы, для которых кадры уже спрашивали. Без этого списка фильм, у которого
        /// кадров нет вовсе (а таких больше половины), запрашивался бы снова и снова.
        var stillsAsked: Set<Int>?
        /// По какому правилу собраны кадры. `nil` — запас старше самих правил.
        var stillsVersion: Int?
        /// По какому правилу обрезаны детали карточек. `nil` — запас старше правила.
        var detailsVersion: Int?
    }

    /// Версия правил хранения кадров. Поднимать, когда меняется то, что мы от кадров
    /// хотим, — например их число на тайтл.
    ///
    /// Без неё правка правил не доезжает до тех, у кого запас уже собран: `stillsAsked`
    /// не даёт переспросить тайтл, и он навсегда остаётся с одним кадром, собранным
    /// по-старому. На симуляторе это лечилось `-debugResetMoviePool`, но на устройстве
    /// такого флага не передашь — отсюда сброс по версии.
    private static let stillsVersion = 3

    /// Версия правил обрезки деталей. Поднимать, когда карточка начинает показывать
    /// то, чего в обрезанной записи нет.
    ///
    /// Здесь, в отличие от кадров, сбрасывается **весь** запас: детали лежат не
    /// отдельным заказом, а приезжают тем же запросом, что и сами фильмы, и добрать
    /// на диске выброшенную при записи секцию нечем. Цена — один запрос из суточных
    /// двухсот на следующем запуске.
    ///
    /// 2 — появилась карусель «Съёмочная группа» (2026-08-29): до неё в записи
    /// оставляли только режиссёров и актёров.
    private static let detailsVersion = 2

    private var storage: Storage
    /// Детали карточек, прочитанные с диска. `nil` — файл ещё не открывали.
    private var details: [String: KinopoiskMovie]?
    private let fileURL: URL
    private let detailsURL: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = caches.appendingPathComponent("movie-pool.json")
        detailsURL = caches.appendingPathComponent("movie-pool-details.json")
        storage = Self.read(from: fileURL) ?? Storage()

        // Кадры собраны по старым правилам — просим их заново. Сам пул фильмов
        // при этом цел: он к правилам кадров отношения не имеет, и терять пачку,
        // за которую уже заплачено квотой, незачем.
        if storage.stillsVersion != Self.stillsVersion {
            storage.stills = nil
            storage.stillsAsked = nil
            storage.stillsVersion = Self.stillsVersion
            save()
        }

        // Запас обрезан под прежнюю карточку — набираем его заново целиком.
        if storage.detailsVersion != Self.detailsVersion {
            storage = Storage(stillsVersion: Self.stillsVersion, detailsVersion: Self.detailsVersion)
            details = [:]
            try? FileManager.default.removeItem(at: detailsURL)
            save()
        }
    }

    // MARK: - Чтение

    /// Все годные — без оглядки на показанные. Главная Кинопоиска берёт отсюда промо:
    /// она не расходует запас витрины и ничего в нём не помечает (2026-10-04).
    func all(where isEligible: @Sendable (KinopoiskMovie) -> Bool) -> [KinopoiskMovie] {
        storage.movies.filter(isEligible)
    }

    /// Годные и ещё не показанные.
    func unseen(where isEligible: @Sendable (KinopoiskMovie) -> Bool) -> [KinopoiskMovie] {
        storage.movies.filter { !storage.shown.contains($0.id) && isEligible($0) }
    }

    /// Пора ли идти в сеть. Считается по самому дефицитному блоку, а не по всему запасу:
    /// фильмов с логотипом заметно меньше, и именно они кончаются первыми.
    func needsRefill(scarcest isEligible: @Sendable (KinopoiskMovie) -> Bool) -> Bool {
        if storage.movies.isEmpty { return true }
        if Date().timeIntervalSince(storage.fetchedAt) > Self.maxAge { return true }
        return unseen(where: isEligible).count < Self.refillThreshold
    }

    /// Подборки, из которых уже брали, — чтобы пополнение принесло другое кино.
    func usedSources() -> [String] {
        storage.sources
    }

    // MARK: - Кадры

    /// Кадры тайтла, если они есть в запасе.
    func stills(for id: Int) -> [KinopoiskStill] {
        storage.stills?[String(id)] ?? []
    }

    /// Годные непоказанные, у которых уже есть кадр. Витрина берёт фильм отсюда
    /// в первую очередь: кадр сцены живее официального `backdrop`.
    func unseenWithStill(where isEligible: @Sendable (KinopoiskMovie) -> Bool) -> [KinopoiskMovie] {
        unseen(where: isEligible).filter { !stills(for: $0.id).isEmpty }
    }

    /// Кому кадры ещё не спрашивали — очередь на догрузку.
    func awaitingStills(limit: Int, where isEligible: @Sendable (KinopoiskMovie) -> Bool) -> [Int] {
        let asked = storage.stillsAsked ?? []
        return unseen(where: isEligible)
            .lazy
            .map(\.id)
            .filter { !asked.contains($0) }
            .prefix(limit)
            .map { $0 }
    }

    /// Хватает ли запаса кадров, чтобы витрине было из чего выбирать.
    func needsStills(where isEligible: @Sendable (KinopoiskMovie) -> Bool) -> Bool {
        unseenWithStill(where: isEligible).count < Self.stillsThreshold
    }

    /// Сколько кадров держим на тайтл: один каверу и по одному каждой из четырёх
    /// видеокарточек. Больше не берём — файл запаса читается синхронно на первом
    /// кадре, и лишние ссылки в нём никому не нужны.
    static let stillsPerTitle = 5

    /// Ниже этой высоты кадр не берём: кавер и портретные карточки на ретине
    /// требуют ~1400px по высоте, и мелкий кадр растягивается в мыло — жалоба
    /// пользователя 2026-08-25 (нативные стиллы КП: замер 623×380…1200×798).
    static let minStillHeight = 720

    /// Отбор кадров тайтла из выдачи `/v1.4/image` — правила единые для запаса
    /// и добора на экране (`MovieDetailsStore`): только горизонтальные (вертикальные
    /// среди still — промо-фотосессии, а не сцены), без мелких, крупные первыми —
    /// самый большой кадр уходит каверу, — и не больше `stillsPerTitle`.
    static func pickStills(_ stills: [KinopoiskStill]) -> [KinopoiskStill] {
        stills
            .filter { !$0.isPortrait && ($0.height ?? 0) >= minStillHeight }
            .sorted { ($0.width ?? 0) * ($0.height ?? 0) > ($1.width ?? 0) * ($1.height ?? 0) }
            .prefix(stillsPerTitle)
            .map { $0 }
    }

    /// Кладёт кадры пачки. `asked` — все тайтлы, которые спрашивали, включая те,
    /// у которых кадров не нашлось: иначе они попадут в следующую догрузку снова.
    func store(stills: [KinopoiskStill], asked: [Int]) {
        var map = storage.stills ?? [:]
        for (id, group) in Dictionary(grouping: stills, by: \.movieId) {
            let picked = Self.pickStills(group)
            guard !picked.isEmpty else { continue }
            map[String(id)] = picked
        }
        storage.stills = map
        storage.stillsAsked = (storage.stillsAsked ?? []).union(asked)
        save()
    }

    /// Данные карточки тайтла, если он есть в запасе. `nil` — тайтл не из витрины
    /// (например `-debugMovieId`) либо запас записан прошлой версией, без деталей:
    /// в обоих случаях вызывающий идёт в сеть.
    ///
    /// Файл открывается при первом обращении: он на пару мегабайт, а первому кадру
    /// витрины нужен только лёгкий `movie-pool.json`.
    func details(id: Int) -> KinopoiskMovie? {
        loadedDetails()[String(id)]
    }

    /// Поиск по запасу на диске — первый источник кросс-сервисного поиска по кино.
    ///
    /// Запас и так лежит локально (около 250 фильмов), поэтому подстрочное совпадение
    /// по названию стоит ноль запросов и ноль ожидания. В сеть `SearchState` идёт
    /// только когда здесь нашлось мало: квота Кинопоиска — 200 запросов в сутки
    /// на ключ, и поиск по мере набора сжёг бы её за вечер.
    ///
    /// Сравнение без регистра и диакритики: «ежик» обязан находить «Ёжик».
    func search(_ text: String, limit: Int) -> [KinopoiskMovie] {
        let needle = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        guard !needle.isEmpty else { return [] }
        return storage.movies
            .filter { movie in
                [movie.name, movie.alternativeName]
                    .compactMap { $0 }
                    .contains { title in
                        title
                            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
                            .contains(needle)
                    }
            }
            .prefix(limit)
            .map { $0 }
    }

    func stats() -> (total: Int, shown: Int, ageDays: Int) {
        (
            storage.movies.count,
            storage.shown.count,
            Int(Date().timeIntervalSince(storage.fetchedAt) / 86_400)
        )
    }

    // MARK: - Запись

    /// Докладывает пачку в запас. Дубликаты по id отбрасываются: подборки пересекаются,
    /// и один и тот же фильм пришёл бы дважды.
    ///
    /// Запись раскладывается надвое: витринная копия без тяжёлых секций и копия для
    /// карточки, обрезанная до того, что карточка показывает.
    func store(_ movies: [KinopoiskMovie], source: String) {
        var known = Set(storage.movies.map(\.id))
        var details = loadedDetails()
        for movie in movies where !known.contains(movie.id) {
            storage.movies.append(Self.showcaseCopy(movie))
            details[String(movie.id)] = Self.detailsCopy(movie)
            known.insert(movie.id)
        }
        storage.fetchedAt = Date()
        if !storage.sources.contains(source) {
            storage.sources.append(source)
        }
        // Отметки о показе для фильмов, которых больше нет в запасе, не нужны.
        storage.shown.formIntersection(known)
        // Детали, потерявшие свой фильм, тоже не нужны.
        details = details.filter { known.contains(Int($0.key) ?? -1) }
        self.details = details
        save()
        saveDetails(details)
    }

    /// Помечает показанными. Когда показаны все — отметки сбрасываются: запас идёт
    /// на второй круг, а не заставляет лезть в сеть.
    func markShown(_ ids: [Int]) {
        storage.shown.formUnion(ids)
        if storage.shown.count >= storage.movies.count, !storage.movies.isEmpty {
            storage.shown = Set(ids)
        }
        save()
    }

    #if DEBUG
    /// Сбросить запас целиком — для проверки первого запуска.
    func reset() {
        storage = Storage()
        details = [:]
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: detailsURL)
    }
    #endif

    // MARK: - Две копии записи

    /// Копия для витрины. Состав, похожие и ролики отсюда убраны: витрине они не нужны,
    /// а этот файл читается синхронно на первом кадре — каждый лишний мегабайт в нём
    /// оплачивается задержкой запуска.
    private static func showcaseCopy(_ movie: KinopoiskMovie) -> KinopoiskMovie {
        var copy = movie
        copy.persons = nil
        copy.similarMovies = nil
        copy.videos = nil
        return copy
    }

    /// Копия для карточки: ровно те персоны и похожие тайтлы, которые карточка покажет.
    /// Обрезка не косметическая — состав приходит целиком (в среднем 74 персоны),
    /// и без неё запас на 250 фильмов весил бы 5 МБ вместо двух.
    private static func detailsCopy(_ movie: KinopoiskMovie) -> KinopoiskMovie {
        var copy = movie
        let persons = movie.persons ?? []
        // Кого показывает «Съёмочная группа», решает `MovieDetails`: отбор один и тот же
        // при записи на диск и при показе, иначе на диск попадали бы одни персоны,
        // а на экран просились другие. Режиссёры приходят оттуда же — они первые
        // в порядке специальностей, и строке «Режиссёр» в «Деталях» их хватает.
        copy.persons = Array(persons.filter { $0.enProfession == "actor" }.prefix(MovieDetails.castLimit))
            + MovieDetails.crewSelection(persons).map(\.person)
        // Похожие не режутся (правка 2026-08-25): секция показывает все. Вес терпимый —
        // главную тяжесть записи давали персоны, а не похожие.
        return copy
    }

    // MARK: - Снимок для первого кадра

    /// Синхронный снимок запаса с диска.
    ///
    /// Нужен, чтобы **первый же кадр** показал настоящий фильм. Асинхронная загрузка
    /// успевает только через полторы секунды (замер записью), и всё это время на экране
    /// висел бы мок — а моковых фильмов в витрине быть не должно вовсе. Файл локальный,
    /// чтение занимает миллисекунды, так что блокировать первый кадр им не страшно.
    nonisolated static func diskSnapshot() -> (
        movies: [KinopoiskMovie],
        shown: Set<Int>,
        stills: [String: [KinopoiskStill]]
    ) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        guard let storage = read(from: caches.appendingPathComponent("movie-pool.json")) else {
            return ([], [], [:])
        }
        return (storage.movies, storage.shown, storage.stills ?? [:])
    }

    // MARK: - Диск

    private static func read(from url: URL) -> Storage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Storage.self, from: data)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(storage) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    /// Детали с диска, единожды за сессию. Ключ словаря — id строкой: числовые ключи
    /// `JSONEncoder` разворачивает в плоский массив, а файл хочется читать глазами.
    private func loadedDetails() -> [String: KinopoiskMovie] {
        if let details { return details }
        let loaded = (try? Data(contentsOf: detailsURL))
            .flatMap { try? JSONDecoder().decode([String: KinopoiskMovie].self, from: $0) } ?? [:]
        details = loaded
        return loaded
    }

    private func saveDetails(_ details: [String: KinopoiskMovie]) {
        guard let data = try? JSONEncoder().encode(details) else { return }
        try? data.write(to: detailsURL, options: .atomic)
    }
}
