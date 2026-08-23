import SwiftUI

/// Сущность, на экран которой можно перейти из витрины.
///
/// Плоская структура, а не ссылка на блок витрины: экран сущности переживает
/// пересборку ленты (живые данные приезжают асинхронно и подменяют блоки),
/// и держать в пути навигации то, что может исчезнуть, нельзя.
struct EntityRef: Hashable {
    var id: String
    var title: String
    var subtitle: String
    var artwork: ArtworkSource
}

/// Куда ведёт тап по карточке витрины. `Hashable` нужен дважды: как значение
/// `NavigationPath` и как `sourceID` зум-перехода — обе стороны перехода
/// адресуются одним и тем же значением, поэтому рассинхрон невозможен.
enum EntityRoute: Hashable {
    case movie(EntityRef)
    case book(EntityRef)
    case album(EntityRef)

    var ref: EntityRef {
        switch self {
        case .movie(let ref), .book(let ref), .album(let ref): ref
        }
    }

    /// Обложка альбома круглая, у фильма и книги — скруглённый прямоугольник.
    var hasRoundArtwork: Bool {
        if case .album = self { return true }
        return false
    }
}

extension ShowcaseBlock {
    /// Экран сущности, который открывает карточка. `nil` — переходить некуда:
    /// у «Моей Волны» нет своей сущности, это генератор потока, а не альбом.
    var entityRoute: EntityRoute? {
        switch self {
        case .movie(let b):
            .movie(EntityRef(id: b.id, title: b.title, subtitle: "", artwork: b.poster))
        case .album(let b):
            .album(EntityRef(id: b.id, title: b.title, subtitle: b.subtitle, artwork: b.cover))
        case .book(let b):
            .book(EntityRef(id: b.id, title: b.title, subtitle: "", artwork: b.cover))
        case .reading(let b):
            .book(EntityRef(id: b.id, title: b.title, subtitle: "", artwork: b.cover))
        case .watching(let b):
            .movie(EntityRef(id: b.id, title: b.title, subtitle: "", artwork: b.still))
        case .vibe:
            nil
        }
    }
}
