import Foundation

/// Свои плейлисты пользователя — стартовый набор чипса «Мои» (вариант 3, выбор
/// пользователя 2026-10-20). Создания плейлистов в прототипе нет, поэтому набор
/// неизменный и в коллекции не хранится. Треки — живые Deezer (замер 2026-10-20),
/// превью играют, как у любого трека. Обложка — мозаика 2×2 из обложек первых
/// альбомов плейлиста, как у своих плейлистов Музыки; собрана заранее в ассет.
enum MyPlaylists {
    struct Track {
        let id: Int
        let title: String
        let artist: String
        let album: (id: Int, title: String)
        /// md5 обложки альбома Deezer
        let cover: String
        var isExplicit = false
    }

    struct Playlist {
        let slug: String
        let title: String
        /// Мозаика `mockMyPlaylist…`
        let cover: String
        let tracks: [Track]

        /// Id экрана — `own-<slug>`: не Deezer, детали — отсюда, без сети.
        var entityID: String { "own-\(slug)" }
        var artwork: ArtworkSource { .asset(cover) }
    }

    static let all: [Playlist] = [
        Playlist(slug: "oldies", title: "Старое доброе", cover: "mockMyPlaylistOldies", tracks: [
            Track(id: 5093617, title: "There Is a Light That Never Goes Out", artist: "The Smiths", album: (467267, "The Sound of the Smiths"), cover: "d1005397b8a3a743fb0c8aad35f42db3"),
            Track(id: 13786035, title: "This Charming Man", artist: "The Smiths", album: (1261479, "Hatful of Hollow"), cover: "75ba5f16ccf6284d129a7fe837220e5a"),
            Track(id: 131744724, title: "Blitzkrieg Bop", artist: "Ramones", album: (13995252, "Ramones"), cover: "5e4fa09fd2de120d601098123f43e328"),
            Track(id: 30910351, title: "Sensitive", artist: "The Field Mice", album: (2948621, "Coastal"), cover: "1897723b4f8e8eb0c4219191e58144ed"),
            Track(id: 448260732, title: "Группа крови", artist: "Кино", album: (54717452, "Группа крови"), cover: "b39e82e1e4fdaf3f08ae582e8c9565cd"),
        ]),
        Playlist(slug: "fresh", title: "Свежее", cover: "mockMyPlaylistFresh", tracks: [
            Track(id: 2833834772, title: "360", artist: "Charli xcx", album: (597350882, "BRAT"), cover: "de9e79511cda59914de9add50946e43c", isExplicit: true),
            Track(id: 2302698185, title: "Bending Hectic", artist: "The Smile", album: (447073745, "Bending Hectic"), cover: "9b141e7d5d90de5d992601f92b00cd9c"),
            Track(id: 2525537871, title: "Houdini", artist: "Dua Lipa", album: (508032681, "Houdini"), cover: "12c05200e9097af48e0ad4fc259cee25"),
            Track(id: 908604612, title: "Blinding Lights", artist: "The Weeknd", album: (137217782, "After Hours"), cover: "fd00ebd6d30d7253f813dba3bb1c66a9"),
            Track(id: 672271572, title: "Eli", artist: "Bosnian Rainbows", album: (95104172, "Bosnian Rainbows"), cover: "718fe9a868eea0fb378c1ffe9163a176"),
        ]),
        Playlist(slug: "no-words", title: "Без слов", cover: "mockMyPlaylistNoWords", tracks: [
            Track(id: 29373661, title: "Roygbiv", artist: "Boards of Canada", album: (2795271, "Music Has The Right To Children"), cover: "c3c2e2a739ed501d01791b16a3fd9ad3"),
            Track(id: 29381041, title: "Dayvan Cowboy", artist: "Boards of Canada", album: (2795781, "The Campfire Headphase"), cover: "eddeaf610b6664d409346b06f23544b6"),
            Track(id: 29373691, title: "Olson", artist: "Boards of Canada", album: (2795271, "Music Has The Right To Children"), cover: "c3c2e2a739ed501d01791b16a3fd9ad3"),
            Track(id: 29377601, title: "Avril 14th", artist: "Aphex Twin", album: (2795561, "Drukqs"), cover: "9a07ccb5692aa410f99902bc9602b376"),
            Track(id: 138547595, title: "Treefingers", artist: "Radiohead", album: (14880741, "Kid A"), cover: "e5925065cdb1cefbc3bd75af4a1f1801"),
        ]),
        Playlist(slug: "louder", title: "Погромче", cover: "mockMyPlaylistLouder", tracks: [
            Track(id: 2202119247, title: "One Armed Scissor", artist: "At the Drive-In", album: (420206277, "Relationship of Command"), cover: "b0892516361122a4a153e96f78681b4c"),
            Track(id: 2309096, title: "The Widow", artist: "The Mars Volta", album: (230048, "Frances the Mute"), cover: "726d2777243de725313e5392fcb6f097"),
            Track(id: 1717942497, title: "Waiting Room", artist: "Fugazi", album: (310447807, "13 Songs"), cover: "581ec2884da760b9febdea49513f9e98"),
            Track(id: 7179758, title: "No One Knows", artist: "Queens of the Stone Age", album: (662259, "Songs For The Deaf"), cover: "ace9490e8fe0c7468b102aa5145fb766"),
        ]),
    ]

    static func playlist(entityID: String) -> Playlist? {
        all.first { $0.entityID == entityID }
    }

    /// Строки чипса «Мои» и превью карточки «Мои плейлисты». Id — тот же, что ставит
    /// экран плейлиста (`playlist-own-<slug>`): «нравится» с экрана — та же запись.
    /// Подпись — число треков: владелец — сам пользователь.
    static var items: [CollectionItem] {
        all.map { playlist in
            var item = CollectionItem.playlist(
                id: "playlist-\(playlist.entityID)",
                title: playlist.title,
                owner: "",
                cover: playlist.artwork
            )
            item.subtitle = CollectionCopy.tracks(playlist.tracks.count)
            return item
        }
    }

    /// Обложка альбома Deezer: 500 — строке, 1000 — плееру.
    static func coverURL(_ hash: String, size: Int) -> URL? {
        URL(string: "https://cdn-images.dzcdn.net/images/cover/\(hash)/\(size)x\(size)-000000-80-0-0.jpg")
    }
}

extension PlaylistDetails {
    /// Свой плейлист — без сети, из стартового набора.
    init(myPlaylist playlist: MyPlaylists.Playlist) {
        self.init(
            title: playlist.title,
            owner: "",
            tracks: playlist.tracks.map { track in
                Track(
                    id: track.id,
                    title: track.title,
                    artist: track.artist,
                    thumbnail: MyPlaylists.coverURL(track.cover, size: 500).map { .remote($0) },
                    cover: MyPlaylists.coverURL(track.cover, size: 1000).map { .remote($0) },
                    album: track.album.title,
                    isExplicit: track.isExplicit
                )
            }
        )
    }
}
