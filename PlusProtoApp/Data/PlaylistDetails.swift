import Foundation

/// Модель экрана плейлиста, готовая к показу, — по шаблону `AlbumDetails`: вся возня
/// с DTO здесь, вью только раскладывает строки.
struct PlaylistDetails {
    struct Track: Identifiable {
        let id: Int
        let title: String
        let artist: String
        /// Обложка альбома трека — в строке треклиста: треки плейлиста из разных
        /// альбомов (задача пользователя 2026-10-05). Своя, 500 px — строке 48 pt
        /// на ×3 хватает, полноразмерная тянула бы память на сотне строк.
        let thumbnail: ArtworkSource?
        /// Та же обложка во весь размер — для плеера, у него она большая.
        let cover: ArtworkSource?
        let album: String?
        let isExplicit: Bool
    }

    let title: String
    /// Владелец плейлиста — подпись карточек и коллекции; на экране не показывается.
    let owner: String
    let tracks: [Track]

    /// Сколько треков на экране: у редакционных плейлистов их бывает за сотню, а
    /// полного списка с подгрузкой в прототипе нет.
    private static let tracksLimit = 100

    init(playlist: DeezerPlaylist) {
        title = playlist.title
        owner = playlist.creator?.name ?? ""
        tracks = (playlist.tracks?.data ?? []).prefix(Self.tracksLimit).map { track in
            let album = track.album
            return Track(
                id: track.id,
                title: track.titleShort ?? track.title,
                artist: track.artist?.name ?? "",
                thumbnail: (album?.coverBig ?? album?.coverXl).flatMap(URL.init(string:)).map { .remote($0) },
                cover: (album?.coverXl ?? album?.coverBig)?.deezerUpscaled.map { .remote($0) },
                album: album?.title,
                isExplicit: track.explicitLyrics ?? false
            )
        }
    }

    private init(title: String, owner: String, tracks: [Track]) {
        self.title = title
        self.owner = owner
        self.tracks = tracks
    }

    /// Пока ответ едет — то, что знает карточка, с которой открыли: название и владелец.
    static func placeholder(for entity: EntityRef) -> PlaylistDetails {
        PlaylistDetails(title: entity.title, owner: entity.subtitle, tracks: [])
    }
}
