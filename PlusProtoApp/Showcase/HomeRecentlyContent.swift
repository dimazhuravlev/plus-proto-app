import SwiftUI

/// Выбирает содержимое локальной ленты, сохраняя приоритет истории и dev-примеров.
/// Не хранит состояние: каждый запрос получает актуальные входы из владельца ленты.
@MainActor
struct HomeRecentlyContent {
    let feed: ShowcaseFeed
    let cinemaPromos: [CinemaCatalog.Promo]
    let previewIndex: Int
    let hasContinuingMovie: Bool
    let hasCurrentBook: Bool

    var compactStations: [VibeStation] {
        let start = max(0, previewIndex) + 1
        return (0..<2).map { VibeStation.all[(start + $0) % VibeStation.all.count] }
    }

    var movie: MovieBlock? {
        if previewIndex >= 0 {
            // Второй offline-промо использует тот же кадр под другим названием.
            // В recently оставляем только согласованные пары тайтл / сцена.
            let pool = (cinemaPromos.isEmpty ? CinemaMocks.promos : cinemaPromos)
                .filter { $0.id != "mock-cinema-perfect-days" }
            guard !pool.isEmpty else { return nil }
            let item = pool[previewIndex % pool.count]
            return MovieBlock(id: item.id, title: item.title, poster: item.poster ?? item.cover, still: item.cover, caption: "", captionTint: .clear)
        }
        let recommendation = feed.promo.compactMap { if case .movie(let value) = $0 { value } else { nil } }.first
        if case .asset("mockChipMovieStill") = recommendation?.still,
           let sample = CinemaMocks.promos.first {
            return MovieBlock(id: sample.id, title: sample.title, poster: sample.poster ?? sample.cover, still: sample.cover, caption: "", captionTint: .clear)
        }
        return recommendation
    }

    var album: AlbumBlock? {
        if previewIndex >= 0 {
            let pool = HomeShelfSamples.albums
            if !pool.isEmpty { return pool[previewIndex % pool.count] }
        }
        return feed.promo.compactMap { if case .album(let value) = $0 { value } else { nil } }.first
    }

    var book: BookBlock? {
        if previewIndex >= 0 {
            let pool = HomeShelfSamples.books
            let item = pool[previewIndex % pool.count]
            return BookBlock(id: item.id, title: item.title, render: item.artwork, cover: item.artwork, caption: "", captionTint: .clear)
        }
        return feed.promo.compactMap { if case .book(let value) = $0 { value } else { nil } }.first
    }

    var artist: ArtistBlock? {
        return feed.promo.compactMap { if case .artist(let value) = $0 { value } else { nil } }.first
    }

    private var firstCardCount: Int {
        let preview = previewIndex >= 0
        return 1 + ((movie != nil || (!preview && hasContinuingMovie)) ? 1 : 0)
            + (album != nil ? 1 : 0) + ((book != nil || (!preview && hasCurrentBook)) ? 1 : 0)
            + ((preview || artist != nil) ? 1 : 0)
    }

    private var additionalCount: Int {
        return max(3, 10 - firstCardCount - 2)
    }

    var additionalItems: [HomeShelfItem] {
        let albums = HomeShelfSamples.albums.map { album in
            HomeShelfItem(id: "recent-album-" + album.id, title: album.subtitle, subtitle: album.title, artwork: album.cover,
                          route: .album(EntityRef(id: album.id, title: album.subtitle, subtitle: album.title, artwork: album.cover)))
        }
        let offset = max(0, previewIndex) + 1
        let pools = [albums, HomeShelfSamples.books, HomeShelfSamples.artists].filter { !$0.isEmpty }
        return (0..<additionalCount).map { index in
            let pool = pools[index % pools.count]
            return pool[(offset + index / pools.count) % pool.count]
        }
    }

    /// Позиция меняется вместе с набором, но остаётся стабильной при перерисовке.
    var moviePosition: Int {
        let preview = previewIndex
        guard preview >= 0 else { return 0 }
        return (preview + 1) % (4 + additionalCount)
    }
}
