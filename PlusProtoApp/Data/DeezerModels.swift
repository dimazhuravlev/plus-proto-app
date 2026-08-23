import Foundation

/// DTO Deezer. Порт из MusicPlayer, сокращённый до того, что нужно витрине:
/// альбом (обложка + название + исполнитель) и плейлист как источник подборки.
/// Декодер настроен на `convertFromSnakeCase`, поэтому `cover_xl` → `coverXl`.

// MARK: - Обёртка выдачи

struct DeezerListResponse<T: Decodable>: Decodable {
    let data: [T]
    let total: Int?
    let next: String?
}

// MARK: - Artist

struct DeezerArtistBrief: Decodable, Identifiable {
    let id: Int
    let name: String
    let pictureMedium: String?
    let pictureBig: String?
    let pictureXl: String?
}

// MARK: - Album

struct DeezerAlbumBrief: Decodable, Identifiable {
    let id: Int
    let title: String
    let coverMedium: String?
    let coverBig: String?
    let coverXl: String?
    let artist: DeezerArtistBrief?
    let recordType: String?
    let nbTracks: Int?
}

struct DeezerAlbum: Decodable, Identifiable {
    let id: Int
    let title: String
    let coverBig: String?
    let coverXl: String?
    let releaseDate: String?
    let recordType: String?
    let nbTracks: Int?
    let artist: DeezerArtistBrief?
}

// MARK: - Playlist

struct DeezerPlaylistTrackAlbum: Decodable {
    let id: Int
    let title: String?
    let coverBig: String?
    let coverXl: String?
}

struct DeezerTrack: Decodable, Identifiable {
    let id: Int
    let title: String
    let preview: String?
    let artist: DeezerArtistBrief?
    let album: DeezerPlaylistTrackAlbum?
}

struct DeezerPlaylist: Decodable, Identifiable {
    let id: Int
    let title: String
    let pictureBig: String?
    let pictureXl: String?
    let tracks: DeezerListResponse<DeezerTrack>?
}

// MARK: - Апскейл обложек

extension String {
    /// Deezer отдаёт CDN-ссылки вида `…/500x500-000000-80-0-0.jpg`. Витрине нужна
    /// обложка 180pt при ×3 = 540px, поэтому поднимаем до 1000×1000 подменой сегмента —
    /// тот же приём `xlURL()`, что в `ContentCurationManager` MusicPlayer.
    var deezerUpscaled: URL? {
        let big = replacingOccurrences(
            of: #"/\d+x\d+-"#,
            with: "/1000x1000-",
            options: .regularExpression
        )
        return URL(string: big)
    }
}
