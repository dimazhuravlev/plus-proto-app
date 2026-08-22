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
    /// System/iOS Navbar darkBlur — подложка навбара под блюром
    static let navbarDarkBlur = Color(red: 20 / 255, green: 20 / 255, blue: 20 / 255).opacity(0.7) // #141414B2
    /// Плейсхолдер в поле поиска
    static let searchPlaceholder = Color.white.opacity(0.3)
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

    // Таббар
    static let tabBarHeight: CGFloat = 100
    static let tabItemWidth: CGFloat = 60
    static let tabItemHeight: CGFloat = 62
    static let tabIconTile: CGFloat = 40
    /// Зазор между тайлом и лейблом
    static let tabIconLabelGap: CGFloat = 2
    /// Высота градиентной подложки таббара (выступает на 110 над баром)
    static let tabBarUnderlayHeight: CGFloat = 210

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
    /// Блюр фона витрины
    static let backdropBlur: CGFloat = 100
    static let backdropOpacity: CGFloat = 0.4
}

// MARK: - Градиенты

enum PlusGradient {
    /// Подложка таббара: 16 сглаженных стопов чёрного снизу вверх.
    /// Значения из макета — воспроизводятся дословно, линейная интерполяция даёт видимый банд.
    static let tabBarUnderlay = LinearGradient(
        stops: [
            .init(color: .black.opacity(0.90), location: 0.0000),
            .init(color: .black.opacity(0.867), location: 0.1123),
            .init(color: .black.opacity(0.828), location: 0.2050),
            .init(color: .black.opacity(0.783), location: 0.2812),
            .init(color: .black.opacity(0.732), location: 0.3439),
            .init(color: .black.opacity(0.678), location: 0.3960),
            .init(color: .black.opacity(0.619), location: 0.4406),
            .init(color: .black.opacity(0.556), location: 0.4807),
            .init(color: .black.opacity(0.491), location: 0.5193),
            .init(color: .black.opacity(0.424), location: 0.5594),
            .init(color: .black.opacity(0.354), location: 0.6040),
            .init(color: .black.opacity(0.284), location: 0.6561),
            .init(color: .black.opacity(0.212), location: 0.7188),
            .init(color: .black.opacity(0.141), location: 0.7950),
            .init(color: .black.opacity(0.070), location: 0.8877),
            .init(color: .black.opacity(0.000), location: 1.0000),
        ],
        startPoint: .bottom,
        endPoint: .top
    )

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
