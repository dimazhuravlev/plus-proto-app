import SwiftUI

/// Existing editorial content supplies an offline reserve only to the home mix.
/// It never writes to the shelves, collection or Recently.
@MainActor
enum HomePromoReserve {
    static var local: [ShowcaseBlock] {
        var result = ShowcaseFeed.personal.promo
        result += HomeShelfSamples.movies.compactMap {
            guard let synopsis = PromoReserveSynopsis.movies[$0.id] else { return nil }
            return .movie(MovieBlock(id: $0.id, title: $0.title, poster: $0.artwork,
                              still: $0.artwork, caption: synopsis, captionTint: .clear, synopsis: synopsis))
        }
        result += HomeShelfSamples.books.compactMap {
            guard let synopsis = PromoReserveSynopsis.books[$0.id] else { return nil }
            return .book(BookBlock(id: $0.id, title: $0.title, render: $0.artwork,
                            cover: $0.artwork, caption: synopsis, captionTint: .clear, synopsis: synopsis))
        }
        result += VibePromoStation.all.map { .vibe(.promo($0)) }
        for item in CollectionSeeds.items(now: .now) + CollectionSeeds.purchases + CollectionSeeds.read {
            guard let artwork = item.artwork, let route = item.route else { continue }
            switch item.kind {
            case .movie:
                guard let synopsis = PromoReserveSynopsis.movies[route.ref.id] else { continue }
                result.append(.movie(MovieBlock(id: route.ref.id, title: item.title,
                    poster: artwork, still: artwork, caption: synopsis, captionTint: .clear, synopsis: synopsis)))
            case .book:
                guard let synopsis = PromoReserveSynopsis.books[route.ref.id] else { continue }
                result.append(.book(BookBlock(id: route.ref.id, title: item.title,
                    render: artwork, cover: artwork, caption: synopsis, captionTint: .clear, synopsis: synopsis)))
            case .album:
                result.append(album(id: route.ref.id, cover: artwork,
                                    artist: item.subtitle, title: item.title))
            case .artist:
                if let id = Int(route.ref.id.replacingOccurrences(of: "dz-", with: "")) {
                    result.append(.artist(ArtistBlock(id: id, name: item.title, picture: artwork)))
                }
            case .track:
                if case .album(let ref) = route {
                    result.append(album(id: ref.id, cover: ref.artwork,
                                        artist: ref.subtitle, title: ref.title))
                }
            case .playlist: break
            }
        }
        let albumArtists = PromoCuratedContent.albums.compactMap { item -> ArtistBlock? in
            guard case .album(let album) = item, let id = album.artistID,
                  let picture = album.artistPicture else { return nil }
            return ArtistBlock(id: id, name: album.title, picture: picture)
        }
        let artists = PromoCuratedContent.waveArtists + PromoCuratedContent.artists + albumArtists
            + result.compactMap { if case .artist(let artist) = $0 { artist } else { nil } }
        result += artists.map { .vibe(.promo(.artistWave($0))) }
        return result
    }

    private static func album(id: String, cover: ArtworkSource, artist: String, title: String) -> ShowcaseBlock {
        let identity = PromoAlbumArtists.byAlbumID[id]
        return .album(AlbumBlock(id: id, cover: cover, title: artist, subtitle: title,
                                 artistPicture: identity?.picture, artistID: identity?.id))
    }
}
