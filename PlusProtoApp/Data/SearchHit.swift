import SwiftUI

/// Строка единой выдачи. Сервисы разные, строка одна: дальше UI не знает, из какого
/// API приехал результат, и секции отличаются только заголовком и порядком.
struct SearchHit: Identifiable, Hashable {
    /// Что это. Порядок кейсов — порядок строк внутри музыкальной секции.
    enum Kind: Hashable {
        case track
        case album
        case artist
        case movie
        case book

        /// Круглая миниатюра только у исполнителя — как у аватара в мини-плеере.
        var isRoundArtwork: Bool { self == .artist }
    }

    /// Уникален в пределах выдачи: id доменов между собой пересекаются (у Deezer
    /// и Кинопоиска это просто целые числа), поэтому в ключ входит и тип.
    let id: String
    let kind: Kind
    let title: String
    /// Вторая строка: исполнитель у трека и альбома, год и жанр у фильма, автор у книги.
    let subtitle: String
    let artwork: ArtworkSource?
    /// Куда ведёт тап. `nil` — строка не нажимается: у исполнителя своего экрана
    /// в проекте нет вовсе (в `EntityRoute` только фильм, книга и альбом).
    let route: EntityRoute?
}
