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

    /// Вид заголовка на карточке шеринга: одна строка влево или ступени до трёх строк.
    /// Задаётся фабрикой, а не формой обложки: у альбома и плейлиста форма одна, заголовок разный.
    enum TitleKind: Equatable {
        /// Одна строка, влево (плейлист, артист)
        case single
        /// Ступенями до трёх строк, влево (альбом)
        case stepped
        /// Ступенями до трёх строк, по центру (фильм, книга)
        case steppedCentered
    }

    let title: String
    /// Исполнитель, владелец плейлиста, автор
    let subtitle: String?
    let year: String?
    let cover: ArtworkSource?
    /// Аватар в мета-строке — только у альбома (фото исполнителя)
    let avatar: ArtworkSource?
    let shape: Shape
    let titleLayout: TitleKind

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
            shape: .square,
            titleLayout: .stepped
        )
    }

    static func playlist(title: String, owner: String, cover: ArtworkSource?) -> ShareableEntity {
        ShareableEntity(
            title: title,
            subtitle: owner.isEmpty ? nil : owner,
            year: nil,
            cover: cover,
            avatar: nil,
            shape: .square,
            titleLayout: .single
        )
    }

    static func book(
        title: String,
        author: String,
        cover: ArtworkSource?,
        aspect: CGFloat?
    ) -> ShareableEntity {
        ShareableEntity(
            title: title,
            subtitle: author.isEmpty ? nil : author,
            year: nil,
            cover: cover,
            avatar: nil,
            shape: .book(aspect: aspect),
            titleLayout: .steppedCentered
        )
    }

    static func movie(title: String, year: String?, poster: ArtworkSource?) -> ShareableEntity {
        ShareableEntity(
            title: title,
            subtitle: nil,
            year: year,
            cover: poster,
            avatar: nil,
            shape: .poster,
            titleLayout: .steppedCentered
        )
    }

    static func artist(name: String, photo: ArtworkSource?) -> ShareableEntity {
        ShareableEntity(
            title: name,
            subtitle: nil,
            year: nil,
            cover: photo,
            avatar: nil,
            shape: .circle,
            titleLayout: .single
        )
    }
}
