import Foundation

/// Сущность, которой делятся: то, что рисует карточка экрана шеринга (`ShareOverlay`).
/// Экраны собирают её фабриками ниже из того, что уже знают, — детали ещё не пришли,
/// берём название и обложку из `EntityRef`, подпись пустая (`nil`).
struct ShareableEntity {
    /// Форма обложки на карточке — как у сущности в коллекции «Моё».
    enum Shape: Equatable {
        /// Альбом, плейлист
        case square
        /// Исполнитель
        case circle
        /// Фильм: постер 2:3
        case poster
        /// Книга: обложка своих пропорций (`nil` — пока неизвестны), с блоком страниц
        case book(aspect: CGFloat?)
    }

    let title: String
    /// Исполнитель, владелец плейлиста, автор
    let subtitle: String?
    let year: String?
    let cover: ArtworkSource?
    /// Аватар в мета-строке — только у альбома (фото исполнителя)
    let avatar: ArtworkSource?
    let shape: Shape

    /// Под обложкой есть мета-строка (подпись, год или аватар).
    var hasMetaRow: Bool { subtitle != nil || year != nil || avatar != nil }

    static func album(
        title: String,
        artist: String,
        year: String?,
        cover: ArtworkSource?,
        artistPicture: ArtworkSource?
    ) -> ShareableEntity {
        ShareableEntity(
            title: title,
            subtitle: artist.isEmpty ? nil : artist,
            year: year,
            cover: cover,
            avatar: artistPicture,
            shape: .square
        )
    }

    static func playlist(title: String, owner: String, cover: ArtworkSource?) -> ShareableEntity {
        ShareableEntity(
            title: title,
            subtitle: owner.isEmpty ? nil : owner,
            year: nil,
            cover: cover,
            avatar: nil,
            shape: .square
        )
    }

    static func book(
        title: String,
        author: String,
        year: String?,
        cover: ArtworkSource?,
        aspect: CGFloat?
    ) -> ShareableEntity {
        ShareableEntity(
            title: title,
            subtitle: author.isEmpty ? nil : author,
            year: year,
            cover: cover,
            avatar: nil,
            shape: .book(aspect: aspect)
        )
    }

    static func movie(title: String, year: String?, poster: ArtworkSource?) -> ShareableEntity {
        ShareableEntity(
            title: title,
            subtitle: nil,
            year: year,
            cover: poster,
            avatar: nil,
            shape: .poster
        )
    }

    static func artist(name: String, photo: ArtworkSource?) -> ShareableEntity {
        ShareableEntity(
            title: name,
            subtitle: nil,
            year: nil,
            cover: photo,
            avatar: nil,
            shape: .circle
        )
    }
}
