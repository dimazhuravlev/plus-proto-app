import SwiftUI

/// Подборка Таскалки — музыка, кино и книги одного настроения (`TaskalkaMood`).
///
/// Собирается по требованию — когда палец задержался на настроении или отпущен на нём —
/// и живёт до конца процесса: то же настроение второй раз встаёт сразу и той же подборкой.
///
/// **Квоты.** Кино — без сети вовсе: из того, что уже лежит на диске и в памяти (запас
/// витрины `MoviePool` и подборки главной Кинопоиска), по жанрам настроения. Книги — запрос
/// к Google Books на автора (три на настроение, дальше с диска `URLCache`). Треки — поиск
/// Deezer по исполнителю и названию, у него квоты нет.
@MainActor
@Observable
final class TaskalkaCatalog {
    static let shared = TaskalkaCatalog()

    /// `nil` у раздела — ещё собирается (на экране скелетон), пустой массив — нечего
    /// показать (раздела нет).
    struct Selection: Equatable {
        var tracks: [MusicNowPlaying]?
        var movies: [CinemaCatalog.Title]?
        var books: [BooksHomeCatalog.Book]?

        var isEmpty: Bool {
            tracks?.isEmpty == true && movies?.isEmpty == true && books?.isEmpty == true
        }
    }

    private(set) var selections: [TaskalkaMood.ID: Selection] = [:]

    private enum Limits {
        /// Карточек в карусели — как у витринных каруселей.
        static let cards = 12
        /// Из скольких лучших по жанру выбирается карусель: свежий набор на процесс,
        /// но без задворков.
        static let moviePool = 30
        /// Треков в «Открытом плейлисте» — три колонки по три.
        static let tracks = 9
        /// Сколько ждём раздел, прежде чем признать его пустым: без сети скелетон
        /// не должен висеть минуту таймаута `URLSession`.
        static let ceiling: Duration = .seconds(10)
        /// Книгам — дольше: Google Books пускает раз в секунду, и сразу после запуска
        /// перед нами в очереди дюжина запросов главной Книг.
        static let booksCeiling: Duration = .seconds(20)
    }

    /// Разделы, которые не уложились в потолок: следующий выбор того же настроения
    /// собирает их заново, а не показывает пустоту до конца процесса.
    private var timedOut: Set<TaskalkaMood.ID> = []

    private init() {}

    func selection(for mood: TaskalkaMood) -> Selection? {
        selections[mood.id]
    }

    /// Начать сборку настроения. Повторный вызов ничего не делает — кроме разделов,
    /// не уложившихся в потолок в прошлый раз: их скелетоны встают снова.
    func prepare(_ mood: TaskalkaMood) {
        guard selections[mood.id] == nil else {
            guard timedOut.remove(mood.id) != nil else { return }
            if selections[mood.id]?.tracks?.isEmpty == true {
                selections[mood.id]?.tracks = nil
                Task { await loadTracks(mood) }
            }
            if selections[mood.id]?.books?.isEmpty == true {
                selections[mood.id]?.books = nil
                Task { await loadBooks(mood) }
            }
            return
        }
        selections[mood.id] = Selection()
        Task { await loadMovies(mood) }
        Task { await loadTracks(mood) }
        Task { await loadBooks(mood) }
    }

    // MARK: - Кино

    private func loadMovies(_ mood: TaskalkaMood) async {
        var seen = Set<Int>()
        let candidates = (await MoviePool.shared.all { $0.poster?.url != nil }
            + MovieDetailsStore.knownMovies.filter { $0.poster?.url != nil })
            .filter { seen.insert($0.id).inserted }
        let picked = Self.pickMovies(candidates, for: mood)
        ArtworkLoader.shared.preload(picked.prefix(4).compactMap(\.poster))
        selections[mood.id]?.movies = picked
    }

    /// Вес фильма для настроения; `nil` — фильм ему не подходит.
    ///
    /// Жанр с запретами — у всех. Темы (`keywords`, «про котиков»), страна («по-французски»)
    /// и год («старого доброго») — обязательные условия: жанром их не выразить, и фильм
    /// без кота в описании под «про котиков» был бы враньём. Вес жанра у таких только
    /// поднимает фильм выше.
    private static func score(_ movie: KinopoiskMovie, _ mood: TaskalkaMood) -> Double? {
        let genres = Set((movie.genres ?? []).map { $0.name.lowercased() })
        guard genres.isDisjoint(with: mood.vetoGenres) else { return nil }
        let score = genres.reduce(0) { $0 + (mood.genres[$1] ?? 0) }
        var isConditional = false
        if let maxYear = mood.maxYear {
            guard let year = movie.year, year <= maxYear else { return nil }
            isConditional = true
        }
        if !mood.countries.isEmpty {
            let countries = Set((movie.countries ?? []).map(\.name))
            guard !countries.isDisjoint(with: mood.countries) else { return nil }
            isConditional = true
        }
        if let pattern = pattern(for: mood) {
            let text = [movie.name, movie.alternativeName, movie.shortDescription, movie.description]
                .compactMap { $0 }
                .joined(separator: " ")
            guard pattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil else { return nil }
            isConditional = true
        }
        if isConditional { return 1 + score }
        return score > 0 ? score : nil
    }

    /// Регулярки тем — один разбор на процесс.
    private static var patterns: [TaskalkaMood.ID: NSRegularExpression] = [:]

    private static func pattern(for mood: TaskalkaMood) -> NSRegularExpression? {
        guard let keywords = mood.keywords else { return nil }
        if let cached = patterns[mood.id] { return cached }
        let compiled = try? NSRegularExpression(pattern: keywords, options: [.caseInsensitive])
        patterns[mood.id] = compiled
        return compiled
    }

    private static func pickMovies(_ movies: [KinopoiskMovie], for mood: TaskalkaMood) -> [CinemaCatalog.Title] {
        let rating = { (movie: KinopoiskMovie) in movie.rating?.kp ?? 0 }
        let picked: [KinopoiskMovie]
        if mood.genres.isEmpty {
            // Середина поля — лучшее из каждого жанра по кругу: «всего понемногу».
            var byGenre: [String: [KinopoiskMovie]] = [:]
            for movie in movies.sorted(by: { rating($0) > rating($1) }) {
                guard let genre = movie.genres?.first?.name else { continue }
                byGenre[genre, default: []].append(movie)
            }
            let rows = byGenre.values.map { Array($0.prefix(3).shuffled()) }.shuffled()
            picked = TopPicks.roundRobin(rows, limit: Limits.cards) { "\($0.id)" }
        } else {
            // Жанр важнее рейтинга: вес жанра — целые, рейтинг — десятые.
            picked = movies
                .compactMap { movie in score(movie, mood).map { (movie, $0 * 10 + rating(movie)) } }
                .sorted { $0.1 > $1.1 }
                .prefix(Limits.moviePool)
                .map(\.0)
                .shuffled()
                .prefix(Limits.cards)
                .map { $0 }
        }
        return picked.map(CinemaCatalog.title)
    }

    // MARK: - Музыка

    private func loadTracks(_ mood: TaskalkaMood) async {
        let specs = mood.tracks
        let moodID = mood.id
        let found: [Int: MusicNowPlaying]? = await Self.withCeiling(Limits.ceiling) {
            await withTaskGroup(of: (Int, MusicNowPlaying?).self) { group in
                for (index, spec) in specs.enumerated() {
                    group.addTask { (index, await Self.track(spec, mood: moodID)) }
                }
                var result: [Int: MusicNowPlaying] = [:]
                for await (index, track) in group { result[index] = track }
                return result
            }
        }
        if found == nil { timedOut.insert(mood.id) }
        // Порядок — редакционный, как в списке настроения.
        let tracks: [MusicNowPlaying] = Array(specs.indices.compactMap { found?[$0] }.prefix(Limits.tracks))
        ArtworkLoader.shared.preload(tracks.prefix(6).map(\.cover))
        selections[mood.id]?.tracks = tracks
    }

    /// Трек по исполнителю и названию — простым поиском «исполнитель название».
    /// Расширенный синтаксис Deezer (`artist:"…" track:"…"`) из нашего региона отдаёт
    /// мусор: на Coldplay — французский шансон (замер 2026-10-31). Исполнитель обязан
    /// совпасть — поиск находит каверы и «инструментальные версии» сборников; не нашёлся
    /// автор — трека нет, чужим его не подменяем.
    private nonisolated static func track(_ spec: TaskalkaTrackSpec, mood: TaskalkaMood.ID) async -> MusicNowPlaying? {
        let ownHits = { (hits: [DeezerTrackHit]) in
            hits.filter { hit in
                let name = hit.artist?.name ?? ""
                return name.localizedCaseInsensitiveContains(spec.artist) || spec.artist.localizedCaseInsensitiveContains(name) && !name.isEmpty
            }
        }
        guard let hits = try? await DeezerService.shared.searchTracks(query: "\(spec.artist) \(spec.title)", limit: 10),
              let hit = ownHits(hits).first(where: { $0.title.localizedCaseInsensitiveContains(spec.title) }) ?? ownHits(hits).first,
              let album = hit.album,
              let cover = (album.coverXl ?? album.coverBig).flatMap(URL.init(string:))
        else { return nil }
        return MusicNowPlaying(
            // Хвост `-t<трек>` — по нему звук находит превью (`MusicAudio`).
            id: "taskalka-\(mood.rawValue)-\(album.id)-t\(hit.id)",
            cover: .remote(cover),
            title: hit.title,
            artist: hit.artist?.name ?? spec.artist,
            album: album.title,
            isExplicit: hit.explicitLyrics
        )
    }

    // MARK: - Книги

    private func loadBooks(_ mood: TaskalkaMood) async {
        let authors = mood.authors
        let fetched = await Self.withCeiling(Limits.booksCeiling) { await Self.volumes(by: authors) }
        if fetched == nil { timedOut.insert(mood.id) }
        let volumes = fetched ?? []
        // Пропорции обложек — по самим картинкам (свой потолок у `aspects`): лента встаёт
        // книгами нужной ширины и уже с обложками в кэше.
        let aspects = await BooksHomeCatalog.aspects(of: volumes)
        selections[mood.id]?.books = volumes.map { BooksHomeCatalog.book($0, aspects) }
    }

    /// Книги авторов настроения вперемешку — по книге от каждого по очереди. Отбор — как
    /// у главной Книг: русское издание, автор по фамилии, скан обложки, не пересказ.
    private nonisolated static func volumes(by authors: [TaskalkaAuthor]) async -> [GoogleBook] {
        var perAuthor: [[GoogleBook]] = []
        for author in authors {
            let volumes = (try? await BooksService.shared.search(author.query, limit: 20)) ?? []
            var titles = Set<String>()
            perAuthor.append(volumes.filter { volume in
                guard volume.volumeInfo.language == "ru",
                      (volume.volumeInfo.authors ?? []).contains(where: { $0.localizedCaseInsensitiveContains(author.surname) }),
                      !volume.title.isEmpty,
                      volume.coverURL != nil,
                      !ShowcaseSeeds.bookSummaryMarkers.contains(where: { volume.title.lowercased().contains($0) })
                else { return false }
                return titles.insert(volume.title.lowercased()).inserted
            }.shuffled())
        }
        return TopPicks.roundRobin(perAuthor, limit: Limits.cards, key: \.title)
    }

    // MARK: - Потолок ожидания

    /// Работа с потолком: не уложилась — `nil`.
    private static func withCeiling<T: Sendable>(
        _ ceiling: Duration,
        _ work: @escaping @Sendable () async -> T
    ) async -> T? {
        await withTaskGroup(of: T?.self) { group in
            group.addTask { await work() }
            group.addTask {
                try? await Task.sleep(for: ceiling)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }
}
