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

    private struct Storage: Codable {
        var movies: [KinopoiskMovie] = []
        var shown: Set<Int> = []
        var fetchedAt: Date = .distantPast
        /// Из каких подборок уже брали — чтобы пополнение не попадало в ту же.
        var sources: [String] = []
    }

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
    }

    // MARK: - Чтение

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

    /// Данные карточки тайтла, если он есть в запасе. `nil` — тайтл не из витрины
    /// (например `-debugMovieId`) либо запас записан прошлой версией, без деталей:
    /// в обоих случаях вызывающий идёт в сеть.
    ///
    /// Файл открывается при первом обращении: он на пару мегабайт, а первому кадру
    /// витрины нужен только лёгкий `movie-pool.json`.
    func details(id: Int) -> KinopoiskMovie? {
        loadedDetails()[String(id)]
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
        copy.persons = Array(persons.filter { $0.enProfession == "director" }.prefix(MovieDetails.directorLimit))
            + persons.filter { $0.enProfession == "actor" }.prefix(MovieDetails.castLimit)
        copy.similarMovies = movie.similarMovies.map { Array($0.prefix(MovieDetails.similarLimit)) }
        return copy
    }

    // MARK: - Снимок для первого кадра

    /// Синхронный снимок запаса с диска.
    ///
    /// Нужен, чтобы **первый же кадр** показал настоящий фильм. Асинхронная загрузка
    /// успевает только через полторы секунды (замер записью), и всё это время на экране
    /// висел бы мок — а моковых фильмов в витрине быть не должно вовсе. Файл локальный,
    /// чтение занимает миллисекунды, так что блокировать первый кадр им не страшно.
    nonisolated static func diskSnapshot() -> (movies: [KinopoiskMovie], shown: Set<Int>) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        guard let storage = read(from: caches.appendingPathComponent("movie-pool.json")) else {
            return ([], [])
        }
        return (storage.movies, storage.shown)
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
