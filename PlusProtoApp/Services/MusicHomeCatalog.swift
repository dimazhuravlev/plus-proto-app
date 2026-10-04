import Foundation

/// Главная Музыки — «Моя волна» (макет `generator`, файл Music `13668:68497`): станции
/// и треки под ней (задача пользователя 2026-10-04).
///
/// Живёт в корне приложения, как каталоги витрины и Кинопоиска: экран таба
/// размонтируется на переключении, а данные собираются раз за процесс.
///
/// **Треки** — глобальный «Top Worldwide» Deezer: чарт Deezer привязан к стране и отсюда
/// отдаёт сербскую эстраду (замер 2026-10-04). **Станции** — исполнители с фото
/// из Deezer и настроения текстом, как в макете.
@MainActor
@Observable
final class MusicHomeCatalog {
    struct Track: Identifiable, Equatable {
        let id: String
        let title: String
        let artist: String
        let cover: ArtworkSource?
        let nowPlaying: MusicNowPlaying
    }

    /// Чип станции: исполнитель с фото или настроение без него.
    struct Station: Identifiable, Equatable {
        let id: String
        let title: String
        /// Фото исполнителя. `nil` у настроения — чип текстом.
        var photo: ArtworkSource?
        let isArtist: Bool
    }

    private(set) var tracks: [Track] = []
    private(set) var stations: [Station] = MusicHomeCatalog.seedStations
    /// Треки пришли (или упали на моки) — скелетоны сменяются лентой.
    private(set) var isLoaded = false
    private var didStart = false

    /// «Моя волна» в баре — тот же id, что у блока витрины: включить её с витрины
    /// и с главной Музыки — одно и то же, и повторный тап ставит на паузу.
    static let vibeID = "my-vibe"

    /// Станции макета, по-русски. У исполнителей — id Deezer, фото приезжает по нему.
    private static let stationSeeds: [(title: String, deezerID: Int?)] = [
        ("Taylor Swift", 12246),
        ("Энергичное", nil),
        ("Radiohead", 399),
        ("Джаз", nil),
        ("Русский рэп", nil),
        ("The Weeknd", 4050205),
        ("Спокойное", nil),
        ("Daft Punk", 27),
    ]

    private static var seedStations: [Station] {
        stationSeeds.map { Station(id: "station-\($0.title)", title: $0.title, photo: nil, isArtist: $0.deezerID != nil) }
    }

    /// Top Worldwide
    private static let playlistID = 3_155_776_842
    /// Пять колонок по три строки
    static let trackLimit = 15

    func loadIfNeeded() async {
        guard !didStart else { return }
        didStart = true

        #if DEBUG
        if UserDefaults.standard.bool(forKey: "debugMockFeed") {
            tracks = Self.mockTracks
            isLoaded = true
            return
        }
        #endif

        async let playlist = try? DeezerService.shared.playlist(id: Self.playlistID)
        var photos: [String: ArtworkSource] = [:]
        for seed in Self.stationSeeds {
            guard let id = seed.deezerID,
                  let artist = try? await DeezerService.shared.artist(id: id),
                  artist.hasPhoto,
                  let url = (artist.pictureXl ?? artist.pictureBig ?? artist.pictureMedium)?.deezerUpscaled
            else { continue }
            photos[seed.title] = .remote(url)
        }
        stations = stations.map { station in
            var station = station
            station.photo = photos[station.title]
            return station
        }

        let live = (await playlist)?.tracks?.data ?? []
        let built = live.prefix(Self.trackLimit).map(Self.track)
        tracks = built.isEmpty ? Self.mockTracks : Array(built)
        ArtworkLoader.shared.preload(stations.compactMap(\.photo) + tracks.prefix(6).compactMap(\.cover))
        isLoaded = true
    }

    private static func track(_ track: DeezerTrack) -> Track {
        let cover = (track.album?.coverXl ?? track.album?.coverBig)?.deezerUpscaled.map { ArtworkSource.remote($0) }
        let artist = track.artist?.name ?? ""
        return Track(
            id: "dz-track-\(track.id)",
            title: track.title,
            artist: artist,
            cover: cover,
            nowPlaying: MusicNowPlaying(
                id: "dz-track-\(track.id)",
                cover: cover ?? .asset("mockPlayerCover"),
                title: track.title,
                artist: artist,
                album: track.album?.title
            )
        )
    }

    /// Без сети — очередь «Что дальше» плеера, по кругу до пятнадцати строк.
    private static var mockTracks: [Track] {
        (0..<trackLimit).map { index in
            let item = MusicQueue.items[index % MusicQueue.items.count]
            return Track(
                id: "\(item.id)-\(index)",
                title: item.title,
                artist: item.artist,
                cover: item.cover,
                nowPlaying: item.nowPlaying
            )
        }
    }
}
