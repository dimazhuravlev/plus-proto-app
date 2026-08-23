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
        pickedFeatured = unseen.filter(Self.isFeaturable).randomElement(using: &rng)
        pickedWatching = unseen
            .filter { Self.isWatchable($0) && $0.id != pickedFeatured?.id }
            .randomElement(using: &rng)
        applyMovieBlocks(featuredTint: nil, rng: &rng, preload: false)
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
            let featured = await MoviePool.shared.unseen(where: Self.isFeaturable)
            let watchable = await MoviePool.shared.unseen(where: Self.isWatchable)
            pickedFeatured = featured.randomElement(using: &rng)
            pickedWatching = watchable.filter { $0.id != pickedFeatured?.id }.randomElement(using: &rng)
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

        await MoviePool.shared.markShown([featured.id, pickedWatching?.id].compactMap { $0 })

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
                // Подпись `2004:10769` рассчитана на 3 строки по 182.68pt;
                // `shortDescription` бывает и вдвое длиннее — режем.
                caption: (movie.shortDescription ?? "").showcaseCaption(maxCharacters: 88),
                captionTint: featuredTint ?? Self.mockMovieTint
            )), preload: preload)
        }

        if
            let watching = pickedWatching,
            let still = watching.backdrop?.url(size: .frame),
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

    private func loadMusic() async {
        var rng = ShowcaseRotation.generator(salt: ShowcaseRotation.Salt.music)
        guard let query = ShowcaseSeeds.albumQueries.randomElement(using: &rng) else { return }
        do {
            let albums = try await DeezerService.shared.searchAlbums(query: query, limit: 10)
            guard
                let album = albums.first(where: { $0.coverXl != nil }) ?? albums.first,
                let cover = (album.coverXl ?? album.coverBig)?.deezerUpscaled
            else {
                failures.append("музыка: по запросу «\(query)» нет обложки")
                return
            }

            apply(.album(AlbumBlock(
                id: "dz-\(album.id)",
                cover: .remote(cover, fallback: "mockAlbumCover"),
                title: album.artist?.name ?? album.title,
                subtitle: album.title
            )))

            // «Моя Волна» — не сущность каталога: живой у неё только кавер, и он берётся
            // из соседнего альбома пула, чтобы не совпадать с альбомным блоком.
            let vibeQuery = ShowcaseSeeds.albumQueries.filter { $0 != query }.randomElement(using: &rng) ?? query
            let vibeAlbums = try await DeezerService.shared.searchAlbums(query: vibeQuery, limit: 5)
            let vibeCover = vibeAlbums.compactMap { ($0.coverXl ?? $0.coverBig)?.deezerUpscaled }.first

            apply(.vibe(VibeBlock(
                id: "vibe-\(album.id)",
                title: "Моя Волна",
                subtitle: ShowcaseSeeds.vibeSubtitles.randomElement(using: &rng) ?? "",
                cover: .remote(vibeCover ?? cover, fallback: "mockPlayerCover")
            )))
        } catch {
            failures.append("музыка: \(error.localizedDescription)")
        }
    }

    // MARK: - Книги

    private func loadBooks() async {
        var rng = ShowcaseRotation.generator(salt: ShowcaseRotation.Salt.books)
        let queries = ShowcaseSeeds.bookQueries.shuffled(using: &rng)
        guard queries.count >= 2 else { return }

        // Поиск Google Books по-русски промахивается часто, а после отсева томов
        // без скана выдача бывает пустой — идём по пулу, пока не наберём два тома.
        var found: [GoogleBook] = []
        for query in queries where found.count < 2 {
            guard let book = try? await BooksService.shared.search(query, limit: 12).first else { continue }
            guard !found.contains(where: { $0.id == book.id }) else { continue }
            found.append(book)
        }
        guard found.count == 2 else {
            failures.append("книги: в пуле из \(queries.count) запросов нашлось \(found.count) томов со сканом")
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

    // MARK: - Сборка ленты

    private var currentMovieId: String? {
        for case .movie(let block) in feed.blocks { return block.id }
        return nil
    }

    /// Подменяет блок того же типа на месте. Порядок слотов зафиксирован макетом,
    /// поэтому лента не пересобирается — меняется ровно один элемент.
    private func apply(_ block: ShowcaseBlock, preload: Bool = true) {
        var blocks = feed.blocks
        guard let index = blocks.firstIndex(where: { $0.slot.top == block.slot.top }) else { return }
        blocks[index] = block

        // Фон витрины — обложка первого блока (figma-screen1 §0), поэтому он едет
        // вместе с ним. Врезки заголовка тоже: текст пока моковый, но картинки в нём
        // обязаны совпадать с тем, что показано ниже.
        var backdrop = feed.backdrop
        var headline = feed.headline
        switch block {
        case .movie(let movie):
            backdrop = movie.poster
            headline = headline.replacing(.poster, with: movie.poster)
        case .album(let album):
            headline = headline.replacing(.avatar, with: album.cover)
        case .book(let book):
            headline = headline.replacing(.book, with: book.cover)
        default:
            break
        }

        feed = ShowcaseFeed(headline: headline, blocks: blocks, backdrop: backdrop)
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

private extension String {
    /// Подпись карточки: у макета под неё отведено 3–4 строки, а описания в API
    /// бывают на абзац. Режем по границе предложения, иначе — по слову.
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

private extension ShowcaseHeadline {
    /// Меняет картинку врезки нужного типа, не трогая её позицию и поворот:
    /// координаты в макете подобраны под конкретную разбивку текста.
    func replacing(_ kind: ShowcaseHeadlineChip.Kind, with artwork: ArtworkSource) -> ShowcaseHeadline {
        ShowcaseHeadline(
            text: text,
            chips: chips.map { chip in
                guard chip.kind == kind else { return chip }
                return ShowcaseHeadlineChip(
                    kind: chip.kind,
                    artwork: artwork,
                    size: chip.size,
                    origin: chip.origin,
                    rotation: chip.rotation
                )
            }
        )
    }
}

private extension ShowcaseBlock {
    /// Всё, что блок покажет картинками, — для прогрева кэша.
    var artworks: [ArtworkSource] {
        switch self {
        case .movie(let b): [b.poster]
        case .album(let b): [b.cover]
        case .book(let b): [b.render, b.cover]
        case .vibe(let b): [b.cover]
        case .reading(let b): [b.cover]
        case .watching(let b): [b.still, b.logo]
        }
    }
}
