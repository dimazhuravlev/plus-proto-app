import SwiftUI

/// Локальные оригиналы с CDN Яндекс Музыки / Кинопоиска.
/// Источники и фактические размеры — docs/PROMO_ARTWORK_SOURCES.md.
enum PromoCuratedContent {
    static let movies: [ShowcaseBlock] = [
        movie(4540126, "Дюна: Часть вторая", "Пол Атрейдес объединяется с фрименами и выбирает между любовью и судьбой целой вселенной."),
        movie(589290, "Бегущий по лезвию 2049", "Офицер Кей раскрывает тайну, способную изменить будущее людей и репликантов."),
        movie(258687, "Интерстеллар", "Команда исследователей отправляется за пределы Солнечной системы в поисках нового дома для человечества."),
    ]

    static let albums: [ShowcaseBlock] = [
        .album(AlbumBlock(id: "dz-387192917", cover: .asset("promoHQMichelCover"),
                          title: "Моя Мишель", subtitle: "Из цветов и темноты",
                          artistPicture: .asset("promoHQMichelArtist"), artistID: 5294157)),
        .album(AlbumBlock(id: "dz-645570461", cover: .asset("promoHQZolotoCover"),
                          title: "ZOLOTO", subtitle: "Перевоплотиться",
                          artistPicture: .asset("promoHQZolotoArtist"), artistID: 248738922)),
        .album(AlbumBlock(id: "dz-164994822", cover: .asset("promoHQCreamCover"),
                          title: "Cream Soda", subtitle: "Интергалактик",
                          artistPicture: .asset("promoHQCreamArtist"), artistID: 5535442)),
    ]

    static let artists: [ArtistBlock] = [
        ArtistBlock(id: 57812002, name: "Дора", picture: .asset("promoHQDoraArtist")),
        ArtistBlock(id: 8287582, name: "Антоха МС", picture: .asset("promoHQAntohaArtist")),
        ArtistBlock(id: 11052788, name: "Монеточка", picture: .asset("promoHQMonetochkaArtist")),
    ]

    static let waveArtist = ArtistBlock(id: 173022587, name: "Musia Totibadze", picture: .asset("promoHQMusiaArtist"))

    private static func movie(_ id: Int, _ title: String, _ synopsis: String) -> ShowcaseBlock {
        let poster = ArtworkSource.asset("promoHQMovie\(id)")
        // Этот набор используется только промоблоком с постерами; recently
        // продолжает брать реальные горизонтальные кадры исходного каталога.
        return .movie(MovieBlock(id: "kp-\(id)", title: title, poster: poster, still: poster,
                                 caption: synopsis, captionTint: .clear, synopsis: synopsis))
    }

    static func compose(_ original: [ShowcaseBlock], excluding dismissed: Set<String>) -> [ShowcaseBlock] {
        func pool(_ fresh: [ShowcaseBlock], _ kind: HomePromoKind) -> [ShowcaseBlock] {
            let remaining = fresh.filter { !dismissed.contains($0.id) }
            let ids = Set(remaining.map(\.id))
            let backups = original.filter { $0.homePromoKind == kind && !ids.contains($0.id) && !dismissed.contains($0.id) }
            return Array((remaining + backups).prefix(3))
        }
        let movies = pool(Self.movies, .movie)
        let albums = pool(Self.albums, .album)
        let artists = pool(Self.artists.map { .artist($0) }, .artist)
        let books = original.filter { $0.homePromoKind == .book && !dismissed.contains($0.id) }
        let vibes = original.filter { $0.homePromoKind == .station && !dismissed.contains($0.id) }.map { item in
            if case .vibe(let vibe) = item, vibe.promoStation.artist != nil {
                return ShowcaseBlock.vibe(.promo(.artistWave(Self.waveArtist)))
            }
            return item
        }.filter { !dismissed.contains($0.id) }
        let pools = [movies, albums, books, artists, vibes]
        var result: [ShowcaseBlock] = []
        for index in 0..<(pools.map(\.count).max() ?? 0) {
            for pool in pools where index < pool.count { result.append(pool[index]) }
        }
        return result
    }

    /// Один исполнитель на весь промоблок независимо от формы карточки:
    /// альбом с фото, отдельный артист или волна в его стиле.
    static func uniqueArtists(_ blocks: [ShowcaseBlock]) -> [ShowcaseBlock] {
        var ids = Set<Int>()
        var names = Set<String>()
        return blocks.filter { block in
            let id: Int?
            let name: String
            switch block {
            case .album(let album): id = album.artistID; name = album.title
            case .artist(let artist): id = artist.id; name = artist.name
            case .vibe(let vibe):
                guard let artist = vibe.promoStation.artist else { return true }
                id = artist.id; name = artist.name
            default: return true
            }
            let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
                .components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
            guard !names.contains(key), id.map({ !ids.contains($0) }) ?? true else { return false }
            names.insert(key)
            if let id { ids.insert(id) }
            return true
        }
    }
}
