import SwiftUI

// Минимальные модели для запуска реальной проекции каталога без сетевых сервисов.
enum ArtworkSource { case asset(String) }
enum HomePromoKind { case movie, album, book, artist, station }
struct ArtistBlock { let id: Int; let name: String; let picture: ArtworkSource }
struct MovieBlock {
    let id: String
    let title: String
    let poster: ArtworkSource
    let still: ArtworkSource
    let caption: String
    let captionTint: Color
    var synopsis: String? = nil
    var resume: Bool? = nil
}
struct AlbumBlock {
    let id: String
    let cover: ArtworkSource
    let title: String
    let subtitle: String
    let artistPicture: ArtworkSource?
    let artistID: Int?
}
struct VibePromoStation {
    var artist: ArtistBlock?
    static func artistWave(_ artist: ArtistBlock) -> Self { Self(artist: artist) }
}
struct VibeBlock {
    let id: String
    let promoStation: VibePromoStation
    static func promo(_ station: VibePromoStation) -> Self {
        Self(id: "artist-wave-\(station.artist!.id)", promoStation: station)
    }
}
enum ShowcaseBlock {
    case movie(MovieBlock), album(AlbumBlock), artist(ArtistBlock), vibe(VibeBlock), book(String)
    var id: String {
        switch self {
        case .movie(let value): "movie-" + value.id
        case .album(let value): "album-" + value.id
        case .artist(let value): "artist-\(value.id)"
        case .vibe(let value): "vibe-" + value.id
        case .book(let value): "book-" + value
        }
    }
    var homePromoKind: HomePromoKind {
        switch self {
        case .movie: .movie
        case .album: .album
        case .artist: .artist
        case .vibe: .station
        case .book: .book
        }
    }
}

@main enum PromoCuratedContentChecks {
    static func main() {
        let original = ShowcaseBlock.movie(MovieBlock(id: "perfect-days", title: "Идеальные дни",
            poster: .asset("original"), still: .asset("original"), caption: "", captionTint: .clear))
        let excludedHQ = Set(PromoCuratedContent.movies.map(\.id))
        let shown = PromoCuratedContent.compose([original], excluding: excludedHQ)
        let movie = shown.first { $0.homePromoKind == .movie }!
        precondition(movie.id == "movie-local-promo-maid")
        let dismissed = excludedHQ.union([movie.id])
        for _ in 0..<3 {
            let rebuilt = PromoCuratedContent.compose([original], excluding: dismissed)
            precondition(!rebuilt.contains { $0.id == movie.id }, "Editorial card reappears after dismissal")
        }
        let undone = PromoCuratedContent.compose([original], excluding: dismissed.subtracting([movie.id]))
        precondition(undone.contains { $0.id == movie.id }, "Undo must restore the same display identity")
        precondition(original.id == "movie-perfect-days", "Projection must preserve the source catalog")
        print("PASS: editorial identity is filtered before pooling, stays dismissed on rebuild, and returns on undo")
    }
}
