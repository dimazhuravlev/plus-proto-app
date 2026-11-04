import SwiftUI

/// Изолированный набор для проверки геометрии. Не меняет порядок настоящих рекомендаций.
struct HomePromoPairPreview: View {
    let items: [ShowcaseBlock]
    let zoom: Namespace.ID
    @State private var index = 0

    var body: some View {
        ShowcasePromo(items: Self.pairs(from: items), zoom: zoom,
                      savedIndex: $index, fixedPreview: true)
    }

    private static func pairs(from items: [ShowcaseBlock]) -> [ShowcaseBlock] {
        let books: [ShowcaseBlock] = HomeShelfSamples.books.map {
            .book(BookBlock(id: $0.id, title: $0.title, render: $0.artwork, cover: $0.artwork,
                            caption: "", captionTint: .clear))
        }
        let candidates = items + PromoCuratedContent.movies + PromoCuratedContent.albums
            + PromoCuratedContent.artists.map { ShowcaseBlock.artist($0) }
            + books + VibePromoStation.all.map { ShowcaseBlock.vibe(.promo($0)) }
        let kinds = HomePromoKind.allCases
        let pools = kinds.map { kind -> [ShowcaseBlock] in
            var images = Set<ArtworkSource>()
            return candidates.filter { $0.homePromoKind == kind && images.insert(artwork($0)).inserted }
        }
        var cursors = Array(repeating: 0, count: kinds.count)
        var result: [ShowcaseBlock] = []
        for left in kinds.indices {
            for right in kinds.indices {
                for kind in [left, right] {
                    let pool = pools[kind]
                    guard !pool.isEmpty else { continue }
                    let item = pool[cursors[kind] % pool.count]
                    cursors[kind] += 1
                    result.append(copy(item, slot: result.count))
                }
            }
        }
        return result
    }

    private static func artwork(_ item: ShowcaseBlock) -> ArtworkSource {
        switch item {
        case .movie(let b): b.poster
        case .album(let b): b.cover
        case .book(let b): b.cover
        case .artist(let b): b.picture
        case .vibe(let b): b.promoStation.artwork
        case .reading(let b): b.cover
        case .watching(let b): b.still
        }
    }

    // Каждый экземпляр получает отдельную идентичность для ScrollPosition и реакций.
    private static func copy(_ item: ShowcaseBlock, slot: Int) -> ShowcaseBlock {
        let id = "pair-preview-\(slot)"
        switch item {
        case .movie(let b):
            return .movie(MovieBlock(id: id, title: b.title, poster: b.poster, still: b.still,
                                     caption: b.caption, captionTint: b.captionTint, synopsis: b.synopsis))
        case .album(let b):
            return .album(AlbumBlock(id: id, cover: b.cover, title: b.title, subtitle: b.subtitle,
                                     artistPicture: b.artistPicture, artistID: b.artistID))
        case .book(let b):
            return .book(BookBlock(id: id, title: b.title, render: b.render, cover: b.cover,
                                   caption: b.caption, captionTint: b.captionTint, synopsis: b.synopsis))
        case .artist(let b):
            return .artist(ArtistBlock(id: -1_000_000 - slot, name: b.name, picture: b.picture))
        case .vibe(let b):
            return .vibe(VibeBlock(id: id, title: b.title, subtitle: b.subtitle, cover: b.cover,
                                   art: b.art, station: b.station))
        case .reading, .watching:
            return item
        }
    }
}
