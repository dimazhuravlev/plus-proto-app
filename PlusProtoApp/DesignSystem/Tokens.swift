import SwiftUI

// MARK: - Цвета

/// Палитра — переменные ДС «🌈 Стили» (`lsTLftjJkiuftLZkNqlO7k`, страница `29:5565`) ровно:
/// коллекция Theme в режиме Dark и стиль YaPS/Accent Color (решение пользователя 2026-10-17).
/// Имя — группа и имя переменной Фигмы: `Fill/Seven` → `fillSeven`, `System/iOS Navbar
/// darkBlur` → `systemIOSNavbarDarkBlur`. Значения — то, во что в Dark резолвятся алиасы
/// на константы `.Color constants` (Monochrome/White-30, Accent/Sugar Grape…), — они в
/// комментариях. Градиенты в палитру не входят: вынесенные живут в `PlusGradient`,
/// остальные — у своих компонентов.
extension Color {
    // MARK: Accent

    /// Accent/Primary — Accent/Sugar Grape. Активный чипс фильтров выдачи, лейбл тайтла
    /// у меты, «нравится».
    static let accentPrimary = Color(hex: 0xA332FF)
    /// Accent/Secondary — Accent/Sugar Grape
    static let accentSecondary = Color(hex: 0xA332FF)

    // MARK: Fill

    /// Fill/One — Monochrome/White. Основной текст, иконки.
    static let fillOne = Color.white
    /// Fill/Two — Monochrome/Snow
    static let fillTwo = Color(hex: 0xF2F2F2)
    /// Fill/Three — Monochrome/Platinum
    static let fillThree = Color(hex: 0xE6E6E6)
    /// Fill/Four — Monochrome/White-80. Текстовые блоки длиннее двух строк (UI kit `7529:2161`).
    static let fillFour = Color.white.opacity(0.8)
    /// Fill/Five — Monochrome/White-60. Вторичные иконки строк треков.
    static let fillFive = Color.white.opacity(0.6)
    /// Fill/Six — Monochrome/White-40. Неактивный лейбл таба.
    static let fillSix = Color.white.opacity(0.4)
    /// Fill/Seven — Monochrome/White-30. Плейсхолдер поиска, бейдж explicit, разделитель меты.
    static let fillSeven = Color.white.opacity(0.3)
    /// Fill/Eight — Monochrome/White-15. Разделители, бордеры виджетов.
    static let fillEight = Color.white.opacity(0.15)
    /// Fill/Nine — Monochrome/White-8. Бордеры стекла и обложек, скелетоны.
    static let fillNine = Color.white.opacity(0.08)
    /// Fill/Ten — Monochrome/White-6. Заливка прогресса мини-плеера.
    static let fillTen = Color.white.opacity(0.06)
    /// Fill/Eleven — Monochrome/White-0
    static let fillEleven = Color.white.opacity(0)
    /// Fill/Subtitle — Monochrome/White-50. Вторичный текст, лупа поиска.
    static let fillSubtitle = Color.white.opacity(0.5)
    /// Fill/Inverted — Monochrome/Black. Текст и иконки на белых поверхностях.
    static let fillInverted = Color.black

    // MARK: Surface

    /// Surface/One — Monochrome/Black. Холст экранов.
    static let surfaceOne = Color.black
    /// Surface/Two — Monochrome/Charcoal
    static let surfaceTwo = Color(hex: 0x141414)
    /// Surface/Three — Monochrome/Gray
    static let surfaceThree = Color(hex: 0x333333)
    /// Surface/Four — Monochrome/Graphitic
    static let surfaceFour = Color(hex: 0x1F1F1F)
    /// Surface/Five — Monochrome/Gray-50
    static let surfaceFive = Color(hex: 0x333333).opacity(0.5)
    /// Surface/Highlight — Monochrome/White-6
    static let surfaceHighlight = Color.white.opacity(0.06)
    /// Surface/Inverted — Monochrome/White
    static let surfaceInverted = Color.white

    // MARK: Buttons

    /// Buttons/Secondary — Monochrome/White-8. Фон чипов блока оценки.
    static let buttonsSecondary = Color.white.opacity(0.08)
    /// Buttons/Inverted — Monochrome/White. Белые кнопки: ▶ «Моей волны», выбранный чип оценки.
    static let buttonsInverted = Color.white
    /// Buttons/Extra One — Monochrome/Graphitic
    static let buttonsExtraOne = Color(hex: 0x1F1F1F)
    /// Buttons/Extra Two — Monochrome/White-8
    static let buttonsExtraTwo = Color.white.opacity(0.08)
    /// Buttons/Extra Three — Monochrome/Graphitic-95
    static let buttonsExtraThree = Color(hex: 0x1F1F1F).opacity(0.95)

    // MARK: System

    /// System/Hint — Accent/Blue Lagoon
    static let systemHint = Color(hex: 0x3A71F9)
    /// System/Error — Accent/Permanent Geranium Lake
    static let systemError = Color(hex: 0xE5312E)
    /// System/Bright Red — Accent/Red
    static let systemBrightRed = Color(hex: 0xFF0000)
    /// System/So-so — Monochrome/Light Gray
    static let systemSoSo = Color(hex: 0x777777)
    /// System/Success — Accent/American Green
    static let systemSuccess = Color(hex: 0x3BB33B)
    /// System/iOS Navbar One — Monochrome/Charcoal-90
    static let systemIOSNavbarOne = Color(hex: 0x141414).opacity(0.9)
    /// System/iOS Navbar Two — Monochrome/Black
    static let systemIOSNavbarTwo = Color.black
    /// System/iOS Navbar darkBlur — Monochrome/Charcoal-70
    static let systemIOSNavbarDarkBlur = Color(hex: 0x141414).opacity(0.7)
    /// System/Android Navbar One — Monochrome/Black
    static let systemAndroidNavbarOne = Color.black

    // MARK: Plus

    /// Plus/Solid One — Accent/Orchid. Акцент Плюса: заливка прогресс-баров.
    static let plusSolidOne = Color(hex: 0xD88DFC)
    /// Plus/Solid Two — Accent/Dark Orchid
    static let plusSolidTwo = Color(hex: 0x8F05BC)

    // MARK: YaPS

    /// YaPS/Accent Color — Accent/Orchid (стиль, привязанный к переменной)
    static let yapsAccentColor = Color(hex: 0xD88DFC)

    // MARK: Вне палитры

    /// Buttons/Primary — белый 10 %: фон стекла, круглых кнопок и тайлов. В коллекции Theme
    /// «Стилей» такой переменной нет, а макеты на неё ссылаются (переменная прежней версии
    /// ДС) — держим, пока ДС не скажет, чем её заменить.
    static let buttonsPrimary = Color.white.opacity(0.1)
}

extension Color {
    /// Цвет по хексу макета `0xRRGGBB` — палитра выше и палитры станций «Моей волны».
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Геометрия

/// Радиусы из макета. Значения сырые — в Figma переменных для них нет.
enum PlusRadius {
    /// Тайл иконки таба 40×40
    static let iconTile: CGFloat = 14
    /// Пилюли action bar высотой 60
    static let pill: CGFloat = 32
    /// Обложки карточек в ленте
    static let card: CGFloat = 12
    /// Стеклянный блок карточки «продолжить чтение»
    static let readerBlock: CGFloat = 16
    /// Внешний радиус чипа кино в action bar (88×54)
    static let movieChip: CGFloat = 8
    /// Чип книги (44×60) и внутренний кадр чипа кино
    static let bookChip: CGFloat = 4
    /// Прогресс-бары
    static let progress: CGFloat = 8
}

/// Отступы и размеры из макета. Ширина холста — 402 (iPhone 17 Pro).
enum PlusMetrics {
    /// База макета: все числа Figma сняты на 402 pt. Не ширина экрана — для неё `screenWidth`.
    static let designWidth: CGFloat = 402

    private static var cachedScreenWidth: CGFloat?

    /// Ширина экрана устройства — константа процесса (приложение заперто в портрете).
    /// От неё считается адаптивная вёрстка (правила 2 и 4 CLAUDE.md): размер вью,
    /// от которого зависит её же раскладка, не читаем.
    ///
    /// Источник — окно-сцена (`effectiveGeometry.coordinateSpace.bounds`), ключевое окно не нужно;
    /// `min(width, height)` — страховка портрета. Нет сцены (самый ранний кадр) —
    /// `designWidth`, и этот фолбэк не кэшируется: следующий вызов спросит сцену снова.
    /// Изоляция: `@MainActor` — `UIApplication.shared` главного потока; все потребители — вью.
    @MainActor
    static var screenWidth: CGFloat {
        if let cachedScreenWidth { return cachedScreenWidth }
        guard let bounds = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.effectiveGeometry.coordinateSpace.bounds
        else { return designWidth }
        let width = min(bounds.width, bounds.height)
        cachedScreenWidth = width
        return width
    }

    /// `screenWidth / designWidth` — множитель для композиций, которые масштабируются
    /// целиком (геометрия, не шрифты). На 402 — 1. Карусели и сетки считают через
    /// `CarouselFit` / `PlusGrid` (поля и зазоры у них постоянные).
    @MainActor
    static var widthScale: CGFloat { screenWidth / designWidth }

    /// Горизонтальные поля экрана: хедер, ряд табов, action bar
    static let screenMargin: CGFloat = 24

    /// Шеврон заголовка секции ниже центра строки на 2pt — к средней линии строчных
    /// букв, а не к центру кегля (правка пользователя 2026-10-03, «опустить на 2px»).
    /// Сдвигом отрисовки: раскладка заголовка не меняется. Во всех заголовках с шевроном.
    static let headerChevronDrop: CGFloat = 2

    // Таббар
    static let tabBarHeight: CGFloat = 100
    static let tabItemWidth: CGFloat = 60
    static let tabItemHeight: CGFloat = 62
    static let tabIconTile: CGFloat = 40
    /// Зазор между тайлом и лейблом
    static let tabIconLabelGap: CGFloat = 2
    /// Высота градиентной подложки нижнего хрома — **общая** у таббара и панели
    /// кнопок карточки тайтла (правка пользователя 2026-08-25: было 210 у таббара
    /// и 176 у панели, теперь одно число на обе).
    static let bottomUnderlayHeight: CGFloat = 140

    // Action bar
    static let actionBarHeight: CGFloat = 60
    /// Зазор между широким и компактным элементами
    static let actionBarGap: CGFloat = 8
    /// Компактные поиск и музплеер — всегда круг
    static let actionBarCompact: CGFloat = 60
    static let miniPlayerCover: CGFloat = 48

    // Кнопки на карточках
    static let circleButton: CGFloat = 40
    /// Зазор в паре ♥/✕
    static let circleButtonGap: CGFloat = 6

    // Стекло
    static let hairline: CGFloat = 0.66
    /// Блюр подложки пилюль
    static let glassBlur: CGFloat = 35
    /// Блюр круглых кнопок и стеклянных блоков
    static let buttonBlur: CGFloat = 20
    /// Блюр ambilight-ореола за обложкой
    static let ambilightBlur: CGFloat = 28
}

// MARK: - Градиенты

enum PlusGradient {
    /// Подложка нижнего хрома: 16 сглаженных стопов чёрного снизу вверх.
    /// Значения из макета — воспроизводятся дословно, линейная интерполяция даёт
    /// видимый банд. Доли берутся от `peak`, поэтому форма кривой у всех подложек
    /// одна, а глубина затемнения своя.
    static func bottomUnderlay(peak: Double) -> LinearGradient {
        LinearGradient(
            stops: underlayShares.map { share, location in
                .init(color: .black.opacity(peak * share), location: location)
            },
            startPoint: .bottom,
            endPoint: .top
        )
    }

    /// Доля от пика и позиция стопа. Пик исходного макета — 0.90.
    private static let underlayShares: [(Double, CGFloat)] = [
        (1.0000, 0.0000), (0.9633, 0.1123), (0.9200, 0.2050), (0.8700, 0.2812),
        (0.8133, 0.3439), (0.7533, 0.3960), (0.6878, 0.4406), (0.6178, 0.4807),
        (0.5456, 0.5193), (0.4711, 0.5594), (0.3933, 0.6040), (0.3156, 0.6561),
        (0.2356, 0.7188), (0.1567, 0.7950), (0.0778, 0.8877), (0.0000, 1.0000),
    ]

    /// Подложка таббара — исходная глубина макета.
    static let tabBarUnderlayPeak: Double = 0.90
    static let tabBarUnderlay = bottomUnderlay(peak: tabBarUnderlayPeak)

    /// Заливка глифа активного таба — диагональный градиент слева-сверху вниз-вправо
    static let activeTabGlyph = LinearGradient(
        stops: [
            .init(color: Color(red: 0xE2 / 255, green: 0x69 / 255, blue: 0xE1 / 255), location: 0.0),
            .init(color: Color(red: 0x89 / 255, green: 0x3B / 255, blue: 0xBA / 255), location: 0.4),
            .init(color: Color(red: 0xF1 / 255, green: 0xAF / 255, blue: 0xE0 / 255), location: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Заливка глифа неактивного таба — белый с падающей прозрачностью, поверх ещё 0.9 общей непрозрачности (макет обновлён 2026-10-12)
    static let inactiveTabGlyph = LinearGradient(
        colors: [.white.opacity(0.5), .white.opacity(0.25)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}
