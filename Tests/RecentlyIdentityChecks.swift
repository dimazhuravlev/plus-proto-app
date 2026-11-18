import Foundation
import SwiftUI
extension Color { init(hex: UInt32) { self = .clear } }

// Minimal data dependencies; the actual history implementation is compiled alongside these fixtures.
enum ArtworkSource: Codable, Equatable {
    case asset(String)
    case remote(URL, fallback: String?)
}
struct EntityRef: Codable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let artwork: ArtworkSource
}
enum EntityRoute: Codable, Equatable {
    case movie(EntityRef), book(EntityRef), album(EntityRef), playlist(EntityRef), artist(EntityRef), episodes(EntityRef)
    var ref: EntityRef {
        switch self {
        case .movie(let r), .book(let r), .album(let r), .playlist(let r), .artist(let r), .episodes(let r): r
        }
    }
    var id: String { "episodes:" + ref.id }
}
struct MusicNowPlaying: Codable, Equatable {
    let id: String
    var cover: ArtworkSource = .asset("cover")
    var title = "Track"
    var artist = "Artist"
    var album: String? = "Album"
    var containerID: String? = nil
}
struct MovieInProgress: Codable, Equatable {
    let id: String
    var still: ArtworkSource = .asset("movie")
    var title = "Movie"
    var position: Double? = nil
    var runtime: Double? = nil
}
struct BookInProgress: Codable, Equatable {
    let id: String
    let cover: ArtworkSource
    let title: String
    let author: String?
}
enum RecentlySeeds { static let items: [RecentItem] = [] }

@main enum RecentlyIdentityChecks {
    static func main() throws {
        let suite = "RecentlyIdentityChecks-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let history = RecentlyConsumed(defaults: defaults)
        history.clear()
        let first = MusicNowPlaying(id: "dz-123-t1")
        let second = MusicNowPlaying(id: "dz-123-t2", containerID: "album:dz-123")
        let other = MusicNowPlaying(id: "dz-456-t3", containerID: "album:dz-456")
        history.record(.music(first))
        history.record(.music(other))
        history.record(.music(second))
        precondition(history.items.count == 2)
        precondition(history.items[0].id == "music:album:dz-123")
        precondition(history.items[1].id == "music:album:dz-456")
        precondition(RecentItem.music(MusicNowPlaying(id: "dz-track-123")).id == "music:dz-track-123")
        precondition(RecentItem.music(MusicNowPlaying(id: "dz-track-456")).id != RecentItem.music(MusicNowPlaying(id: "dz-track-123")).id)
        let ref = EntityRef(id: "dz-123", title: "Album", subtitle: "Artist", artwork: .asset("cover"))
        history.record(.entity(.album(ref)))
        history.record(.music(first))
        precondition(history.items.count == 2)
        let station = VibeStation(id: "garage", title: "Спальничный гэридж", agent: "vibeStationPopIndigo", fillHex: 0x160CE8, rimHex: 0xA29EFA)
        history.record(.station(station.id))
        history.record(.stationSnapshot(station))
        precondition(history.items.filter { $0.id == "station:garage" }.count == 1)
        let restored = RecentlyConsumed(defaults: defaults)
        precondition(restored.items == history.items)
        let portrait = ArtworkSource.asset("promoHQAntohaArtist")
        let artistWave = VibeStation(id: "artist-wave-8287582", title: "Антоха МС",
            agent: "vibeStationPopIndigo", fillHex: 0x160CE8, rimHex: 0xA29EFA, artistArtwork: portrait)
        history.record(.stationSnapshot(artistWave))
        let restoredArtist = RecentlyConsumed(defaults: defaults).items[0]
        precondition(restoredArtist.artwork == portrait, "Bundled artist portraits must survive a history round trip")
        precondition(restoredArtist.id == "station:artist-wave-8287582")
        let oldSnapshot = Data("""
        {"id":"artist-wave-173022587","title":"Musia Totibadze","agent":"vibeAgentPop","fillHex":16711680,"rimHex":16777215}
        """.utf8)
        let repaired = try JSONDecoder().decode(VibeStation.self, from: oldSnapshot)
        precondition(repaired.artwork == .asset("promoHQMusiaArtist"))
        precondition(repaired.agent == "vibeStationPopIndigo")
        defaults.set(try JSONEncoder().encode([RecentItem.music(second), .music(other), .music(first)]), forKey: "recentlyConsumed")
        let migrated = RecentlyConsumed(defaults: defaults)
        precondition(migrated.items.map(\.id) == ["music:album:dz-123", "music:album:dz-456"])
        precondition(RecentlyMovieTime.label(9_000) == "2 ч 30 мин")
        precondition(RecentlyMovieTime.label(59) == "1 мин")
        precondition(MovieInProgress(id: "series", position: 9000, runtime: 10800).remainingTime == 1800)
        precondition(MovieInProgress(id: "series", position: 12000, runtime: 10800).remainingTime == 0)
        precondition(MovieInProgress(id: "unknown").remainingTime == nil)
        print("PASS: album identity, move-to-front, distinct unknown tracks, station identity, persistence and old duplicate migration")
    }
}
