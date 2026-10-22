import SwiftUI

/// Вид выдачи поиска — переключатель дебаг-меню (задача пользователя 2026-10-05).
/// Хранится в `UserDefaults` и переживает перезапуск; на один запуск его подменяет
/// аргумент `-searchResultsStyle masonry` (docs/DEBUG.md).
enum SearchResultsStyle: String, CaseIterable, Identifiable {
    /// Карусели по разделам — первая версия (макет `2118:17378`)
    case carousels
    /// Сетка вперемешку с фильтрами — вторая версия (макет `2479:24822`)
    case masonry

    static let storageKey = "searchResultsStyle"
    /// По умолчанию — единая лента (правка пользователя 2026-10-12); выбор в дебаг-меню
    /// сохраняется и перекрывает умолчание.
    static let defaultStyle: SearchResultsStyle = .masonry

    var id: Self { self }

    var title: String {
        switch self {
        case .carousels: "Карусели по разделам"
        case .masonry: "Единая лента выдачи"
        }
    }
}
