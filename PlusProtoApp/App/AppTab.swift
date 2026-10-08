import SwiftUI

/// Пять табов супераппа. Порядок — как в макете (слева направо). Пятый — общая
/// коллекция «Моё» (макет `2351:17327`): она встала на место таба Алисы, которого
/// больше нет (решение пользователя 2026-10-04).
enum AppTab: Int, CaseIterable, Identifiable {
    case plus, music, kinopoisk, books, collection

    var id: Int { rawValue }

    var title: String {
        switch self {
        // «Главная», а не «Плюс» (правка пользователя 2026-10-08).
        case .plus: "Главная"
        case .music: "Музыка"
        case .kinopoisk: "Кинопоиск"
        case .books: "Книги"
        case .collection: "Моё"
        }
    }

    /// Вектор глифа, template — форма у активного и неактивного состояния одна,
    /// различается только заливка (её даёт `TabBarItem`). У «Моего» — сердце
    /// (макеты `2463:79197` / `2463:79223`, правка пользователя 2026-10-04; прежде
    /// в тайле стояли две обложки коллекции).
    var glyphAsset: String {
        switch self {
        case .plus: "tabGlyphPlus"
        case .music: "tabGlyphMusic"
        case .kinopoisk: "tabGlyphKinopoisk"
        case .books: "tabGlyphBooks"
        case .collection: "tabGlyphCollection"
        }
    }

    /// Размер и положение глифа внутри тайла 40×40 — замеры инстансов в мастере таббара
    /// (`2004:9396`/`9406`/`9413`/`9420`/`9427`). Глифы не центрированы и у трёх табов
    /// упираются в край тайла, поэтому тайл их подрезает — это и есть вид из макета.
    ///
    /// У Плюса в таббаре стоит не `PLUS-SYMBOL` (круг 22×22) из мастер-компонента, а
    /// переопределённый `PLUS-SYMBOL_PLUS-SHAPE` — диагональный крест 32.53×31.25.
    var glyphFrame: (size: CGSize, origin: CGPoint) {
        switch self {
        case .plus:
            (CGSize(width: 32.532, height: 31.249), CGPoint(x: 7.468, y: 0))
        case .music:
            (CGSize(width: 32.5, height: 32.5), CGPoint(x: 3.75, y: 3.75))
        case .kinopoisk:
            (CGSize(width: 28.75, height: 28.75), CGPoint(x: 11.25, y: 5.625))
        case .books:
            (CGSize(width: 28.75, height: 32.5), CGPoint(x: 0, y: 7.5))
        case .collection:
            // Сердце — иконка 32 по центру тайла (макеты `2463:79197` / `2463:79223`,
            // правка пользователя 2026-10-08; прежде бокс был растянут ×1.25 и сдвинут
            // вправо, и тайл срезал сердцу правый край).
            (CGSize(width: 32, height: 32), CGPoint(x: 4, y: 4))
        }
    }
}

#if DEBUG
extension AppTab {
    /// Разбор аргумента запуска `-debugTab` (см. `AppNavigationState.init`).
    init?(debugKey: String) {
        switch debugKey {
        case "plus": self = .plus
        case "music": self = .music
        case "kinopoisk": self = .kinopoisk
        case "books": self = .books
        case "collection": self = .collection
        default: return nil
        }
    }
}
#endif
