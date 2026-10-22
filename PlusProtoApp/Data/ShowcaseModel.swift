import SwiftUI

// MARK: - Модель витрины

/// Витрина «Главная» задумана динамической: под событие и контекст меняются набор
/// блоков, их содержание и фон (решение 2026-08-22). Поэтому экран собирается
/// из модели, а не из зашитой вёрстки — два экрана в Figma это одна витрина
/// в двух состояниях.
///
/// Порядок блоков пока не проектируем: `.personal` повторяет экран `2004:10701`
/// (заголовка с врезками нет с 2026-10-08 — сверху навигация `HomeTopNav`).
struct ShowcaseFeed {
    /// Промо-слайдер над лентой (`ShowcasePromo`, макет `2532:26618`, задача пользователя
    /// 2026-10-08): фильмы, альбомы и книги вперемешку — свой набор, не тот, что
    /// в карточках ленты, и новый на каждый холодный запуск.
    var promo: [ShowcaseBlock] = []
    let blocks: [ShowcaseBlock]
}

/// Блок ленты. Каждый несёт свой payload и знает свою геометрию в макете.
enum ShowcaseBlock: Identifiable {
    case movie(MovieBlock)
    case album(AlbumBlock)
    case book(BookBlock)
    case vibe(VibeBlock)
    case reading(ReadingBlock)
    case watching(WatchingBlock)
    /// Карточка исполнителя — только в промо «Главной» (задача 64): в ленте её нет.
    case artist(ArtistBlock)

    var id: String {
        switch self {
        case .movie(let b): "movie-\(b.id)"
        case .album(let b): "album-\(b.id)"
        case .book(let b): "book-\(b.id)"
        case .vibe(let b): "vibe-\(b.id)"
        case .reading(let b): "reading-\(b.id)"
        case .watching(let b): "watching-\(b.id)"
        case .artist(let b): "artist-\(b.id)"
        }
    }

    /// Что открывает тап по карточке. Витрина кросс-сервисная, поэтому плеер выбирается
    /// по типу сущности, а не по активному табу: карточка кино включает кино-плеер,
    /// альбом и «Моя Волна» — музыкальный, книги — книжный.
    var player: ShowcasePlayerTarget {
        switch self {
        case .movie(let b):
            .movie(MovieInProgress(id: b.id, still: b.still, title: b.title))
        case .album(let b):
            .music(MusicNowPlaying(id: b.id, cover: b.cover, title: b.title, artist: b.subtitle))
        case .book(let b):
            .book(BookInProgress(id: b.id, cover: b.cover, title: b.title))
        case .vibe:
            // Волна — поток, а не трек: играет настоящий трек её настроения (`MyVibeTracks`).
            .music(MyVibeTracks.random())
        case .reading(let b):
            .book(BookInProgress(id: b.id, cover: b.cover, title: b.title))
        case .watching(let b):
            .movie(MovieInProgress(id: b.id, still: b.still, title: b.title))
        case .artist(let b):
            // Не зовётся: у исполнителя свой экран (`entityRoute`), музыку включает его
            // кнопка «Слушать». Ветка — ради полноты `switch`.
            .music(MusicNowPlaying(id: "artist-\(b.id)", cover: b.picture, title: b.name, artist: b.name))
        }
    }

    /// Название контента блока. Нужно миниатюре: она стала кнопкой, а кнопка без имени
    /// читается VoiceOver именем ассета обложки.
    var title: String {
        switch self {
        case .movie(let b): b.title
        case .album(let b): b.title
        case .book(let b): b.title
        case .vibe(let b): b.title
        case .reading(let b): b.title
        case .watching(let b): b.title
        case .artist(let b): b.name
        }
    }

    /// Вертикальный слот блока в кадре витрины — см. `ShowcaseLayout`.
    var slot: ShowcaseLayout.Slot {
        switch self {
        case .movie: .movie
        case .album: .album
        case .book: .book
        case .vibe: .vibe
        case .reading: .reading
        case .watching: .watching
        // В ленте исполнителя нет — слот музыкальный, как у альбома; по нему ничего
        // не подменяется (`apply` и заготовки ✕ ходят только по блокам ленты).
        case .artist: .album
        }
    }
}

/// Плеер, который открывает карточка, вместе с тем, что в нём показать.
enum ShowcasePlayerTarget {
    case music(MusicNowPlaying)
    case movie(MovieInProgress)
    case book(BookInProgress)
}

// MARK: - Payload'ы блоков

struct MovieBlock {
    let id: String
    let title: String
    let poster: ArtworkSource
    /// Горизонтальный кадр сцены — им живёт чип киноплеера в action bar (правка
    /// пользователя 2026-08-25: раньше туда уходил постер, и портретная картинка
    /// кропалась в чип 88×54). Карточка витрины по-прежнему показывает постер.
    /// Кадра может не быть — тогда сюда кладётся `backdrop`, а в крайнем случае постер.
    let still: ArtworkSource
    /// Однострочная редакционная подпись. У Кинопоиска это поле `shortDescription`.
    let caption: String
    /// Подпись тонируется в цвет постера — в макете градиент уводит текст к его палитре.
    let captionTint: Color
    var synopsis: String? = nil
    /// Начатый фильм — карточка «Продолжить» промо «Главной» (задача 69): тап запускает
    /// киноплеер с места остановки, а не открывает экран тайтла. `nil` — обычная карточка.
    var resume: MovieInProgress? = nil
}

extension MovieBlock {
    /// Карточка «Продолжить» начатого фильма. Id свой — не совпасть с обычным айтемом
    /// того же фильма; лицо — постер, у записи без него — кадр в кадре постера.
    init(continuing movie: MovieInProgress) {
        self.init(
            id: "continue-\(movie.id)",
            title: movie.title,
            poster: movie.poster ?? movie.still,
            still: movie.still,
            caption: "",
            captionTint: .clear,
            resume: movie
        )
    }
}

struct AlbumBlock {
    let id: String
    let cover: ArtworkSource
    let title: String
    let subtitle: String
    /// Фото исполнителя — аватар в подписи альбома промо «Главной» (макет `2537:27595`).
    /// У альбома ленты его нет: карточке оно не нужно.
    var artistPicture: ArtworkSource? = nil
    /// Id исполнителя в Deezer — по нему подпись альбома промо «Главной» открывает его
    /// экран. Нет id — подпись не нажимается.
    var artistID: Int? = nil
}

/// Исполнитель промо «Главной» (задача 64): круг с фото и имя под ним.
struct ArtistBlock: Hashable {
    /// Id исполнителя в Deezer.
    let id: Int
    let name: String
    /// Фото, поднятое до 1000×1000 (`deezerUpscaled`): круг промо — 220 pt.
    let picture: ArtworkSource
}

struct BookBlock {
    let id: String
    let title: String
    /// Плоская обложка, из которой `BookRender` собирает объёмную книгу. Раньше здесь
    /// лежал готовый изометрический PNG из макета, но у живой книги такого рендера нет —
    /// объём строится из обложки (решение 2026-08-23).
    let render: ArtworkSource
    /// Обложка для чипа в action bar. Отдельное поле: у чипа своя геометрия,
    /// и в будущем сюда может лечь другой кроп.
    let cover: ArtworkSource
    let caption: String
    let captionTint: Color
    var synopsis: String? = nil
    /// Последняя открытая книга — карточка «Продолжить» промо «Главной» (задача 69): тап
    /// открывает читалку, а не экран книги. `nil` — обычная карточка.
    var resume: BookInProgress? = nil
}

extension BookBlock {
    /// Карточка «Продолжить» последней открытой книги. Id свой — не совпасть с обычным
    /// айтемом той же книги.
    init(continuing book: BookInProgress) {
        self.init(
            id: "continue-\(book.id)",
            title: book.title,
            render: book.cover,
            cover: book.cover,
            caption: "",
            captionTint: .clear,
            resume: book
        )
    }
}

struct VibeBlock {
    let id: String
    let title: String
    let subtitle: String
    /// Обложка для мини-плеера: у волны нет своей, берём заглушку трека.
    let cover: ArtworkSource
    /// Иллюстрация волны и тон свечения под ней: ✕ сменяет их по кругу.
    var art: VibeArt = .classic
    /// Станция промо «Главной» (задача 65) — лепесток вместо орба. У блока ленты её нет.
    var station: VibePromoStation? = nil
}

/// Иллюстрации «Моей Волны» — чтобы новая волна по ✕ не была той же картинкой
/// (задача пользователя 2026-10-09). Свечение — тот же ассет `vibeColorEllipse`,
/// повёрнутый по оттенку под иллюстрацию.
enum VibeArt: CaseIterable {
    case classic
    case pop

    var glyph: String {
        switch self {
        case .classic: "vibeGlyph"
        case .pop: "vibeGlyphPop"
        }
    }

    /// Сдвиг оттенка свечения. Свечение (266°) на 15° холоднее глифа (281°); под Pop
    /// (349°) держим то же соотношение — 334°, то есть +68°.
    var haloHue: Angle {
        switch self {
        case .classic: .zero
        case .pop: .degrees(68)
        }
    }

    var next: VibeArt {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

struct ReadingBlock {
    let id: String
    let title: String
    let cover: ArtworkSource
    /// Фрагмент книги. Живой текст берётся из Викитеки, иначе мок (решение 2026-08-22).
    let excerpt: String
    let progress: Double
    /// «Осталось 2 дня 5 часов» — срок аренды, пока статичная строка.
    let remaining: String
}

struct WatchingBlock {
    let id: String
    let title: String
    /// Кадр-постер, который показывается, пока не начнёт играть видео.
    let still: ArtworkSource
    /// Имя забандленного клипа без расширения; играет, только когда карточка видима.
    let clip: String
    /// Логотип проекта поверх кадра — в макете он не повёрнут вместе с рамкой.
    let logo: ArtworkSource
    let progress: Double
    let remaining: String
}

// MARK: - Раскладка

/// Геометрия витрины из `figma-screen1.md`. Координаты абсолютные, в системе кадра
/// шириной 402 — карточки в макете наезжают друг на друга и выходят за края экрана,
/// поэтому вертикальный стек с отступами их не воспроизводит.
///
/// Лента — композиция во всю ширину экрана: вся геометрия (слоты, зазоры, X и размеры
/// внутри карточек) умножается на `scale` = `screenWidth / 402` по обеим осям, шрифты
/// и кнопки 40 — нет (правило 4 CLAUDE.md). Числа в `Slot` и в раскладках карточек —
/// координаты макета на 402, множитель применяется в месте расстановки.
enum ShowcaseLayout {
    /// Множитель геометрии ленты: 1 на 402.
    @MainActor
    static var scale: CGFloat { PlusMetrics.widthScale }

    /// Точка и размер макета на текущей ширине экрана.
    @MainActor
    static func scaled(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x * scale, y: point.y * scale)
    }

    @MainActor
    static func scaled(_ size: CGSize) -> CGSize {
        CGSize(width: size.width * scale, height: size.height * scale)
    }

    /// Вертикальный слот блока: `top` — верх бокса в кадре, `height` — его высота
    /// (оба в координатах макета на 402; по ним же блоки отличаются друг от друга —
    /// ключ слота). Высота кадра на экране — `frameHeight`.
    struct Slot {
        let top: CGFloat
        let height: CGFloat

        /// Высота кадра блока на текущей ширине экрана.
        @MainActor
        var frameHeight: CGFloat { height * ShowcaseLayout.scale }

        static let movie = Slot(top: 220.48, height: 298.51)
        static let album = Slot(top: 562, height: 206)
        static let book = Slot(top: 787.96, height: 283.31)
        /// Наезжает на книжный блок: боксы пересекаются из-за ореола, визуально орб
        /// начинается около 1100.
        static let vibe = Slot(top: 1008, height: 316)
        static let reading = Slot(top: 1308.99, height: 272.01)
        /// Вместе с блоком оценки, который тянется до 1960.
        static let watching = Slot(top: 1647, height: 313)
    }

    /// Низ навигации «Главной» (`HomeTopNav`) — от физического верха экрана.
    static var navBottom: CGFloat {
        ServiceTopNavLayout.topSafeArea + ServiceTopNavLayout.rowHeight
    }

    /// Ряд «продолженного потребления» (`RecentlyRow`, задача 71, экран `2713:26782`):
    /// 8 под навигацией, высота 80, до промо 40. Не масштабируются: плитки ряда
    /// фиксированной ширины.
    static let recentlyGap: CGFloat = 8
    /// Ряд ПП (продолженное потребление) — 72 вместо макетных 80 (правка пользователя 2026-10-13).
    static let recentlyHeight: CGFloat = 72
    static let recentlyToPromo: CGFloat = 40
    /// Полоса ряда целиком — на столько промо и всё ниже стоят ниже навигации.
    static var recentlyBand: CGFloat { recentlyGap + recentlyHeight + recentlyToPromo }

    /// Промо-слайдер — под рядом «продолженного». В макете `2532:26618` его отсчёт шёл
    /// от низа навигации; с задачи 71 между ними ряд.
    static var promoTop: CGFloat { navBottom + recentlyBand }
    /// Первая карточка ленты — под промо: зазор, что был под заголовком с врезками
    /// (220.48 − 184.93). Добавленные 2026-10-08 ещё 40 убраны на следующий день
    /// (правки пользователя). В макете промо карточек ниже нет. Ещё на 32 ближе —
    /// правка пользователя 2026-10-10; не из `belowCards`, чтобы ScrollView промо
    /// не обрезал пару ✕/✓. И на 24 дальше — правка пользователя 2026-10-13.
    static let designPromoToFirstBlock: CGFloat = 35.55 - 32 + 24
    @MainActor
    static var promoToFirstBlock: CGFloat { designPromoToFirstBlock * scale }

    /// Зазоры между одиночными блоками ленты меньше на 24 — правка пользователя
    /// 2026-10-10. Зазор промо → первый блок (`promoToFirstBlock`) не затрагивает.
    static let blockGapTrim: CGFloat = 24

    /// Низ последнего блока — от него считается высота прокручиваемого контента.
    @MainActor
    static var contentBottom: CGFloat { (Slot.watching.top + Slot.watching.height) * scale }

    /// Воздух под последним блоком, поверх клиренса нижнего хрома. Без него докрученная
    /// до конца лента упирается последней карточкой прямо в панель действий.
    static let feedBottomPadding: CGFloat = 56

    /// Расстояние от низа предыдущего блока до верха следующего.
    ///
    /// Значения нерегулярные (20…66pt), а два **отрицательные**: орб «Моей Волны»
    /// начинается раньше, чем кончается книжный блок, и карточка чтения наезжает на орб.
    /// Это макет, а не ошибка — сдвигать нельзя. Минус `blockGapTrim` сверху — правка
    /// пользователя, она сильнее макета: наезды становятся глубже.
    ///
    /// Считается именно зазорами, а не абсолютным `offset`: `offset` не влияет на раскладку,
    /// из-за чего все карточки оказывались в одной точке — ломались и каскадное появление,
    /// и параллакс, которым нужна настоящая позиция блока в скролле.
    @MainActor
    static func gap(above slot: Slot, after previous: Slot?) -> CGFloat {
        guard let previous else { return slot.top * scale }
        return (slot.top - (previous.top + previous.height) - blockGapTrim) * scale
    }
}

// MARK: - Демо-данные

extension ShowcaseFeed {
    /// Фото «Аквариума» у Deezer (id 4179081) — аватар подписи мок-альбома промо
    /// и круг мок-исполнителя.
    private static let akvariumPhoto = "https://cdn-images.dzcdn.net/images/artist/7235346cb03b024ce187eca16aad019f/250x250-000000-80-0-0.jpg"

    /// Мок-исполнитель промо — «Аквариум», фото то же, что в подписи мок-альбома, поднятое
    /// до 1000×1000. Он же — артист мок-волны «в стиле артиста» (задача 68).
    private static let mockArtist = ArtistBlock(
        id: 4179081,
        name: "Аквариум",
        picture: Self.akvariumPhoto.deezerUpscaled.map { ArtworkSource.remote($0) } ?? .asset("")
    )

    /// Мок-станция «Моей Волны» ленты. У промо своя — первая станция списка (задача 65).
    private static let mockVibe = VibeBlock(
        id: "my-vibe",
        title: "Моя Волна",
        subtitle: "Атмосферный постпанк, когда внутри пасмурно",
        cover: .asset("mockPlayerCover")
    )

    /// Персональная лента — экран `2004:10701` один в один. До Этапа 7 данные моковые.
    static let personal = ShowcaseFeed(
        // Фолбэк промо — текстом макета: фильм в центре, альбом и книга по бокам.
        promo: [
            .movie(MovieBlock(
                id: "perfect-days",
                title: "Идеальные дни",
                poster: .asset("mockMoviePoster"),
                still: .asset("mockChipMovieStill"),
                caption: "Одинокий уборщик ищет красоту в каждом мгновении. Шедевр Вима Вендерса о магии жизни — и номинант на «Оскар»",
                captionTint: Color(red: 0xA7 / 255, green: 0xCA / 255, blue: 0xC6 / 255)
            )),
            .album(AlbumBlock(
                id: "akvarium",
                cover: .asset("mockAlbumCover"),
                title: "Аквариум",
                subtitle: "Равноденствие",
                // Фото группы у Deezer (id 4179081): без сети — серый круг скелетона.
                artistPicture: URL(string: Self.akvariumPhoto).map { ArtworkSource.remote($0) },
                artistID: 4179081
            )),
            // Книги промо — не та, что в ленте ниже, и их две: без живых книг в круге
            // стояла одна, та же, что в ленте (жалоба 2026-10-09). Подписи — по аннотациям
            // издательств. Оттенок подписи у промо не используется.
            .book(BookBlock(
                id: "zamirovskaya-things",
                title: "Некоторые вещи уже произошли",
                render: .asset("mockBookZamirovskaya"),
                cover: .asset("mockBookZamirovskaya"),
                caption: "Рассказы Татьяны Замировской о катастрофах и о том, как они меняют память, язык и нас самих",
                captionTint: Color(red: 0xBC / 255, green: 0xEB / 255, blue: 0xFB / 255)
            )),
            // Первый круг — фильм, альбом, книга, исполнитель; за ним станция, потом второй
            // круг — книга и волна «в стиле артиста» (`ShowcaseCatalog.publishPromo`).
            // Исполнитель — тот же «Аквариум», что в подписи альбома.
            .artist(Self.mockArtist),
            .vibe(.promo(VibePromoStation.all[0])),
            .book(BookBlock(
                id: "fedorova-35-july",
                title: "35 июля. Но это не точно",
                render: .asset("mockBookFedorova"),
                cover: .asset("mockBookFedorova"),
                caption: "Две повести Ани Фёдоровой о детстве на стыке девяностых и нулевых: бабушка, тамагочи, приволжский город",
                captionTint: Color(red: 0xBC / 255, green: 0xEB / 255, blue: 0xFB / 255)
            )),
            // Волна «в стиле артиста» (задача 68) — мок-исполнитель; у живой — артист
            // из запаса исполнителей круга (`ShowcaseCatalog.pickPromoArtistWave`).
            .vibe(.promo(.artistWave(Self.mockArtist))),
        ],
        blocks: [
            .movie(MovieBlock(
                id: "perfect-days",
                title: "Идеальные дни",
                poster: .asset("mockMoviePoster"),
                still: .asset("mockChipMovieStill"),
                caption: "Обыкновенный уборщик ищет красоту в каждом мгновении. Шедевр Вима Вендерса о магии жизни",
                captionTint: Color(red: 0xA7 / 255, green: 0xCA / 255, blue: 0xC6 / 255)
            )),
            .album(AlbumBlock(
                id: "akvarium",
                cover: .asset("mockAlbumCover"),
                title: "Аквариум",
                subtitle: "Равноденствие"
            )),
            .book(BookBlock(
                id: "graeber-truth",
                title: "Главная тайная истина мира…",
                render: .asset("mockBookGraeberTruth"),
                cover: .asset("mockBookGraeberTruth"),
                caption: "Эссе Дэвида Гребера: мир — то, что мы создаём, и его вполне можно устроить иначе",
                // Светлый тон жёлтой обложки — как у живых книг, где тон берётся с обложки.
                captionTint: Color(red: 0xF6 / 255, green: 0xF1 / 255, blue: 0xB0 / 255)
            )),
            .vibe(Self.mockVibe),
            .reading(ReadingBlock(
                id: "bullshit-jobs",
                title: "Бредовая работа",
                cover: .asset("mockChipBookCover"),
                excerpt: """
                Пиль предполагал, что у рабочих не было другого выбора, кроме как продавать свой труд, \
                но он не учёл важного обстоятельства общинных земель, которая происходила с конца XVIII \
                века, — крестьяне больше не имели доступа к какой-либо земле. Безземельный работник, \
                уволившись с наёмной работы в Манчестере, Ливерпуле или Глазго, просто умер бы от голода. \
                Однако в Западной Австралии обилие пустующих земель (даже с учётом того, что они были \
                отобраны у коренных жителей) означало, что у переселенцев был выбор.
                """,
                progress: 0.36,
                remaining: "Осталось 2 дня 5 часов"
            )),
            .watching(WatchingBlock(
                id: "yura",
                title: "Здесь был Юра",
                still: .asset("mockVideoStill"),
                clip: "yura",
                logo: .asset("mockLogoYura"),
                progress: 0.815,
                remaining: "Осталось 16 мин"
            )),
        ]
    )
}

// MARK: - Пара ✕/✓

extension ShowcaseBlock {
    /// У карточки есть пара ✕/✓, и ✕ меняет её контент (`ShowcaseCatalog.prepareReplacement`).
    var isReplaceable: Bool {
        switch self {
        case .movie, .album, .book, .vibe, .artist: true
        case .reading, .watching: false
        }
    }
}

// MARK: - Картинки ленты

extension ShowcaseBlock {
    /// Всё, что блок покажет картинками, — для прогрева кэша.
    var artworks: [ArtworkSource] {
        switch self {
        // Кадр — не декорация карточки, а картинка чипа киноплеера: без прогрева
        // он въезжает дырой ровно в момент тапа.
        case .movie(let b): [b.poster, b.still]
        case .album(let b): [b.cover] + [b.artistPicture].compactMap { $0 }
        case .book(let b): [b.render, b.cover]
        // У волны «в стиле артиста» промо — и фото артиста (задача 68).
        case .vibe(let b): [b.cover] + [b.station?.artist?.picture].compactMap { $0 }
        case .reading(let b): [b.cover]
        case .watching(let b): [b.still, b.logo]
        case .artist(let b): [b.picture]
        }
    }
}

extension ShowcaseFeed {
    /// Все картинки первого экрана: промо и блоки. По этому списку
    /// сплэш понимает, что витрину можно показывать, — карточка без обложки
    /// и есть то мигание, ради которого заставку заводили.
    var artworks: [ArtworkSource] {
        promo.flatMap(\.artworks) + blocks.flatMap(\.artworks)
    }
}
