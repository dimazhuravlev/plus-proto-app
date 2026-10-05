import SwiftUI

/// Сущность, на экран которой можно перейти из витрины.
///
/// Плоская структура, а не ссылка на блок витрины: экран сущности переживает
/// пересборку ленты (живые данные приезжают асинхронно и подменяют блоки),
/// и держать в пути навигации то, что может исчезнуть, нельзя.
struct EntityRef: Hashable, Codable {
    var id: String
    var title: String
    var subtitle: String
    var artwork: ArtworkSource
}

/// Куда ведёт тап по карточке витрины. `Hashable` нужен дважды: как значение
/// `NavigationPath` и как `sourceID` зум-перехода — обе стороны перехода
/// адресуются одним и тем же значением, поэтому рассинхрон невозможен.
enum EntityRoute: Hashable, Identifiable, Codable {
    case movie(EntityRef)
    case book(EntityRef)
    case album(EntityRef)
    /// Плейлист Deezer — экран по конструкции альбома (`PlaylistScreen`, 2026-10-05).
    /// id — `dz-<id плейлиста>`; `title` — название, `subtitle` — владелец.
    case playlist(EntityRef)
    /// Экраны персон — один экран на три роли (`PersonScreen`, задача 2026-10-04).
    /// id: исполнитель — `dz-<id Deezer>`; режиссёр — `kp-<id персоны Кинопоиска>`
    /// (из съёмочной группы фильма) или `wp-<страница Википедии>` (из выдачи поиска —
    /// тогда персона ищется по имени); писатель — `wp-…` или `name-<имя>` (с экрана книги).
    case artist(EntityRef)
    case director(EntityRef)
    case writer(EntityRef)

    /// Для показа слоем: `fullScreenCover(item:)` требует `Identifiable`.
    var id: String {
        switch self {
        case .movie(let ref): "movie-" + ref.id
        case .book(let ref): "book-" + ref.id
        case .album(let ref): "album-" + ref.id
        case .playlist(let ref): "playlist-" + ref.id
        case .artist(let ref): "artist-" + ref.id
        case .director(let ref): "director-" + ref.id
        case .writer(let ref): "writer-" + ref.id
        }
    }

    var ref: EntityRef {
        switch self {
        case .movie(let ref), .book(let ref), .album(let ref), .playlist(let ref),
             .artist(let ref), .director(let ref), .writer(let ref): ref
        }
    }

    /// Карточка тайтла показывается **слоем поверх хрома**, а не пушем: по макету
    /// у неё своя панель действий во всю ширину, и таббар с action bar она перекрывает
    /// собой. Пушем это недостижимо — хром лежит слоем выше контента табов, и экран,
    /// запушенный внутрь стека, всегда оказывается под ним.
    ///
    /// Альбом и книга остаются обычным пушем: они хром показывают.
    var coversChrome: Bool {
        if case .movie = self { return true }
        return false
    }

    /// Обложка альбома круглая, у фильма и книги — скруглённый прямоугольник;
    /// фото персоны — круг.
    var hasRoundArtwork: Bool {
        switch self {
        case .album, .playlist, .artist, .director, .writer: true
        case .movie, .book: false
        }
    }
}

extension MovieSimilarTitle {
    /// Экран тайтла из блока «Похожее». Формат id — витринный `kp-<id>`: по нему
    /// `EntityRef.kinopoiskID` достаёт числовой id, и экран грузит живые детали.
    /// Без постера перехода нет: обложка экрана обязательна, а подставлять чужой
    /// бандленный кадр нечестно — прецедент «переходить некуда» уже есть у «Моей Волны».
    var route: EntityRoute? {
        guard let poster else { return nil }
        return .movie(EntityRef(id: "kp-\(id)", title: title, subtitle: "", artwork: .remote(poster)))
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
