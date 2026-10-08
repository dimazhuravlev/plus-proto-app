import SwiftUI

/// Сборка витрины из живых данных трёх сервисов.
///
/// Стартовое состояние — моковая лента `ShowcaseFeed.personal`: она же служит фолбэком.
/// Экран поэтому рисуется сразу и никогда не бывает пустым, а живые блоки въезжают
/// по мере ответов. Домены грузятся независимо и публикуются по отдельности: ждать
/// самый медленный сервис ради одного апдейта незачем, а слоты витрины фиксированы —
/// подмена блока не двигает соседей.
///
/// Аналог `ContentCurationManager` из MusicPlayer, но без стадийной догрузки:
/// витрине нужен ровно один комплект блоков, а не бесконечная лента.
@MainActor
@Observable
final class ShowcaseCatalog {
    private(set) var feed: ShowcaseFeed = .personal
    private(set) var isLoading = false
    /// Что не доехало. Не ошибка экрана: блок просто остаётся моковым.
    private(set) var failures: [String] = []

    private var hasLoaded = false

    /// Фильмы, выбранные синхронно из запаса на первом кадре. Асинхронный проход
    /// потом не выбирает заново, а лишь добирает акцентный цвет подписи — иначе
    /// фильм на экране успевал бы смениться на глазах.
    private var pickedFeatured: KinopoiskMovie?
    private var pickedWatching: KinopoiskMovie?
    /// Горизонтальный кадр выбранного тайтла «продолжить смотреть», если он есть.
    private var watchingStill: KinopoiskStill?
    /// Кадр сцены показанного фильма — для чипа киноплеера в action bar.
    private var featuredStill: KinopoiskStill?

    /// Заготовленные замены блоков по ✕ — по верху слота: следующий айтем каждой
    /// карточки готовится заранее, вместе с картинками, и смена укладывается в 400 мс
    /// ухода старого (`ShowcaseFeedbackPair`).
    private var upcoming: [CGFloat: Task<Replacement?, Never>] = [:]

    /// Промо-слайдер — свой набор по видам, на экране вперемешку (`publishPromo`):
    /// не те фильмы, альбомы и книги, что в карточках ленты (задача пользователя
    /// 2026-10-08). Пустой вид — фолбэк моковой ленты.
    private var promoMovies: [MovieBlock] = []
    private var promoAlbums: [AlbumBlock] = []
    private var promoBooks: [BookBlock] = []
    /// Заготовленные замены айтемов промо по ✕ — по месту в слайдере.
    private var upcomingPromo: [Int: Task<Replacement?, Never>] = [:]
    /// Айтем промо на месте — помнится на сессию, как у промо Кинопоиска и Книг.
    var promoIndex = 0

    /// Витрина стартует с настоящими фильмами, а не с моковыми: запас лежит на диске
    /// и читается за миллисекунды. Мок остаётся только на самый первый запуск после
    /// установки, когда запас ещё пуст, — и тут же сменяется живыми данными.
    /// Витрина стартует с настоящими фильмами, а не с моковыми: запас лежит на диске
    /// и читается за миллисекунды.
    ///
    /// **Только собственные поля, никаких общих эффектов.** Выражение по умолчанию
    /// у `@State` вычисляется на каждом пересоздании вью, то есть этот `init` работает
    /// не один раз, а на каждом проходе. Пока он трогал общий `ArtworkLoader`, SwiftUI
    /// уходил в бесконечный круг перерисовки: экран оставался белым, а разбор
    /// аргументов запуска успевал отработать четверть миллиона раз.
    init() {
        var rng = ShowcaseRotation.movieGenerator()
        let snapshot = MoviePool.diskSnapshot()
        let unseen = snapshot.movies.filter { !snapshot.shown.contains($0.id) }
        // Тот же приём, что и в асинхронном проходе: сперва тайтлы, у которых уже
        // есть кадр, и только если таких нет — любые годные.
        func withStill(_ movies: [KinopoiskMovie]) -> [KinopoiskMovie] {
            movies.filter { !(snapshot.stills[String($0.id)] ?? []).isEmpty }
        }

        let featurable = unseen.filter(Self.isFeaturable)
        pickedFeatured = withStill(featurable).randomElement(using: &rng)
            ?? featurable.randomElement(using: &rng)
        featuredStill = pickedFeatured.flatMap { snapshot.stills[String($0.id)] }?.first

        let watchable = unseen.filter { Self.isWatchable($0) && $0.id != pickedFeatured?.id }
        pickedWatching = withStill(watchable).randomElement(using: &rng)
            ?? watchable.randomElement(using: &rng)
        watchingStill = pickedWatching.flatMap { snapshot.stills[String($0.id)] }?.first

        applyMovieBlocks(featuredTint: nil, rng: &rng, preload: false)

        // Промо — ещё фильмы из того же запаса, не те, что в ленте.
        let promoPool = featurable.filter { $0.id != pickedFeatured?.id && $0.id != pickedWatching?.id }
        var promoPicked = Array(withStill(promoPool).shuffled(using: &rng).prefix(ShowcaseSeeds.promoPerKind))
        for movie in promoPool.shuffled(using: &rng)
        where promoPicked.count < ShowcaseSeeds.promoPerKind && !promoPicked.contains(where: { $0.id == movie.id }) {
            promoPicked.append(movie)
        }
        promoMovies = promoPicked.compactMap { movie in
            Self.promoMovieBlock(movie, still: snapshot.stills[String(movie.id)]?.first)
        }
        publishPromo(preload: false)
    }

    /// Один заход за сессию. Повторный сбор — `reload()`.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    func reload() async {
        isLoading = true
        failures = []

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugResetMoviePool") {
            await MoviePool.shared.reset()
        }
        #endif

        // Три независимых заказа: домен, который упал или отвечает медленно,
        // не задерживает остальные.
        async let movies: Void = loadMovies()
        async let music: Void = loadMusic()
        async let books: Void = loadBooks()
        _ = await (movies, music, books)

        isLoading = false
        prefetchReplacements()
    }

    // MARK: - Кино

    /// Кино берётся из запаса на диске (`MoviePool`), а не из сети на каждый запуск.
    ///
    /// Требование — новые фильмы при **каждом холодном запуске**. В лоб это значит запрос
    /// на запуск, а квота Кинопоиска 200 в сутки: одна сессия разработки — два десятка
    /// перезапусков. Поэтому в сеть ходим редко и помногу: `limit=250` отдаёт подборку
    /// целиком, а показываем по одному фильму в блок. Одного запроса хватает примерно
    /// на сотню запусков, и каждый из них показывает то, чего ещё не показывали.
    ///
    /// Окна ротации у кино поэтому больше нет: выбор честно случайный на каждый запуск.
    /// Для воспроизводимых скриншотов есть `-debugFrozenFeed` — он фиксирует зерно.
    private func loadMovies() async {
        var rng = ShowcaseRotation.movieGenerator()

        // Считаем по «продолжить смотреть»: логотип есть далеко не у всех, и годные
        // для этого блока кончаются первыми.
        if await MoviePool.shared.needsRefill(scarcest: Self.isWatchable) {
            await refillMoviePool(using: &rng)
            // Кадры — до выбора: иначе первый запуск после установки покажет фильм
            // без кадра, хотя кадр к тому моменту уже приехал.
            await loadStills()
            pickedFeatured = await Self.pick(where: Self.isFeaturable, using: &rng)
            pickedWatching = await Self.pick(
                where: Self.isWatchable,
                excluding: pickedFeatured?.id,
                using: &rng
            )
            if let id = pickedFeatured?.id {
                featuredStill = await MoviePool.shared.stills(for: id).first
            }
            if let id = pickedWatching?.id {
                watchingStill = await MoviePool.shared.stills(for: id).first
            }
            promoMovies = await pickPromoMovies(using: &rng)
        } else {
            // Запас кадров тратится по фильму за запуск — доливаем его заранее,
            // на будущие запуски. Выбор на экране при этом не трогаем: фильм уже
            // показан, и подменять его на глазах нельзя.
            await loadStills()
        }

        guard let featured = pickedFeatured else {
            failures.append("кино: в запасе нет фильма с постером и описанием")
            return
        }
        if pickedWatching == nil {
            failures.append("продолжить смотреть: в запасе нет кадра с логотипом")
        }

        // Акцент подписи считается по постеру — это загрузка картинки, синхронно
        // на первом кадре её не получить.
        var tint: Color?
        if let poster = featured.poster?.url(size: .medium) {
            tint = await ArtworkLoader.shared.accent(for: poster)
        }
        applyMovieBlocks(featuredTint: tint, rng: &rng)
        publishPromo()

        let promoIDs = promoMovies.compactMap { Int($0.id.dropFirst("kp-".count)) }
        await MoviePool.shared.markShown([featured.id, pickedWatching?.id].compactMap { $0 } + promoIDs)

        // Греем кэш под будущие запуски: фильм каждый раз новый, и без прогрева его
        // постер каждый раз качается с нуля на глазах у пользователя.
        await preloadNextMovies()
    }

    /// Кладёт оба киноблока по уже выбранным фильмам. Отдельно от загрузки, потому что
    /// вызывается дважды: синхронно на первом кадре и после подсчёта акцента.
    private func applyMovieBlocks(featuredTint: Color?, rng: inout SeededGenerator, preload: Bool = true) {
        if let movie = pickedFeatured, let poster = movie.poster?.url(size: .medium) {
            apply(.movie(MovieBlock(
                id: "kp-\(movie.id)",
                title: movie.displayTitle,
                // Без бандленного фолбэка, по той же причине, что и у логотипа ниже:
                // моковый постер чужого фильма врёт о контенте, а фильм в витрине
                // теперь каждый запуск новый — врал бы он каждый раз.
                poster: .remote(poster),
                // Чипу киноплеера нужен горизонтальный кадр, а не портретный постер:
                // кадр сцены → официальный `backdrop` → постер как крайний случай.
                // Размер `wide`, как у блока «продолжить смотреть»: пресет `frame`
                // живёт только на `get-ott`, кадры отвечают на него 404.
                still: .remote(
                    featuredStill?.url(size: .wide)
                        ?? movie.backdrop?.url(size: .frame)
                        ?? poster
                ),
                // Подпись `2004:10769` рассчитана на 3 строки по 182.68pt;
                // `shortDescription` бывает и вдвое длиннее — режем.
                caption: (movie.shortDescription ?? "").showcaseCaption(maxCharacters: 88),
                captionTint: featuredTint ?? Self.mockMovieTint
            )), preload: preload)
        }

        if
            let watching = pickedWatching,
            // Кадр из `/v1.4/image` предпочтительнее `backdrop`: это живой кадр сцены,
            // а не одна официальная картинка на весь тайтл. Кадра может не быть —
            // тогда блок остаётся на `backdrop`, как раньше.
            //
            // Размер у кадра `wide`, а не `frame`: пресет 1344×756 живёт только
            // на `get-ott`, кадры лежат на `get-kinopoisk-image` и отвечают на него 404.
            let still = watchingStill?.url(size: .wide) ?? watching.backdrop?.url(size: .frame),
            // Логотипы лежат на tmdb, а он у нас не резолвится — `logoURL`
            // уводит их через прокси (см. `TMDBImageProxy`).
            let logo = watching.logo?.logoURL(width: Self.logoPixelWidth)
        {
            apply(.watching(WatchingBlock(
                id: "kp-w-\(watching.id)",
                title: watching.displayTitle,
                still: .remote(still),
                // Видео из открытых API кино не отдаёт никто — клип остаётся забандленным.
                clip: ShowcaseSeeds.watchingClip,
                // Без бандленного фолбэка: моковый логотип чужого фильма
                // соврал бы о контенте. Не загрузится — карточка покажет название.
                logo: .remote(logo),
                progress: Double.random(in: 0.15...0.9, using: &rng),
                remaining: ShowcaseSeeds.watchingRemaining.randomElement(using: &rng) ?? ""
            )), preload: preload)
        }
    }

    /// Фильмы промо из запаса: сперва с кадром, не те, что в ленте.
    private func pickPromoMovies(using rng: inout SeededGenerator) async -> [MovieBlock] {
        let excluded = Set([pickedFeatured?.id, pickedWatching?.id].compactMap { $0 })
        let withStill = await MoviePool.shared.unseenWithStill(where: Self.isFeaturable)
            .filter { !excluded.contains($0.id) }
        let any = await MoviePool.shared.unseen(where: Self.isFeaturable)
            .filter { !excluded.contains($0.id) }
        var picked = Array(withStill.shuffled(using: &rng).prefix(ShowcaseSeeds.promoPerKind))
        for movie in any.shuffled(using: &rng)
        where picked.count < ShowcaseSeeds.promoPerKind && !picked.contains(where: { $0.id == movie.id }) {
            picked.append(movie)
        }
        var blocks: [MovieBlock] = []
        for movie in picked {
            let still = await MoviePool.shared.stills(for: movie.id).first
            if let block = Self.promoMovieBlock(movie, still: still) { blocks.append(block) }
        }
        return blocks
    }

    /// Фильм промо — как блок ленты, но с описанием длиннее: под слайдером на него
    /// четыре строки шириной 244, а не три по 182.
    private static func promoMovieBlock(_ movie: KinopoiskMovie, still: KinopoiskStill?) -> MovieBlock? {
        guard let poster = movie.poster?.url(size: .medium) else { return nil }
        return MovieBlock(
            id: "kp-\(movie.id)",
            title: movie.displayTitle,
            poster: .remote(poster),
            still: .remote(still?.url(size: .wide) ?? movie.backdrop?.url(size: .frame) ?? poster),
            caption: (movie.shortDescription ?? "").showcaseCaption(maxCharacters: ShowcaseSeeds.promoCaptionLimit),
            captionTint: mockMovieTint
        )
    }

    /// Прогрев картинок для следующих запусков. Берём немного: смысл в том, чтобы
    /// ближайшие два-три запуска открывались с готовым постером, а не в том,
    /// чтобы скачать весь запас.
    private func preloadNextMovies() async {
        let next = await MoviePool.shared.unseen(where: Self.isFeaturable).prefix(3)
        let posters = next.compactMap { $0.poster?.url(size: .medium) }.map { ArtworkSource.remote($0) }
        let stills = await MoviePool.shared.unseen(where: Self.isWatchable).prefix(2)
            .compactMap { $0.backdrop?.url(size: .frame) }
            .map { ArtworkSource.remote($0) }
        ArtworkLoader.shared.preload(posters + stills)
    }

    /// Фильм для блока: сперва тот, у которого уже есть кадр, иначе любой годный —
    /// тогда блок обойдётся `backdrop`, как раньше.
    private static func pick(
        where isEligible: @escaping @Sendable (KinopoiskMovie) -> Bool,
        excluding excluded: Int? = nil,
        using rng: inout SeededGenerator
    ) async -> KinopoiskMovie? {
        let withStill = await MoviePool.shared.unseenWithStill(where: isEligible)
            .filter { $0.id != excluded }
        if let picked = withStill.randomElement(using: &rng) { return picked }
        return await MoviePool.shared.unseen(where: isEligible)
            .filter { $0.id != excluded }
            .randomElement(using: &rng)
    }

    /// Догружает кадры тайтлов пачками.
    ///
    /// Кадры лежат в отдельной ручке, и поштучно они стоили бы запроса на фильм —
    /// поэтому `movieId` передаётся списком, и одна пачка закрывает два десятка тайтлов.
    /// Кадры есть примерно у половины каталога, так что пачек берём несколько:
    /// иначе запас непоказанных с кадром кончается через пару запусков.
    private func loadStills() async {
        let needsFeatured = await MoviePool.shared.needsStills(where: Self.isFeaturable)
        let needsWatching = await MoviePool.shared.needsStills(where: Self.isWatchable)
        guard needsFeatured || needsWatching else { return }

        let limit = ShowcaseSeeds.stillsBatch * ShowcaseSeeds.stillsBatchCount
        var queue = await MoviePool.shared.awaitingStills(limit: limit, where: Self.isFeaturable)
        let watchable = await MoviePool.shared.awaitingStills(limit: limit, where: Self.isWatchable)
        queue.append(contentsOf: watchable.filter { !queue.contains($0) })
        guard !queue.isEmpty else { return }

        for start in stride(from: 0, to: min(queue.count, limit), by: ShowcaseSeeds.stillsBatch) {
            let chunk = Array(queue[start..<min(start + ShowcaseSeeds.stillsBatch, queue.count)])
            do {
                let stills = try await KinopoiskService.shared.stills(movieIDs: chunk)
                await MoviePool.shared.store(stills: stills, asked: chunk)
            } catch {
                failures.append("кадры: \(error.localizedDescription)")
                return
            }
        }
    }

    /// Один запрос за целой подборкой. Берём ту, из которой ещё не брали, — иначе
    /// пополнение принесёт те же фильмы и запас не вырастет.
    private func refillMoviePool(using rng: inout SeededGenerator) async {
        let used = await MoviePool.shared.usedSources()
        let fresh = ShowcaseSeeds.movieLists.filter { !used.contains($0) }
        let pool = fresh.isEmpty ? ShowcaseSeeds.movieLists : fresh
        guard let slug = pool.randomElement(using: &rng) else { return }

        do {
            let batch = try await KinopoiskService.shared.movies(
                list: slug,
                limit: ShowcaseSeeds.moviePoolBatch,
                page: 1
            )
            await MoviePool.shared.store(batch, source: slug)
        } catch {
            failures.append("кино: \(error.localizedDescription)")
        }
    }

    /// Блоку «посмотреть» нужен постер и короткое описание.
    private static let isFeaturable: @Sendable (KinopoiskMovie) -> Bool = { movie in
        movie.poster?.url(size: .medium) != nil && !(movie.shortDescription ?? "").isEmpty
    }

    /// Блоку «продолжить смотреть» — горизонтальный кадр и логотип проекта.
    private static let isWatchable: @Sendable (KinopoiskMovie) -> Bool = { movie in
        movie.backdrop?.url(size: .frame) != nil && movie.logo?.logoURL(width: logoPixelWidth) != nil
    }

    // MARK: - Музыка

    /// Альбом — из дискографии сида или его «похожих» у Deezer (см. `ShowcaseSeeds.musicArtists`).
    /// Раньше витрина выбирала из десятка заранее названных альбомов и крутила одни и те же.
    private func loadMusic() async {
        var rng = ShowcaseRotation.generator(salt: ShowcaseRotation.Salt.music)
        guard let seed = ShowcaseSeeds.musicArtists.randomElement(using: &rng) else { return }

        // Круг выбора — сид и его соседи. Похожие не доехали — круг из одного сида:
        // витрина всё равно покажет альбом, просто без разнообразия этого запуска.
        var circle = [seed]
        if let related = try? await DeezerService.shared.relatedArtists(
            id: seed.id,
            limit: ShowcaseSeeds.relatedArtistsLimit
        ) {
            circle += related.map { (name: $0.name, id: $0.id) }
        }
        circle.shuffle(using: &rng)

        var picked: (artist: String, artistID: Int, album: DeezerAlbumBrief, cover: URL)?
        for candidate in circle.prefix(ShowcaseSeeds.artistAttempts) {
            guard let albums = try? await DeezerService.shared.artistAlbums(id: candidate.id) else { continue }
            let fitting = albums.filter(Self.isShowcaseAlbum)
            if let album = fitting.randomElement(using: &rng),
               let cover = (album.coverXl ?? album.coverBig)?.deezerUpscaled {
                picked = (candidate.name, candidate.id, album, cover)
                break
            }
        }
        guard let picked else {
            failures.append("музыка: у «\(seed.name)» и похожих нет студийного альбома с обложкой")
            return
        }

        // Дискография артиста отдаёт альбомы без вложенного исполнителя — имя берём из круга.
        apply(.album(AlbumBlock(
            id: "dz-\(picked.album.id)",
            cover: .remote(picked.cover, fallback: "mockAlbumCover"),
            title: picked.artist,
            subtitle: picked.album.title
        )))

        // «Моя Волна» — не сущность каталога: живой у неё только кавер, и он берётся
        // у другого артиста того же круга — в настроении альбома, но не он сам.
        var vibeCover: URL?
        for candidate in circle.filter({ $0.id != picked.artistID }).prefix(ShowcaseSeeds.artistAttempts - 1) {
            guard let albums = try? await DeezerService.shared.artistAlbums(id: candidate.id) else { continue }
            vibeCover = albums.compactMap { ($0.coverXl ?? $0.coverBig)?.deezerUpscaled }.randomElement(using: &rng)
            if vibeCover != nil { break }
        }

        apply(.vibe(VibeBlock(
            id: "vibe-\(picked.album.id)",
            title: "Моя Волна",
            subtitle: ShowcaseSeeds.vibeSubtitles.randomElement(using: &rng) ?? "",
            cover: .remote(vibeCover ?? picked.cover, fallback: "mockPlayerCover")
        )))

        // Промо — альбомы других исполнителей того же круга, по одному на исполнителя.
        var promo: [AlbumBlock] = []
        var attempts = 0
        for candidate in circle where candidate.id != picked.artistID {
            guard promo.count < ShowcaseSeeds.promoPerKind, attempts < ShowcaseSeeds.promoArtistAttempts else { break }
            attempts += 1
            guard let albums = try? await DeezerService.shared.artistAlbums(id: candidate.id) else { continue }
            let fitting = albums.filter { Self.isShowcaseAlbum($0) && $0.id != picked.album.id }
            if let album = fitting.randomElement(using: &rng),
               let cover = (album.coverXl ?? album.coverBig)?.deezerUpscaled {
                promo.append(AlbumBlock(
                    id: "dz-\(album.id)",
                    cover: .remote(cover, fallback: "mockAlbumCover"),
                    title: candidate.name,
                    subtitle: album.title
                ))
            }
        }
        promoAlbums = promo
        publishPromo()
    }

    /// Студийный альбом с обложкой: синглы, EP, концертники и сборники витрине не годятся.
    private static func isShowcaseAlbum(_ album: DeezerAlbumBrief) -> Bool {
        guard album.recordType == "album", album.coverXl != nil || album.coverBig != nil else { return false }
        let words = Set(album.title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted))
        return words.isDisjoint(with: ShowcaseSeeds.albumStopWords)
    }

    // MARK: - Книги

    /// Книги — случайные тома случайных авторов из `ShowcaseSeeds.bookSeeds`, две книги
    /// двух разных авторов. Раньше витрина выбирала из восьми заранее названных книг.
    private func loadBooks() async {
        var rng = ShowcaseRotation.generator(salt: ShowcaseRotation.Salt.books)
        let seeds = ShowcaseSeeds.bookSeeds.shuffled(using: &rng).prefix(ShowcaseSeeds.bookAttempts)

        // Поиск Google Books по-русски шумный: книги об авторе, пересказы, журналы,
        // иноязычные издания при `langRestrict=ru`. Отбираем тома, которые написал сам
        // автор, по-русски, с описанием, — и идём по сидам, пока не наберём две книги.
        var found: [GoogleBook] = []
        // Годные тома тех же запросов — запас под промо: книги слайдера без лишних
        // запросов (каждый — секунда троттла под заставкой).
        var spare: [GoogleBook] = []
        for seed in seeds where found.count < 2 || spare.count < ShowcaseSeeds.promoPerKind {
            guard let volumes = try? await BooksService.shared.search(seed.query, limit: 20) else { continue }
            var fitting = volumes.filter { Self.isShowcaseBook($0, by: seed.author) }.shuffled(using: &rng)
            if found.count < 2, let book = fitting.first, !found.contains(where: { $0.id == book.id }) {
                found.append(book)
                fitting.removeFirst()
            }
            spare += fitting.filter { book in !spare.contains(where: { $0.id == book.id }) }
        }
        promoBooks = spare
            .filter { book in !found.contains(where: { $0.id == book.id }) && book.coverURL != nil }
            .prefix(ShowcaseSeeds.promoPerKind)
            .compactMap(Self.promoBookBlock)
        publishPromo()

        guard found.count == 2 else {
            failures.append("книги: за \(seeds.count) запросов нашлось \(found.count) томов")
            return
        }

        let featured = found[0]
        if let cover = featured.coverURL {
            let tint = await ArtworkLoader.shared.accent(for: cover)
            apply(.book(BookBlock(
                id: "gb-\(featured.id)",
                title: featured.title,
                // Объём строится из плоской обложки — см. `BookRender`.
                render: .remote(cover, fallback: "mockBookTechno"),
                cover: .remote(cover, fallback: "mockBookTechno"),
                caption: (featured.volumeInfo.description ?? featured.volumeInfo.subtitle ?? "")
                    .showcaseCaption(maxCharacters: 92),
                captionTint: tint ?? Self.mockBookTint
            )))
        }

        let reading = found[1]
        if let cover = reading.coverURL {
            let description = reading.volumeInfo.description ?? ""
            apply(.reading(ReadingBlock(
                id: "gb-r-\(reading.id)",
                title: reading.title,
                cover: .remote(cover, fallback: "mockBookMini"),
                // Кадр фрагмента 322×532 рассчитан на сплошной текст: короткое
                // описание оставило бы половину блока пустой, поэтому ниже порога
                // берём моковый отрывок.
                excerpt: description.count >= 320 ? description : Self.mockExcerpt,
                progress: Double.random(in: 0.1...0.85, using: &rng),
                remaining: ShowcaseSeeds.readingRemaining.randomElement(using: &rng) ?? ""
            )))
        }
    }

    /// Том для витрины: написан самим автором сида (фамилия в `authors`), по-русски,
    /// с описанием под подпись карточки, и это не пересказ. Скан обложки отбирает сервис.
    private static func isShowcaseBook(_ book: GoogleBook, by surname: String) -> Bool {
        let info = book.volumeInfo
        guard info.language == "ru", (info.description?.count ?? 0) >= Self.bookDescriptionMinimum else { return false }
        guard (info.authors ?? []).contains(where: { $0.localizedCaseInsensitiveContains(surname) }) else { return false }
        let title = book.title.lowercased()
        return !ShowcaseSeeds.bookSummaryMarkers.contains { title.contains($0) }
    }

    /// Книга промо — описание длиннее, чем у карточки ленты (`promoCaptionLimit`).
    private static func promoBookBlock(_ book: GoogleBook) -> BookBlock? {
        guard let cover = book.coverURL else { return nil }
        return BookBlock(
            id: "gb-\(book.id)",
            title: book.title,
            render: .remote(cover, fallback: "mockBookTechno"),
            cover: .remote(cover, fallback: "mockBookTechno"),
            caption: (book.volumeInfo.description ?? book.volumeInfo.subtitle ?? "")
                .showcaseCaption(maxCharacters: ShowcaseSeeds.promoCaptionLimit),
            captionTint: mockBookTint
        )
    }

    /// Описание короче — подпись карточки книги вышла бы в одну строку.
    private static let bookDescriptionMinimum = 100

    // MARK: - Замена блока по ✕

    /// Замена блока: новый блок и что сделать, когда он встал (у кино — отметить
    /// фильм показанным и сделать его текущим для чипа плеера).
    private struct Replacement {
        let block: ShowcaseBlock
        var commit: @MainActor () -> Void = {}
    }

    /// Сколько карточка ждёт замену сверх 400 мс ухода. Не дождалась — айтем
    /// проявляется прежним: пустой слот хуже, чем тот же контент.
    private static let replacementTimeout: Duration = .seconds(4)

    /// Новый айтем того же слота для ✕ на карточке (задача пользователя 2026-10-03):
    /// заготовленный заранее или собранный сейчас, с картинками в кэше. Возвращает,
    /// чем его поставить, — карточка ставит, когда старый контент уже погас. `nil` —
    /// замены нет: моковая лента без сети или сеть не ответила вовремя.
    func prepareReplacement(for block: ShowcaseBlock) async -> (@MainActor () -> Void)? {
        // Живых данных не собирали (`-debugMockFeed`, пустые ключи) — сеть не трогаем.
        guard hasLoaded, block.isReplaceable else { return nil }
        let key = block.slot.top
        let task = upcoming.removeValue(forKey: key) ?? Task { await self.makeReplacement(for: block) }
        guard let replacement = await Self.value(of: task, within: Self.replacementTimeout),
              replacement.block.id != block.id
        else { return nil }
        return { [weak self] in
            guard let self else { return }
            // Фон витрины и врезки заголовка не трогаем: ✕ обновляет ровно блок,
            // а смена фона под всей лентой читалась бы обновлением экрана.
            self.apply(replacement.block, refreshesFeedArt: false)
            replacement.commit()
            // Следующая замена — заранее, от нового айтема.
            self.upcoming[key] = Task { await self.makeReplacement(for: replacement.block) }
        }
    }

    /// Заготовить замены всем карточкам с парой ✕/✓ — после сборки живой ленты.
    private func prefetchReplacements() {
        for block in feed.blocks where block.isReplaceable && upcoming[block.slot.top] == nil {
            upcoming[block.slot.top] = Task { await self.makeReplacement(for: block) }
        }
        for (index, block) in feed.promo.enumerated() where block.isReplaceable && upcomingPromo[index] == nil {
            upcomingPromo[index] = Task { await self.makePromoReplacement(for: block) }
        }
    }

    /// Новый айтем того же вида на место айтема промо по ✕ — так же, как у карточек
    /// ленты (`prepareReplacement`): заготовленный или собранный сейчас, с картинками.
    func preparePromoReplacement(at index: Int) async -> (@MainActor () -> Void)? {
        guard hasLoaded, feed.promo.indices.contains(index) else { return nil }
        let block = feed.promo[index]
        guard block.isReplaceable else { return nil }
        let task = upcomingPromo.removeValue(forKey: index) ?? Task { await self.makePromoReplacement(for: block) }
        guard let replacement = await Self.value(of: task, within: Self.replacementTimeout),
              replacement.block.id != block.id
        else { return nil }
        return { [weak self] in
            guard let self else { return }
            self.replacePromo(at: index, with: replacement.block)
            replacement.commit()
            self.upcomingPromo[index] = Task { await self.makePromoReplacement(for: replacement.block) }
        }
    }

    private func makePromoReplacement(for block: ShowcaseBlock) async -> Replacement? {
        let replacement: Replacement? = switch block {
        case .movie(let current): await nextMovie(after: current, forPromo: true)
        case .album(let current): await nextAlbum(after: current)
        case .book(let current): await nextBook(after: current, forPromo: true)
        case .vibe, .reading, .watching: nil
        }
        if let replacement { await ArtworkLoader.shared.prewarm(replacement.block.artworks) }
        return replacement
    }

    /// Подменяет айтем промо на месте — и в наборе своего вида, чтобы поздняя сборка
    /// (`publishPromo`) его не вернула.
    private func replacePromo(at index: Int, with block: ShowcaseBlock) {
        guard feed.promo.indices.contains(index) else { return }
        switch (feed.promo[index], block) {
        case (.movie(let old), .movie(let new)):
            if let i = promoMovies.firstIndex(where: { $0.id == old.id }) { promoMovies[i] = new }
        case (.album(let old), .album(let new)):
            if let i = promoAlbums.firstIndex(where: { $0.id == old.id }) { promoAlbums[i] = new }
        case (.book(let old), .book(let new)):
            if let i = promoBooks.firstIndex(where: { $0.id == old.id }) { promoBooks[i] = new }
        default:
            break
        }
        var promo = feed.promo
        promo[index] = block
        feed = ShowcaseFeed(promo: promo, blocks: feed.blocks, backdrop: feed.backdrop)
    }

    /// Промо на экран — вперемешку: фильм, альбом, книга, и снова. Вид, живых айтемов
    /// которого нет, — из моковой ленты: слайдер не пустеет и не теряет вид.
    private func publishPromo(preload: Bool = true) {
        let fallback = ShowcaseFeed.personal.promo
        let movies: [ShowcaseBlock] = promoMovies.isEmpty
            ? fallback.filter { if case .movie = $0 { true } else { false } }
            : promoMovies.map { .movie($0) }
        let albums: [ShowcaseBlock] = promoAlbums.isEmpty
            ? fallback.filter { if case .album = $0 { true } else { false } }
            : promoAlbums.map { .album($0) }
        let books: [ShowcaseBlock] = promoBooks.isEmpty
            ? fallback.filter { if case .book = $0 { true } else { false } }
            : promoBooks.map { .book($0) }
        var promo: [ShowcaseBlock] = []
        for index in 0..<max(movies.count, albums.count, books.count) {
            for kind in [movies, albums, books] where index < kind.count {
                promo.append(kind[index])
            }
        }
        feed = ShowcaseFeed(promo: promo, blocks: feed.blocks, backdrop: feed.backdrop)
        // Прогрев — общий эффект, из `init` его звать нельзя: см. комментарий там.
        if preload { ArtworkLoader.shared.preload(promo.flatMap(\.artworks)) }
    }

    private func makeReplacement(for block: ShowcaseBlock) async -> Replacement? {
        let replacement: Replacement? = switch block {
        case .movie(let current): await nextMovie(after: current)
        case .album(let current): await nextAlbum(after: current)
        case .book(let current): await nextBook(after: current)
        case .vibe(let current): await nextVibe(after: current)
        case .reading, .watching: nil
        }
        // Картинки — в кэш до смены: новый айтем проявляется уже с обложкой.
        if let replacement { await ArtworkLoader.shared.prewarm(replacement.block.artworks) }
        return replacement
    }

    /// Фильм — из запаса на диске, как и при сборке: непоказанный, с постером
    /// и описанием, не тот, что в соседнем блоке «продолжить смотреть».
    private func nextMovie(after current: MovieBlock, forPromo: Bool = false) async -> Replacement? {
        var rng = SystemRandomNumberGenerator()
        // Не тот же, не «продолжить смотреть» и ни один фильм ленты или промо.
        var excluded = Set([Int(current.id.dropFirst("kp-".count)), pickedWatching?.id].compactMap { $0 })
        for case .movie(let shown) in feed.blocks + feed.promo {
            if let id = Int(shown.id.dropFirst("kp-".count)) { excluded.insert(id) }
        }
        let withStill = await MoviePool.shared.unseenWithStill(where: Self.isFeaturable)
            .filter { !excluded.contains($0.id) }
        let any = await MoviePool.shared.unseen(where: Self.isFeaturable)
            .filter { !excluded.contains($0.id) }
        guard let movie = withStill.randomElement(using: &rng) ?? any.randomElement(using: &rng),
              let poster = movie.poster?.url(size: .medium)
        else { return nil }
        let still = await MoviePool.shared.stills(for: movie.id).first
        if forPromo, let block = Self.promoMovieBlock(movie, still: still) {
            // Чип плеера и «текущий фильм» — у карточки ленты, промо их не трогает.
            return Replacement(block: .movie(block)) {
                Task { await MoviePool.shared.markShown([movie.id]) }
            }
        }
        let tint = await ArtworkLoader.shared.accent(for: poster)
        let block = MovieBlock(
            id: "kp-\(movie.id)",
            title: movie.displayTitle,
            poster: .remote(poster),
            still: .remote(still?.url(size: .wide) ?? movie.backdrop?.url(size: .frame) ?? poster),
            caption: (movie.shortDescription ?? "").showcaseCaption(maxCharacters: 88),
            captionTint: tint ?? Self.mockMovieTint
        )
        return Replacement(block: .movie(block)) { [weak self] in
            self?.pickedFeatured = movie
            self?.featuredStill = still
            Task { await MoviePool.shared.markShown([movie.id]) }
        }
    }

    /// Альбом — студийный, с обложкой, из дискографии случайного сида; не тот же.
    private func nextAlbum(after current: AlbumBlock) async -> Replacement? {
        var rng = SystemRandomNumberGenerator()
        for seed in ShowcaseSeeds.musicArtists.shuffled(using: &rng).prefix(ShowcaseSeeds.artistAttempts) {
            guard let albums = try? await DeezerService.shared.artistAlbums(id: seed.id) else { continue }
            let fitting = albums.filter {
                Self.isShowcaseAlbum($0) && "dz-\($0.id)" != current.id && !shownAlbumIDs.contains("dz-\($0.id)")
            }
            if let album = fitting.randomElement(using: &rng),
               let cover = (album.coverXl ?? album.coverBig)?.deezerUpscaled {
                return Replacement(block: .album(AlbumBlock(
                    id: "dz-\(album.id)",
                    cover: .remote(cover, fallback: "mockAlbumCover"),
                    title: seed.name,
                    subtitle: album.title
                )))
            }
        }
        return nil
    }

    /// Альбомы на экране — в ленте и в промо: замена их не повторяет.
    private var shownAlbumIDs: Set<String> {
        var ids: Set<String> = []
        for case .album(let album) in feed.blocks + feed.promo { ids.insert(album.id) }
        return ids
    }

    /// Книга — тем же отбором, что при сборке; не та же, не та, что в «продолжить читать»,
    /// и ни одна книга промо.
    private func nextBook(after current: BookBlock, forPromo: Bool = false) async -> Replacement? {
        var rng = SystemRandomNumberGenerator()
        var excluded: Set<String> = [String(current.id.dropFirst("gb-".count))]
        for case .reading(let reading) in feed.blocks {
            excluded.insert(String(reading.id.dropFirst("gb-r-".count)))
        }
        for case .book(let book) in feed.blocks + feed.promo {
            excluded.insert(String(book.id.dropFirst("gb-".count)))
        }
        for seed in ShowcaseSeeds.bookSeeds.shuffled(using: &rng).prefix(ShowcaseSeeds.bookAttempts) {
            guard let volumes = try? await BooksService.shared.search(seed.query, limit: 20) else { continue }
            let fitting = volumes.filter { Self.isShowcaseBook($0, by: seed.author) && !excluded.contains($0.id) }
            guard let book = fitting.randomElement(using: &rng), let cover = book.coverURL else { continue }
            if forPromo, let block = Self.promoBookBlock(book) {
                return Replacement(block: .book(block))
            }
            let tint = await ArtworkLoader.shared.accent(for: cover)
            return Replacement(block: .book(BookBlock(
                id: "gb-\(book.id)",
                title: book.title,
                render: .remote(cover, fallback: "mockBookTechno"),
                cover: .remote(cover, fallback: "mockBookTechno"),
                caption: (book.volumeInfo.description ?? book.volumeInfo.subtitle ?? "")
                    .showcaseCaption(maxCharacters: 92),
                captionTint: tint ?? Self.mockBookTint
            )))
        }
        return nil
    }

    /// «Моя Волна» — другой подзаголовок и обложка для плеера от другого исполнителя.
    /// Сеть не ответила — хватает и нового подзаголовка: «Волна» всё равно другая.
    private func nextVibe(after current: VibeBlock) async -> Replacement? {
        var rng = SystemRandomNumberGenerator()
        let subtitle = ShowcaseSeeds.vibeSubtitles.filter { $0 != current.subtitle }.randomElement(using: &rng)
            ?? current.subtitle
        var cover: (album: Int, url: URL)?
        for seed in ShowcaseSeeds.musicArtists.shuffled(using: &rng).prefix(ShowcaseSeeds.artistAttempts) {
            guard let albums = try? await DeezerService.shared.artistAlbums(id: seed.id) else { continue }
            if let album = albums.filter({ "vibe-\($0.id)" != current.id }).randomElement(using: &rng),
               let url = (album.coverXl ?? album.coverBig)?.deezerUpscaled {
                cover = (album.id, url)
                break
            }
        }
        return Replacement(block: .vibe(VibeBlock(
            id: cover.map { "vibe-\($0.album)" } ?? "vibe-\(UUID().uuidString)",
            title: current.title,
            subtitle: subtitle,
            cover: cover.map { .remote($0.url, fallback: "mockPlayerCover") } ?? current.cover
        )))
    }

    /// Значение задачи — или `nil`, если не дождались. Саму задачу не отменяем:
    /// она уже вынута из заготовок, просто доживает и пропадает.
    private static func value(of task: Task<Replacement?, Never>, within limit: Duration) async -> Replacement? {
        await withTaskGroup(of: Replacement?.self) { group in
            group.addTask { await task.value }
            group.addTask {
                try? await Task.sleep(for: limit)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - Сборка ленты

    private var currentMovieId: String? {
        for case .movie(let block) in feed.blocks { return block.id }
        return nil
    }

    /// Подменяет блок того же типа на месте. Порядок слотов зафиксирован макетом,
    /// поэтому лента не пересобирается — меняется ровно один элемент.
    /// `refreshesFeedArt: false` — фон остаётся прежним (замена по ✕).
    private func apply(_ block: ShowcaseBlock, preload: Bool = true, refreshesFeedArt: Bool = true) {
        var blocks = feed.blocks
        guard let index = blocks.firstIndex(where: { $0.slot.top == block.slot.top }) else { return }
        blocks[index] = block

        guard refreshesFeedArt else {
            feed = ShowcaseFeed(promo: feed.promo, blocks: blocks, backdrop: feed.backdrop)
            return
        }

        // Фон витрины — обложка первого блока (figma-screen1 §0), поэтому он едет
        // вместе с ним.
        var backdrop = feed.backdrop
        if case .movie(let movie) = block { backdrop = movie.poster }

        feed = ShowcaseFeed(promo: feed.promo, blocks: blocks, backdrop: backdrop)
        // Замена по ✕ — сразу от живого блока, а не после всей ленты: книги приходят
        // последними, и ✕ у кино или альбома, нажатый до них, ждал бы пустым слотом.
        if hasLoaded, block.isReplaceable {
            upcoming[block.slot.top] = Task { await self.makeReplacement(for: block) }
        }
        // Прогрев — общий эффект, и из `init` его звать нельзя: см. комментарий там.
        guard preload else { return }
        ArtworkLoader.shared.preload(blocks.flatMap(\.artworks))
    }

    // MARK: - Фолбэки моковой ленты

    /// Логотип в блоке «продолжить смотреть» рисуется в боксе 147pt — на ×3 это 441px.
    private static let logoPixelWidth = 441

    private static let mockMovieTint = Color(red: 0xA7 / 255, green: 0xCA / 255, blue: 0xC6 / 255)
    private static let mockBookTint = Color(red: 0xBC / 255, green: 0xEB / 255, blue: 0xFB / 255)

    /// Отрывок из моковой ленты — им закрывается блок чтения, когда у живой книги
    /// описание слишком короткое.
    private static let mockExcerpt: String = {
        for case .reading(let block) in ShowcaseFeed.personal.blocks { return block.excerpt }
        return ""
    }()
}

// MARK: - Помощники

extension String {
    /// Подпись карточки: у макета под неё отведено 3–4 строки, а описания в API
    /// бывают на абзац. Режем по границе предложения, иначе — по слову.
    /// Общая с описанием в промо главной Книг.
    func showcaseCaption(maxCharacters: Int) -> String {
        let flat = replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flat.count > maxCharacters else { return flat }

        let head = String(flat.prefix(maxCharacters + 20))
        if let stop = head.lastIndex(where: { ".!?".contains($0) }), head.distance(from: head.startIndex, to: stop) > maxCharacters / 2 {
            return String(head[...stop])
        }
        let clipped = String(flat.prefix(maxCharacters))
        guard let space = clipped.lastIndex(of: " ") else { return clipped }
        return String(clipped[..<space]) + "…"
    }
}
