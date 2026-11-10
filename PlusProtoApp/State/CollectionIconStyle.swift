import Foundation

/// Иконка кнопки «в коллекцию» (задача пользователя 2026-11-10): у музыки, кино и книг
/// кнопка одна — «+», добавленное — галочка, тем же кросс-попом; «Не нравится» в плеере
/// музыки — крест вместо перечёркнутого сердца. Прежний вариант — сердце у музыки, книг
/// и персон, закладка у кино — остаётся для сравнения.
///
/// Выбор — дебаг-меню «Общее» (ключ `collectionIconStyle`), на один запуск — аргументом
/// `-collectionIconStyle legacy`. Читают его глифы (`LikeGlyph`, `BookmarkGlyph`) и плеер
/// музыки — экраны с кнопками ничего о нём не знают.
enum CollectionIconStyle: String, CaseIterable, Identifiable {
    /// Сердце у музыки, книг и персон, закладка у кино; «Не нравится» — перечёркнутое сердце.
    case legacy
    /// Везде «+» → галочка; «Не нравится» — крест.
    case plus

    static let storageKey = "collectionIconStyle"
    static let defaultStyle: CollectionIconStyle = .plus

    /// Выбор вне `body` — для шторки действий: её пункты собираются в момент показа.
    static var current: CollectionIconStyle {
        UserDefaults.standard.string(forKey: storageKey).flatMap(Self.init(rawValue:)) ?? defaultStyle
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .legacy: "Текущие"
        case .plus: "Везде «+»"
        }
    }
}
