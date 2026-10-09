import SwiftUI

// MARK: - Цвета

/// Палитра из Figma. Почти вся нейтралка — белый с прозрачностью;
/// литеральных хексов ровно два: акцент Плюса и заливка навбара.
extension Color {
    /// Fill/One — основной текст, активный лейбл таба, home indicator
    static let fillOne = Color.white
    /// Fill/Six — неактивный лейбл таба
    static let fillSix = Color.white.opacity(0.4)
    /// Fill/Subtitle — вторичный текст (исполнитель в мини-плеере)
    static let fillSubtitle = Color.white.opacity(0.5)
    /// Fill/Four — текстовые блоки длиннее двух строк: текст читалки, описание книги.
    /// Один из четырёх цветов текста по правилам типографики UI kit (`7529:2161`).
    static let fillFour = Color.white.opacity(0.8)
    /// Fill/Nine — бордеры стеклянных поверхностей (0.66pt)
    static let fillNine = Color.white.opacity(0.08)
    /// Fill/Ten — заливка прогресса в мини-плеере
    static let fillTen = Color.white.opacity(0.06)
    /// Buttons/Primary — фон круглых кнопок и тайлов иконок
    static let buttonsPrimary = Color.white.opacity(0.1)
    /// Buttons/Secondary — фон чипов в блоке оценки
    static let buttonsSecondary = Color.white.opacity(0.08)
    /// Plus/Solid One — акцент бренда: заливка прогресс-баров
    static let plusAccent = Color(red: 216 / 255, green: 141 / 255, blue: 252 / 255) // #D88DFC
    /// Movies — фиолетовый кино: лейбл тайтла у меты, активный чипс фильтров выдачи
    static let moviesAccent = Color(red: 163 / 255, green: 50 / 255, blue: 255 / 255) // #A332FF
    /// System/iOS Navbar darkBlur — подложка навбара под блюром
    static let navbarDarkBlur = Color(red: 20 / 255, green: 20 / 255, blue: 20 / 255).opacity(0.7) // #141414B2
    /// Плейсхолдер в поле поиска
    static let searchPlaceholder = Color.white.opacity(0.3)
    /// Лупа в поле поиска — приглушена, ярче плейсхолдера, но не белая.
    /// Замер по изолированному рендеру `2001:110987` на фоне канваса #444:
    /// глиф (171,171,171) поверх пилюли (87,87,87) → альфа 0.50.
    static let searchIcon = Color.white.opacity(0.5)
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

/// Отступы и размеры из макета. Ширина холста — 402 (iPhone 16 Pro).
enum PlusMetrics {
    static let designWidth: CGFloat = 402

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
    static let tabBarUnderlay = bottomUnderlay(peak: 0.90)

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

    /// Заливка глифа неактивного таба — белый с падающей прозрачностью, поверх ещё 0.7 общей непрозрачности
    static let inactiveTabGlyph = LinearGradient(
        colors: [.white.opacity(0.5), .white.opacity(0.25)],
        startPoint: .topTrailing,
        endPoint: .bottomLeading
    )
}
