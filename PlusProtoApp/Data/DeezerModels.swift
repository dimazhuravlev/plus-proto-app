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
    /// Число фанатов — приходит только у `/search/artist`. Вес исполнителя
    /// в ранжировании секций поиска.
    let nbFan: Int?
    /// Число альбомов — тоже из `/search/artist`. Без альбомов исполнитель
    /// не годится в колдунщик полной выдачи.
    let nbAlbum: Int?

    /// Есть ли у исполнителя своё фото. Deezer и без фото отдаёт ссылку — на серый
    /// силуэт, с пустым сегментом вместо хеша: `…/images/artist//1000x1000-….jpg`
    /// (замер 2026-10-03). Такие исполнители в выдачу не идут (правка пользователя).
    var hasPhoto: Bool {
        guard let url = pictureXl ?? pictureBig ?? pictureMedium else { return false }
        return !url.contains("/artist//")
    }
}

/// Плейлист из `/search/playlist` — строка полной выдачи музыки.
struct DeezerPlaylistBrief: Decodable, Identifiable {
    let id: Int
    let title: String
    let pictureBig: String?
    let pictureXl: String?
    let user: Owner?

    struct Owner: Decodable {
        let name: String?
    }
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
    /// `/artist/{id}/albums` отдаёт дату и флаг explicit — экрану альбома нужны
    /// год в подписи карточки и бейдж. В `/search/album` этих полей нет, поля опциональны.
    let releaseDate: String?
    let explicitLyrics: Bool?
}

/// Трек из `/album/{id}/tracks`. Отдельный тип, а не расширение `DeezerTrack`:
/// у трека альбома есть позиция и номер диска, но нет вложенного `album`.
struct DeezerAlbumTrack: Decodable, Identifiable {
    let id: Int
    let title: String
    /// Название без версии — «Rain On Tin» против полного «Rain On Tin (Extended Version)»
    let titleShort: String?
    /// «Extended Version», «Remastered» — вторая строка в треклисте
    let titleVersion: String?
    let trackPosition: Int?
    let diskNumber: Int?
    let explicitLyrics: Bool?
}

/// Трек из `/search/track`. От `DeezerAlbumTrack` отличается тем, что несёт свой
/// альбом и исполнителя: в выдаче поиска трек живёт сам по себе, вне треклиста.
struct DeezerTrackHit: Decodable, Identifiable {
    let id: Int
    let title: String
    let artist: DeezerArtistBrief?
    let album: DeezerAlbumBrief?
    /// Популярность трека у Deezer, 0…1 000 000. Нужна ранжированию секций поиска:
    /// у культового трека и у кавера с тем же названием совпадает всё, кроме неё.
    let rank: Int?
    /// Флаг explicit — приходит у `/artist/{id}/top` (бейдж в «Популярных треках»).
    let explicitLyrics: Bool?
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
