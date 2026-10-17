import SwiftUI

/// Айтем карусели музыки — то, что рисует `MusicCard`, и куда ведёт тап.
struct MusicItem: Identifiable {
    let id: String
    var shape: MusicCardShape = .square
    let title: String
    var subtitle: String? = nil
    let cover: ArtworkSource
    /// Аватар исполнителя под обложкой (Large).
    var avatar: ArtworkSource? = nil
    var isExplicit = false
    let route: EntityRoute?
    /// Что играет тап, когда своего экрана нет (трек без известного альбома).
    var playable: MusicNowPlaying? = nil
}

/// Блок «Похоже на …» (`card / music / artist block`): исполнитель, его фото и ряд похожих —
/// исполнители вперемешку с их альбомами, как в макете.
struct MusicArtistBlock: Identifiable {
    let id: String
    let name: String
    let photo: ArtworkSource
    let route: EntityRoute
    /// Фон карточки — тон фото исполнителя (в макете `#96834c` под Дельфина).
    let tone: Color?
    let items: [MusicItem]
    /// Что играет ▶: первый трек его альбома — очередь дособерёт бар (`fillQueueFromAlbum`).
    let track: MusicNowPlaying?
}

/// Живые данные витрины «Для вас» таба Музыки (задача пользователя 2026-10-17): блоки
/// «Похоже на …» по исполнителям пользователя и «Новые релизы» — свежие альбомы похожих.
/// Deezer, без квоты. Редакционные релизы и чарт альбомов Deezer из региона отдают
/// пустые списки (замер 2026-10-17), поэтому релизы собираются из дискографий похожих
/// исполнителей по дате выхода. Остальные секции «Для вас» — история пользователя
/// и моки макета (`MusicForYouFeed`).
///
/// Живёт в корне (`AppRootView`): экран таба размонтируется на каждом переключении.
/// Набор — свой на каждый холодный запуск, стабильный внутри процесса (`ShowcaseRotation`).
@MainActor
@Observable
final class MusicHomeCatalog {
    private(set) var blocks: [MusicArtistBlock] = []
    private(set) var releases: [MusicItem] = []
    private(set) var isLoaded = false
    @ObservationIgnored private var didStart = false

    private enum Limits {
        /// Блоков «Похоже на» — четыре, как в макете
        static let blocks = 4
        /// В ряду блока — девять: исполнители и альбомы вперемешку
        static let blockItems = 9
        /// Позиции альбомов в ряду блока (`artist, album, artist, artist, album, album, …`)
        static let blockAlbumSlots: Set<Int> = [1, 4, 5]
        static let related = 14
        static let releases = 8
    }

    func loadIfNeeded() async {
        guard !didStart else { return }
        didStart = true
        var rng = ShowcaseRotation.generator(salt: ShowcaseRotation.Salt.musicForYou)
        let seeds = Self.seedArtists(using: &rng)

        var built: [MusicArtistBlock] = []
        var circle: [DeezerArtistBrief] = []
        await withTaskGroup(of: (Int, MusicArtistBlock?, [DeezerArtistBrief]).self) { group in
            for (index, seed) in seeds.enumerated() {
                group.addTask { await (index, Self.block(for: seed), Self.relatedCircle(of: seed)) }
            }
            var results: [(Int, MusicArtistBlock?, [DeezerArtistBrief])] = []
            for await result in group { results.append(result) }
            for (_, block, related) in results.sorted(by: { $0.0 < $1.0 }) {
                if let block { built.append(block) }
                circle.append(contentsOf: related)
            }
        }
        blocks = Array(built.prefix(Limits.blocks))
        releases = await Self.releases(from: circle)
        isLoaded = true

        // Фото блоков и обложки релизов — заранее: лента встаёт сразу с картинками.
        ArtworkLoader.shared.preload(blocks.map(\.photo) + releases.prefix(3).map(\.cover))
    }

    // MARK: - Затравки

    /// Исполнители пользователя — из «Моего» и ряда ПП, — дальше сиды витрины вперемешку.
    /// Затравок с запасом: у части исполнителей Deezer не отдаёт фото или похожих.
    private static func seedArtists(using rng: inout SeededGenerator) -> [Int] {
        var ids: [Int] = []
        func add(_ route: EntityRoute?) {
            guard case .artist(let ref) = route, let id = ref.deezerID, !ids.contains(id) else { return }
            ids.append(id)
        }
        for item in CollectionStore.shared.items where item.kind == .artist { add(item.route) }
        let seeds = ShowcaseSeeds.musicArtists.map(\.id).shuffled(using: &rng)
        for id in seeds where !ids.contains(id) { ids.append(id) }
        return Array(ids.prefix(Limits.blocks + 2))
    }

    // MARK: - Блок «Похоже на»

    private nonisolated static func block(for seedID: Int) async -> MusicArtistBlock? {
        let deezer = DeezerService.shared
        guard let artist = try? await deezer.artist(id: seedID), artist.hasPhoto,
              let photoURL = (artist.pictureXl ?? artist.pictureBig).flatMap(URL.init(string:)),
              let related = try? await deezer.relatedArtists(id: seedID, limit: Limits.related)
        else { return nil }
        let withPhoto = related.filter(\.hasPhoto)
        guard withPhoto.count >= Limits.blockItems else { return nil }

        // Альбомы — у похожих на местах альбомов; не нашлось — на месте стоит исполнитель.
        var items: [MusicItem] = []
        for (index, other) in withPhoto.prefix(Limits.blockItems).enumerated() {
            if Limits.blockAlbumSlots.contains(index),
               let album = try? await deezer.artistAlbums(id: other.id, limit: 10).first(where: isShowcaseAlbum) {
                items.append(albumItem(album, artist: other, coverSize: .big))
            } else {
                items.append(artistItem(other))
            }
        }

        let photo = ArtworkSource.remote(photoURL)
        let tone = await ArtworkLoader.shared.backdropTone(for: photoURL)
        let route = EntityRoute.artist(EntityRef(id: "dz-\(artist.id)", title: artist.name, subtitle: "", artwork: photo))
        return MusicArtistBlock(
            id: "similar-\(artist.id)",
            name: artist.name,
            photo: photo,
            route: route,
            tone: tone,
            items: items,
            track: await firstTrack(of: artist, photo: photo)
        )
    }

    /// Первый трек первого альбома — ▶ блока. Очередь альбома дособерёт бар.
    private nonisolated static func firstTrack(of artist: DeezerArtistBrief, photo: ArtworkSource) async -> MusicNowPlaying? {
        let deezer = DeezerService.shared
        guard let album = try? await deezer.artistAlbums(id: artist.id, limit: 10).first(where: isShowcaseAlbum),
              let track = try? await deezer.albumTracks(id: album.id, limit: 1).first,
              let cover = (album.coverXl ?? album.coverBig).flatMap(URL.init(string:))
        else { return nil }
        return MusicNowPlaying(
            id: "dz-\(album.id)-t\(track.id)",
            cover: .remote(cover),
            title: track.titleShort ?? track.title,
            artist: artist.name,
            album: album.title,
            artistPicture: photo,
            containerID: "album:dz-\(album.id)"
        )
    }

    private nonisolated static func relatedCircle(of seedID: Int) async -> [DeezerArtistBrief] {
        (try? await DeezerService.shared.relatedArtists(id: seedID, limit: Limits.related))?.filter(\.hasPhoto) ?? []
    }

    // MARK: - Новые релизы

    /// Свежий альбом у каждого из круга похожих — и самые свежие из них.
    private nonisolated static func releases(from circle: [DeezerArtistBrief]) async -> [MusicItem] {
        var seen = Set<Int>()
        let artists = circle.filter { seen.insert($0.id).inserted }.prefix(Limits.releases * 2)
        var latest: [(album: DeezerAlbumBrief, artist: DeezerArtistBrief)] = []
        await withTaskGroup(of: (DeezerAlbumBrief, DeezerArtistBrief)?.self) { group in
            for artist in artists {
                group.addTask {
                    guard let albums = try? await DeezerService.shared.artistAlbums(id: artist.id, limit: 25) else { return nil }
                    let newest = albums.filter(isShowcaseAlbum).max { ($0.releaseDate ?? "") < ($1.releaseDate ?? "") }
                    return newest.map { ($0, artist) }
                }
            }
            for await pair in group {
                if let pair { latest.append(pair) }
            }
        }
        return latest
            .sorted { ($0.album.releaseDate ?? "") > ($1.album.releaseDate ?? "") }
            .prefix(Limits.releases)
            .map { pair in
                var item = albumItem(pair.album, artist: pair.artist, coverSize: .xl)
                item.avatar = (pair.artist.pictureBig ?? pair.artist.pictureMedium).flatMap(URL.init(string:)).map { .remote($0) }
                return item
            }
    }

    // MARK: - Айтемы

    private enum CoverSize { case big, xl }

    private nonisolated static func albumItem(_ album: DeezerAlbumBrief, artist: DeezerArtistBrief, coverSize: CoverSize) -> MusicItem {
        let raw = coverSize == .xl ? (album.coverXl ?? album.coverBig) : (album.coverBig ?? album.coverXl)
        let cover = raw.flatMap(URL.init(string:)).map { ArtworkSource.remote($0) } ?? .asset("mockAlbumCover")
        return MusicItem(
            id: "album-\(album.id)",
            title: album.title,
            subtitle: artist.name,
            cover: cover,
            isExplicit: album.explicitLyrics ?? false,
            route: .album(EntityRef(id: "dz-\(album.id)", title: album.title, subtitle: artist.name, artwork: cover))
        )
    }

    private nonisolated static func artistItem(_ artist: DeezerArtistBrief) -> MusicItem {
        let photo = (artist.pictureBig ?? artist.pictureXl).flatMap(URL.init(string:)).map { ArtworkSource.remote($0) }
            ?? .asset("mockAvatar")
        return MusicItem(
            id: "artist-\(artist.id)",
            shape: .circle,
            title: artist.name,
            cover: photo,
            route: .artist(EntityRef(id: "dz-\(artist.id)", title: artist.name, subtitle: "", artwork: photo))
        )
    }

    /// Альбом для витрины — студийный, с обложкой, без сборников и концертников
    /// (тот же фильтр, что у «Главной»: `ShowcaseCatalog.isShowcaseAlbum`).
    private nonisolated static func isShowcaseAlbum(_ album: DeezerAlbumBrief) -> Bool {
        ShowcaseCatalog.isShowcaseAlbum(album)
    }
}
