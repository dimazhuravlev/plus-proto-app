import Foundation

/// Модель экрана альбома, готовая к показу. Вся возня с DTO — здесь, вью только
/// раскладывает строки (тот же принцип, что `MovieDetails`): факты не выдумываем,
/// нет поля в API — нет и строки на экране.
struct AlbumDetails {
    struct Track: Identifiable {
        let id: Int
        /// Позиция на своём диске — колонка номера в треклисте
        let number: Int
        let disk: Int
        let title: String
        /// «Extended Version» и подобное — вторая строка. `nil` — строка одна.
        let subtitle: String?
        let isExplicit: Bool
    }

    struct OtherAlbum: Identifiable {
        let id: Int
        let title: String
        let year: String?
        let cover: ArtworkSource
        let isExplicit: Bool
    }

    let title: String
    let artist: String
    let year: String?
    /// Фото артиста из `/album/{id}.artist` — аватар в шапке
    let artistPicture: ArtworkSource
    /// Треки, сгруппированные по дискам: `disks[0]` — первый диск. Экран склеивает
    /// группы в один список — заголовок «Диск N» убран (правка пользователя
    /// 2026-08-29), но группировка нужна порядку: у Deezer позиция трека считается
    /// внутри своего диска.
    let disks: [[Track]]
    let others: [OtherAlbum]

    /// Сколько альбомов влезает в «Другие альбомы»: карусель не листается до конца
    /// дискографии, дальше жил бы экран «все альбомы» — его в прототипе нет.
    private static let othersLimit = 10

    init(album: DeezerAlbum, tracks: [DeezerAlbumTrack], otherAlbums: [DeezerAlbumBrief]) {
        title = album.title
        artist = album.artist?.name ?? ""
        year = Self.year(from: album.releaseDate)
        artistPicture = Self.artwork(
            from: album.artist?.pictureXl ?? album.artist?.pictureBig ?? album.artist?.pictureMedium,
            fallback: "mockAvatar"
        )

        let grouped = Dictionary(grouping: tracks) { $0.diskNumber ?? 1 }
        disks = grouped.keys.sorted().map { disk in
            grouped[disk, default: []].enumerated().map { index, track in
                Track(
                    id: track.id,
                    // Позиция из API, а не порядковый номер: у Deezer встречаются
                    // издания с пропусками (бонус-треки выпилены из выдачи).
                    number: track.trackPosition ?? index + 1,
                    disk: disk,
                    title: track.titleShort ?? track.title,
                    subtitle: Self.nonEmpty(Self.trimmedVersion(track.titleVersion)),
                    isExplicit: track.explicitLyrics ?? false
                )
            }
        }

        // Дискография приходит с синглами, компиляциями и переизданиями одного
        // названия — оставляем альбомы, убираем текущий и дубли по названию.
        var seenTitles = Set<String>()
        others = otherAlbums
            .filter { $0.id != album.id && ($0.recordType ?? "album") == "album" }
            .filter { seenTitles.insert($0.title.lowercased()).inserted }
            .prefix(Self.othersLimit)
            .map { brief in
                OtherAlbum(
                    id: brief.id,
                    title: brief.title,
                    year: Self.year(from: brief.releaseDate),
                    cover: Self.artwork(
                        from: brief.coverXl ?? brief.coverBig ?? brief.coverMedium,
                        fallback: "mockAlbumCover"
                    ),
                    isExplicit: brief.explicitLyrics ?? false
                )
            }
    }

    private init(
        title: String,
        artist: String,
        year: String?,
        artistPicture: ArtworkSource,
        disks: [[Track]],
        others: [OtherAlbum]
    ) {
        self.title = title
        self.artist = artist
        self.year = year
        self.artistPicture = artistPicture
        self.disks = disks
        self.others = others
    }

    /// Пока ответ едет — только то, что витрина уже знает. Для моковой витрины
    /// (`mock: true`) — треклист и дискография из макета `2079:11226`, чтобы
    /// `-debugMockFeed` давал экран для сверки вёрстки без сети.
    static func placeholder(for entity: EntityRef, mock: Bool) -> AlbumDetails {
        // Семантика `EntityRef` альбома перевёрнута витриной: `title` — артист,
        // `subtitle` — название альбома (см. `ShowcaseCatalog`).
        let albumTitle = entity.subtitle.isEmpty ? entity.title : entity.subtitle
        let artistName = entity.subtitle.isEmpty ? "" : entity.title

        guard mock else {
            return AlbumDetails(
                title: albumTitle,
                artist: artistName,
                year: nil,
                artistPicture: .asset("mockAvatar"),
                disks: [],
                others: []
            )
        }

        let mockTracks: [Track] = [
            Track(id: 1, number: 1, disk: 1, title: "Generals", subtitle: nil, isExplicit: false),
            Track(id: 2, number: 2, disk: 1, title: "Rain On Tin", subtitle: "Extended Version", isExplicit: false),
            Track(id: 3, number: 3, disk: 1, title: "How Do You?", subtitle: nil, isExplicit: true),
            Track(id: 4, number: 4, disk: 1, title: "Drone", subtitle: "feat. At the Drive-In, Weating", isExplicit: false),
            Track(id: 5, number: 5, disk: 1, title: "Joe le Taxi", subtitle: nil, isExplicit: false),
        ]
        let mockOthers: [OtherAlbum] = [
            OtherAlbum(id: 1, title: "Midnight", year: "2024", cover: .asset("mockAlbumCover"), isExplicit: true),
            OtherAlbum(id: 2, title: "Evermore", year: "2020", cover: .asset("mockAlbumCover"), isExplicit: false),
            OtherAlbum(id: 3, title: "Lover", year: "2020", cover: .asset("mockAlbumCover"), isExplicit: false),
            OtherAlbum(id: 4, title: "Reputation", year: "2019", cover: .asset("mockAlbumCover"), isExplicit: false),
            OtherAlbum(id: 5, title: "1989", year: "2017", cover: .asset("mockAlbumCover"), isExplicit: false),
            OtherAlbum(id: 6, title: "Speak Now", year: "2016", cover: .asset("mockAlbumCover"), isExplicit: false),
        ]
        return AlbumDetails(
            title: albumTitle,
            artist: artistName,
            year: "2014",
            artistPicture: .asset("mockAvatar"),
            disks: [mockTracks],
            others: mockOthers
        )
    }

    // MARK: - Форматирование

    private static func year(from releaseDate: String?) -> String? {
        guard let releaseDate, releaseDate.count >= 4 else { return nil }
        return String(releaseDate.prefix(4))
    }

    /// Deezer оборачивает версию в скобки — «(Extended Version)», в макете их нет.
    private static func trimmedVersion(_ version: String?) -> String? {
        guard var version = version?.trimmingCharacters(in: .whitespaces) else { return nil }
        if version.hasPrefix("(") && version.hasSuffix(")") {
            version = String(version.dropFirst().dropLast())
        }
        return version
    }

    private static func nonEmpty(_ string: String?) -> String? {
        guard let string, !string.isEmpty else { return nil }
        return string
    }

    private static func artwork(from urlString: String?, fallback: String) -> ArtworkSource {
        guard let url = urlString?.deezerUpscaled else { return .asset(fallback) }
        return .remote(url, fallback: fallback)
    }
}
