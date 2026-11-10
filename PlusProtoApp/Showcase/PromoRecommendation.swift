import SwiftUI

extension ShowcaseBlock {
    /// В V1 сохраняет кнопка тоста после лайка, в V2 — сама реакция сохранения.
    var recommendationCollectionItem: CollectionItem? {
        if let route = entityRoute {
            switch route {
            case .movie(let ref): return .movie(ref, poster: ref.artwork, year: nil)
            case .book(let ref): return .book(ref, aspect: nil)
            case .album(let ref): return .album(ref)
            case .artist(let ref): return .artist(ref)
            case .playlist, .director, .writer, .actor, .episodes: break
            }
        }
        if case .vibe(let vibe) = self {
            if let artist = vibe.promoStation.artist { return .artist(artist.route.ref) }
            // Жанровая станция сохраняется как музыкальная подборка, с реальным
            // музыкальным target волны для запуска из коллекции.
            let music: MusicNowPlaying?
            if case .music(let value) = player { music = value } else { music = nil }
            return CollectionItem(id: "playlist:vibe-\(vibe.id)", kind: .playlist,
                                  title: vibe.title, subtitle: vibe.promoStation.name,
                                  artwork: vibe.promoStation.artwork, playable: music)
        }
        return nil
    }

    /// Figma uBatydFjyjVhDM8AZqG5gC, 19598:7496. Музыкальные типы
    /// (включая артистов и станции) используют одно сервисное сердце.
    var promoSaveIcon: String {
        switch homePromoKind {
        case .book: "promoSaveBook"
        case .movie: "promoSaveMovie"
        case .album, .artist, .station: "promoSaveMusic"
        }
    }
}
