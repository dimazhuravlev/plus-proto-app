import Foundation

/// Главная Кинопоиска — промоблок и подборки (макет `2269:16939`, задача пользователя
/// 2026-10-04). «Смотреть дальше» здесь не живёт: это история киноплеера
/// (`ActionBarState.watchHistory`), её экран читает сам.
///
/// Живёт в корне приложения, как каталог витрины: экран таба размонтируется на каждом
/// переключении, а лента должна собраться один раз за процесс.
///
/// **Квота.** Промо — из дискового запаса витрины (`MoviePool`): ни одного запроса.
/// Подборки — по запросу на каждую, и только на первом запуске: сервис ходит
/// с `returnCacheDataElseLoad`, повторные запуски берут ответ с диска `URLCache`.
@MainActor
@Observable
final class CinemaCatalog {
    /// Слайд промоблока.
    struct Promo: Identifiable, Equatable {
        let id: String
        let title: String
        /// Короткое описание под логотипом — редакционная строка Кинопоиска.
        let lead: String
        /// Кадр обложки — тот же, что встанет в кавер карточки тайтла: зум переходит
        /// из картинки в ту же картинку.
        let cover: ArtworkSource
        /// PNG-логотип. Нет — название текстом.
        let logo: ArtworkSource?
        let route: EntityRoute
        /// Что запускает «Смотреть».
        let movie: MovieInProgress
        /// Постер и год — для закладки «Позже»: в коллекции «Моё» тайтл стоит постером.
        var poster: ArtworkSource? = nil
        var year: String? = nil
    }

    /// Карточка подборки — постер и название.
    struct Title: Identifiable, Equatable {
        let id: String
        let title: String
        let poster: ArtworkSource?
        let route: EntityRoute
    }

    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let titles: [Title]
    }

    private(set) var promos: [Promo] = []
    private(set) var rows: [Row] = []
    /// Слайд промо, на котором остановились, — на всю сессию: экран таба
    /// пересоздаётся на каждом переключении, а позиция должна пережить возврат.
    var promoIndex = 0
    /// Данные собраны — скелетоны сменяются лентой.
    private(set) var isLoaded = false
    private var didStart = false

    /// Подборки Кинопоиска под карусели макета: заголовки — макета, содержимое — живое.
    /// «Авторское кино» — лауреаты Каннского фестиваля, «Документальное» — полсотни
    /// главных документальных фильмов, «Смотреть на выходных» — самые кассовые
    /// в России (замер подборок 2026-10-04: постеры есть почти у всех).
    ///
    /// Ещё три — «Оскароносцы» (лауреаты за лучший фильм), «Фантастика» (сотня лучших
    /// научно-фантастических) и «Мультфильмы» (лучшие анимационные по версии Time Out):
    /// задача пользователя тем же днём — «+3 карусели с разными названиями».
    private static let rowSpecs: [(slug: String, title: String)] = [
        ("cannes-golden-palm", "Авторское кино"),
        ("top_50_documentary", "Документальное"),
        ("box-russia-dollar", "Смотреть на выходных"),
        ("oscar-best-film", "Оскароносцы"),
        ("top_100_scifi_by_total_scifi_online", "Фантастика"),
        ("top_100_animation_by_time_out", "Мультфильмы"),
    ]
    static let promoLimit = 6
    private static let rowLimit = 15
    /// Берём с запасом: часть отсеется — без постера или уже стоит выше, а из остатка
    /// карусель каждый холодный запуск набирает свои 15 (`rowPool`).
    private static let rowFetchLimit = 60
    /// Из скольких самых заметных тайтлов подборки (по голосам) выбирается карусель:
    /// свежий набор на каждый запуск, но без глубоких задворков списка.
    private static let rowPool = 45
    /// Кадра на логотип хватает с запасом: PNG ложится в бокс 280×72 на ×3.
    private static let logoPixelWidth = 840

    /// Собрать ленту. Один раз за процесс — повторное появление таба не трогает сеть.
    func loadIfNeeded() async {
        guard !didStart else { return }
        didStart = true

        guard Self.isLive else {
            promos = CinemaMocks.promos
            rows = CinemaMocks.rows
            isLoaded = true
            return
        }

        let fetched = await Self.fetchRows()
        // Каждый холодный запуск — свой набор: и промо, и подборки (правка пользователя
        // 2026-10-04: лента повторялась из запуска в запуск). Зерно случайное на запуск,
        // `-debugFrozenFeed` его фиксирует.
        var rng = ShowcaseRotation.generator(salt: ShowcaseRotation.Salt.cinema)
        // Промо — из запаса витрины и из самих подборок вперемешку: одного запаса
        // мало, слайды повторялись. Первый запуск без кэша — только подборки.
        var candidates: [KinopoiskMovie] = []
        var candidateIDs = Set<Int>()
        for movie in await MoviePool.shared.all(where: Self.isPromoEligible)
            + fetched.values.joined().filter(Self.isPromoEligible)
        where candidateIDs.insert(movie.id).inserted {
            candidates.append(movie)
        }
        // Обложка слайда — кадр из самого фильма, тот же, что встанет в кавер карточки
        // тайтла (правка пользователя 2026-10-04: не постер и не официальная картинка).
        // Кадры — из запаса: карточка тайтла из запаса берёт те же самые, и первый кадр
        // совпадает. Тайтл без кадров в промо не попадает.
        var builtPromos: [Promo] = []
        for movie in candidates.shuffled(using: &rng) {
            guard builtPromos.count < Self.promoLimit else { break }
            let stills = await MoviePool.shared.stills(for: movie.id)
            guard stills.first?.url(size: .huge) != nil else { continue }
            builtPromos.append(Self.promo(movie, stills: stills))
        }

        // Тайтл — один раз на экран: промо выше подборок, подборки — по порядку.
        var used = Set(builtPromos.compactMap { Int($0.id.dropFirst("kp-".count)) })
        var builtRows: [Row] = []
        for spec in Self.rowSpecs {
            let movies = (fetched[spec.slug] ?? [])
                .filter { $0.poster?.url != nil && !used.contains($0.id) }
                .sorted { ($0.votes?.kp ?? 0) > ($1.votes?.kp ?? 0) }
                .prefix(Self.rowPool)
                .shuffled(using: &rng)
                .prefix(Self.rowLimit)
            used.formUnion(movies.map(\.id))
            guard !movies.isEmpty else { continue }
            builtRows.append(Row(id: spec.slug, title: spec.title, titles: movies.map(Self.title)))
        }

        MovieDetailsStore.remember(Array(fetched.values.joined()))
        // Первый слайд — с картинками: обложка и логотип ждутся (не дольше потолка),
        // иначе лента встала бы пустой рамкой и обложка проявлялась бы на глазах.
        // Остальное догружается в фоне.
        if let first = builtPromos.first {
            await Self.prewarm([first.cover] + [first.logo].compactMap { $0 })
        }
        ArtworkLoader.shared.preload(
            builtPromos.dropFirst().prefix(2).flatMap { [$0.cover] + [$0.logo].compactMap { $0 } }
                + builtRows.flatMap { $0.titles.prefix(4).compactMap(\.poster) }
        )

        promos = builtPromos.isEmpty ? CinemaMocks.promos : builtPromos
        rows = builtRows
        isLoaded = true
    }

    // MARK: - Сеть

    /// Сколько первый слайд ждёт свои картинки, прежде чем лента встанет без них.
    private static let prewarmCeiling: Duration = .milliseconds(1500)

    /// Прогрев с потолком: медленная сеть не держит скелетон дольше `prewarmCeiling` —
    /// не доехавшее проявится на месте само.
    private static func prewarm(_ sources: [ArtworkSource]) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await ArtworkLoader.shared.prewarm(sources) }
            group.addTask { try? await Task.sleep(for: prewarmCeiling) }
            await group.next()
            group.cancelAll()
        }
    }

    /// Подборки — параллельно. Упавшая подборка просто не встаёт: карусели без неё.
    private static func fetchRows() async -> [String: [KinopoiskMovie]] {
        let slugs = rowSpecs.map(\.slug)
        let limit = rowFetchLimit
        return await withTaskGroup(of: (String, [KinopoiskMovie]).self) { group in
            for slug in slugs {
                group.addTask {
                    let movies = (try? await KinopoiskService.shared.movies(list: slug, limit: limit)) ?? []
                    return (slug, movies)
                }
            }
            var result: [String: [KinopoiskMovie]] = [:]
            for await (slug, movies) in group {
                result[slug] = movies
            }
            return result
        }
    }

    /// Идти ли в сеть — те же правила, что у витрины: без ключа Кинопоиска и под
    /// `-debugMockFeed` лента на моках.
    private static var isLive: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugMockFeed") { return false }
        #endif
        return APIKeysCheck.isKinopoiskConfigured
    }

    // MARK: - Разбор

    /// Промо держится на логотипе и описании: без них слайд немой. Кадр из фильма
    /// проверяется отдельно — по запасу кадров (`loadIfNeeded`).
    nonisolated private static func isPromoEligible(_ movie: KinopoiskMovie) -> Bool {
        movie.logo?.url != nil
            && !(movie.shortDescription ?? "").isEmpty
    }

    private static func promo(_ movie: KinopoiskMovie, stills: [KinopoiskStill]) -> Promo {
        let details = MovieDetails(movie: movie, stills: stills)
        let cover = details.backdrop.map { ArtworkSource.remote($0) } ?? .asset("mockVideoStill")
        let logo = movie.logo?.logoURL(width: logoPixelWidth).map { ArtworkSource.remote($0) }
        return Promo(
            id: "kp-\(movie.id)",
            title: details.title,
            lead: details.lead,
            cover: cover,
            logo: logo,
            route: .movie(EntityRef(id: "kp-\(movie.id)", title: details.title, subtitle: "", artwork: cover)),
            movie: MovieInProgress(
                id: "kp-\(movie.id)",
                still: cover,
                title: details.title,
                subtitle: details.playerSubtitle,
                runtime: details.runtime
            ),
            poster: details.poster.map { ArtworkSource.remote($0) },
            year: details.year
        )
    }

    /// Постер — через тот же прокси tmdb, что в выдаче поиска: часть постеров
    /// Кинопоиск отдаёт ссылкой на заблокированный хост.
    private static func title(_ movie: KinopoiskMovie) -> Title {
        let raw = movie.poster?.url(size: .medium)
        let poster = (raw.flatMap { TMDBImageProxy.rewrite($0, width: 600) } ?? raw).map { ArtworkSource.remote($0) }
        return Title(
            id: "kp-\(movie.id)",
            title: movie.displayTitle,
            poster: poster,
            route: .movie(EntityRef(
                id: "kp-\(movie.id)",
                title: movie.displayTitle,
                subtitle: "",
                artwork: poster ?? .asset("mockMoviePoster")
            ))
        )
    }
}

// MARK: - Моки

/// Лента без сети — свежий клон без ключей и `-debugMockFeed`.
enum CinemaMocks {
    static let promos: [CinemaCatalog.Promo] = [
        promo(
            id: "mock-cinema-yura",
            title: "Здесь был Юра",
            lead: "Двое братьев и один необычный день, который перевернёт их жизнь",
            cover: .asset("mockVideoStill"),
            logo: .asset("mockLogoYura")
        ),
        promo(
            id: "mock-cinema-perfect-days",
            title: "Идеальные дни",
            lead: "Обыкновенный уборщик ищет красоту в каждом мгновении",
            cover: .asset("mockChipMovieStill"),
            logo: nil
        ),
    ]

    static let rows: [CinemaCatalog.Row] = [
        row("mock-auteur", "Авторское кино", ["Идеальные дни", "Анатомия падения", "Паразиты", "Анора", "Титан"]),
        row("mock-docs", "Документальное", ["Человек на проволоке", "Выход через сувенирную лавку", "Корпорация «Еда»", "Вальс с Баширом"]),
        row("mock-weekend", "Смотреть на выходных", ["Летучий корабль", "Сто лет тому вперёд", "Батя", "Пророк"]),
        row("mock-oscar", "Оскароносцы", ["Титаник", "Форрест Гамп", "Гладиатор", "Оппенгеймер"]),
        row("mock-scifi", "Фантастика", ["Интерстеллар", "Матрица", "Начало", "Бегущий по лезвию"]),
        row("mock-animation", "Мультфильмы", ["Унесённые призраками", "ВАЛЛ-И", "Головоломка", "Коко"]),
    ]

    private static func promo(
        id: String,
        title: String,
        lead: String,
        cover: ArtworkSource,
        logo: ArtworkSource?
    ) -> CinemaCatalog.Promo {
        CinemaCatalog.Promo(
            id: id,
            title: title,
            lead: lead,
            cover: cover,
            logo: logo,
            route: .movie(EntityRef(id: id, title: title, subtitle: "", artwork: cover)),
            movie: MovieInProgress(id: id, still: cover, title: title)
        )
    }

    private static func row(_ id: String, _ title: String, _ titles: [String]) -> CinemaCatalog.Row {
        CinemaCatalog.Row(
            id: id,
            title: title,
            titles: titles.enumerated().map { index, name in
                let titleID = "\(id)-\(index)"
                return CinemaCatalog.Title(
                    id: titleID,
                    title: name,
                    poster: .asset("mockMoviePoster"),
                    route: .movie(EntityRef(id: titleID, title: name, subtitle: "", artwork: .asset("mockMoviePoster")))
                )
            }
        )
    }
}
