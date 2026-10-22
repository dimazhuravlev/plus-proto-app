import SwiftUI

/// Локальные примеры полок из Figma 331:45286. У моков нет выдуманных id внешних API:
/// экран открывается на известных названии и обложке; реальные каталоги подменяют их.
struct HomeShelfItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let artwork: ArtworkSource
    let route: EntityRoute
    var rating: String? = nil
}

enum HomeShelfSamples {
    static let movies = [
        movie("maid", "Горничная", "shelfMovieMaid"),
        movie("project", "Проект «Конец света»", "shelfMovieProject"),
        movie("drama", "Драма!", "shelfMovieDrama")
    ]
    static let books = [
        book("dragons", "Не время для драконов", "shelfBookDragons"),
        book("ninth", "Девятый", "shelfBookNinth"),
        book("atomic", "Atomic Heart", "shelfBookAtomic")
    ]
    static let artists = [
        artist("fortuna", "FORTUNA 812", "shelfArtistFortuna"),
        artist("prince", "тёмный принц", "shelfArtistPrince"),
        artist("lutik", "ЛЮТИК", "shelfArtistLutik")
    ]
    static let tracks: [MusicNowPlaying] = [
        MusicNowPlaying(id: "home-track-friends", cover: .asset("shelfTrackFriends"), title: "INTERNET FRIENDS", artist: ""),
        MusicNowPlaying(id: "home-track-snow", cover: .asset("shelfTrackSnow"), title: "Снегом стать*", artist: ""),
        MusicNowPlaying(id: "home-track-durka", cover: .asset("shelfTrackDurka"), title: "ДУРКА", artist: "")
    ]
    @MainActor static var albums: [AlbumBlock] {
        CollectionSeeds.items(now: .now).compactMap { item in
            guard item.kind == .album, let source = item.artwork, let route = item.route else { return nil }
            // В Showcase AlbumBlock исторически title — артист, subtitle — альбом.
            return AlbumBlock(id: route.ref.id, cover: source, title: item.subtitle, subtitle: item.title)
        }
    }
    private static func movie(_ id: String, _ title: String, _ asset: String) -> HomeShelfItem {
        let ref = EntityRef(id: "local-shelf-\(id)", title: title, subtitle: "", artwork: .asset(asset))
        return HomeShelfItem(id: ref.id, title: title, subtitle: "", artwork: ref.artwork, route: .movie(ref), rating: "7.0")
    }
    private static func book(_ id: String, _ title: String, _ asset: String) -> HomeShelfItem {
        let ref = EntityRef(id: "local-shelf-\(id)", title: title, subtitle: "", artwork: .asset(asset))
        return HomeShelfItem(id: ref.id, title: title, subtitle: "", artwork: ref.artwork, route: .book(ref), rating: "7.0")
    }
    private static func artist(_ id: String, _ title: String, _ asset: String) -> HomeShelfItem {
        let ref = EntityRef(id: "name-\(id)", title: title, subtitle: "", artwork: .asset(asset))
        return HomeShelfItem(id: ref.id, title: title, subtitle: "", artwork: ref.artwork, route: .artist(ref))
    }
}
