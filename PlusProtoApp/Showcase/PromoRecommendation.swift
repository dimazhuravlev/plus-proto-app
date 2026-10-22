import SwiftUI

extension ShowcaseBlock {
    /// Лайк обучает рекомендации; только отдельная кнопка тоста сохраняет сущность.
    var recommendationCollectionItem: CollectionItem? {
        if let route = entityRoute {
            switch route {
            case .movie(let ref): return .movie(ref, poster: ref.artwork, year: nil)
            case .book(let ref): return .book(ref, aspect: nil)
            case .album(let ref): return .album(ref)
            case .artist(let ref): return .artist(ref)
            case .playlist, .director, .writer, .episodes: break
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
}
