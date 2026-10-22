import SwiftUI

// MARK: - Тексты и картинки айтема

extension ShowcaseBlock {
    var promoAccessibilityLabel: String {
        if case .album(let album) = self { return "Альбом \(album.subtitle), \(album.title)" }
        return title
    }

    /// Что запускает карточка «Продолжить» (задача 69): киноплеер с места остановки или
    /// читалку. `nil` — обычная карточка.
    /// Тап по карточке «Продолжить» сразу запускает: только книга — у фильма тап открывает
    /// экран тайтла, плеер — по кнопке «Продолжить».
    var opensPlayerOnTap: Bool {
        if case .book(let book) = self { return book.resume != nil }
        return false
    }

    var promoResume: ShowcasePlayerTarget? {
        switch self {
        case .movie(let movie): movie.resume.map { .movie($0) }
        case .book(let book): book.resume.map { .book($0) }
        case .album, .vibe, .reading, .watching, .artist: nil
        }
    }

    /// Строка под кругом исполнителя. У остальных видов её нет: «Моя волна» и название
    /// станции — внутри лепестка (`PromoStationCard`).
    @MainActor
    var promoCaption: String? {
        switch self {
        case .artist(let artist): artist.name
        case .movie, .album, .book, .vibe, .reading, .watching: nil
        }
    }

    /// Картинка фона под слайдером — обложка айтема. У исполнителя — его фото, у станции —
    /// её иллюстрация в цветах станции, а не кавер плеера; у волны «в стиле артиста» —
    /// фото артиста.
    var promoArtwork: ArtworkSource {
        switch self {
        case .movie(let movie): movie.poster
        case .album(let album): album.cover
        case .book(let book): book.cover
        // Волна «в стиле артиста» красит фон цветом своей капли, а не фото артиста (правка
        // пользователя 2026-10-13): источник — растр капли из палитры.
        case .vibe(let vibe):
            if case .artist = vibe.promoStation.kind, let index = vibe.promoStation.paletteIndex {
                .asset("\(PromoStationPetal.backdropPrefix)\(index)")
            } else {
                vibe.promoStation.artwork
            }
        case .reading(let reading): reading.cover
        case .watching(let watching): watching.still
        case .artist(let artist): artist.picture
        }
    }
}
