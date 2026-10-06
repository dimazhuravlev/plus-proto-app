import SwiftUI

/// Роль персоны на её экране — один экран на три (`PersonScreen`).
enum PersonRole {
    case artist, director, writer
}

/// Данные экрана персоны (задача пользователя 2026-10-04):
/// - **исполнитель** — Deezer: популярные треки, альбомы, похожие исполнители;
/// - **режиссёр** — Кинопоиск: фильмография персоны, отобранная по профессии
///   у каждого тайтла, и постеры одной пачкой (2–3 запроса из суточной квоты,
///   повторное открытие — из `URLCache`);
/// - **писатель** — Google Books: книги автора тем же приёмом, что «Книги писателя».
@MainActor
@Observable
final class PersonStore {
    struct Track: Identifiable, Hashable {
        let id: Int
        let title: String
        let artist: String
        let album: String?
        let cover: ArtworkSource?
        let isExplicit: Bool
    }

    /// Фото из API — если маршрут пришёл без своего (писатель с экрана книги,
    /// режиссёр без фото в Википедии).
    private(set) var photo: ArtworkSource?
    private(set) var tracks: [Track] = []
    /// Альбомы исполнителя — строки выдачи (`SearchHit`) с маршрутами на экран альбома.
    private(set) var albums: [SearchHit] = []
    /// Альбомы с бейджем explicit — по id строки.
    private(set) var explicitAlbums: Set<String> = []
    /// Что включает «Слушать» исполнителя — первый трек первого альбома из списка
    /// (правка пользователя 2026-10-04). Готовится вместе с экраном: кнопка не ждёт сети.
    private(set) var listenTarget: MusicNowPlaying?
    private(set) var similar: [SearchHit] = []
    /// Фильмы режиссёра или книги писателя — плоский список, ячейки полной выдачи.
    private(set) var works: [SearchHit] = []
    /// Ответ пришёл (пустой — тоже): скелетоны сменяются контентом или уходят.
    private(set) var isLoaded = false

    func load(role: PersonRole, entity: EntityRef) async {
        guard !isLoaded else { return }
        switch role {
        case .artist: await loadArtist(entity)
        case .director: await loadDirector(entity)
        case .writer: await loadWriter(entity)
        }
        guard !Task.isCancelled else { return }
        isLoaded = true
    }

    // MARK: - Исполнитель

    private func loadArtist(_ entity: EntityRef) async {
        guard let id = entity.deezerID else { return }
        async let top = try? DeezerService.shared.artistTop(id: id, limit: 15)
        async let discography = try? DeezerService.shared.artistAlbums(id: id, limit: 50)
        async let related = try? DeezerService.shared.relatedArtists(id: id, limit: 20)
        let (chart, albumsRaw, relatedRaw) = await (top ?? [], discography ?? [], related ?? [])
        guard !Task.isCancelled else { return }
        // `/artist/{id}/top` из России отвечает пустым списком (замер 2026-10-04: и у The
        // Weeknd, и у Daft Punk `total: 0`), а поиск работает: треки по имени, только
        // его собственные, по популярности Deezer, без повторов названий.
        var topTracks = chart
        if topTracks.isEmpty {
            var seen = Set<String>()
            topTracks = ((try? await DeezerService.shared.searchTracks(query: entity.title, limit: 50)) ?? [])
                .filter { $0.artist?.id == id }
                .sorted { ($0.rank ?? 0) > ($1.rank ?? 0) }
                .filter { seen.insert($0.title.lowercased()).inserted }
                .prefix(Self.topTracksLimit)
                .map { $0 }
        }

        // Фото — из маршрута; нет своего — из профиля исполнителя.
        if entity.artwork.remoteURL == nil,
           let artist = try? await DeezerService.shared.artist(id: id),
           let picture = (artist.pictureXl ?? artist.pictureBig)?.deezerUpscaled {
            photo = .remote(picture)
        }
        tracks = topTracks.map { track in
            Track(
                id: track.id,
                title: track.title,
                artist: track.artist?.name ?? entity.title,
                album: track.album?.title,
                cover: (track.album?.coverXl ?? track.album?.coverBig ?? track.album?.coverMedium)?
                    .deezerUpscaled.map { .remote($0) },
                isExplicit: track.explicitLyrics ?? false
            )
        }

        // Студийные альбомы первыми, свежие раньше; дальше EP и синглы. Переиздания
        // одного названия — одной карточкой.
        var seenTitles = Set<String>()
        let picked = albumsRaw
            .sorted { lhs, rhs in
                let left = Self.recordRank(lhs.recordType), right = Self.recordRank(rhs.recordType)
                if left != right { return left < right }
                return (lhs.releaseDate ?? "") > (rhs.releaseDate ?? "")
            }
            .filter { seenTitles.insert($0.title.lowercased()).inserted }
            .prefix(Self.albumsLimit)
        explicitAlbums = Set(picked.filter { $0.explicitLyrics == true }.map { "album-\($0.id)" })
        albums = picked
            .map { album in
                // Без бандленного фолбэка: пока обложка едет, под ней скелетон, а не
                // моковый чужой альбом (жалоба пользователя 2026-10-04).
                let cover = (album.coverXl ?? album.coverBig ?? album.coverMedium)?.deezerUpscaled
                    .map { ArtworkSource.remote($0) }
                // Ссылка на альбом: `title` — альбом, `subtitle` — исполнитель.
                return SearchHit(
                    id: "album-\(album.id)",
                    kind: .album,
                    title: album.title,
                    subtitle: album.releaseDate.map { String($0.prefix(4)) } ?? "",
                    artwork: cover,
                    route: .album(EntityRef(
                        id: "dz-\(album.id)",
                        title: album.title,
                        subtitle: entity.title,
                        artwork: cover ?? .asset("")
                    ))
                )
            }

        if let first = picked.first,
           let track = try? await DeezerService.shared.albumTracks(id: first.id, limit: 1).first {
            let year = first.releaseDate.map { String($0.prefix(4)) }
            listenTarget = MusicNowPlaying(
                // id — как у треков на экране альбома (`dz-<альбом>-t<трек>`): открой
                // пользователь этот альбом, его пилюля тоже покажет «Пауза».
                id: "dz-\(first.id)-t\(track.id)",
                cover: albums.first?.artwork ?? entity.artwork,
                title: track.titleShort ?? track.title,
                artist: entity.title,
                album: first.title,
                year: year,
                artistPicture: entity.artwork.remoteURL != nil ? entity.artwork : photo,
                isExplicit: track.explicitLyrics ?? false
            )
        }

        similar = relatedRaw
            .filter(\.hasPhoto)
            .prefix(Self.similarLimit)
            .map { artist in
                let picture = (artist.pictureXl ?? artist.pictureBig ?? artist.pictureMedium)?.deezerUpscaled
                    .map { ArtworkSource.remote($0) }
                return SearchHit(
                    id: "artist-\(artist.id)",
                    kind: .artist,
                    title: artist.name,
                    subtitle: "",
                    artwork: picture,
                    route: .artist(EntityRef(
                        id: "dz-\(artist.id)",
                        title: artist.name,
                        subtitle: "",
                        artwork: picture ?? .asset("")
                    ))
                )
            }
    }

    private static let topTracksLimit = 15
    private static let albumsLimit = 20
    private static let similarLimit = 15

    private static func recordRank(_ type: String?) -> Int {
        switch type {
        case "album": 0
        case "ep": 1
        default: 2
        }
    }

    // MARK: - Режиссёр

    private func loadDirector(_ entity: EntityRef) async {
        // Пустой ключ Кинопоиска — не ошибка: витрина живёт на моках, сеть не трогаем.
        guard APIKeysCheck.isKinopoiskConfigured else { return }
        var personID = entity.kinopoiskID
        if personID == nil {
            // Из выдачи поиска у персоны только имя (Википедия): ищем по нему.
            // Однофамильцев несколько, и первый часто без фото — берём совпадение
            // имени с фото, потом просто совпадение имени.
            let hits = (try? await KinopoiskService.shared.searchPersons(query: entity.title)) ?? []
            let exact = hits.filter { Self.sameName($0.name ?? $0.enName ?? "", entity.title) }
            personID = (exact.first(where: \.hasPhoto) ?? exact.first ?? hits.first(where: \.hasPhoto))?.id
        }
        guard let personID,
              let person = try? await KinopoiskService.shared.person(id: personID),
              !Task.isCancelled
        else { return }
        if entity.artwork.remoteURL == nil, let url = person.photoURL {
            photo = .remote(url)
        }

        var seen = Set<Int>()
        let directed = (person.movies ?? [])
            .filter { $0.enProfession == "director" && seen.insert($0.id).inserted }
            .map(\.id)
        let movies = (try? await KinopoiskService.shared.moviesBrief(ids: directed)) ?? []
        guard !Task.isCancelled else { return }

        let showable = movies
            .filter { $0.poster?.url(size: .small) != nil && !$0.displayTitle.isEmpty }
            .sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        works = showable.map(Self.hit(movie:))
    }

    private static func sameName(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Строка фильма — как в выдаче поиска: постер через прокси tmdb, год подписью.
    private static func hit(movie: KinopoiskMovie) -> SearchHit {
        let raw = movie.poster?.url(size: .small)
        let poster = raw.flatMap { TMDBImageProxy.rewrite($0, width: 300) } ?? raw
        return SearchHit(
            id: "movie-\(movie.id)",
            kind: .movie,
            title: movie.displayTitle,
            subtitle: movie.year.map { "\($0)" } ?? "",
            artwork: poster.map { .remote($0) },
            route: .movie(EntityRef(
                id: "kp-\(movie.id)",
                title: movie.displayTitle,
                subtitle: "",
                artwork: poster.map { ArtworkSource.remote($0) } ?? .asset("mockMoviePoster")
            ))
        )
    }

    // MARK: - Писатель

    private func loadWriter(_ entity: EntityRef) async {
        let name = entity.title
        let surname = name.split(separator: " ").last.map(String.init) ?? name
        let needsPortrait = entity.artwork.remoteURL == nil
        async let search = try? BooksService.shared.search(name, limit: 40)
        async let portrait: URL? = needsPortrait ? WikipediaPeople.shared.portrait(of: name) : nil
        let (volumes, portraitURL) = await (search ?? [], portrait)
        guard !Task.isCancelled else { return }
        if let portraitURL { photo = .remote(portraitURL) }

        // Его собственные тома: выдача по имени наполовину о нём (биографии, пособия),
        // издания одной книги — одной строкой.
        var seenTitles = Set<String>()
        let own = volumes.filter { volume in
            guard (volume.volumeInfo.authors ?? []).contains(where: { $0.localizedCaseInsensitiveContains(surname) }),
                  !volume.title.isEmpty,
                  volume.coverURL != nil
            else { return false }
            return seenTitles.insert(volume.title.lowercased()).inserted
        }
        works = own.compactMap { volume in
            guard let cover = volume.coverURL else { return nil }
            return SearchHit(
                id: "book-\(volume.id)",
                kind: .book,
                title: volume.title,
                // Автор у всех строк один — подписью год издания.
                subtitle: volume.volumeInfo.publishedDate.map { String($0.prefix(4)) } ?? "",
                artwork: .remote(cover),
                route: .book(EntityRef(
                    id: "gb-\(volume.id)",
                    title: volume.title,
                    subtitle: name,
                    artwork: .remote(cover)
                ))
            )
        }
    }
}
