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
    var id: String { artist.map { "artist-wave-\($0.id)" } ?? "genre" }
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

@main @MainActor enum PromoCuratedContentChecks {
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

        let suite = "PromoReactionChecks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = PromoReactionHistory(defaults: defaults)
        for card in PromoCuratedContent.movies { history.record(.like, for: card.id) }
        let disliked = "movie-backup-0"
        let undo = history.record(.dislike, for: disliked)
        let restarted = PromoReactionHistory(defaults: defaults)
        precondition(restarted.reactedIDs == excludedHQ.union([disliked]), "Both reactions must survive a new session")

        let backups = (0..<6).map { index in
            ShowcaseBlock.movie(MovieBlock(id: "backup-\(index)", title: "Backup \(index)",
                poster: .asset("backup"), still: .asset("backup"), caption: "", captionTint: .clear))
        }
        let saved = Set([backups[1].id])
        let refreshed = PromoCuratedContent.compose(backups, excluding: restarted.reactedIDs,
                                                   isEligible: { !saved.contains($0.id) })
        let refreshedMovies = refreshed.filter { $0.homePromoKind == .movie }
        precondition(refreshedMovies.map(\.id) == Array(backups[2...5]).map(\.id),
                     "Reacted and saved cards must be skipped without truncating the reserve to three slots")
        let sessionSnapshot = restarted.reactedIDs
        history.record(.like, for: backups[2].id)
        precondition(!sessionSnapshot.contains(backups[2].id), "A new like must not mutate the current session snapshot")
        undo()
        let afterUndo = PromoReactionHistory(defaults: defaults).reactedIDs
        precondition(!afterUndo.contains(disliked) && afterUndo.contains(backups[2].id),
                     "Undo must persist and preserve subsequent reactions on other cards")

        let sourceWave = ShowcaseBlock.vibe(.promo(.artistWave(ArtistBlock(id: 42, name: "New artist", picture: .asset("artist")))))
        let curatedWaveIDs = Set(PromoCuratedContent.waveArtists.map { ShowcaseBlock.vibe(.promo(.artistWave($0))).id })
        let waves = PromoCuratedContent.compose([sourceWave], excluding: curatedWaveIDs)
        precondition(waves.contains { $0.id == sourceWave.id } && waves.allSatisfy { !curatedWaveIDs.contains($0.id) },
                     "An evaluated curated artist wave must be replaced by the fresh source artist")
        print("PASS: reactions persist, saved cards are replaced before slot limits, undo persists, and artist waves use fresh candidates")

        let reserve = (0..<60).map { index in
            ShowcaseBlock.movie(MovieBlock(id: "reserve-\(index)", title: "Reserve \(index)",
                poster: .asset("poster"), still: .asset("poster"), caption: "", captionTint: .clear))
        }
        let evaluated = Set((PromoCuratedContent.movies + Array(reserve.prefix(12))).map(\.id))
        let savedIDs = Set(reserve[12..<20].map(\.id))
        let full = PromoCuratedContent.compose(reserve + reserve, excluding: evaluated,
                                               isEligible: { !savedIDs.contains($0.id) })
        precondition(full.count == 30, "A depleted curated pool must refill to 30")
        precondition(Set(full.map(\.id)).count == 30, "Carousel items must have unique identities")
        precondition(full.allSatisfy { !evaluated.contains($0.id) && !savedIDs.contains($0.id) })
        precondition(PromoCuratedContent.compose(reserve + reserve, excluding: evaluated,
            isEligible: { !savedIDs.contains($0.id) }).map(\.id) == full.map(\.id),
            "Recomposition must preserve carousel order")
        let artist = ArtistBlock(id: 9001, name: "Another artist", picture: .asset("another-artist"))
        let candidate = ShowcaseBlock.vibe(.promo(.artistWave(artist)))
        let withWave = PromoCuratedContent.compose(reserve + [.artist(artist), candidate], excluding: curatedWaveIDs)
        precondition(withWave.count == 30)
        precondition(withWave.contains { $0.id == candidate.id }, "Artist wave must survive standalone artist deduplication")
        precondition(!withWave.contains { $0.id == ShowcaseBlock.artist(artist).id })
        precondition(PromoCuratedContent.uniqueArtists(withWave).count == withWave.count)
        let oldArtist = ShowcaseBlock.vibe(.promo(.artistWave(ArtistBlock(
            id: 173022587, name: "Musia Totibadze", picture: .asset("old-portrait")))))
        let newArtists = PromoCuratedContent.compose(reserve + [oldArtist], excluding: [])
        precondition(!newArtists.contains { $0.id == oldArtist.id }, "Musia must leave new recommendations without erasing listening history")
        precondition(newArtists.filter { curatedWaveIDs.contains($0.id) }.count >= 2,
                     "Multiple replacement artists must remain after cross-type deduplication")
        let fallback = PromoCuratedContent.compose(reserve + [candidate, sourceWave], excluding: curatedWaveIDs,
            isEligible: { $0.id != candidate.id })
        precondition(fallback.count == 30 && fallback.contains { $0.id == sourceWave.id },
                     "An ineligible artist wave must yield to another candidate")
        print("PASS: 30 unique items after exclusions, stable order, no three-item cap")
    }
}
