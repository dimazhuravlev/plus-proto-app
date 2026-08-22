import SwiftUI

// MARK: - Модель витрины

/// Витрина «Плюс» задумана динамической: под событие и контекст меняются заголовок,
/// набор блоков, их содержание и фон (решение 2026-08-22). Поэтому экран собирается
/// из модели, а не из зашитой вёрстки — два экрана в Figma это одна витрина
/// в двух состояниях.
///
/// Порядок блоков и динамику заголовка пока не проектируем: `.personal` повторяет
/// экран `2004:10701` один в один.
struct ShowcaseFeed {
    let headline: ShowcaseHeadline
    let blocks: [ShowcaseBlock]
    /// Обложка, из которой строится фон экрана. По решению — кавер первого блока витрины.
    let backdrop: ArtworkSource
}

/// Заголовок с врезками: между словами стоят повёрнутые миниатюры сущностей,
/// о которых идёт речь (`2004:10773`).
struct ShowcaseHeadline {
    let text: String
    /// Врезки позиционируются абсолютно поверх текста — в макете они повёрнуты,
    /// а повернуть вложение внутри `Text` нельзя.
    let chips: [ShowcaseHeadlineChip]
}

struct ShowcaseHeadlineChip: Identifiable {
    enum Kind {
        /// Круглый аватар исполнителя
        case avatar
        /// Постер фильма со скруглением и рамкой
        case poster
        /// Обложка книги с корешком
        case book
    }

    let id = UUID()
    let kind: Kind
    let artwork: ArtworkSource
    let size: CGSize
    /// Левый верхний угол в координатах кадра витрины (ширина 402)
    let origin: CGPoint
    let rotation: Angle
}

/// Блок ленты. Каждый несёт свой payload и знает свою геометрию в макете.
enum ShowcaseBlock: Identifiable {
    case movie(MovieBlock)
    case album(AlbumBlock)
    case book(BookBlock)
    case vibe(VibeBlock)
    case reading(ReadingBlock)
    case watching(WatchingBlock)

    var id: String {
        switch self {
        case .movie(let b): "movie-\(b.id)"
        case .album(let b): "album-\(b.id)"
        case .book(let b): "book-\(b.id)"
        case .vibe(let b): "vibe-\(b.id)"
        case .reading(let b): "reading-\(b.id)"
        case .watching(let b): "watching-\(b.id)"
        }
    }

    /// Что открывает тап по карточке. Витрина кросс-сервисная, поэтому плеер выбирается
    /// по типу сущности, а не по активному табу: карточка кино включает кино-плеер,
    /// альбом и «Моя Волна» — музыкальный, книги — книжный.
    var player: ShowcasePlayerTarget {
        switch self {
        case .movie(let b):
            .movie(MovieInProgress(id: b.id, still: b.poster, title: b.title))
        case .album(let b):
            .music(MusicNowPlaying(id: b.id, cover: b.cover, title: b.title, artist: b.subtitle))
        case .book(let b):
            .book(BookInProgress(id: b.id, cover: b.cover, title: b.title))
        case .vibe(let b):
            .music(MusicNowPlaying(id: b.id, cover: b.cover, title: b.title, artist: b.subtitle))
        case .reading(let b):
            .book(BookInProgress(id: b.id, cover: b.cover, title: b.title))
        case .watching(let b):
            .movie(MovieInProgress(id: b.id, still: b.still, title: b.title))
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
    /// Однострочная редакционная подпись. У Кинопоиска это поле `shortDescription`.
    let caption: String
    /// Подпись тонируется в цвет постера — в макете градиент уводит текст к его палитре.
    let captionTint: Color
}

struct AlbumBlock {
    let id: String
    let cover: ArtworkSource
    let title: String
    let subtitle: String
}

struct BookBlock {
    let id: String
    let title: String
    /// Изометрическая книга — плоский PNG: пять слоёв со skew в SwiftUI не окупаются.
    let render: ArtworkSource
    /// Плоская обложка для чипа в action bar: изометрический рендер туда не годится.
    let cover: ArtworkSource
    let caption: String
    let captionTint: Color
}

struct VibeBlock {
    let id: String
    let title: String
    let subtitle: String
    /// Обложка для мини-плеера: у волны нет своей, берём заглушку трека.
    let cover: ArtworkSource
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
enum ShowcaseLayout {
    static let designWidth: CGFloat = PlusMetrics.designWidth

    /// Вертикальный слот блока: `top` — верх бокса в кадре, `height` — его высота.
    struct Slot {
        let top: CGFloat
        let height: CGFloat

        static let header = Slot(top: 70.79, height: 114.14)
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

    /// Низ последнего блока — от него считается высота прокручиваемого контента.
    static let contentBottom: CGFloat = Slot.watching.top + Slot.watching.height

    /// Расстояние от низа предыдущего блока до верха следующего.
    ///
    /// Значения нерегулярные (20…66pt), а два **отрицательные**: орб «Моей Волны»
    /// начинается раньше, чем кончается книжный блок, и карточка чтения наезжает на орб.
    /// Это макет, а не ошибка — сдвигать нельзя.
    ///
    /// Считается именно зазорами, а не абсолютным `offset`: `offset` не влияет на раскладку,
    /// из-за чего все карточки оказывались в одной точке — ломались и каскадное появление,
    /// и параллакс, которым нужна настоящая позиция блока в скролле.
    static func gap(above slot: Slot, after previous: Slot?) -> CGFloat {
        guard let previous else { return slot.top }
        return slot.top - (previous.top + previous.height)
    }

    /// Фон: копия обложки шириной в два экрана, размытая и приглушённая (§0).
    enum Backdrop {
        static let size = CGSize(width: 804, height: 2269)
        static let origin = CGPoint(x: -201, y: -81)
        static let blur: CGFloat = PlusMetrics.backdropBlur
        static let opacity: CGFloat = PlusMetrics.backdropOpacity
    }
}

// MARK: - Демо-данные

extension ShowcaseFeed {
    /// Персональная лента — экран `2004:10701` один в один. До Этапа 7 данные моковые.
    static let personal = ShowcaseFeed(
        headline: ShowcaseHeadline(
            // Переносы и зазоры как в макете: `\n` фиксирует разбиение (автоперенос
            // его не повторит), а пробелы держат место под врезки. Ширина подобрана
            // замером: U+2007 (figure space) на кегле 32 даёт ~18pt, U+2009 — ~6.4pt.
            // Под аватар 36pt — два широких, под постер и книгу — широкий плюс тонкий.
            text: "Тебе нравится \u{2007}\u{2007} Joy\nDivision, \u{2007}\u{2009}\u{2009} Балабанов\nи \u{2007}\u{2009}\u{2009} Дэвид Гребер",
            chips: [
                ShowcaseHeadlineChip(
                    kind: .avatar,
                    artwork: .asset("mockAvatar"),
                    size: CGSize(width: 36, height: 36),
                    origin: CGPoint(x: 244.79, y: 73.30),
                    rotation: .degrees(-4)
                ),
                ShowcaseHeadlineChip(
                    kind: .poster,
                    artwork: .asset("mockChipPoster"),
                    size: CGSize(width: 29, height: 40),
                    origin: CGPoint(x: 152.80, y: 103.86),
                    rotation: .degrees(5)
                ),
                ShowcaseHeadlineChip(
                    kind: .book,
                    artwork: .asset("mockChipBook"),
                    size: CGSize(width: 28, height: 41),
                    origin: CGPoint(x: 47.60, y: 144.03),
                    rotation: .degrees(-4)
                ),
            ]
        ),
        blocks: [
            .movie(MovieBlock(
                id: "perfect-days",
                title: "Идеальные дни",
                poster: .asset("mockMoviePoster"),
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
                id: "technofeudalism",
                title: "Технофеодализм",
                render: .asset("mockBookIsometric"),
                cover: .asset("mockBookTechno"),
                caption: "Что пришло на смену капитализму и как это изменило мир? Новый взгляд на экономику",
                captionTint: Color(red: 0xBC / 255, green: 0xEB / 255, blue: 0xFB / 255)
            )),
            .vibe(VibeBlock(
                id: "my-vibe",
                title: "Моя Волна",
                subtitle: "Атмосферный постпанк, когда внутри пасмурно",
                cover: .asset("mockPlayerCover")
            )),
            .reading(ReadingBlock(
                id: "bullshit-jobs",
                title: "Бредовая работа",
                cover: .asset("mockBookMini"),
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
        ],
        backdrop: .asset("mockBgCollage")
    )
}
